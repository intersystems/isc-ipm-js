/// AppS.CCR.AngularCCREventHandler, but modified for Package Manager use
Class pkg.isc.ipm.js.angular.processor Extends %ZPM.PackageManager.Developer.Processor.Abstract
{

/// Description of resource processor class (shown in UI)
Parameter DESCRIPTION As STRING = "Runs npm install and Angular 6+ builds in a specified directory.";

/// Comma-separated list of resource attribute names that this processor uses
Parameter ATTRIBUTES As STRING = "baseHref,clearTarget,appName,installCommand";

/// OS-dependent build script name
Parameter BUILDSCRIPT As COSEXPRESSION = "$Select($$$isUNIX:""angularBuild.sh"",1:""angularBuild.bat"")";

/// Base URL for the application
Property baseHref As %String [ Required ];

/// Set to false if the target for the deployed UI has other files too (e.g., that shouldn't be deleted).
Property clearTarget As %Boolean [ InitialExpression = 1 ];

/// Set to the application name (if differs from deepest folder in resource name, to which it defaults)
Property appName As %String;

/// Either "install" or "ci"; default is "ci"
Property installCommand As %String(VALUELIST=",install,ci") [ InitialExpression = "ci" ];

Method OnBeforePhase(pPhase As %String, ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		$$$ThrowOnError(##super(pPhase, .pParams))
		Do ..CleanSettings()
		Set verbose = $Get(pParams("Verbose"),0)
		If (pPhase = "Compile") && ##class(%Library.File).Exists(..ResourceReference.Module.Root_..ResourceReference.Name_"/package.json") {
			// Compile the Angular UI. Supposes npm is installed and on the PATH, but that's it.
			Do ..RunAngularBuild(.pParams)
		} ElseIf (pPhase = "Activate") {
			// Move files to the right place.
			Set sourceDir = ##class(%Library.File).NormalizeDirectory(..ResourceReference.Module.Root_..ResourceReference.Name_"/dist/"_..appName)
			Set targetDir = $System.CSP.GetFileName(..baseHref)
			Set testFile = sourceDir_"index.html"
			If '##class(%Library.File).Exists(testFile) {
				$$$ThrowStatus($$$ERROR($$$GeneralError,$$$FormatText("File '%1' does not exist; will not activate angular UI changes.",testFile)))
			}
			If verbose {
				Write !,"Activating Angular application changes..."
				Write !,"Copying ",sourceDir," to ",targetDir
			}
			$$$ThrowOnError(##class(%ZPM.PackageManager.Developer.File).CopyDir(sourceDir,targetDir,..clearTarget))
			// Clear CSPGateway caches...
			If verbose {
				Write !,"Clearing CSPGateway caches..."
			}
			#dim registry As %CSP.Mgr.GatewayRegistry
			Set registry = $System.CSP.GetGatewayRegistry()
			$$$ThrowOnError(registry.RemoveFilesFromCaches(..baseHref_"*"))
			If verbose {
				Write !,"Angular UI changes activated."
			}
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method OnAfterPhase(pPhase As %String, ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		$$$ThrowOnError(##super(pPhase, .pParams))
		Do ..CleanSettings()
		Set verbose = $Get(pParams("Verbose"),0)
		If (pPhase = "Activate") {
			// Done as final step to get around copy order issues
			Set indexHtml = $System.CSP.GetFileName(..baseHref)_"index.html"
			If ##class(%Library.File).Exists(indexHtml) {
				If verbose {
					Write !,"Changing baseHref to '",..baseHref,"' in ",indexHtml
				}
				Do ..ReplaceInTextFile(indexHtml,"{{baseHref}}",..baseHref)
				Do ..ReplaceInTextFile(indexHtml,"{{baseHrefLower}}",$ZConvert(..baseHref,"L"))
			}
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method CleanSettings()
{
	// Ensure baseHref is correctly formatted.
	Set baseHref = ..baseHref
	
	If (baseHref '= "") {
		If $Extract(baseHref,*) '= "/" {
			Set baseHref = baseHref_"/"
		}
	}
	
	Set searchStr = "/"_$Namespace_"/"
	If (baseHref [ searchStr) {
		Set baseHref = $Replace(baseHref,searchStr,$ZConvert(searchStr,"L"))
	}
	
	// Store for later use (in Activate phase)
	Set ..baseHref = baseHref
	
	// Ensure appName is defined
	If ..appName = "" {
		Set ..appName = $Case($Extract(..ResourceReference.Name,*),
			"/":$Piece(..ResourceReference.Name,"/",*-1),
			:$Piece(..ResourceReference.Name,"/",*))
	}
}

Method RunAngularBuild(ByRef pParams) [ Internal ]
{
	If $Data(pParams("Angular","NoBuild"),flag)#2 && flag {
		Quit
	}

	Set verbose = $Get(pParams("Verbose"),0)
	Set buildDirectory = ..ResourceReference.Module.Root _ ..ResourceReference.Name
	Set buildScript = ##class(%Library.File).NormalizeFilename(..#BUILDSCRIPT, buildDirectory)
	Set stream = ##class(%Stream.FileBinary).%New()
	$$$ThrowOnError(stream.LinkToFile(buildScript))
	Do ..GenerateBuildScript(buildDirectory,stream,verbose)
	$$$ThrowOnError(stream.%Save())
	
	If verbose {
		Write !!,"Running Angular build script...",!
	}
	
	$$$ThrowOnError(..MonitorBackgroundBuild(buildScript, buildDirectory, verbose))
}

ClassMethod MonitorBackgroundBuild(pBuildScript As %String, pBuildDirectory As %String, pVerbose As %Boolean) As %Status [ Internal ]
{
	Set tSC = $$$OK
	Set tErrorOccured = 0
	Try {
		Set tStart = $zh
		Do $System.Event.Clear($Job)
		Set tErrorFile = ##class(%Library.File).NormalizeFilename("error.log",pBuildDirectory)
		Set tOutputFile = ##class(%Library.File).NormalizeFilename("output.log",pBuildDirectory)
		Job ..BuildInBackground(pBuildScript,tOutputFile,tErrorFile)
		Set tChild = $ZChild
		
		// Wait for background job to create files
		Hang 1
		
		Set tErrorStream = ##class(%IO.FileStream).%New()
		If 'tErrorStream.Open(tErrorFile,"RS",,,.tSC) {
			$$$ThrowOnError(tSC)
		}
		Set tOutputStream = ##class(%IO.FileStream).%New()
		If 'tOutputStream.Open(tOutputFile,"RS",,,.tSC) {
			$$$ThrowOnError(tSC)
		}
		
		Set tQuitAfterNextRead = 0
		For {
			// Check logs.
			For tStream = tOutputStream,tErrorStream {
				For {
					#dim tStream As %IO.FileStream
					
					// Say we're not at the end, since more content may have been written.
					// If stream was previously set to AtEnd, it won't allow further reads.
					// Solution for this: close, reopen, and seek to previous position. This allows detection of new content.
					Set tPosition = tStream.Position
					Do tStream.Close(.tSC)
					$$$ThrowOnError(tSC)
					Do tStream.Open(tStream.Name,"RS",,,.tSC)
					$$$ThrowOnError(tSC)
					Do tStream.Seek(tPosition,.tSC)
					$$$ThrowOnError(tSC)
					
					Set tTimeout = 1
					// Read a line if we can
					Set tData = tStream.ReadLine($$$MaxStringLength,.tTimeout,.tSC)
					$$$ThrowOnError(tSC)
					If 'tTimeout && '(tStream.AtEnd && (tData = "")) {
						// We have content if there was no timeout, unless we have reached the end of the stream without any data.
						If (pVerbose) {
							Write tData,!
						}
						
						// Detect npm errors:
						If $Match(tData,"^npm ERR!") {
							Set tErrorOccured = 1
						}
						
						// Detect ng build errors:
						If $Match(tData,"^ERROR.*") {
							Set tErrorOccured = 1
						}
					} Else {
						Quit
					}
				}
			}
			If tQuitAfterNextRead {
				Quit
			}
			
			// Wait for message.
			Set tResult = $System.Event.Wait("",1)
			If (tResult = -1) {
				// Terminated abnormally.
				Set tMsg = "Angular build process terminated abnormally."
				If pVerbose {
					Write tMsg,!
				}
				Set tQuitAfterNextRead = 1
				Set tSC = $$$ERROR($$$GeneralError,tMsg)
			} ElseIf (tResult = 1) {
				If pVerbose {
					Write "Angular build process completed. Elapsed time: ",($zh-tStart)," seconds.",!
				}
				Set tQuitAfterNextRead = 1
			} ElseIf (tResult = 0) {
				// Timed out - this is fine, must still be running. Wait a second before trying again.
				Hang 1
			}
		}
	} Catch e {
		Return e.AsStatus()
	}
	If tErrorOccured {
		Set tMsg = "One or more errors occurred in Angular build. See full log for details."
		If (pVerbose) {
			Write tMsg,!
		}
		Set tSC = $$$ERROR($$$GeneralError,tMsg)
	}
	Return tSC
}

ClassMethod BuildInBackground(pBuildScript As %String, stdOut As %String, stdErr As %String) [ Internal ]
{
	Set flags = "/STDOUT="""_stdOut_""" /STDERR="""_stdErr_""""
	If $$$isUNIX {
		Do $zf(-100, "", "chmod", "777", pBuildScript)
		Do $zf(-100, flags, "sh", pBuildScript)
	} Else {
		Do $zf(-100, flags, pBuildScript)
	}
	Do $System.Event.Signal($ZParent)
}

Method GenerateBuildScript(pBuildDirectory As %String, pScriptStream As %Stream.Object, pVerbose As %Boolean) [ Internal, Private ]
{
	//navigate to the directory containing the Angular project definition
	If $$$isUNIX {
		Do pScriptStream.WriteLine("cd "_##class(%Library.File).NormalizeDirectory(pBuildDirectory))
	} Else {
		// For Windows:
		Do pScriptStream.WriteLine("cd /D "_##class(%Library.File).NormalizeDirectory(pBuildDirectory))
	}
	
	Set buildOptions("baseHref") = ..baseHref
	
	//run npm install to update all dependencies.  changes to dependencies are source controled by pacakge.json,
	//so any changes made during development will be installed on each server during this command
	
	Set prefix = $Select($$$isUNIX:"",1:"call ")
	Do pScriptStream.WriteLine(prefix_"npm "_..installCommand)
	Do pScriptStream.WriteLine(prefix_..GetBuildString(.buildOptions, pVerbose))
}

Method GetBuildString(ByRef buildOptions, pVerbose As %Boolean) As %String [ Internal, Private ]
{
	Set buildString = "npx ng build"

	Set buildOption = $Order(buildOptions(""), 1)
	While (buildOption '= "") {
		set optionValue = buildOptions(buildOption)
		set buildString = buildString_" --"_buildOption_$Case(optionValue,"":"",:"=")_optionValue
		set buildOption = $Order(buildOptions(buildOption), 1, optionValue)
	}
	If (pVerbose) {
		Write !,"Building with: """_buildString_""""
	}
	Return buildString
}

/// Overridden to export only /dist/<..appName>
Method OnExportItem(pFullExportPath As %String, pItemName As %String, ByRef pItemParams, ByRef pParams, Output pItemHandled As %Boolean) As %Status
{
	Set pItemHandled = 1
	Set tModule = ..ResourceReference.Module
	Set tVerbose = +$Get(pParams("Verbose"))
	
	If (tModule.Root = "") {
		Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("No module root configured for '%1'",tSrcModule))
		Quit
	}
	
	If '##class(%File).DirectoryExists(tModule.Root) {
		Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Directory %2, listed as root for module '%1', does not exist.",tSrcModule,tModule.Root))
		Quit
	}
	
	Set tSourcePath = ##class(%File).NormalizeFilenameWithSpaces(tModule.Root_pItemName_"/dist/"_..appName)
	Set tExportPath = ##class(%File).NormalizeFilenameWithSpaces(pFullExportPath_pItemName_"/dist/"_..appName)
	Set tSC = $$$OK
	Set tDirectory = ##class(%File).GetDirectory(tExportPath,1)
	If '##class(%File).DirectoryExists(tDirectory) {
		Set tGood = ##class(%File).CreateDirectoryChain(tDirectory,.tReturn)
		If 'tGood {
			Set tLastErr = $Get(%objlasterror)
			Set tSC = $$$EMBEDSC($$$ERROR($$$GeneralError,$$$FormatText("Error creating directory '%1': %2",tDirectory,tReturn)),tLastErr)
			Quit
		}
		Write:tVerbose !,"Created ",tDirectory
	}
	If ##class(%File).DirectoryExists(tSourcePath) {
		// NOTE: Does not overlay directories.
		Set tSourcePath = ##class(%File).NormalizeDirectory(tSourcePath)
		Set tExportPath = ##class(%File).NormalizeDirectory(tExportPath)
		Set tSC = ##class(%ZPM.PackageManager.Developer.File).CopyDir(tSourcePath,tExportPath)
		If $$$ISERR(tSC) {
			Quit
		}
		Write:tVerbose !,tSourcePath," -> ",tExportPath
	} ElseIf ##class(%File).Exists(tSourcePath) {
		Set tGood = ##class(%File).CopyFile(tSourcePath,tExportPath,1,.tReturn)
		If 'tGood {
			Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Error copying file '%1' to '%2': %3",tSourcePath,tExportPath,tReturn))
			Quit
		}
		Write:tVerbose !,tSourcePath," -> ",tExportPath
	}
	
	Set indexHtml = ##class(%File).NormalizeFilenameWithSpaces(pFullExportPath_pItemName_"/dist/"_..appName_"/index.html")
	Do ..ReplaceInTextFile(indexHtml,..baseHref,"{{baseHref}}")
	Do ..ReplaceInTextFile(indexHtml,$ZConvert(..baseHref,"L"),"{{baseHrefLower}}")
	Quit $$$OK
}

ClassMethod ReplaceInTextFile(file As %String, string As %String, replaceString As %String)
{
	Set stream = ##class(%Stream.FileCharacter).%OpenId(file,,.sc)
	$$$ThrowOnError(sc)
	While 'stream.AtEnd {
		Set lines($i(lines)) = $Replace(stream.ReadLine(),string,replaceString)
	}
	$$$ThrowOnError(stream.Rewind())
	$$$ThrowOnError(stream.Clear())
	For i=1:1:lines {
		$$$ThrowOnError(stream.WriteLine(lines(i)))
	}
	$$$ThrowOnError(stream.%Save())
}

}

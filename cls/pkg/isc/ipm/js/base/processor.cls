Class pkg.isc.ipm.js.base.processor Extends %ZPM.PackageManager.Developer.Processor.Abstract [ Abstract ]
{

/// Description of resource processor class (shown in UI)
Parameter DESCRIPTION As STRING = "Base class for JS/TS project builds with npm and some framework";

/// Comma-separated list of resource attribute names that this processor uses
Parameter ATTRIBUTES As STRING = "clearTarget,installCommand";

/// Subtype keyword (e.g., Angular, React)
Parameter FLAVOR [ Abstract ];

/// Set to false if the target for the deployed UI has other files too (e.g., that shouldn't be deleted).
Property clearTarget As %Boolean [ InitialExpression = 1 ];

/// Either "install" or "ci"; default is "ci"
Property installCommand As %String(VALUELIST = ",install,ci") [ InitialExpression = "ci" ];

Method OnBeforePhase(pPhase As %String, ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		$$$ThrowOnError(##super(pPhase, .pParams))
		Do ..CleanSettings()
		Set verbose = $Get(pParams("Verbose"),0)
		If (pPhase = "Compile") && ##class(%Library.File).Exists(..ResourceReference.Module.Root_..ResourceReference.Name_"/package.json") {
			// Compile the UI. Supposes npm is installed and on the PATH, but that's it.
			Do ..RunBuild(.pParams)
		} ElseIf (pPhase = "Activate") {
			Do ..PromoteFiles(verbose,.pParams)
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
			If '..PromotedFiles(.pParams) {
				Do ..PromoteFiles(verbose,.pParams)
			}
            Do ..PerformActivateFileReplacements()
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method PromotedFiles(ByRef pParams) As %Boolean
{
	Quit $Get(pParams($classname(),..ResourceReference.Name,"PromotedFiles"),0)
}

Method PromoteFiles(verbose As %Boolean, ByRef pParams)
{
	// Move files to the right place.
	Set sourceDir = ##class(%Library.File).NormalizeDirectory(..GetSourceDirectory())
	Set targetDir = ..GetTargetDirectory()
	If (targetDir = "") {
		// May happen due to a chicken-and-egg problem in module activation.
		Quit
	}
	Set testFile = sourceDir_"index.html"
	If '##class(%Library.File).Exists(testFile) {
		$$$ThrowStatus($$$ERROR($$$GeneralError,$$$FormatText("File '%1' does not exist; will not activate %2 UI changes.",testFile,..#FLAVOR)))
	}
	If verbose {
		Write !,"Activating "_..#FLAVOR_" application changes..."
		Write !,"Copying ",sourceDir," to ",targetDir
	}
	$$$ThrowOnError(..CopyDir(sourceDir,targetDir,..clearTarget))
	// Clear CSPGateway caches...
	If verbose {
		Write !,"Clearing CSPGateway caches..."
	}
	#dim registry As %CSP.Mgr.GatewayRegistry
	Set registry = $System.CSP.GetGatewayRegistry()
	$$$ThrowOnError(registry.RemoveFilesFromCaches(..GetTargetDirectory()_"*"))
	If verbose {
		Write !,..#FLAVOR," UI changes activated."
	}
	Set pParams($classname(),..ResourceReference.Name,"PromotedFiles") = 1
}

ClassMethod CopyDir(pSource As %String, pDest As %String, pDeleteFirst As %Boolean = 1, pVerbose As %Boolean = 0) As %Status
{
	If ##class(%Dictionary.Definition).%ExistsId("%IPM.Utils.File") {
		Return ##class(%IPM.Utils.File).CopyDir(pSource, pDest, pDeleteFirst, pVerbose)
	} Else {
		Return ##class(%ZPM.PackageManager.Developer.File).CopyDir(pSource, pDest, pDeleteFirst, pVerbose)
	}
}

Method CleanSettings() [ Abstract ]
{
}

Method GetTargetDirectory() As %String [ Abstract ]
{
}

Method GetSourceDirectory() As %String
{
	Quit ##class(%Library.File).NormalizeDirectory(..ResourceReference.Module.Root_..ResourceReference.Name_..GetBuildSubdirectory())
}

Method GetBuildSubdirectory() As %String [ Abstract ]
{
}

Method PerformExportFileReplacements(pFullExportPath As %String, pItemName As %String) [ Abstract ]
{
}

Method PerformActivateFileReplacements() [ Abstract ]
{
}

Method GetInstallCommand(buildDirectory As %String, Output command)
{
    Kill command
    Set command(0) = "npm"
    Set command($i(command)) = ..installCommand
    Set command($i(command)) = "--prefix"
    Set command($i(command)) = buildDirectory
    Set command($i(command)) = "--no-progress"
    Set command($i(command)) = "--node-flags"
    Set command($i(command)) = "--max-old-space-size=8000"
}

Method GetBuildCommand(buildDirectory As %String, Output command)
{
    Kill command
	Set command(0) = "npm"
	Set command($i(command)) = "run"
	Set command($i(command)) = "--prefix"
	Set command($i(command)) = buildDirectory
	Set command($i(command)) = "build"
	Set command($i(command)) = "--node-flags"
	Set command($i(command)) = "--max-old-space-size=8000"
}

Method RunBuild(ByRef pParams) [ Internal ]
{
	If $Data(pParams(..#FLAVOR,"NoBuild"),flag)#2 && flag {
		Quit
	}

	Set verbose = $Get(pParams("Verbose"),0)
	If verbose {
		Write !!,"Running ",..#FLAVOR," build script...",!
	}

	Set buildDirectory = ##class(%Library.File).NormalizeDirectory(..ResourceReference.Module.Root _ ..ResourceReference.Name)

	If ..NeedToInstall(buildDirectory) || ($Data(pParams(..#FLAVOR,"ForceInstall"),flag)#2 && flag) {
		// First stage: npm ci
        Do ..GetInstallCommand(buildDirectory,.installCommand)
		Merge buildStages($i(buildStages)) = installCommand
	}

	// Second stage: ng build
    Do ..GetBuildCommand(buildDirectory,.buildCommand)
	Merge buildStages($i(buildStages)) = buildCommand
	
	$$$ThrowOnError(..MonitorBackgroundBuild(buildDirectory, .buildStages, verbose))
}

Method MonitorBackgroundBuild(pBuildDirectory As %String, ByRef pBuildStages, pVerbose As %Boolean) As %Status [ Internal ]
{
	Set tSC = $$$OK
	Try {
		Set tStart = $zh

		If pVerbose {
			Write "Building in ",pBuildStages," stage(s).",!
		}

		Do ..CollectHashes(pBuildDirectory, .hashes)

		For i=1:1:pBuildStages {
			Set tErrorOccured = 0

			// Construct OS-level command args to run in background
			Set logFile = ##class(%Library.File).TempFilename()
			Set command = pBuildStages(i,0)
			Kill jobArgs
			Merge jobArgs = pBuildStages(i)
			Kill jobArgs(0)
			If pVerbose {
				Write "Running in background: ",command
				For j=1:1:jobArgs {
					Write " ",jobArgs(j)
				}
				Write !
			}
			Set argSub = $Increment(^IRIS.Temp.JobArgs)
			Kill ^IRIS.Temp.JobArgs(argSub)
			Merge ^IRIS.Temp.JobArgs(argSub) = jobArgs

			Do $System.Event.Clear($Job)
			Job ..BuildInBackground(command,logFile,argSub)
			Set tChild = $ZChild
		
			// Wait for background job to create files
			Hang 1
			
			Set tStream = ##class(%IO.FileStream).%New()
			If 'tStream.Open(logFile,"RS",,,.tSC) {
				$$$ThrowOnError(tSC)
			}
			
			Set tQuitAfterNextRead = 0
			For {
				For {
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
						If $Match(tData,"^npm ERR!.*") {
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

				If (tQuitAfterNextRead) {
					Quit
				}
			
				// Wait for message.
				Set tResult = $System.Event.Wait("",1)
				If (tResult = -1) {
					// Terminated abnormally.
					Set tMsg = ..#FLAVOR_" build process terminated abnormally."
					If pVerbose {
						Write tMsg,!
					}
					Set tQuitAfterNextRead = 1
					Set tSC = $$$ERROR($$$GeneralError,tMsg)
				} ElseIf (tResult = 1) {
					If pVerbose {
						Write ..#FLAVOR_" build process completed. Elapsed time: ",($zh-tStart)," seconds.",!
					}
					Set tQuitAfterNextRead = 1
				} ElseIf (tResult = 0) {
					// Timed out - this is fine, must still be running. Wait a second before trying again.
					Hang 1
				}
			}

			If tErrorOccured {
				// Don't try to run the next stage.
				Write "Quitting early because an error occurred.",!
				Quit
			}
		}
	} Catch e {
		Write !,e.DisplayString(),!
		Set tErrorOccured = 1
	}
	If tErrorOccured {
		Set tMsg = "One or more errors occurred in "_..#FLAVOR_" build. See full log for details."
		If (pVerbose) {
			Write tMsg,!
		}
		Set tSC = $$$ERROR($$$GeneralError,tMsg)
	} Else {
		// If build succeeded, store hashes.
		Do ..StoreHashes(pBuildDirectory, .hashes)
	}
	Return tSC
}

ClassMethod NeedToInstall(directory As %String)
{
	Set packageUnchanged = ##class(pkg.isc.ipm.js.latestHash).IsUpToDate(directory_"package.json")
	Set lockUnchanged = ##class(pkg.isc.ipm.js.latestHash).IsUpToDate(directory_"package-lock.json")
	Quit '(packageUnchanged && lockUnchanged)
}

ClassMethod CollectHashes(directory As %String, ByRef hashes)
{
	For file = "package.json","package-lock.json" {
		Set hashes(file) = ##class(pkg.isc.ipm.js.latestHash).GetCurrentHash(directory_file)
	}
}

ClassMethod StoreHashes(directory As %String, ByRef hashes)
{
	For file = "package.json","package-lock.json" {
		Do ##class(pkg.isc.ipm.js.latestHash).StoreHash(directory_file,hashes(file))
	}
}

ClassMethod BuildInBackground(buildCommand As %String, outFile As %String, argSub As %Integer) [ Internal ]
{
	Set flags = "/SHELL /STDOUT="""_outFile_""" /STDERR="""_outFile_""""
	Try {
		Merge options = ^IRIS.Temp.JobArgs(argSub)
		Kill ^IRIS.Temp.JobArgs(argSub)

		// Only npm and npx are allowed.
		Set buildCommand = $Case(buildCommand,
			"npm":"npm",
			"npx":"npx")
		Do $zf(-100, flags, buildCommand, .options)
	} Catch e {
		Do e.Log()
	}
	Do $System.Event.Signal($ZParent)
}

/// Overridden to export only <code>..GetBuildSubdirectory()</code> (not the rest of the source)
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
	
	Set tSourcePath = ##class(%File).NormalizeFilenameWithSpaces(tModule.Root_pItemName_..GetBuildSubdirectory())
	Set tExportPath = ##class(%File).NormalizeFilenameWithSpaces(pFullExportPath_pItemName_..GetBuildSubdirectory())
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
		Set tSC = ..CopyDir(tSourcePath,tExportPath)
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
	
    Do ..PerformExportFileReplacements(pFullExportPath, pItemName)
	Quit $$$OK
}

ClassMethod ReplaceInDirectory(directory As %String, string As %String, replaceString As %String)
{
	Set result = ##class(%Library.File).FileSetFunc(directory,,,1)
	While result.%Next() {
		If result.Type = "D" {
			Do ..ReplaceInDirectory(result.Name, string, replaceString)
		} Else {
			Do ..ReplaceInTextFile(result.Name, string, replaceString)
		}
	}
}

ClassMethod ReplaceInTextFile(file As %String, string As %String, replaceString As %String)
{
	Set stream = ##class(%Stream.FileBinary).%OpenId(file,,.sc)
	$$$ThrowOnError(sc)
	While 'stream.AtEnd {
		Set lines($i(lines)) = $Replace(stream.Read($$$MaxStringLength/2),string,replaceString)
	}
	$$$ThrowOnError(stream.Rewind())
	$$$ThrowOnError(stream.Clear())
	For i=1:1:lines {
		$$$ThrowOnError(stream.Write(lines(i)))
	}
	$$$ThrowOnError(stream.%Save())
}

ClassMethod SanitizeWebAppBase(base As %String) As %String
{
	If (base '= "") {
		If $Extract(base,*) '= "/" {
			Set base = base_"/"
		}
	}
	
	Set searchStr = "/"_$Namespace_"/"
	If (base [ searchStr) {
		Set base = $Replace(base,searchStr,$ZConvert(searchStr,"L"))
	}

	Quit base
}

}

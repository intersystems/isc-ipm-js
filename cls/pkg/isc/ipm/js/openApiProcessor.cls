Class pkg.isc.ipm.js.openApiProcessor Extends %ZPM.PackageManager.Developer.Processor.Abstract
{

/// Description of resource processor class (shown in UI)
Parameter DESCRIPTION As STRING = "Runs npm install and Angular 6+ builds in a specified directory.";

/// Comma-separated list of resource attribute names that this processor uses
Parameter ATTRIBUTES As STRING = "DispatchClass,Url,TargetFolder,Generator,AdditionalProperties,BaseUrl";

Property DispatchClass As %Dictionary.Classname [ Required ];

Property Url As %String [ Required ];

Property TargetFolder As %String [ Required ];

Property Generator As %String;

Property AdditionalProperties As %String(MAXLEN="");

Property BaseUrl As %String;

/// Called as phase <var>pPhase</var> is executed for the resource. If <var>pResourceHandled</var> is set to true,
/// then the default behavior for that resource will be bypassed in the current phase.
/// Currently, this is only used in the Verify phase, because of different handling of intermediate error statuses.
/// TODO: Implement for standard database resources (.INC, .CLS, etc.)
Method OnPhase(pPhase As %String, ByRef pParams, Output pResourceHandled As %Boolean = 0) As %Status
{
    Set sc = $$$OK
    Try {
        If (pPhase '= "Generate") {
            Quit
        }

        If $Extract(..Url,*) '= "/" {
            Set ..Url = ..Url_"/"
        }
        Set ..Url = $ZConvert(..Url,"L")
        Set verbose = +$Get(pParams("Verbose"))
        If (verbose) {
            Write !,"Generating OpenAPI documentation for ",..Url," ...",!
        }
        $$$ThrowOnError($classmethod(..DispatchClass,"ConsoleBuildOpenAPIDocumentation",..Url,verbose,,.response,..BaseUrl))

        Set targetFile = ##class(%Library.File).NormalizeFilename(..ResourceReference.Module.Root_..ResourceReference.Name)
        Do ##class(%Library.File).CreateDirectoryChain(##class(%Library.File).GetDirectory(targetFile))
        If (verbose) {
            Write !,"Outputting to ",targetFile
        }

        If (verbose) {
            Write !,"Generating sources from OpenAPI documentation...",!
        }

        Set stream = ##class(%Stream.FileCharacter).%OpenId(targetFile)
        $$$ThrowOnError(response.%JSONExportToString(.jsonString))
        $$$ThrowOnError(##class(%pkg.isc.json.formatter).%New().FormatToStream(jsonString,stream))
        $$$ThrowOnError(stream.%Save())

        If (..Generator = "") {
            Quit
        }

        Set targetFolder = ##class(%Library.File).NormalizeFilename(..ResourceReference.Module.Root_..TargetFolder)
        Do ##class(%Library.File).CreateDirectoryChain(targetFolder)

        Set tempOut = ##class(%Library.File).TempFilename()
        Set args($i(args)) = "@openapitools/openapi-generator-cli"
        Set args($i(args)) = "generate"
        Set args($i(args)) = "-i"
        Set args($i(args)) = targetFile
        Set args($i(args)) = "-g"
        Set args($i(args)) = ..Generator
        Set args($i(args)) = "-o"
        Set args($i(args)) = targetFolder
        If (..AdditionalProperties '= "") {
            Set args($i(args)) = "--additional-properties="_..AdditionalProperties
        }
        // Need /SHELL for npx
        Do $zf(-100,"/SHELL /STDOUT="_$$$QUOTE(tempOut)_" /STDERR="_$$$QUOTE(tempOut)_"","npx",args...)

        If verbose {
            Set stream = ##class(%Stream.FileCharacter).%OpenId(tempOut)
            Set stream.RemoveOnClose = 1
            Do stream.OutputToDevice()
        } Else {
            Do ##class(%Library.File).Delete(tempOut)
        }

        Set pResourceHandled = 1
    } Catch e {
        Set sc = e.AsStatus()
    }
	Quit sc
}

}
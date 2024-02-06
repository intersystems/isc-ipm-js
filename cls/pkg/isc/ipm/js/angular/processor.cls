/// Resource processor class to manage Angular build, deployment, and packaging
Class pkg.isc.ipm.js.angular.processor Extends pkg.isc.ipm.js.base.processor
{

/// Description of resource processor class (shown in UI)
Parameter DESCRIPTION As STRING = "Runs npm install and Angular 6+ builds in a specified directory.";

/// Comma-separated list of resource attribute names that this processor uses
Parameter ATTRIBUTES As STRING = "baseHref,clearTarget,appName,installCommand";

/// Subtype keyword (e.g., Angular, React)
Parameter FLAVOR = "Angular";

/// Base URL for the application
Property baseHref As %String [ Required ];

/// Set to false if the target for the deployed UI has other files too (e.g., that shouldn't be deleted).
Property clearTarget As %Boolean [ InitialExpression = 1 ];

/// Set to the application name (if differs from deepest folder in resource name, to which it defaults)
Property appName As %String;

/// Either "install" or "ci"; default is "ci"
Property installCommand As %String(VALUELIST = ",install,ci") [ InitialExpression = "ci" ];

Method GetTargetDirectory() As %String
{
	Quit $System.CSP.GetFileName(..baseHref)
}

Method GetBuildSubdirectory() As %String
{
	Quit "/dist/"_..appName
}

Method PerformExportFileReplacements(pFullExportPath As %String, pItemName As %String)
{
	// Generalize for installation elsewhere
	Set indexHtml = ##class(%File).NormalizeFilenameWithSpaces(pFullExportPath_pItemName_"/dist/"_..appName_"/index.html")
	Do ..ReplaceInTextFile(indexHtml,..baseHref,"{{baseHref}}")
	Do ..ReplaceInTextFile(indexHtml,$ZConvert(..baseHref,"L"),"{{baseHrefLower}}")
}

Method PerformActivateFileReplacements()
{
	// Done as final step to get around copy order issues
	Set indexHtml = $System.CSP.GetFileName(..baseHref)_"index.html"
	If ##class(%Library.File).Exists(indexHtml) {
		Do ..ReplaceInTextFile(indexHtml,"{{baseHref}}",..baseHref)
		Do ..ReplaceInTextFile(indexHtml,"{{baseHrefLower}}",$ZConvert(..baseHref,"L"))
	}
}

Method GetBuildCommand(buildDirectory As %String, Output command)
{
	Do ##super(buildDirectory,.command)
	Set command($i(command)) = "--"
	Set command($i(command)) = "--base-href="_..baseHref
	Set command($i(command)) = "--progress=false"
}

Method CleanSettings()
{
	// Ensure baseHref is correctly formatted.
	Set ..baseHref = ..SanitizeWebAppBase(..baseHref)
	
	// Ensure appName is defined
	If ..appName = "" {
		Set ..appName = $Case($Extract(..ResourceReference.Name,*),
			"/":$Piece(..ResourceReference.Name,"/",*-1),
			:$Piece(..ResourceReference.Name,"/",*))
	}
}

}


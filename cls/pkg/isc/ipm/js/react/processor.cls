/// Resource processor class to manage React build, deployment, and packaging
Class pkg.isc.ipm.js.react.processor Extends pkg.isc.ipm.js.base.processor
{

/// Description of resource processor class (shown in UI)
Parameter DESCRIPTION As STRING = "Runs npm install and builds a React app in a specified directory.";

/// Comma-separated list of resource attribute names that this processor uses
Parameter ATTRIBUTES As STRING = "publicURL,clearTarget,installCommand";

/// Subtype keyword (e.g., Angular, React)
Parameter FLAVOR = "React";

/// Public URL for the application
Property publicURL As %String [ Required ];

Method GetTargetDirectory() As %String
{
	Quit $System.CSP.GetFileName(..publicURL)
}

Method GetBuildSubdirectory() As %String
{
	Quit "/build"
}

Method PerformExportFileReplacements(pFullExportPath As %String, pItemName As %String)
{
	// Generalize for installation elsewhere
	Set targetDir = ##class(%File).NormalizeDirectory(pFullExportPath_pItemName_..GetBuildSubdirectory())
	Do ..ReplaceInDirectory(targetDir,..publicURL,"{{publicURL}}")
	Do ..ReplaceInDirectory(targetDir,$ZConvert(..publicURL,"L"),"{{publicURLLower}}")
}

Method PerformActivateFileReplacements()
{
	Set targetDir = $System.CSP.GetFileName(..publicURL)
	If ##class(%Library.File).DirectoryExists(targetDir) {
		Do ..ReplaceInDirectory(targetDir,"{{publicURL}}",..publicURL)
		Do ..ReplaceInDirectory(targetDir,"{{publicURLLower}}",$ZConvert(..publicURL,"L"))
	}
}

Method CleanSettings()
{
	// Ensure publicURL is correctly formatted.
	Set ..publicURL = ..SanitizeWebAppBase(..publicURL)
}

}


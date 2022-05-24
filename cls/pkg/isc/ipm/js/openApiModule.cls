Class pkg.isc.ipm.js.openApiModule Extends %ZPM.PackageManager.Developer.Lifecycle.Module
{

Parameter PHASES As COSEXPRESSION = "##class(%ZPM.PackageManager.Developer.Lifecycle.Module).#PHASES _ $ListBuild(""Generate"")";

/// Custom phase: Generate
/// Generates OpenAPI sources (via openApiProcessor)
Method %Generate(ByRef pParams) As %Status
{
	Set sc = $$$OK
	Try {
		// Standard resource processing
		Set sc = $$$OK
		Set key = ""
		For {
			Set tResource = ..Module.Resources.GetNext(.key)
			Quit:key=""
			
			If $IsObject(tResource.Processor) {
				Set sc = $$$ADDSC(sc,tResource.Processor.OnPhase("Generate",.pParams))
			}
		}
	} Catch e {
		Set sc = e.AsStatus()
	}
	Quit sc
}

/// This method defines what a complete phase means for a given phase
ClassMethod GetCompletePhasesForOne(pOnePhase As %String) As %List
{
	quit $case(pOnePhase,
		"Generate":$lb("Generate"),
		:##super(pOnePhase))
}

}
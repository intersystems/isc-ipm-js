Class pkg.isc.ipm.js.base.staticFilesHandler Extends %CSP.REST
{

Parameter STATICFILEREGEX = ".*";

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
<Route Url="/(.*)" Method="GET" Call="ServeStaticFile" />
</Routes>
}

ClassMethod ServeStaticFile(pPath As %String) As %Status
{
    #dim %request As %CSP.Request
    #dim %response As %CSP.Response
    Set physicalPath = $System.CSP.GetFileName(%request.Application_pPath)
    If '##class(%Library.File).Exists(physicalPath) || ##class(%Library.File).DirectoryExists(physicalPath) {
	    Set pPath = "index.html"
    } ElseIf $Match(pPath, ..#STATICFILEREGEX){
    	Do %response.SetHeader("cache-control", "public, max-age=31536000")
    }
    Do %request.Set("FILE",%request.Application_pPath)
    Quit ##class(%CSP.StreamServer).Page()
}

}


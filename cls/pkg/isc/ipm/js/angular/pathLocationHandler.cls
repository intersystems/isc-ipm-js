/// REST dispatch class to support Angular's path location strategy
/// Serves index.html for all non-asset requests
Class pkg.isc.ipm.js.angular.pathLocationHandler Extends %CSP.REST
{

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
    If $Match(pPath, "^(assets/.*|.*\.(woff|woff2))$"){
    	Do %response.SetHeader("cache-control", "public, max-age=31536000")
    }
    If '$Match(pPath,"^(assets/.*|.*\.(js|map|html|css|woff|woff2))$") {
	    Set pPath = "index.html"
    }
    Do %request.Set("FILE",%request.Application_pPath)
    Quit ##class(%CSP.StreamServer).Page()
}

}

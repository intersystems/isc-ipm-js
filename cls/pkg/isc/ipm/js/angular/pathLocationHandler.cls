/// REST dispatch class to support Angular's path location strategy
/// Serves index.html for all non-asset requests
Class pkg.isc.ipm.js.angular.pathLocationHandler Extends pkg.isc.ipm.js.base.staticFilesHandler
{

Parameter STATICFILEREGEX = "^(assets/.*|.*\.(woff|woff2))$";

}


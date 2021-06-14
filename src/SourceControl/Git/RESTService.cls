/// A REST service that can be triggered externally (by git hooks) to import and compile changed code.
/// 
/// Usage: Create a web application with this class as the REST Dispatch Class.
/// 
/// Security settings:
/// - The Web Application needs %All in Application Roles
/// - The Web Application should be protected with a resource and password authentication:
///   - Add a resource, e. g. 'SourceControl'
///   - Set Resource Required 'SourceControl'
///   - Set Allowed Authentication Methods to 'Password'
/// - Configure a technical user that has access to 'SourceControl:USE', e. g. 'git'
/// - Configure 'git' as the RESTUsername in SourceControl.Git.Utils. Utils will set the user's password
///   to a new random string whenever source control is being enabled and write the password into the git hooks.
Class SourceControl.Git.RESTService Extends %CSP.REST
{

Parameter HandleCorsRequest = 1;

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
      <Route Url="/onexternalchange" Method="POST" Call="OnExternalChange"/>
   </Routes>
}

ClassMethod OnExternalChange() As %Status
{
	#dim %request As %CSP.Request
	
	if ('$IsObject(%request.Content)) return ..#HTTP204NOCONTENT
	
	while ('%request.Content.AtEnd) {
		set line = %request.Content.ReadLine(, .sc, .eol)
		
		If $$$ISERR(sc) return ..#HTTP500INTERNALSERVERERROR
		
		do ##class(Git).OnExternalChange(line)
	}
	
	return ..#HTTP200OK
}

}


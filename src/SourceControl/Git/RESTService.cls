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


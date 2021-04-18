Include %occStatus

Class SourceControl.Git.PackageInSourceControl Extends %Persistent
{

Parameter DEFAULTGLOBAL = "^Git.Data.Packages";

/// The name of the package to include in source control, ending with a "."
Property PackageName As %String(MAXLEN = 255);

Index PackageIndex On PackageName [ IdKey ];

/// The name of the namespace which the package should be exported from and imported to
Property OriginalNamespace As %String(MAXLEN = 255);

Method %OnNew(pPackageName As %String(MAXLEN=255), pOriginalNamespace As %String(MAXLEN=255)) As %Status
{
	set ..PackageName = pPackageName
	set ..OriginalNamespace = pOriginalNamespace
	return $$$OK
}

Method %OnAddToSaveSet(depth As %Integer, insert As %Integer, callcount As %Integer) As %Status [ Private, ServerOnly = 1 ]
{
	// make sure pPackageName ends with exactly on period
    set ..PackageName = $zstrip(..PackageName, ">", ".") _ "."
    
    set ..OriginalNamespace = $zconvert(..OriginalNamespace, "U")
    
    if ('##class(%SYS.Namespace).Exists(..OriginalNamespace)) {
    	// Error: Namespace does not exist
    	return $System.Status.Error(433, ..OriginalNamespace)
    }
    
    return $$$OK
}

/// Searches for a package that includes pSubPackageName
/// Returns the package name (including the terminating ".") if found, "" otherwise
ClassMethod FindPackage(pSubPackageName As %String(MAXLEN=255)) As %String
{
	// make sure pSubPackageName ends with exactly on period
	set pSubPackageName = $zstrip(pSubPackageName, ">", ".") _ "."

	&sql(SELECT PackageName INTO :result FROM PackageInSourceControl WHERE :pSubPackageName %STARTSWITH PackageName)
	
	return result
}

/// Returns a list of all package names (including the terminating ".") in source control
ClassMethod ListPackages() As %ListOfDataTypes
{
	set resultList = ##class(%ListOfDataTypes).%New()

	&sql(declare C1 cursor for select PackageName into :name from PackageInSourceControl)
	
	&sql(open C1)
	quit:(SQLCODE'=0)
	
	&sql(fetch C1)
	While (SQLCODE = 0) {
		do resultList.Insert(name)        
		&sql(fetch C1)
    }
    
    &sql(close C1)
	
	return resultList
}

Storage Default
{
<Data name="PackageInSourceControlDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>PackageName</Value>
</Value>
<Value name="3">
<Value>OriginalNamespace</Value>
</Value>
</Data>
<DataLocation>^Git.Data.PackagesD</DataLocation>
<DefaultData>PackageInSourceControlDefaultData</DefaultData>
<IdLocation>^Git.Data.PackagesD</IdLocation>
<IndexLocation>^Git.Data.PackagesI</IndexLocation>
<StreamLocation>^Git.Data.PackagesS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}


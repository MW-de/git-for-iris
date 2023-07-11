Include (%occStatus, %occErrors)

Class SourceControl.Git.UDL
{

Parameter ExportFormats = ",cls,lut,";

ClassMethod FormatIsSupported(format As %String) As %Boolean [ CodeMode = expression ]
{
..#ExportFormats [ "," _ $zconvert(format, "L") _ ","
}

ClassMethod Export(InternalName As %String, filename As %String) As %Status
{
	set sc = $$$OK
		
	set fileDir = $piece(filename,##class(Utils).#Slash,1,*-1)
	
	if ('##class(%File).DirectoryExists(fileDir)) {
		if ('##class(%File).CreateDirectoryChain(fileDir)) {
			quit $$$ERROR(5001,"Cannot create directory: "_fileDir)
		}
	}

	set format = $zconvert($piece(InternalName, ".", *), "L")

	if (format = "cls") return ..ExportCLS(InternalName, filename)
	
	if (format = "lut") return ..ExportLUT(InternalName, filename)
	
	return $$$ERROR($$$GeneralError, "Format not supported: "_format)
}

/// Using strings, limits file size to MAXSTRING (3.6 MB)
ClassMethod ExportCLS(InternalName As %String, filename As %String) As %Status
{
	set namespace = $namespace
	
	// get class content
	set sc = ##class(%Compiler.UDL.TextServices).GetTextAsString(namespace, InternalName, .classContent)
	quit:$$$ISERR(sc) sc
	
	set fileStream = ##class(%FileCharacterStream).%New()
	set fileStream.Filename = filename
	
	set sc = fileStream.Write(classContent)
	quit:$$$ISERR(sc) sc
	
	set sc = fileStream.SaveStream()
	
	quit sc
}

ClassMethod ExportLUT(InternalName As %String, filename As %String) As %Status
{
	return ##class(Ens.Util.LookupTable).%Export(filename, $piece(InternalName, ".", 1, *-1))
}

// todo: possibly replace with $system.OBJ.GetPackageList

/// Retrives all Classes and Lookup Tables in Package path recursively and adds them to outputList
/// Example: TraversePackage("HS.Local", outputList)
ClassMethod TraversePackage(path As %String(MAXLEN=255), ByRef outputList As %ListOfDataTypes, sep As %String = ".", level As %Integer = 0, force As %Boolean = 0) As %Status
{
    #define Dir
    #define OrderBy
    #define SystemFiles
    #define Flat
    #define NotStudio
    #define ShowGenerated 0
    #define Filter
    #define CspFile 5
    #define Directory 9
    #define CSPFolder 10
    
    #dim rs As %ResultSet = ##class(%ResultSet).%New("%RoutineMgr:StudioOpenDialog")
    #dim ec As %Status = rs.Execute(path_$case(path,"":"",:"/")_"*",$$$Dir, $$$OrderBy, $$$SystemFiles, $$$Flat, $$$NotStudio, $$$ShowGenerated, $$$Filter)
    quit:'ec ec
    
    while rs.Next() {
        #dim name As %String = rs.Get("Name")
        #dim isdirectory As %String = rs.Get("IsDirectory")
        #dim type As %String = rs.Get("Type")
        
        if (type = $$$Directory) || (type = $$$CSPFolder) {
            #dim newpath As %String = $case(path,"":name,:path_isdirectory_name)
            do ..TraversePackage(newpath, .outputList, isdirectory, level + 1, force)
        }
        else {
            #dim InternalName As %String = path_sep_name
            if (type = $$$CspFile) && ($Extract(InternalName) '= "/") {
                set InternalName = "/"_InternalName
            }
         
            do outputList.Insert(InternalName)
        }
    }
    
    // add lookup tables
    do ..TraversePackageLUT(path, .outputList)
    
    kill rs
    quit ec
}

/// Enumerates all lookup tables and adds those which start with <var>package</var> to <var>outputList</var>
/// Add trailing . to <var>package</var> to ensure the package name is delimited.
/// 
/// Lookup tables will be appended with pSuffix (default: ".lut") in <var>outputList</var>
/// 
/// Returns the number of lookup tables added to <var>outputList</var>
/// 
/// Example: ##class(SourceControl.Git.UDL).TraversePackageLUT("User.", list)
ClassMethod TraversePackageLUT(package As %String, ByRef outputList As %ListOfDataTypes, pSuffix As %String = ".lut") As %Integer
{
	#dim tLUTs As %ResultSet = ##class(Ens.Util.LookupTable).EnumerateFunc()
	
	set n = 0
	while tLUTs.%Next() {
		if (##class(Ens.Util.FunctionSet).StartsWith(tLUTs.%Get("Name"), package)) {
			do outputList.Insert(tLUTs.%Get("Name") _ pSuffix)
			set n = n + 1
		}
	}
	
	return n
}

ClassMethod Import(InternalName, filename, TargetNamespace As %String = {$namespace}) As %Status
{
	set format = $zconvert($piece(filename, ".", *), "L")

	if (format = "cls") return ..ImportCLS(InternalName, filename, TargetNamespace)
	
	if (format = "lut") return ..ImportLUT(InternalName, filename, TargetNamespace)
	
	return $$$ERROR($$$GeneralError, "Format not supported: "_format)
}

ClassMethod ImportCLS(InternalName, filename, TargetNamespace As %String = {$namespace}) As %Status
{
	return ##class(%Compiler.UDL.TextServices).SetTextFromFile(TargetNamespace, InternalName, filename)
}

ClassMethod ImportLUT(InternalName, filename, TargetNamespace As %String = {$namespace}) As %Status
{
	new $namespace
	set $namespace = TargetNamespace
	
	return ##class(Ens.Util.LookupTable).%Import(filename)
}

// Compiles class(es) <var>InternalName</var> in <var>TargetNamespace</var> with <var>CompileFlags</var>

// Uses %SYSTEM.OBJ.CompileList and takes Package.Class.Name.cls as <var>InternalName</var>

// Supports wildcards such as Package.*.cls

ClassMethod Compile(InternalName, TargetNamespace As %String = {$namespace}, CompileFlags = "cuk") As %Status
{
	// Change namespace if necessary
	If (TargetNamespace '= $namespace) {
		new $namespace
		set $namespace = TargetNamespace
	}
	
	// CompileList expects "Package.Class.Name.cls"
	// Compile expects "Package.Class.Name"
	// working with InternalName here which includes the extension, so CompileList is used
	
	// the .err output is currently unused
	return ##class(%SYSTEM.OBJ).CompileList(InternalName, CompileFlags, .err)
}

ClassMethod TraverseDirectory(Directory As %String(MAXLEN=255), ByRef FileList As %ListOfDataTypes) As %Status
{
	set sc = $$$OK
	
	set trs = ##class(%ResultSet).%New("%Library.File:FileSet")
 	set sc = trs.Execute(Directory, "*")
 	
	while trs.Next() {
		set name = trs.Get("Name")
 		set type = trs.Get("Type")
 		if type = "D" {
	 		if $find(name,$replace("/.git","/",##class(Utils).#Slash)) continue
	 		set sc = ..TraverseDirectory(name, .FileList)
	 		break:$$$ISERR(sc)
 		}
 		else {
	 		do FileList.Insert(name)
 		}
 	}
 	
 	quit sc
}

}


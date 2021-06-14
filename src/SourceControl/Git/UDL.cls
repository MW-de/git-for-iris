Include (%occStatus, %occErrors)

Class SourceControl.Git.UDL
{

ClassMethod Export(InternalName As %String, filename As %String) As %String
{
	set sc = $$$OK
		
	set namespace = $namespace
	set fileDir = $piece(filename,##class(Utils).#Slash,1,*-1)
	
	// get class content
	set sc = ##class(%Compiler.UDL.TextServices).GetTextAsString(namespace, InternalName, .classContent)
	quit:$$$ISERR(sc) sc
	
	// write class content to file
	
	if ('##class(%File).DirectoryExists(fileDir)) {
		if ('##class(%File).CreateDirectoryChain(fileDir)) {
			quit $$$ERROR(5001,"Cannot create directory: "_fileDir)
		}
	}
	
	set fileStream = ##class(%FileCharacterStream).%New()
	set fileStream.Filename = filename
	
	set sc = fileStream.Write(classContent)
	quit:$$$ISERR(sc) sc
	
	set sc = fileStream.SaveStream()
	
	quit sc
}

// todo: possibly replace with $system.OBJ.GetPackageList

/// Retrives all Classes in Package path recursively and adds them to outputList
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
    
    kill rs
    quit ec
}

ClassMethod Import(InternalName, filename, TargetNamespace As %String = {$namespace}) As %Status
{
	return ##class(%Compiler.UDL.TextServices).SetTextFromFile(TargetNamespace, InternalName, filename)
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


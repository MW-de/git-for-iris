Include (%occStatus, %occErrors)

Class SourceControl.Git.Utils [ Abstract ]
{

Parameter StorageConfig = "^Git.Config";

Parameter StorageDataItems = "^Git.Data.Items";

Parameter ClassName = "SourceControl.Git.Utils";

Parameter Slash = {$case($system.Version.GetOS(),"Windows":"\",:"/")};

/// List of Settings
Parameter Settings = {$ListBuild("CodeDirectory", "Enabled")};

// Default Settings as Parameters

Parameter DefaultCodeDirectory = "/opt/iriscode/";

Parameter DefaultEnabled = 0;

ClassMethod SettingIsDefined(setting As %String) As %Numeric [ CodeMode = expression ]
{
$data(@..#StorageConfig@(setting))
}

ClassMethod ReadSetting(setting As %String) As %String [ CodeMode = expression ]
{
$Get(@..#StorageConfig@(setting))
}

ClassMethod DefaultSetting(setting As %String) As %String [ CodeMode = expression ]
{
$parameter(..#ClassName, "Default" _ setting)
}

ClassMethod GetSetting(setting As %String) As %String [ CodeMode = expression ]
{
$select(..SettingIsDefined(setting) = 1:..ReadSetting(setting), 1:..DefaultSetting(setting))
}

ClassMethod SetSetting(setting As %String, value As %String(MAXLEN=""))
{
	set @..#StorageConfig@(setting) = value
}

// todo: implement

ClassMethod Log(msg As %String(MAXLEN=""), errorlevel As %Integer = 2)
{
}

// 8012 because this error has corresponding error message

ClassMethod MakeError(msg As %String(MAXLEN=255)) As %Status [ CodeMode = expression, Private ]
{
$$$ERROR(8012,"Git",msg)
}

ClassMethod MakeAndWriteError(msg As %String(MAXLEN=255)) As %Status [ Private ]
{
	set error = ..MakeError(msg)
	write msg,!
	return error
}

ClassMethod NamespaceCodeDirectory(Namespace As %String = "") As %String [ CodeMode = expression ]
{
..GetSetting("CodeDirectory") _ $zconvert($Translate($select(Namespace'="":Namespace, 1:$znspace),"%"),"U") _ ..#Slash
}

ClassMethod NamespaceFromCodeDirectory(Directory As %String(MAXLEN=255) = "") As %String
{
	set codeDirectory = ..GetSetting("CodeDirectory") 

	if ($extract(Directory, 1, $length(codeDirectory)) = codeDirectory) {
		return $piece($extract(Directory, $length(codeDirectory) + 1, *), "/", 1)
	}
	
	throw ..MakeError("Error in NamespaceFromCodeDirectory: Invalid path given for file " _ Directory)
}

ClassMethod AddSlash(path As %String(MAXLEN=255)) As %String [ CodeMode = expression ]
{
$select(path = "":"", 1:$zstrip(path, ">", ..#Slash) _ ..#Slash)
}

ClassMethod AddDefaultSettings() As %Status
{
	set ptr = 0
    while $listnext(..#Settings, ptr, value) {
    	if (..SettingIsDefined(value) = 0) {
    		do ..SetSetting(value, ..DefaultSetting(value))
    	} 
    }

    return $$$OK
}

ClassMethod GetSourceControlStatus() As %Boolean
{
	return (..GetSetting("Enabled") = $$$YES)
}

ClassMethod SetSourceControlStatus(Enable As %Boolean) As %Status
{
	do ..SetSetting("Enabled", (Enable = $$$YES))
	
	if (Enable = $$$YES) {
		write !,"=== Enabling Source control... ===",!,"Exporting all packages in source control to code directory...",!
		do ..ExportAll()
		
		write "Installing git hooks into all .git/hooks directories...",!
		do ##class(GitInterface).SearchGitDirectoriesAndInstallHooks(..GetSetting("CodeDirectory"))
		
		write "Note: If you 'git init' later, re-enable source control to reinstall the hooks.",!,"=== Source control enabled. ==="
	}
	else {
		write !!,"=== Source control disabled. ===",!!
	}
	
	return $$$OK
}

ClassMethod UserAction(InternalName As %String(MAXLEN=255), MenuName As %String, ByRef Target As %String, ByRef Action As %String, ByRef Reload As %Boolean) As %Status
{
	#define Force 1
    #dim menuName As %String = $Piece(MenuName,",")
    #dim menuItemName As %String = $Piece(MenuName,",",2)
    #dim ec As %Status = $$$OK
    
   
    if (menuName = "%SourceMenu") {
        if (menuItemName = "Settings") {
            set Action = 2
            set Target = "/csp/sys/exp/UtilExpGlobalView.csp?$ID2=" _ $zstrip(..#StorageConfig, "<", "^") _ "&$NAMESPACE=" _ $znspace
        }
        elseif (menuItemName = "Packages in Source Control") {
            set Action = 2
            // todo: get Global from PackageInSourceControl
            set Target = "/csp/sys/exp/UtilExpGlobalView.csp?$ID2=Git.Data.PackagesD&$NAMESPACE=" _ $znspace
        }
        elseif (menuItemName = "Enable Source Control") {
            do ..SetSourceControlStatus($$$YES)
        }
        elseif (menuItemName = "Disable Source Control") {
            do ..SetSourceControlStatus($$$NO)
        }
        elseif (menuItemName = "Export all changed") {
            return ..ExportAll($$$NO)
        }
        elseif (menuItemName = "Export all") {
            return ..ExportAll($$$YES)
        }
        elseif (menuItemName = "Import all changed") {
            return ..ImportAll($$$NO)
        }
        elseif (menuItemName = "Import all") {
            return ..ImportAll($$$YES)
        }
    }

    //w Target,!
    quit ec
}

ClassMethod AfterUserAction(Type As %Integer, Name As %String, InternalName As %String, Answer As %Integer, Msg As %String = "", ByRef Reload As %Boolean) As %Status
{
    quit $$$OK
}

/// replaces any slashes with the ones for current OS<br/>
/// removes first slash if present<br/>
/// adds last slash if not present<br/>
ClassMethod NormalizeFolder(folder As %String(MAXLEN=255)) As %String
{
	set folder = $Translate(folder, "/", ..#Slash)
	set:$Extract(folder)=..#Slash $Extract(folder) = ""
	set:$Extract(folder,*)'=..#Slash folder = folder _ ..#Slash
	quit folder
}

// todo: simplify this as necessary

ClassMethod ExternalName(InternalName As %String(MAXLEN=255)) As %String
{
    set name = $Translate(InternalName, "/", ..#Slash)

    // lower case for extensions
    #dim extension As %String = $ZConvert($Piece(name,".",$Length(name,".")),"L")
    #dim baseName As %String = $piece(name,".",1,$length(name,".")-1)
    
    
    set extensionSuffix = "." _ extension

    // we shall put classes in different folders
    if extension = "cls" {
        set name = $Translate(baseName, ".", ..#Slash) _ extensionSuffix
    }
    else {
        set name = baseName _ extensionSuffix
    }
    
    // we shall delete csp-app from csp files
    if $Extract(name, 1) = ..#Slash {
        set $Extract(name, 1) = ""
    }
    if $Piece(name, ..#Slash, 1) = "csp" {
        set $Piece(name, ..#Slash, 1, 2) = "csp"
    }

    quit $Translate(name," *?","___")
}

// todo: supports much less than correspondig ExternalName(). fix.

/// Returns the internal class name from ExternalName without preceding NamespaceCodeDirectory(). Use SplitFullExternalName() first, if necessary)
ClassMethod InternalName(ExternalName As %String(MAXLEN=255)) As %String
{
	//set name = ..NameWithoutExtension($translate(ExternalName, ..#Slash, "/"))
	set name = $translate(ExternalName, ..#Slash, "/")
	
	return ..NormalizeExtension($translate(name, "/", "."))
}

ClassMethod AddPackageToSourceControl(pPackageName As %String(MAXLEN=255), pOriginalNamespace As %String(MAXLEN=255)) As %Status
{
	// todo: check for nested packages, check for package mappings
	
	// make sure package ends with exactly on period
    set package = $zstrip(pPackageName, ">", ".") _ "."
	
	if (##class(PackageInSourceControl).FindPackage(package) '= "") {
		return $$$ERROR(5001, "Package or a parent package already in source control: " _ pPackageName)
	}
	
	set pkg = ##class(PackageInSourceControl).%New(package, pOriginalNamespace)
	do pkg.%Save()
	
	// if enabled, re-enable to run export and hook installation
	if (..GetSourceControlStatus() = $$$YES) do ..SetSourceControlStatus($$$YES)
	
	return $$$OK
}

ClassMethod RemovePackageFromSourceControl(pPackageName As %String(MAXLEN=255)) As %Status
{
	// todo: perform auto-delete?
	
	// make sure package ends with exactly on period
    set package = $zstrip(pPackageName, ">", ".") _ "."
	
	if ('##class(PackageInSourceControl).%ExistsId(package)) {
		return $$$ERROR(5001, "Package not in source control: " _ pPackageName)
	}
	
	return ##class(PackageInSourceControl).%DeleteId(package)
}

ClassMethod NameWithoutExtension(InternalName As %String) As %String [ CodeMode = expression ]
{
$Piece(InternalName, ".", 1, $Length(InternalName,".")-1)
}

ClassMethod GetSourceControlPackage(InternalName As %String(MAXLEN=255)) As %String
{
	return ##class(PackageInSourceControl).FindPackage(InternalName)
}

ClassMethod IsInSourceControl(InternalName As %String(MAXLEN=255)) As %String
{
 
    return (..GetSourceControlPackage(InternalName) '= "")
}

ClassMethod FullExternalName(InternalName As %String(MAXLEN=255), OriginalNamespace As %String = "") As %String [ CodeMode = expression ]
{
..NamespaceCodeDirectory(OriginalNamespace)_..ExternalName(InternalName)
}

ClassMethod SplitFullExternalName(FullExternalName As %String(MAXLEN=255)) As %String
{
	// will throw an error on failure
	set namespace = ..NamespaceFromCodeDirectory(FullExternalName)

	set namespaceDir = ..NamespaceCodeDirectory(namespace)

	if ($extract(FullExternalName, 1, $length(namespaceDir)) = namespaceDir) {
		return $lb(namespace, $extract(FullExternalName, $length(namespaceDir) + 1, *))
	}
	
	throw ..MakeError("Error in SplitFullExternalName: Invalid path given for file " _ FullExternalName)
}

// todo: not sure whether this is still needed.

ClassMethod NormalizeInternalName(name As %String(MAXLEN=255)) As %String
{
	set name = ..NormalizeExtension(name)

	//Studio passes name of routine with dots as it is in folders
	//e.g. Package.SubPackage.Routine.mac has InternalName =  /Package/SubPackage/Routine.mac
	//This happens if right-click in Workspace -> Namespace
	//If right-click in Workspace -> Project then everything passes ok
	//let's fix this
	if $Extract(name) '= "/" {
		quit name
	}
	
	set type = ..Type(name)
	
	if (type = "inc") || (type = "mac") || (type = "int") {
		set name = $Extract($Translate(name, "/", "."), 2, *)
	}
    quit name
}

ClassMethod NormalizeExtension(name As %String(MAXLEN=255)) As %String
{
    #dim extension = $Piece(name, ".", $Length(name, "."))
    if $Length(extension) <= 3 {
        set $Piece(name, ".", $Length(name, ".")) = $ZConvert(extension, "L")
    }
    quit name
}

ClassMethod DeleteExternalFile(InternalName As %String(MAXLEN=255)) As %Status
{
    #dim fullName = ##class(Utils).FullExternalName(InternalName)
    #dim ec As %Status = $$$OK
    if ##class(%File).Exists(fullName) {
        set ec = ##class(%File).Delete(fullName)
        do ..RemoveFileInfo(InternalName)
        write fullName, " for ", InternalName, " deleted",!
    }
    Quit ec
}

// todo: do we need NormalizeExtension here? - no, has to be done before

ClassMethod UpdateRoutineFileInfo(InternalName As %String(MAXLEN=255), Filename As %String(MAXLEN=""), Namespace = {$namespace})
{
	// Swap namespace if necessary
	If (Namespace '= $namespace) {
		new $namespace
		set $namespace = Namespace
	}

    #dim fileTSH = ##class(%File).GetFileDateModified(Filename)
    #dim fileSize = ##class(%File).GetFileSize(Filename)
         
    #dim routineTSH = ##class(%Library.RoutineMgr).TS(InternalName)

    set @..#StorageDataItems@(InternalName) = $lb(fileTSH, fileSize, routineTSH)
}

// todo: do we need NormalizeExtension here?

ClassMethod RemoveFileInfo(InternalName As %String(MAXLEN=255), Namespace = {$namespace})
{
	
	// Swap namespace if necessary
	If (Namespace '= $namespace) {
		new $namespace
		set $namespace = Namespace
	}

    kill @..#StorageDataItems@(InternalName)
}

// todo: do we need NormalizeExtension here?

ClassMethod RoutineFileHasChanged(InternalName As %String(MAXLEN=255), Filename As %String(MAXLEN=""), Namespace = {$namespace}) As %Boolean
{
	// Swap namespace if necessary
	If (Namespace '= $namespace) {
		new $namespace
		set $namespace = Namespace
	}

    #dim fileTSH = ##class(%File).GetFileDateModified(Filename)
    #dim fileSize = ##class(%File).GetFileSize(Filename)
    
    #dim routineTSH = ##class(%Library.RoutineMgr).TS(InternalName)
    
    return $get(@..#StorageDataItems@(InternalName)) '= $lb(fileTSH, fileSize, routineTSH)
}

/// imports file if it has changed on disk.
/// if <var>force</var> = 1 then imports in any case.
ClassMethod ImportItemIntoNamespace(InternalName As %String(MAXLEN=255), TargetNamespace As %String = {$namespace}, force As %Boolean = 0) As %Status
{
    #dim sc As %Status = $$$OK
    #dim filename As %String = ..FullExternalName(InternalName, TargetNamespace)
     
    if (..RoutineFileHasChanged(InternalName, filename, TargetNamespace)) || force {
        
        set sc = ##class(UDL).Import(InternalName, filename, TargetNamespace)
        
        if sc {
            do ..UpdateRoutineFileInfo(InternalName, filename, TargetNamespace)
            write InternalName," has been imported from ", filename,!
        } else {
	        write "ERROR importing" ,InternalName,!
	        do $system.Status.DisplayError(sc)
        }
    } else {
	    write InternalName, " is the same as on-disk version, skipping import",!
    }
    Quit sc
}

/// FullExternalName may point to a directory or to a file.
ClassMethod OnExternalChange(FullExternalName As %String(MAXLEN=255)) As %Status
{
	// enforce trailing slash
	set FullExternalName = $zstrip(FullExternalName, ">", ..#Slash) _ ..#Slash

	if ($extract(FullExternalName, 1, $length(..GetSetting("CodeDirectory"))) '= ..GetSetting("CodeDirectory")) {
		return ..MakeAndWriteError("Error: OnExternalChange: File or directory is outside the CodeDirectory: " _ FullExternalName)
	}

	// if it is a directory
	if (##class(%File).DirectoryExists(FullExternalName)) {
		return ..ImportDirectory(FullExternalName)
	}

	if (##class(%File).Exists(FullExternalName)) {
		return ..CheckAndImportFile(FullExternalName)
	}
	
	return ..MakeAndWriteError("Error: OnExternalChange: File or directory does not exist: " _ FullExternalName)
}

/// if <var>Force</var> = 1 then (re-)import all items even if the file on disk has not changed
ClassMethod ImportAll(Force As %Boolean = 0) As %Status
{
    return ..ImportDirectory(..GetSetting("CodeDirectory"), Force)
}

/// Traverses and imports a directory
ClassMethod ImportDirectory(FullExternalName As %String(MAXLEN=255), Force As %Boolean = 0) As %Status
{
	#dim fileList As %ListOfDataTypes = ##class(%ListOfDataTypes).%New() 
	
	set tSC = ##class(UDL).TraverseDirectory(FullExternalName, .fileList)
	
	if ($$$ISERR(tSC)) {
		return ..MakeAndWriteError("Error: CheckAndImportDirectoryIntoNamespace: Could not traverse directory: " _ FullExternalName)
	}
	
	for i=1:1:fileList.Count() {
		do ..CheckAndImportFile(fileList.GetAt(i), Force)
	}
	
	return $$$OK
}

ClassMethod CheckAndImportFile(FullExternalName As %String(MAXLEN=255), Force As %Boolean = 0) As %Status
{
	// Derive external name and target namespace
	try {
		set fullExternalNameSplit = ..SplitFullExternalName(FullExternalName)
		
		set targetNamespace = $lg(fullExternalNameSplit, 1)
		set externalName = $lg(fullExternalNameSplit, 2)
		
		if (targetNamespace = "") throw $$$ERROR(5001, "")
	}
	catch {
		return ..MakeAndWriteError("Notice: CheckAndImportFile: Could not resolve file into namespace and class name: " _ FullExternalName _ ", skipping.")
	}
	
	// Check namespace
	if ('##class(%SYS.Namespace).Exists(targetNamespace)) {
		return ..MakeAndWriteError("Error: CheckAndImportFile: Target namespace does not exist: " _ targetNamespace)
	}
	
	// Check file type
	if ($extract(externalName, *-3, *) '= ".cls") {
		return ..MakeAndWriteError("Notice: CheckAndImportFile: Skipping non-.cls file " _ externalName)
	}

	// Check source control package configuration and whether the file is in source control
	set internalName = ..InternalName(externalName)
	set packageName = ..GetSourceControlPackage(internalName)
	
	#dim packageInfo As PackageInSourceControl
	if (packageName '= "") set packageInfo = ##class(PackageInSourceControl).%OpenId(packageName)
	
	if (packageName = "") || ('packageInfo) {
		return ..MakeAndWriteError("Error: CheckAndImportFileIntoNamespace: No Package in source control found for class: " _ internalName)
	}
	
	if (packageInfo.OriginalNamespace '= "") && (packageInfo.OriginalNamespace '= targetNamespace) {
		return ..MakeAndWriteError("Error: CheckAndImportFileIntoNamespace: Namespace mismatch in file path (" _ targetNamespace _ ") and configuration for package " _ packageName _ " (" _ packageInfo.OriginalNamespace _ ")")
	}
	
	write "Importing " _ externalName _ " into " _ targetNamespace _ " as class " _ internalName,!
	
	// Now import
	// Note that ImportItemIntoNamespace will derive the file name from internalName again
	return ..ImportItemIntoNamespace(internalName, targetNamespace, Force)
}

/// Exports all Items in all Packages listed in PackageInSourceControl
ClassMethod ExportAll(force As %Boolean = 0) As %Status
{
	#dim packages As %ListOfDataTypes = ##class(PackageInSourceControl).ListPackages()
	
	if (packages.Count() = 0) {
		write "Notice: ExportAll was called, but there are no packages in source control.",!
		return $$$OK
	}

    for i=1:1:packages.Count() {
    	set currentPackage = packages.GetAt(i)
    	
        write "Notice: ExportAll: Starting export of package " _ currentPackage,!
        do ..ExportAllItemsInPackage(currentPackage, force)
        write "Notice: ExportAll: Finished export of package " _ currentPackage,!
    }
    
    return $$$OK
}

ClassMethod ExportAllItemsInPackage(package As %String(MAXLEN=255), force As %Boolean = 0) As %Status
{
	set tSC = $$$OK
	#dim itemList As %ListOfDataTypes = ##class(%ListOfDataTypes).%New()
	
	// strip tailing "." - add later when necessary
	set package = $zstrip(package, ">", ".")
	
	#dim packageInfo As PackageInSourceControl = ##class(PackageInSourceControl).%OpenId(package _ ".")
	
	if ('packageInfo) {
	 	return ..MakeAndWriteError("Error: ExportAllItemsInPackage: Package not found in PackageInSourceControl: " _ package)
	}
	
	// Retrieve class list
	set sc = ##class(UDL).TraversePackage(package, .itemList)
	
	if ($$$ISERR(sc)) {
		return ..MakeAndWriteError("Error traversing package in ExportAllItemsInPackage: " _ package)
	}
	
	// Export each item in the class list
	for i=1:1:itemList.Count() {
		set sc = ..ExportItem(itemList.GetAt(i), packageInfo.OriginalNamespace, force)
		
		if ($$$ISERR(sc)) {
			write "Error: Could not export class " _ itemList.GetAt(i),!
			set tSC = ..MakeError("Error exporting one or more classes in ExportAllItemsInPackage")
		}
	}
	
	return tSC
}

// Entry point for OnAfterSave and OnAfterCompile hooks

ClassMethod OnInternalChange(InternalName As %String(MAXLEN=255), PackageName As %String(MAXLEN=255) = "") As %Status
{
	if (PackageName = "") set PackageName = ..GetSourceControlPackage(InternalName)
	
	#dim packageInfo As PackageInSourceControl
	if (PackageName '= "") set packageInfo = ##class(PackageInSourceControl).%OpenId(PackageName)
	
	if (PackageName = "") || ('packageInfo) {
		return ..MakeAndWriteError("Error: ExportOnSave: No Package in source control found for class: " _ InternalName)
	}
	
	return ..ExportItem(InternalName, packageInfo.OriginalNamespace)
}

ClassMethod ExportItem(InternalName As %String(MAXLEN=255), OriginalNamespace As %String = "", force As %Boolean = 0) As %Status
{
    #dim filename As %String = ..FullExternalName(InternalName, OriginalNamespace)
    
    if ('force) && (##class(%File).Exists(filename)) {
    	if ('..RoutineFileHasChanged(InternalName, filename, OriginalNamespace)) {
    		write "Notice: ExportItem: Skipping export of ", InternalName, " because it has not changed since last export.",!
    		return $$$OK
    	}	
    }
   
    write "Exporting ", InternalName, " to ", filename,!
    
    $$$QuitOnError(##class(UDL).Export(InternalName, filename))
      
    do ..UpdateRoutineFileInfo(InternalName, filename, OriginalNamespace)
    
    return $$$OK
}

}


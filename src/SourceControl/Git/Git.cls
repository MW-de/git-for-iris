Class SourceControl.Git.Git Extends %Studio.Extension.Base
{

XData Menu
{
<MenuBase>
<Menu Name="%SourceMenu" Type="0">
<MenuItem Name="Settings" />
<MenuItem Name="Packages in Source Control" />
<MenuItem Name="Enable Source Control"/>
<MenuItem Name="Disable Source Control"/>
<MenuItem Separator="true"/>
<MenuItem Name="Export all changed" />
<MenuItem Name="Export all" />
<MenuItem Name="Import all changed" />
<MenuItem Name="Import all" />
</Menu>
</MenuBase>
}

Method UserAction(Type As %Integer, Name As %String, InternalName As %String, SelectedText As %String, ByRef Action As %String, ByRef Target As %String, ByRef Msg As %String, ByRef Reload As %Boolean) As %Status
{
	#dim ec As %Status = $$$OK
	#dim menu As %Status = $Piece(Name, ",", 1)
	if menu '= "%SourceMenu", menu'="%SourceMenuContext" {
		quit $$$OK
	}
	set InternalName = ##class(Utils).NormalizeInternalName(InternalName)
	set ec = ##class(Utils).UserAction(InternalName, Name, .Target, .Action, .Reload)
	quit ec
}

/// This is called for every menu item returned to Studio to allow the menu to be enabled/disabled without
/// having to write a custom query for <query>MenuItems</query>. The <var>DisplayName</var> of this menu is
/// also passed by reference and this may be modified to change the appearance of this menu item. The <var>MenuName</var>
/// is the main menu name then the submenu name separated by a ','. If <var>Enabled</var> is set to -1 then it will remove
/// this menu item from the list totally, 0 will gray the menu item out and the default 1 will display the menu item as normal.
Method OnMenuItem(MenuName As %String, InternalName As %String, SelectedText As %String, ByRef Enabled As %Boolean, ByRef DisplayName As %String) As %Status
{
	#dim ec As %Status = $$$OK

	#dim menu As %String= $Piece(MenuName,",")
	#dim name As %String = $Piece(MenuName,",",2)
	

	if (name = "Enable Source Control") {
        set Enabled = (##class(Utils).GetSourceControlStatus() '= $$$YES) 
    }
    elseif (name = "Disable Source Control") {
    	set Enabled = (##class(Utils).GetSourceControlStatus() = $$$YES)
    }

		
	Quit ec
}

/// This is called after the item has been saved to the database.
/// It may be passed a reference to the object representing the item
/// just saved. It can be use to export this documement to an external form for example.
Method OnAfterSave(InternalName As %String, Object As %RegisteredObject = {$$$NULLOREF}) As %Status
{
	if (##class(Utils).GetSourceControlStatus() '= $$$YES) return $$$OK

	set InternalName = ##class(Utils).NormalizeInternalName(InternalName)
	set packageName = ##class(Utils).GetSourceControlPackage(InternalName)
	
	if (packageName '= "") {
		write !,"Source Control: " _ InternalName _ " is under source control. Exporting to code directory.",!
		return ##class(Utils).OnInternalChange(InternalName, packageName)
	}
	
	write !,"Source Control: " _ InternalName _ " is not under source control.",!
	return $$$OK
}

/// Called after the compile of the item is done.
Method OnAfterCompile(InternalName As %String) As %Status
{
	return ..OnAfterSave(InternalName)
}

/// Called after an item is deleted.
/// TODO: Automatic deletion of files is not implemented yet
Method OnAfterDelete(InternalName As %String) As %Status
{
	if (##class(Utils).GetSourceControlStatus() '= $$$YES) return $$$OK

	set InternalName = ##class(Utils).NormalizeInternalName(InternalName)
	set packageName = ##class(Utils).GetSourceControlPackage(InternalName)
	
	if (packageName '= "") {
		write !,"Source Control: Item " _ InternalName _ " has been deleted from the database. Automatic deletion of code files is currently disabled, the file will remain in the code directory.",!
		// return ##class(Utils).DeleteExternalFile(InternalName)
	}
	
	quit $$$OK
}

/// External programs may notify source control that a class or package has changed.
/// For packages, the folder name must be given with a trailing slash.
ClassMethod OnExternalChange(FullExternalName As %String) As %Status
{
	if (##class(Utils).GetSourceControlStatus() '= $$$YES) return $$$OK

	return ##class(Utils).OnExternalChange(FullExternalName)
}

}


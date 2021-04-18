Class SourceControl.Git.GitInterface
{

ClassMethod SearchGitDirectoriesAndInstallHooks(Directory As %String(MAXLEN=255)) As %Status
{
	set sc = $$$OK
	
	set trs = ##class(%ResultSet).%New("%Library.File:FileSet")
 	set sc = trs.Execute(Directory, "*")
 	
	while trs.Next() {
		set name = trs.Get("Name")
 		set type = trs.Get("Type")
 		if (type = "D") {
 		
 			// if /.git was found, install the hooks and return from current sub-tree
	 		if ($extract(name, *-4, *) = $replace("/.git", "/", ##class(Utils).#Slash)) {
	 			write "Installing git hooks into " _ Directory _ "...",!
	 		
	 			return ..InstallHooksIntoGitDirectory(Directory)
	 		}
	 		
	 		// otherwise, keep searching deeper
	 		set sc = ..SearchGitDirectoriesAndInstallHooks(name)
	 		break:$$$ISERR(sc)
 		}
 	}
 	
 	quit sc
}

// <var>Directory</var> = The /path/to/dir

ClassMethod InstallHooksIntoGitDirectory(GitBaseDirectory As %String(MAXLEN=255)) As %Status
{
	set hookDir = ##class(%Library.File).Construct(GitBaseDirectory, ".git", "hooks")

	if ('##class(%Library.File).Writeable(hookDir)) {
		write "Error: InstallHooksIntoGitDirectory: .git/hooks directory is not writeable. Cannot install hooks.",!
		return $$$ERROR(337, hookDir)
	}

	set tSC = ..InstallHook(GitBaseDirectory, "post-checkout")
	if ($$$ISERR(tSC)) {
		write $system.Status.GetErrorText(tSC),!
		return tSC
	}
	
	set tSC = ..InstallHook(GitBaseDirectory, "post-merge")
	if ($$$ISERR(tSC)) {
		write $system.Status.GetErrorText(tSC),!
		return tSC
	}
	
	return $$$OK
}

ClassMethod InstallHook(GitBaseDirectory As %String(MAXLEN=255), HookName As %String) As %Status
{
	set filename = ##class(%Library.File).Construct(GitBaseDirectory, ".git", "hooks", HookName)

	set fileStream = ##class(%FileCharacterStream).%New()
	set fileStream.Filename = filename
	
	set tSC = ..WriteHookScriptContent(GitBaseDirectory, HookName, .fileStream)
	quit:$$$ISERR(tSC) tSC
	
	set tSC = fileStream.SaveStream()
	quit:$$$ISERR(tSC) tSC
	
	set tSC = ..SetExecutePermissions(filename)
	quit:$$$ISERR(tSC) tSC
	
	write "Hook '" _ HookName _ "' installed.",!
	return tSC
}

ClassMethod WriteHookScriptContent(GitBaseDirectory As %String(MAXLEN=255), HookName As %String, ByRef Stream As %Stream.Object) As %Status
{
	do Stream.WriteLine("#!/bin/sh")
	
	if (HookName = "post-merge") {
		do Stream.WriteLine("./post-checkout")
		return $$$OK
	}
	
	if (HookName = "post-checkout") {	
		do Stream.WriteLine("GitCodeDirectoryOnIRIS=""" _ GitBaseDirectory _ """")
		do Stream.WriteLine("RESTService=""http://localhost:52773/csp/user/sc/onexternalchange""")
		
		do Stream.WriteLine("curl -X POST -H 'Content-Type:text/plain' -d ""${GitCodeDirectoryOnIRIS}"" ${RESTService}")
		return $$$OK
	}
	
	return $$$ERROR(5001, "Unrecognized hook name: " _ HookName)
}

ClassMethod SetExecutePermissions(Filename As %String(MAXLEN=255)) As %Status
{
	set attr = ##class(%Library.File).Attributes(Filename)

	// file not found
	if (attr < 0) return $$$ERROR(1101, Filename)

	// output returns -1 on failure, 1 on success (on linux systems)
	do ##class(%Library.File).SetAttributes(Filename, $zb(attr, 1+8+64, 7), .output)
		
	return $select(output < 0:$$$ERROR(76), 1:$$$OK)
}

}


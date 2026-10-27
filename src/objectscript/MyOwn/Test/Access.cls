/// Temporary accounts for the role tests (scripts/Test-PortalViewer.ps1). Only names that start
/// with "myown.test." can be created or removed here, and only portal roles can be given.
Class MyOwn.Test.Access
{

Parameter Prefix = "myown.test.";

Parameter AllowedRoles = "MyOwnViewer,MyOwnDemo";

/// Creates or resets the account with exactly that role; the password comes from the caller.
ClassMethod EnsureUser(name As %String, role As %String, password As %String) As %String [ SqlName = TestEnsureUser, SqlProc ]
{
    If $Extract(name, 1, $Length(..#Prefix)) '= ..#Prefix Quit "refused: name must start with " _ ..#Prefix
    If '$ListFind($ListFromString(..#AllowedRoles), role) Quit "refused: role not allowed"
    New $Namespace
    Set $Namespace = "%SYS"
    If '##class(Security.Users).Exists(name) {
        Set tSC = ##class(Security.Users).Create(name, role, password)
        If $$$ISERR(tSC) Quit $System.Status.GetErrorText(tSC)
    }
    Kill properties
    Set properties("Roles") = role
    Set properties("Password") = password
    Set properties("Enabled") = 1
    Set properties("ChangePassword") = 0
    Set properties("Comment") = "Temporary account of the MyOwn Portal role tests."
    Set tSC = ##class(Security.Users).Modify(name, .properties)
    Quit $Select($$$ISOK(tSC): "ok", 1: $System.Status.GetErrorText(tSC))
}

ClassMethod RemoveUser(name As %String) As %String [ SqlName = TestRemoveUser, SqlProc ]
{
    If $Extract(name, 1, $Length(..#Prefix)) '= ..#Prefix Quit "refused: name must start with " _ ..#Prefix
    New $Namespace
    Set $Namespace = "%SYS"
    If '##class(Security.Users).Exists(name) Quit "ok"
    Set tSC = ##class(Security.Users).Delete(name)
    Quit $Select($$$ISOK(tSC): "ok", 1: $System.Status.GetErrorText(tSC))
}

}

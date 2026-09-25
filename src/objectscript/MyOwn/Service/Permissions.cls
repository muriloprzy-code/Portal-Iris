Class MyOwn.Service.Permissions
{

/// Access to the published IRIS user, role, resource, and permission APIs.

ClassMethod GetUsers(Output items As %DynamicArray) As %Status
{
    Set tSC = $$$OK
    Set items = []
    Try {
        New $Namespace
        Set $Namespace = "%SYS"
        Set statement = ##class(%SQL.Statement).%New()
        Set tSC = statement.%PrepareClassQuery("Security.Users", "List")
        $$$ThrowOnError(tSC)
        Set result = statement.%Execute("*", "*", "*", 0).%NextResult()
        While result.%Next() {
            Set item = {}
            Set item.name = result.%Get("Name")
            Set item.enabled = result.%Get("Enabled")
            Set item.roles = result.%Get("Roles")
            Set item.lastLogin = result.%Get("LastLoginTime")
            Do items.%Push(item)
        }
    } Catch exception {
        Set tSC = exception.AsStatus()
    }
    Quit tSC
}

ClassMethod GetRoles(Output items As %DynamicArray) As %Status
{
    Set tSC = $$$OK
    Set items = []
    Try {
        New $Namespace
        Set $Namespace = "%SYS"
        Set statement = ##class(%SQL.Statement).%New()
        Set tSC = statement.%PrepareClassQuery("Security.Roles", "List")
        $$$ThrowOnError(tSC)
        Set result = statement.%Execute("*", "*", 0).%NextResult()
        While result.%Next() {
            Set item = {}
            Set item.name = result.%Get("Name")
            Set item.description = result.%Get("Description")
            Set item.grantedRoles = result.%Get("GrantedRoles")
            Set item.canBeEdited = result.%Get("CanBeEdited")
            Do items.%Push(item)
        }
    } Catch exception {
        Set tSC = exception.AsStatus()
    }
    Quit tSC
}

ClassMethod GetResources(Output items As %DynamicArray) As %Status
{
    Set tSC = $$$OK
    Set items = []
    Try {
        New $Namespace
        Set $Namespace = "%SYS"
        Set statement = ##class(%SQL.Statement).%New()
        Set tSC = statement.%PrepareClassQuery("Security.Resources", "List")
        $$$ThrowOnError(tSC)
        Set result = statement.%Execute("*", -1, -1, 0).%NextResult()
        While result.%Next() {
            Set item = {}
            Set item.name = result.%Get("Name")
            Set item.description = result.%Get("Description")
            Set item.publicPermission = result.%Get("PublicPermissionLong")
            Set item.resourceType = result.%Get("ResourceType")
            Set item.canBeDeleted = result.%Get("AllowDelete")
            Do items.%Push(item)
        }
    } Catch exception {
        Set tSC = exception.AsStatus()
    }
    Quit tSC
}

ClassMethod GetUserDetail(username As %String, Output detail As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set detail = {}
    Try {
        Set username = $ZStrip(username, "<>W")
        If username = "" {
            Set tSC = $$$ERROR($$$GeneralError, "A user name is required.")
            $$$ThrowOnError(tSC)
        }

        New $Namespace
        Set $Namespace = "%SYS"
        Kill properties
        Set tSC = ##class(Security.Users).Get(username, .properties)
        $$$ThrowOnError(tSC)

        Set detail.name = username
        Set detail.fullName = $Get(properties("FullName"))
        Set detail.enabled = $Get(properties("Enabled"))
        Set detail.namespace = $Get(properties("NameSpace"))
        Set detail.comment = $Get(properties("Comment"))
        Set detail.expirationDate = $Get(properties("ExpirationDate"))
        Set detail.lastLogin = $Get(properties("LoginDateTime"))
        Set detail.loginService = $Get(properties("LoginService"))
        Set detail.directRoles = ..SplitList($Get(properties("Roles")))

        Set tSC = ##class(Security.Users).GetRoleSet(username, .effectiveRoles)
        $$$ThrowOnError(tSC)
        Set detail.effectiveRoles = ..SplitList(effectiveRoles)

        Set tSC = ##class(Security.Users).GetResourceSet(username, "", .effectiveResources)
        $$$ThrowOnError(tSC)
        Set detail.effectivePermissions = ..SplitPermissions(effectiveResources)
    } Catch exception {
        Set tSC = exception.AsStatus()
    }
    Quit tSC
}

ClassMethod GetRoleDetail(roleName As %String, Output detail As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set detail = {}
    Try {
        Set roleName = $ZStrip(roleName, "<>W")
        If roleName = "" {
            Set tSC = $$$ERROR($$$GeneralError, "A role name is required.")
            $$$ThrowOnError(tSC)
        }

        New $Namespace
        Set $Namespace = "%SYS"
        Kill properties
        Set tSC = ##class(Security.Roles).Get(roleName, .properties, .role)
        $$$ThrowOnError(tSC)

        Set detail.name = roleName
        Set detail.description = $Get(properties("Description"))
        Set detail.grantedRoles = ..SplitList($Get(properties("GrantedRoles")))
        Set detail.permissions = ..SplitPermissions($Get(properties("Resources")))
        Set detail.systemRole = ($Extract(roleName, 1) = "%")
    } Catch exception {
        Set tSC = exception.AsStatus()
    }
    Quit tSC
}

ClassMethod AddUserRole(username As %String, roleName As %String, Output result As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set result = {}
    Try {
        Set username = $ZStrip(username, "<>W")
        Set roleName = $ZStrip(roleName, "<>W")
        Set tSC = ..ValidateRoleChange(username, roleName)
        $$$ThrowOnError(tSC)

        New $Namespace
        Set $Namespace = "%SYS"
        Set roles = roleName
        Set tSC = ##class(Security.Users).AddRoles(username, .roles)
        $$$ThrowOnError(tSC)

        Set result.user = username
        Set result.role = roleName
        Set result.action = "added"
    } Catch exception {
        Set tSC = exception.AsStatus()
    }
    Quit tSC
}

ClassMethod RemoveUserRole(username As %String, roleName As %String, Output result As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set result = {}
    Try {
        Set username = $ZStrip(username, "<>W")
        Set roleName = $ZStrip(roleName, "<>W")
        Set tSC = ..ValidateRoleChange(username, roleName)
        $$$ThrowOnError(tSC)

        New $Namespace
        Set $Namespace = "%SYS"
        Set roles = roleName
        Set tSC = ##class(Security.Users).RemoveRoles(username, .roles)
        $$$ThrowOnError(tSC)

        Set result.user = username
        Set result.role = roleName
        Set result.action = "removed"
    } Catch exception {
        Set tSC = exception.AsStatus()
    }
    Quit tSC
}

ClassMethod CanManage() As %Boolean
{
    Quit $System.Security.Check("%Admin_Secure", "USE")
}

ClassMethod ValidateRoleChange(username As %String, roleName As %String) As %Status [ Private ]
{
    Set tSC = $$$OK
    Try {
        If (username = "") || (roleName = "") {
            Set tSC = $$$ERROR($$$GeneralError, "Both user and role are required.")
            $$$ThrowOnError(tSC)
        }
        If roleName = "%All" {
            Set tSC = $$$ERROR($$$GeneralError, "The %All role cannot be changed through MyOwn Portal.")
            $$$ThrowOnError(tSC)
        }

        New $Namespace
        Set $Namespace = "%SYS"
        Kill properties
        Set tSC = ##class(Security.Users).Get(username, .properties)
        $$$ThrowOnError(tSC)
        Kill roleProperties
        Set tSC = ##class(Security.Roles).Get(roleName, .roleProperties, .role)
        $$$ThrowOnError(tSC)
    } Catch exception {
        Set tSC = exception.AsStatus()
    }
    Quit tSC
}

ClassMethod SplitList(value As %String) As %DynamicArray [ Private ]
{
    Set items = []
    For index = 1:1:$Length(value, ",") {
        Set item = $ZStrip($Piece(value, ",", index), "<>W")
        If item '= "" Do items.%Push(item)
    }
    Quit items
}

ClassMethod SplitPermissions(value As %String) As %DynamicArray [ Private ]
{
    Set items = []
    For index = 1:1:$Length(value, ",") {
        Set entry = $ZStrip($Piece(value, ",", index), "<>W")
        If entry '= "" {
            Set item = {}
            Set item.resource = $Piece(entry, ":", 1)
            Set item.permission = $Piece(entry, ":", 2)
            Do items.%Push(item)
        }
    }
    Quit items
}

}

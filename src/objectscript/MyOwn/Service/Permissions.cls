Class MyOwn.Service.Permissions
{

/// Access to the published IRIS user, role, resource, and permission APIs.

ClassMethod GetUsers(authorization As %String, Output items As %DynamicArray, Output source As %String) As %Status
{
    Set source = "sysadmin-v2"
    Quit ..GetUsersFromSysAdmin(authorization, .items)
}

ClassMethod GetRoles(authorization As %String, Output items As %DynamicArray, Output source As %String) As %Status
{
    Set source = "sysadmin-v2"
    Quit ..GetRolesFromSysAdmin(authorization, .items)
}

ClassMethod GetResources(authorization As %String, Output items As %DynamicArray, Output source As %String) As %Status
{
    Set source = "sysadmin-v2"
    Quit ..GetResourcesFromSysAdmin(authorization, .items)
}

ClassMethod GetUsersFromSysAdmin(authorization As %String, Output items As %DynamicArray) As %Status [ Private ]
{
    Set items = []
    Set tSC = ##class(MyOwn.Service.SysAdminClient).Request("GET", "/api/admin/v2/security/users?names=*&maxRows=1000", authorization, "", .payload, .httpStatus)
    If $$$ISERR(tSC) Quit tSC
    Set records = payload.%Get("result")
    If '$IsObject(records) Quit $$$ERROR($$$GeneralError, "The SysAdmin user response did not include a result array.")
    For index = 0:1:(records.%Size() - 1) {
        Set record = records.%Get(index)
        Set username = record.%Get("Name")
        Set detailPath = "/api/admin/v2/security/user?name=" _ ##class(MyOwn.Service.SysAdminClient).EncodeQueryValue(username)
        Set tSC = ##class(MyOwn.Service.SysAdminClient).Request("GET", detailPath, authorization, "", .detailPayload, .detailHttpStatus)
        If $$$ISERR(tSC) Quit tSC
        Set user = detailPayload.%Get("result")
        If '$IsObject(user) Quit $$$ERROR($$$GeneralError, "The SysAdmin user detail response did not include a result object.")

        Set item = {}
        Set item.name = username
        Set item.enabled = +user.%Get("Enabled")
        Set userRoles = user.%Get("Roles")
        If '$IsObject(userRoles) Set userRoles = []
        Set rolesText = ""
        For roleIndex = 0:1:(userRoles.%Size() - 1) {
            If rolesText '= "" Set rolesText = rolesText _ ", "
            Set rolesText = rolesText _ userRoles.%Get(roleIndex)
        }
        Set item.roles = rolesText
        Set item.lastLogin = ""
        Do items.%Push(item)
    }
    Quit $$$OK
}

ClassMethod GetRolesFromSysAdmin(authorization As %String, Output items As %DynamicArray) As %Status [ Private ]
{
    Set items = []
    Set tSC = ##class(MyOwn.Service.SysAdminClient).Request("GET", "/api/admin/v2/security/roles?maxRows=1000", authorization, "", .payload, .httpStatus)
    If $$$ISERR(tSC) Quit tSC
    Set records = payload.%Get("result")
    If '$IsObject(records) Quit $$$ERROR($$$GeneralError, "The SysAdmin role response did not include a result array.")
    For index = 0:1:(records.%Size() - 1) {
        Set record = records.%Get(index)
        Set item = {}
        Set item.name = record.%Get("Name")
        Set item.description = record.%Get("Description")
        Set item.grantedRoles = ""
        Set item.canBeEdited = ($Extract(item.name, 1) '= "%")
        Do items.%Push(item)
    }
    Quit $$$OK
}

ClassMethod GetResourcesFromSysAdmin(authorization As %String, Output items As %DynamicArray) As %Status [ Private ]
{
    Set items = []
    Set tSC = ##class(MyOwn.Service.SysAdminClient).Request("GET", "/api/admin/v2/security/resources?names=*&maxRows=1000", authorization, "", .payload, .httpStatus)
    If $$$ISERR(tSC) Quit tSC
    Set records = payload.%Get("result")
    If '$IsObject(records) Quit $$$ERROR($$$GeneralError, "The SysAdmin resource response did not include a result array.")
    For index = 0:1:(records.%Size() - 1) {
        Set record = records.%Get(index)
        Set item = {}
        Set item.name = record.%Get("Name")
        Set item.description = record.%Get("Description")
        Set item.publicPermission = record.%Get("PublicPermission")
        Set item.resourceType = record.%Get("ResourceType")
        Set item.canBeDeleted = record.%Get("AllowDelete")
        Do items.%Push(item)
    }
    Quit $$$OK
}

ClassMethod GetUserDetail(username As %String, authorization As %String, Output detail As %DynamicObject, Output source As %String) As %Status
{
    Set source = "sysadmin-v2"
    Quit ..GetUserDetailFromSysAdmin(username, authorization, .detail)
}

ClassMethod GetRoleDetail(roleName As %String, authorization As %String, Output detail As %DynamicObject, Output source As %String) As %Status
{
    Set source = "sysadmin-v2"
    Quit ..GetRoleDetailFromSysAdmin(roleName, authorization, .detail)
}

ClassMethod AddUserRole(username As %String, roleName As %String, authorization As %String, Output result As %DynamicObject, Output source As %String) As %Status
{
    Set source = "sysadmin-v2"
    Quit ..ChangeUserRoleFromSysAdmin(username, roleName, authorization, 1, .result)
}

ClassMethod RemoveUserRole(username As %String, roleName As %String, authorization As %String, Output result As %DynamicObject, Output source As %String) As %Status
{
    Set source = "sysadmin-v2"
    Quit ..ChangeUserRoleFromSysAdmin(username, roleName, authorization, 0, .result)
}

ClassMethod GetUserDetailFromSysAdmin(username As %String, authorization As %String, Output detail As %DynamicObject) As %Status [ Private ]
{
    Set detail = {}
    Set username = $ZStrip(username, "<>W")
    If username = "" Quit $$$ERROR($$$GeneralError, "A user name is required.")
    Set path = "/api/admin/v2/security/user?name=" _ ##class(MyOwn.Service.SysAdminClient).EncodeQueryValue(username)
    Set tSC = ##class(MyOwn.Service.SysAdminClient).Request("GET", path, authorization, "", .payload, .httpStatus)
    If $$$ISERR(tSC) Quit tSC
    Set user = payload.%Get("result")
    If '$IsObject(user) Quit $$$ERROR($$$GeneralError, "The SysAdmin user response did not include a result object.")

    Set directRoles = user.%Get("Roles")
    If '$IsObject(directRoles) Set directRoles = []
    Set effectiveRoles = []
    Set effectivePermissions = []
    Set seenRoles = {}
    Set seenPermissions = {}
    For index = 0:1:(directRoles.%Size() - 1) {
        Set roleName = directRoles.%Get(index)
        Set tSC = ..AppendEffectiveRole(authorization, roleName, seenRoles, effectiveRoles, seenPermissions, effectivePermissions)
        If $$$ISERR(tSC) Quit tSC
    }

    Set detail.name = username
    Set detail.fullName = user.%Get("FullName")
    Set detail.enabled = user.%Get("Enabled")
    Set detail.namespace = user.%Get("NameSpace")
    Set detail.comment = user.%Get("Comment")
    Set detail.expirationDate = user.%Get("ExpirationDate")
    Set detail.lastLogin = ""
    Set detail.loginService = ""
    Set detail.directRoles = directRoles
    Set detail.effectiveRoles = effectiveRoles
    Set detail.effectivePermissions = effectivePermissions
    Quit $$$OK
}

ClassMethod GetRoleDetailFromSysAdmin(roleName As %String, authorization As %String, Output detail As %DynamicObject) As %Status [ Private ]
{
    Set detail = {}
    Set roleName = $ZStrip(roleName, "<>W")
    If roleName = "" Quit $$$ERROR($$$GeneralError, "A role name is required.")
    Set path = "/api/admin/v2/security/role?name=" _ ##class(MyOwn.Service.SysAdminClient).EncodeQueryValue(roleName)
    Set tSC = ##class(MyOwn.Service.SysAdminClient).Request("GET", path, authorization, "", .payload, .httpStatus)
    If $$$ISERR(tSC) Quit tSC
    Set role = payload.%Get("result")
    If '$IsObject(role) Quit $$$ERROR($$$GeneralError, "The SysAdmin role response did not include a result object.")
    Set grantedRoles = role.%Get("GrantedRoles")
    If '$IsObject(grantedRoles) Set grantedRoles = []
    Set permissions = []
    Set resources = role.%Get("Resources")
    If $IsObject(resources) {
        For index = 0:1:(resources.%Size() - 1) {
            Set resource = resources.%Get(index)
            Set permission = {}
            Set permission.resource = resource.%Get("Name")
            Set permission.permission = resource.%Get("Permissions")
            Do permissions.%Push(permission)
        }
    }
    Set detail.name = roleName
    Set detail.description = role.%Get("Description")
    Set detail.grantedRoles = grantedRoles
    Set detail.permissions = permissions
    Set detail.systemRole = ($Extract(roleName, 1) = "%")
    Quit $$$OK
}

ClassMethod ChangeUserRoleFromSysAdmin(username As %String, roleName As %String, authorization As %String, addRole As %Boolean, Output result As %DynamicObject) As %Status [ Private ]
{
    Set result = {}
    Set username = $ZStrip(username, "<>W")
    Set roleName = $ZStrip(roleName, "<>W")
    If (username = "") || (roleName = "") Quit $$$ERROR($$$GeneralError, "Both user and role are required.")
    If roleName = "%All" Quit $$$ERROR($$$GeneralError, "The %All role cannot be changed through MyOwn Portal.")

    Set userPath = "/api/admin/v2/security/user?name=" _ ##class(MyOwn.Service.SysAdminClient).EncodeQueryValue(username)
    Set tSC = ##class(MyOwn.Service.SysAdminClient).Request("GET", userPath, authorization, "", .userPayload, .httpStatus)
    If $$$ISERR(tSC) Quit tSC
    Set rolePath = "/api/admin/v2/security/role?name=" _ ##class(MyOwn.Service.SysAdminClient).EncodeQueryValue(roleName)
    Set tSC = ##class(MyOwn.Service.SysAdminClient).Request("GET", rolePath, authorization, "", .rolePayload, .httpStatus)
    If $$$ISERR(tSC) Quit tSC

    Set user = userPayload.%Get("result")
    If '$IsObject(user) Quit $$$ERROR($$$GeneralError, "The SysAdmin user response did not include a result object.")
    Set currentRoles = user.%Get("Roles")
    If '$IsObject(currentRoles) Set currentRoles = []
    Set updatedRoles = []
    Set alreadyAssigned = 0
    For index = 0:1:(currentRoles.%Size() - 1) {
        Set currentRole = currentRoles.%Get(index)
        If $ZConvert(currentRole, "U") = $ZConvert(roleName, "U") Set alreadyAssigned = 1
        If addRole || ($ZConvert(currentRole, "U") '= $ZConvert(roleName, "U")) Do updatedRoles.%Push(currentRole)
    }
    If addRole && 'alreadyAssigned Do updatedRoles.%Push(roleName)

    Set update = {}
    Do update.%Set("Roles", updatedRoles)
    Set tSC = ##class(MyOwn.Service.SysAdminClient).Request("PUT", userPath, authorization, update.%ToJSON(), .updatedPayload, .httpStatus)
    If $$$ISERR(tSC) Quit tSC
    Set result.user = username
    Set result.role = roleName
    Set result.action = $Select(addRole:"added", 1:"removed")
    Quit $$$OK
}

ClassMethod AppendEffectiveRole(authorization As %String, roleName As %String, seenRoles As %DynamicObject, effectiveRoles As %DynamicArray, seenPermissions As %DynamicObject, effectivePermissions As %DynamicArray) As %Status [ Private ]
{
    If roleName = "" Quit $$$OK
    If seenRoles.%IsDefined(roleName) Quit $$$OK
    Do seenRoles.%Set(roleName, 1)
    Do effectiveRoles.%Push(roleName)
    Set path = "/api/admin/v2/security/role?name=" _ ##class(MyOwn.Service.SysAdminClient).EncodeQueryValue(roleName)
    Set tSC = ##class(MyOwn.Service.SysAdminClient).Request("GET", path, authorization, "", .payload, .httpStatus)
    If $$$ISERR(tSC) Quit tSC
    Set role = payload.%Get("result")
    If '$IsObject(role) Quit $$$ERROR($$$GeneralError, "The SysAdmin role response did not include a result object.")

    Set resources = role.%Get("Resources")
    If $IsObject(resources) {
        For index = 0:1:(resources.%Size() - 1) {
            Set resource = resources.%Get(index)
            Set resourceName = resource.%Get("Name")
            Set resourcePermission = resource.%Get("Permissions")
            Set permissionKey = resourceName _ ":" _ resourcePermission
            If 'seenPermissions.%IsDefined(permissionKey) {
                Do seenPermissions.%Set(permissionKey, 1)
                Set permission = {}
                Set permission.resource = resourceName
                Set permission.permission = resourcePermission
                Do effectivePermissions.%Push(permission)
            }
        }
    }
    Set grantedRoles = role.%Get("GrantedRoles")
    If $IsObject(grantedRoles) {
        For index = 0:1:(grantedRoles.%Size() - 1) {
            Set tSC = ..AppendEffectiveRole(authorization, grantedRoles.%Get(index), seenRoles, effectiveRoles, seenPermissions, effectivePermissions)
            If $$$ISERR(tSC) Quit tSC
        }
    }
    Quit $$$OK
}

ClassMethod CanManage() As %Boolean
{
    Quit $System.Security.Check("%Admin_Secure", "USE")
}

}

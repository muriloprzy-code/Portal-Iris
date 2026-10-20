Class MyOwn.Agent.Context.Access
{

ClassMethod ComparePrivileges(user As %String, role As %String, authorization As %String, Output context As %DynamicObject) As %Status
{
    Set context = {}
    Set user = ##class(MyOwn.Agent.Sanitize).Identifier(user)
    Set role = ##class(MyOwn.Agent.Sanitize).Identifier(role)
    If (user = "") || (role = "") Quit $$$ERROR($$$GeneralError, "A valid user and role are required.")
    Set tSC = ##class(MyOwn.Service.Permissions).GetUserDetail(user, authorization, .profile, .profileSource)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ##class(MyOwn.Service.Permissions).GetRoleDetail(role, authorization, .roleDetail, .roleSource)
    If $$$ISERR(tSC) Quit tSC

    Set context.requester = user
    Set context.roleRequested = role
    Set context.currentRoles = profile.effectiveRoles
    Set context.delta = []
    Set context.deltaLevel = "low"
    Set context.riskFloor = "low"
    Set existing = {}
    Set permissions = profile.effectivePermissions
    For index = 0:1:(permissions.%Size() - 1) {
        Set permission = permissions.%Get(index)
        Do existing.%Set(permission.%Get("resource"), permission.%Get("permission"))
    }
    Set additions = roleDetail.permissions
    For index = 0:1:(additions.%Size() - 1) {
        Set permission = additions.%Get(index)
        Set resource = permission.%Get("resource")
        If 'existing.%IsDefined(resource) {
            Do context.delta.%Push(permission)
            If ..IsHighRisk(resource) Set context.riskFloor = "high"
            If permission.%Get("permission") [ "W" Set context.deltaLevel = "medium"
        }
    }
    If context.riskFloor = "high" Set context.deltaLevel = "high"
    Set context.untrustedData = {}
    Quit $$$OK
}

ClassMethod IsHighRisk(resource As %String) As %Boolean [ Private ]
{
    Set tSC = ##class(MyOwn.Agent.Config).GetOrCreate(.config)
    If $$$ISERR(tSC) Quit 1
    Set found = 0
    Set iterator = config.HighRiskResources.GetIterator()
    While iterator.%GetNext(.key, .value) {
        If $ZConvert(value, "U") = $ZConvert(resource, "U") {
            Set found = 1
            Quit
        }
    }
    Quit found
}

}

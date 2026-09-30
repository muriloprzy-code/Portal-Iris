Class MyOwn.Service.Applications
{

Parameter ProtectedApplication = "/myown/api";

Parameter ProtectedRoot = "/myown";

/// Read-only inventory of web applications through the published security API.
ClassMethod GetApplications(authorization As %String, Output items As %DynamicArray, Output source As %String) As %Status
{
    Set source = "sysadmin-v2"
    Quit ..GetApplicationsFromSysAdmin(authorization, .items)
}

/// Return the published configuration for one web application.
ClassMethod GetApplication(application As %String, authorization As %String, Output item As %DynamicObject, Output source As %String) As %Status
{
    Set source = "sysadmin-v2"
    Quit ..GetApplicationFromSysAdmin(application, authorization, .item)
}

/// Enable or disable a project-owned application using the published security API.
ClassMethod SetApplicationEnabled(application As %String, enabled As %Boolean, authorization As %String, Output item As %DynamicObject, Output source As %String) As %Status
{
    Set source = "sysadmin-v2"
    Quit ..SetApplicationEnabledWithSysAdmin(application, enabled, authorization, .item)
}

ClassMethod GetApplicationsFromSysAdmin(authorization As %String, Output items As %DynamicArray) As %Status [ Private ]
{
    Set items = []
    Set tSC = ##class(MyOwn.Service.SysAdminClient).Request("GET", "/api/admin/v2/web-apps?maxRows=1000", authorization, "", .payload, .httpStatus)
    If $$$ISERR(tSC) Quit tSC
    Set records = payload.%Get("result")
    If '$IsObject(records) Quit $$$ERROR($$$GeneralError, "The SysAdmin web application response did not include a result array.")
    For index = 0:1:(records.%Size() - 1) {
        Set record = records.%Get(index)
        Set application = record.%Get("Name")
        Set detailPath = "/api/admin/v2/web-app?name=" _ ##class(MyOwn.Service.SysAdminClient).EncodeQueryValue(application)
        Set tSC = ##class(MyOwn.Service.SysAdminClient).Request("GET", detailPath, authorization, "", .detailPayload, .detailHttpStatus)
        If $$$ISERR(tSC) Quit tSC
        Set applicationData = detailPayload.%Get("result")
        If '$IsObject(applicationData) Quit $$$ERROR($$$GeneralError, "The SysAdmin web application detail response did not include a result object.")

        Set item = {}
        Set item.name = application
        Set item.namespace = applicationData.%Get("NameSpace")
        Set item.namespaceDefault = +applicationData.%Get("IsNameSpaceDefault")
        Set item.enabled = +applicationData.%Get("Enabled")
        Set item.type = record.%Get("Type")
        Set item.resource = applicationData.%Get("Resource")
        Set item.authenticationMethods = ..JoinDynamicArray(record.%Get("AuthenticationMethods"))
        Set item.systemApplication = record.%Get("IsSystemApp")
        Set item.dispatchClass = applicationData.%Get("DispatchClass")
        Do items.%Push(item)
    }
    Quit $$$OK
}

ClassMethod GetApplicationFromSysAdmin(application As %String, authorization As %String, Output item As %DynamicObject) As %Status [ Private ]
{
    Set item = {}
    If application = "" Quit $$$ERROR($$$GeneralError, "The application name is required.")
    Set path = "/api/admin/v2/web-app?name=" _ ##class(MyOwn.Service.SysAdminClient).EncodeQueryValue(application)
    Set tSC = ##class(MyOwn.Service.SysAdminClient).Request("GET", path, authorization, "", .payload, .httpStatus)
    If $$$ISERR(tSC) Quit tSC
    Set applicationData = payload.%Get("result")
    If '$IsObject(applicationData) Quit $$$ERROR($$$GeneralError, "The SysAdmin web application response did not include a result object.")
    Set namespace = applicationData.%Get("NameSpace")
    Set reason = ..ProtectionReason(application, namespace)
    Set item.name = application
    Set item.description = applicationData.%Get("Description")
    Set item.namespace = namespace
    Set item.enabled = applicationData.%Get("Enabled")
    Set item.dispatchClass = applicationData.%Get("DispatchClass")
    Set item.resource = applicationData.%Get("Resource")
    Set item.authenticationCode = applicationData.%Get("AutheEnabled")
    Set item.cookiePath = applicationData.%Get("CookiePath")
    Set item.sessionUse = applicationData.%Get("UseCookies")
    Set item.namespaceDefault = applicationData.%Get("IsNameSpaceDefault")
    Set item.canManage = ..CanManage()
    Set item.manageable = (reason = "")
    Set item.protectionReason = reason
    Quit $$$OK
}

ClassMethod SetApplicationEnabledWithSysAdmin(application As %String, enabled As %Boolean, authorization As %String, Output item As %DynamicObject) As %Status [ Private ]
{
    Set item = {}
    If '..CanManage() Quit $$$ERROR($$$GeneralError, "The current user cannot manage web applications.")
    Set tSC = ..GetApplicationFromSysAdmin(application, authorization, .detail)
    If $$$ISERR(tSC) Quit tSC
    If 'detail.manageable Quit $$$ERROR($$$GeneralError, detail.protectionReason)
    Set update = {}
    Set update.Enabled = +enabled
    Set path = "/api/admin/v2/web-app?name=" _ ##class(MyOwn.Service.SysAdminClient).EncodeQueryValue(application)
    Set tSC = ##class(MyOwn.Service.SysAdminClient).Request("PUT", path, authorization, update.%ToJSON(), .payload, .httpStatus)
    If $$$ISERR(tSC) Quit tSC
    Set item.name = application
    Set item.enabled = +enabled
    Set item.action = $Select(enabled:"enabled", 1:"disabled")
    Quit $$$OK
}

ClassMethod JoinDynamicArray(values As %DynamicAbstractObject) As %String [ Private ]
{
    If '$IsObject(values) Quit ""
    Set text = ""
    For index = 0:1:(values.%Size() - 1) {
        If text '= "" Set text = text _ ", "
        Set text = text _ values.%Get(index)
    }
    Quit text
}

/// Application management requires the %Admin_Secure resource.
ClassMethod CanManage() As %Boolean
{
    Quit $System.Security.Check("%Admin_Secure", "USE")
}

/// Keep state changes inside this project and protect every application that
/// serves the portal itself (the REST API and the static React frontend).
ClassMethod ProtectionReason(application As %String, namespace As %String) As %String [ Private ]
{
    Set lower = $ZConvert(application, "L")
    If (lower = ..#ProtectedApplication) || (lower = ..#ProtectedRoot) || ($Extract(lower, 1, $Length(..#ProtectedRoot) + 1) = (..#ProtectedRoot _ "/")) Quit "The MyOwn Portal applications are protected from state changes."
    If namespace '= "MYOWN" Quit "Only applications in the MYOWN namespace can be changed."
    Quit ""
}

}

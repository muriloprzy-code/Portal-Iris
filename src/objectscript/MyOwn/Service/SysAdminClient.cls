Class MyOwn.Service.SysAdminClient Extends %RegisteredObject
{

Parameter DefaultPort = 52773;

Parameter MaximumResponseLength = 2097152;

/// Calls the local IRIS SysAdmin API. Requests are deliberately restricted to
/// /api/admin so this helper cannot be turned into a general-purpose proxy.
ClassMethod Request(method As %String, path As %String, authorization As %String, body As %String, Output payload As %DynamicObject, Output httpStatus As %Integer) As %Status
{
    Set tSC = $$$OK
    Set payload = {}
    Set httpStatus = 0
    Try {
        Set method = $ZConvert(method, "U")
        If '$ListFind($ListBuild("GET", "POST", "PUT", "DELETE"), method) {
            Set tSC = $$$ERROR($$$GeneralError, "Unsupported SysAdmin API method.")
            $$$ThrowOnError(tSC)
        }
        If $Extract(path, 1, $Length("/api/admin/")) '= "/api/admin/" {
            Set tSC = $$$ERROR($$$GeneralError, "Only local SysAdmin API paths are allowed.")
            $$$ThrowOnError(tSC)
        }
        If (path [ "\") || (path [ "#") || ($ZConvert(path, "L") [ "://") {
            Set tSC = $$$ERROR($$$GeneralError, "The SysAdmin API path contains a prohibited value.")
            $$$ThrowOnError(tSC)
        }
        If authorization = "" {
            Set tSC = $$$ERROR($$$GeneralError, "The authenticated IRIS request did not include an Authorization header.")
            $$$ThrowOnError(tSC)
        }

        Set request = ##class(%Net.HttpRequest).%New()
        Set request.Server = "127.0.0.1"
        Set request.Port = ..GetPort()
        Set request.Https = 0
        Set request.Timeout = 15
        Set request.OpenTimeout = 5
        Set request.WriteTimeout = 5
        Set request.FollowRedirect = 0
        Set request.AcceptGzip = 0
        Set request.UserAgent = "MyOwn-SysAdminClient/1.0"
        Set request.ContentType = "application/json"
        Do request.SetHeader("Accept", "application/json")
        Do request.SetHeader("Authorization", authorization)

        If body '= "" Do request.EntityBody.Write(body)
        Set tSC = request.Send(method, path)
        $$$ThrowOnError(tSC)

        Set response = request.HttpResponse
        Set httpStatus = +response.StatusCode
        Set responseBody = ""
        If $IsObject(response.Data) Set responseBody = response.Data.Read(..#MaximumResponseLength)
        If responseBody '= "" Set payload = {}.%FromJSON(responseBody)

        If (httpStatus < 200) || (httpStatus >= 300) {
            Set message = "SysAdmin API returned HTTP " _ httpStatus _ "."
            If $IsObject(payload) {
                Set statusObject = payload.%Get("status")
                If $IsObject(statusObject) {
                    Set summary = statusObject.%Get("summary")
                    If summary '= "" Set message = summary
                }
            }
            Set tSC = $$$ERROR($$$GeneralError, message)
        }
    } Catch exception {
        Set tSC = exception.AsStatus()
    }
    Quit tSC
}

/// Reads the unversioned capability endpoint described by the SysAdmin API.
ClassMethod GetInfo(authorization As %String, Output info As %DynamicObject) As %Status
{
    Set info = {}
    Set tSC = ..Request("GET", "/api/admin/info", authorization, "", .payload, .httpStatus)
    If $$$ISERR(tSC) Quit tSC
    Set info = payload.%Get("result")
    If '$IsObject(info) Quit $$$ERROR($$$GeneralError, "The SysAdmin API info response did not include a result object.")
    Quit $$$OK
}

/// Verifies that the installed SysAdmin API satisfies the portal requirement.
ClassMethod RequireV2(authorization As %String, Output info As %DynamicObject) As %Status
{
    Set info = {}
    Set tSC = ..GetInfo(authorization, .info)
    If $$$ISERR(tSC) Quit tSC
    If +info.%Get("apiVersion") < 2 Quit $$$ERROR($$$GeneralError, "MyOwn Portal requires SysAdmin API v2 or later.")
    Quit $$$OK
}

/// Escapes a value before it is placed in a SysAdmin API query string.
ClassMethod EncodeQueryValue(value As %String) As %String
{
    Quit $ZConvert(value, "O", "URL")
}

ClassMethod GetPort() As %Integer [ Private ]
{
    Set port = +$Get(^MyOwn.Config("SysAdminPort"))
    If port < 1 Set port = ..#DefaultPort
    Quit port
}

}

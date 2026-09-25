Class MyOwn.Service.APIExplorer Extends %RegisteredObject
{

Parameter MaximumBodyLength = 32768;

Parameter MaximumResponseLength = 65536;

/// Execute a bounded request against this IRIS web server only.
ClassMethod Execute(method As %String, path As %String, headers As %DynamicObject, body As %String, authorization As %String, port As %Integer, Output result As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set result = {}
    Try {
        Set method = $ZConvert(method, "U")
        Set tSC = ..ValidateRequest(method, path, body)
        $$$ThrowOnError(tSC)

        Set request = ##class(%Net.HttpRequest).%New()
        Set request.Server = "127.0.0.1"
        Set request.Port = port
        Set request.Https = 0
        Set request.Timeout = 10
        Set request.OpenTimeout = 5
        Set request.WriteTimeout = 5
        Set request.FollowRedirect = 0
        Set request.AcceptGzip = 0
        Set request.UserAgent = "MyOwn-APIExplorer/1.0"

        If authorization '= "" Do request.SetHeader("Authorization", authorization)
        Set tSC = ..ApplyHeaders(request, headers)
        $$$ThrowOnError(tSC)

        If body '= "" {
            If request.ContentType = "" Set request.ContentType = "application/json"
            Do request.EntityBody.Write(body)
        }

        Set started = $ZHOROLOG
        Set tSC = request.Send(method, path)
        $$$ThrowOnError(tSC)
        Set finished = $ZHOROLOG

        Set response = request.HttpResponse
        Set responseBody = ""
        If $IsObject(response.Data) Set responseBody = response.Data.Read(..#MaximumResponseLength)

        Set elapsed = finished - started
        Set result.method = method
        Set result.path = path
        Set result.status = +response.StatusCode
        Set result.statusText = response.ReasonPhrase
        Set result.durationMs = $Justify(elapsed * 1000, 0, 0)
        Set result.contentType = response.ContentType
        Set result.body = responseBody
        Set result.truncated = $Select($IsObject(response.Data):'response.Data.AtEnd, 1:0)
    } Catch exception {
        Set tSC = exception.AsStatus()
    }
    Quit tSC
}

ClassMethod ValidateRequest(method As %String, path As %String, body As %String) As %Status [ Private ]
{
    If '$ListFind($ListBuild("GET", "HEAD", "POST", "PUT", "PATCH", "DELETE"), method) Quit $$$ERROR($$$GeneralError, "Unsupported HTTP method.")
    If path = "" Quit $$$ERROR($$$GeneralError, "The request path is required.")
    If $Length(path) > 2048 Quit $$$ERROR($$$GeneralError, "The request path is too long.")
    If $Length(body) > ..#MaximumBodyLength Quit $$$ERROR($$$GeneralError, "The request body exceeds 32 KB.")

    Set lower = $ZConvert(path, "L")
    If $Extract(path, 1) '= "/" Quit $$$ERROR($$$GeneralError, "Only local absolute paths are allowed.")
    If $Extract(path, 1, 2) = "//" Quit $$$ERROR($$$GeneralError, "Network paths are not allowed.")
    If (lower [ "://") || (path [ "\") || (lower [ "%5c") || (lower [ "%2e") || (path [ "#") Quit $$$ERROR($$$GeneralError, "The request path contains a prohibited value.")

    Set allowed = 0
    If (lower = "/myown/api") || ($Extract(lower, 1, $Length("/myown/api/")) = "/myown/api/") Set allowed = 1
    If $Extract(lower, 1, 5) = "/api/" Set allowed = 1
    If 'allowed Quit $$$ERROR($$$GeneralError, "Only local MyOwn Portal and IRIS API paths are allowed.")
    If $Piece(lower, "?", 1) = "/myown/api/apis/test" Quit $$$ERROR($$$GeneralError, "The explorer cannot call itself.")
    Quit $$$OK
}

ClassMethod ApplyHeaders(request As %Net.HttpRequest, headers As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    If '$IsObject(headers) Quit tSC

    Set count = 0
    Set iterator = headers.%GetIterator()
    While iterator.%GetNext(.name, .value) {
        Set count = count + 1
        If count > 20 {
            Set tSC = $$$ERROR($$$GeneralError, "No more than 20 headers are allowed.")
            Quit
        }
        Set lower = $ZConvert(name, "L")
        If (name [ $Char(13)) || (name [ $Char(10)) || (value [ $Char(13)) || (value [ $Char(10)) {
            Set tSC = $$$ERROR($$$GeneralError, "Header line breaks are not allowed.")
            Quit
        }
        If ($Length(name) > 100) || ($Length(value) > 2048) {
            Set tSC = $$$ERROR($$$GeneralError, "A request header is too long.")
            Quit
        }
        If $ListFind($ListBuild("authorization", "cookie", "host", "content-length", "connection", "proxy-authorization", "transfer-encoding"), lower) {
            Set tSC = $$$ERROR($$$GeneralError, "A protected request header was provided.")
            Quit
        }
        If lower = "content-type" {
            Set request.ContentType = value
        } Else {
            Set tSC = request.SetHeader(name, value)
            If $$$ISERR(tSC) Quit
        }
    }
    Quit tSC
}

}

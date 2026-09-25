Class MyOwn.Service.Logs
{

/// Returns a bounded, read-only view of recent messages.log events.
ClassMethod GetLogs(Output response As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set response = {}
    Set items = []
    Set maximum = 500
    Set total = 0
    Set file = ""
    Try {
        Set filename = ##class(%File).ManagerDirectory() _ "messages.log"
        Set file = ##class(%File).%New(filename)
        Set tSC = file.Open("RU")
        $$$ThrowOnError(tSC)

        While 'file.AtEnd {
            Set readStatus = $$$OK
            Set line = file.ReadLine(, .readStatus)
            Set tSC = readStatus
            $$$ThrowOnError(tSC)
            If $Extract(line, 9) '= "-" Continue
            If line '[ "[" Continue
            If line '[ "]" Continue

            Set event = ..ParseLine(line, total + 1)
            If '$IsObject(event) Continue

            Set total = total + 1
            Set slot = ((total - 1) # maximum) + 1
            Set recent(slot) = event
        }
        Do file.Close()

        Set returned = total
        If returned > maximum Set returned = maximum
        For offset = 0:1:(returned - 1) {
            Set slot = ((total - 1 - offset) # maximum) + 1
            Do items.%Push(recent(slot))
        }

        Set response.items = items
        Set response.totalRead = total
        Set response.limit = maximum
        Set response.truncated = (total > maximum)
        Set response.source = "messages.log"
    } Catch exception {
        If $IsObject(file) Do file.Close()
        Set tSC = exception.AsStatus()
    }
    Quit tSC
}

ClassMethod ParseLine(line As %String, sequence As %Integer) As %DynamicObject
{
    Set firstSpace = $Find(line, " ")
    If firstSpace = 0 Quit ""

    Set rawTimestamp = $Extract(line, 1, firstSpace - 2)
    Set remainder = $Extract(line, firstSpace, *)
    Set closePid = $Find(remainder, ")")
    If closePid = 0 Quit ""

    Set pid = $Piece($Piece(remainder, "(", 2), ")", 1)
    Set afterPid = $ZStrip($Extract(remainder, closePid, *), "<W")
    Set severityCode = +$Piece(afterPid, " ", 1)
    Set sourceStart = $Find(afterPid, "[")
    Set sourceEnd = $Find(afterPid, "]")
    If (sourceStart = 0) || (sourceEnd = 0) Quit ""

    Set event = {}
    Set event.id = rawTimestamp _ "-" _ pid _ "-" _ sequence
    Set event.timestamp = ..ToISO(rawTimestamp)
    Set event.pid = pid
    Set event.severityCode = severityCode
    Set event.severity = ..SeverityName(severityCode)
    Set event.source = $Extract(afterPid, sourceStart, sourceEnd - 2)
    Set event.message = ..Sanitize($ZStrip($Extract(afterPid, sourceEnd, *), "<W"))
    Quit event
}

/// Converts the messages.log stamp (MM/DD/YY-HH:MM:SS:mmm) to ISO 8601 local time
/// (YYYY-MM-DDTHH:MM:SS.mmm). The log separates milliseconds with a colon, which
/// JavaScript cannot parse, so the last field is emitted as a decimal fraction.
ClassMethod ToISO(value As %String) As %String
{
    Set date = $Piece(value, "-", 1)
    Set time = $Piece(value, "-", 2, *)
    Set year = $Piece(date, "/", 3)
    If $Length(year) = 2 Set year = "20" _ year
    Set clock = $Piece(time, ":", 1, 3)
    Set millis = $Piece(time, ":", 4)
    Set fraction = $Select(millis '= "":"." _ millis, 1:"")
    Quit year _ "-" _ $Piece(date, "/", 1) _ "-" _ $Piece(date, "/", 2) _ "T" _ clock _ fraction
}

ClassMethod SeverityName(code As %Integer) As %String
{
    If code >= 3 Quit "Fatal"
    If code = 2 Quit "Error"
    If code = 1 Quit "Warning"
    Quit "Information"
}

ClassMethod Sanitize(message As %String) As %String
{
    Set lower = $ZConvert(message, "L")
    If (lower [ "password") || (lower [ "secret") || (lower [ "token") || (lower [ "authorization") || (lower [ "credential") {
        Quit "[Potentially sensitive message hidden]"
    }
    Quit message
}

}

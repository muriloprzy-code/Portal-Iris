Class MyOwn.Service.Audit
{

Parameter Source = "MyOwn";
Parameter Type = "Administration";
Parameter Event = "Change";

/// Records safe metadata for an attempted state-changing operation.
ClassMethod Record(action As %String, target As %String, succeeded As %Boolean) As %Status
{
    Set action = ..SafeValue(action, 40)
    Set target = ..SafeValue(target, 120)
    Set outcome = $Select(succeeded:"Success", 1:"Failure")
    Set eventData = "action=" _ action _ ";target=" _ target _ ";outcome=" _ outcome
    Set description = action _ " " _ outcome
    Quit $System.Security.Audit(..#Source, ..#Type, ..#Event, eventData, description)
}

ClassMethod SafeValue(value As %String, maximum As %Integer) As %String [ Private ]
{
    Set value = $Translate(value, $Char(13, 10, 9), "   ")
    Set value = $Replace(value, ";", "_")
    Set value = $Replace(value, "=", "_")
    Quit $Extract(value, 1, maximum)
}

}

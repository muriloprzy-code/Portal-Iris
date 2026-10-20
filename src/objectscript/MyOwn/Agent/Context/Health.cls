Class MyOwn.Agent.Context.Health
{

ClassMethod Current(Output context As %DynamicObject) As %Status
{
    Set tSC = ##class(MyOwn.Service.HealthAnalysis).GetReport(.report)
    If $$$ISERR(tSC) Quit tSC
    Set context = {}
    Set context.health = report
    Set context.anomalies = report.anomalies
    Set context.candidates = []
    Set context.untrustedData = {}
    Quit $$$OK
}

ClassMethod MetricHistory(metric As %String, count As %Integer = 20, Output data As %DynamicArray) As %Status
{
    Set data = []
    If count < 1 Set count = 1
    If count > 50 Set count = 50
    Set metricPosition = $Select(metric="diskUsedPercent":3, metric="databaseSpacePercent":4, metric="lockTablePercent":5, metric="processes":7, 1:0)
    If metricPosition = 0 Quit $$$ERROR($$$GeneralError, "Unsupported metric")
    Set key = ""
    Set returned = 0
    For {
        Set key = $Order(^MyOwn.HealthSnapshot(key), -1)
        If (key = "") || (returned >= count) Quit
        Set entry = $Get(^MyOwn.HealthSnapshot(key))
        If $Length(entry, "|") >= metricPosition {
            Set point = {}
            Set point.at = key
            Set point.value = +$Piece(entry, "|", metricPosition)
            Do data.%Push(point)
            Set returned = returned + 1
        }
    }
    Quit $$$OK
}

}

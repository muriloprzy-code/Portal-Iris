Class MyOwn.Service.HealthAnalysis
{

/// Builds one report from live IRIS metrics, Embedded Python scoring, and IRIS Vector Search.
ClassMethod GetReport(Output report As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set report = {}
    Try {
        Set tSC = ##class(MyOwn.Service.System).GetSummary(.summary)
        $$$ThrowOnError(tSC)

        Set diskRisk = ..PercentRisk(summary.disk.usedPercent)
        Set databaseRisk = ..PercentRisk(summary.databaseSpace)
        Set lockRisk = ..PercentRisk(summary.lockTable)
        Set alertRisk = ..Bound((+summary.seriousAlerts) / 5)
        Set processRisk = ..Bound((+summary.processes) / 200)

        Set analysisJSON = ..AnalyzeWithPython(diskRisk, databaseRisk, lockRisk, alertRisk, processRisk)
        Set analysis = {}.%FromJSON(analysisJSON)

        Set report.score = analysis.score
        Set report.status = analysis.status
        Set report.summary = analysis.summary
        Set report.engine = "InterSystems IRIS Embedded Python"
        Set report.metrics = {}
        Set report.metrics.diskUsedPercent = +summary.disk.usedPercent
        Set report.metrics.databaseSpacePercent = +(databaseRisk * 100)
        Set report.metrics.lockTablePercent = +(lockRisk * 100)
        Set report.metrics.seriousAlerts = +summary.seriousAlerts
        Set report.metrics.processes = +summary.processes

        Set healthyReserve = 1 - ..MaxRisk(diskRisk, databaseRisk, lockRisk, alertRisk, processRisk)
        Set vectorText = diskRisk _ "," _ databaseRisk _ "," _ lockRisk _ "," _ alertRisk _ "," _ processRisk _ "," _ healthyReserve
        Set tSC = ..FindClosestPattern(vectorText, .match)
        $$$ThrowOnError(tSC)
        Set report.vectorMatch = match
    } Catch exception {
        Set tSC = exception.AsStatus()
    }
    Quit tSC
}

/// Embedded Python performs the deliberately small and explainable scoring model.
ClassMethod AnalyzeWithPython(diskRisk As %Double, databaseRisk As %Double, lockRisk As %Double, alertRisk As %Double, processRisk As %Double) As %String [ Language = python ]
{
    import json

    risks = {
        "disk": float(diskRisk),
        "database": float(databaseRisk),
        "locks": float(lockRisk),
        "alerts": float(alertRisk),
        "processes": float(processRisk),
    }
    weights = {"disk": 0.32, "database": 0.23, "locks": 0.18, "alerts": 0.20, "processes": 0.07}
    weighted_risk = sum(risks[name] * weights[name] for name in risks)
    score = max(0, min(100, round(100 * (1 - weighted_risk))))

    if score >= 80:
        status = "Healthy"
    elif score >= 60:
        status = "Attention"
    else:
        status = "Critical"

    labels = {"disk": "disk usage", "database": "database capacity", "locks": "lock table usage", "alerts": "serious alerts", "processes": "process load"}
    main_factor = max(risks, key=risks.get)
    if status == "Healthy":
        summary = "The instance is healthy and the monitored resources are within the expected range."
    else:
        summary = f"The instance needs {status.lower()}; the strongest risk signal is {labels[main_factor]}."

    return json.dumps({"score": score, "status": status, "summary": summary})
}

ClassMethod FindClosestPattern(vectorText As %String, Output match As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set match = {}
    Try {
        Set statement = ##class(%SQL.Statement).%New()
        Set sql = "SELECT TOP 1 Code, Title, Severity, Recommendation, VECTOR_COSINE(MetricVector, TO_VECTOR(?, DOUBLE)) AS Similarity FROM MyOwn.HealthPattern ORDER BY Similarity DESC"
        Set tSC = statement.%Prepare(sql)
        $$$ThrowOnError(tSC)
        Set result = statement.%Execute(vectorText)
        If result.%SQLCODE < 0 Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, result.%Message))
        If result.%Next() {
            Set match.code = result.%Get("Code")
            Set match.title = result.%Get("Title")
            Set match.severity = result.%Get("Severity")
            Set match.recommendation = result.%Get("Recommendation")
            Set match.similarity = +$Justify(result.%Get("Similarity") * 100, 0, 1)
        } Else {
            Set tSC = $$$ERROR($$$GeneralError, "No health patterns are available.")
        }
    } Catch exception {
        Set tSC = exception.AsStatus()
    }
    Quit tSC
}

ClassMethod PercentRisk(value As %String) As %Double [ Private ]
{
    Set normalized = $ZConvert(value, "U")
    If normalized = "NORMAL" Quit 0.1
    If normalized = "WARNING" Quit 0.6
    If (normalized = "ALERT") || (normalized = "CRITICAL") Quit 1
    Set numeric = +$Translate(value, "%", "")
    Quit ..Bound(numeric / 100)
}

ClassMethod Bound(value As %Double) As %Double [ Private ]
{
    Quit $Select(value<0:0, value>1:1, 1:value)
}

ClassMethod MaxRisk(a As %Double, b As %Double, c As %Double, d As %Double, e As %Double) As %Double [ Private ]
{
    Set maximum = a
    If b > maximum Set maximum = b
    If c > maximum Set maximum = c
    If d > maximum Set maximum = d
    If e > maximum Set maximum = e
    Quit maximum
}

}

/// Recorded model answers for MYOWN_AI_MODE=replay (no key, no network). The "t03" cases are the
/// raw answers of gemini-3.8-flash in the T03 real test (docs/AI-HUB-NOTES.md, "Teste real"),
/// with the task id, user and role replaced by placeholders; latency and tokens are the measured
/// ones. The "synthetic" cases fill workflow branches T03 did not cover, and the test cases
/// (invalid-json, timeout, provider-error, write-tool) exercise the fallback and the policy.
Class MyOwn.AIHub.Fixtures
{

/// Picks a case from the context (context.replayCase wins when present).
ClassMethod Pick(workflow As %String, context As %DynamicObject) As %String
{
    If context.%Get("replayCase") '= "" Quit context.replayCase
    If workflow = "access-request" {
        Quit $Case(context.%Get("riskFloor"), "high": "access-high", "medium": "access-medium", : "access-low")
    }
    Set task = context.%Get("task")
    If $IsObject(task) {
        If task.%Get("suspended") && task.%Get("lastRunOk") Quit "task-recovered"
        If task.%Get("consecutiveFailures") >= 3 Quit "task-failing"
    }
    If $IsObject(context.%Get("logs")) && (context.logs.%Size() > 0) Quit "log-alert"
    Set anomalies = context.%Get("anomalies")
    If $IsObject(anomalies) && (anomalies.%Size() > 0) {
        Set critical = 0
        For index = 0:1:(anomalies.%Size() - 1) {
            If anomalies.%Get(index).%Get("severity") = "critical" Set critical = 1
        }
        Quit $Select(critical: "disk-critical", 1: "warning")
    }
    Quit "nothing"
}

/// The fixture of a case: {source, raw, latencyMs, usage, tools[], error{reason, detail}}.
ClassMethod Get(case As %String, Output fixture As %DynamicObject) As %Status
{
    Set fixture = ""
    Set xdata = ##class(%Dictionary.CompiledXData).%OpenId($ClassName() _ "||Cases")
    If '$IsObject(xdata) Quit $$$ERROR($$$GeneralError, "fixtures not found")
    Set all = {}.%FromJSON(xdata.Data)
    Set fixture = all.%Get(case)
    If '$IsObject(fixture) Quit $$$ERROR($$$GeneralError, "unknown replay case")
    Quit $$$OK
}

/// Replaces {{taskId}}, {{requester}} and {{roleRequested}} with JSON-escaped context values.
ClassMethod Fill(raw As %String, context As %DynamicObject) As %String
{
    Set taskId = ""
    Set candidates = context.%Get("candidates")
    If $IsObject(candidates) && (candidates.%Size() > 0) Set taskId = candidates.%Get(0).%Get("id")
    If (taskId = "") && $IsObject(context.%Get("task")) Set taskId = context.task.%Get("id")
    Set raw = $Replace(raw, "{{taskId}}", $ZConvert(taskId, "O", "JSON"))
    Set raw = $Replace(raw, "{{requester}}", $ZConvert(context.%Get("requester"), "O", "JSON"))
    Quit $Replace(raw, "{{roleRequested}}", $ZConvert(context.%Get("roleRequested"), "O", "JSON"))
}

XData Cases [ MimeType = application/json ]
{
{
  "disk-critical": {"source": "t03:C1", "latencyMs": 35007, "usage": {"promptTokens": 311, "completionTokens": 129, "totalTokens": 842},
    "raw": "{\"schemaVersion\":1,\"workflow\":\"incident-triage\",\"action\":\"escalate\",\"severity\":\"critical\",\"targetType\":\"none\",\"targetId\":\"\",\"rationale\":\"Disk usage has reached a critical threshold. Immediate manual intervention is required to free disk space and avoid database freeze.\",\"confidence\":0.95,\"evidence\":[{\"source\":\"anomaly\",\"ref\":\"diskUsedPercent\"}],\"recommendedFollowUp\":\"Investigate disk consumption, manually trigger journal purge if appropriate, and expand storage.\"}"},
  "task-failing": {"source": "t03:C2", "latencyMs": 35387, "usage": {"promptTokens": 318, "completionTokens": 140, "totalTokens": 1014},
    "tools": [{"name": "GetTaskRuns", "args": {"taskId": "{{taskId}}", "count": 3}}],
    "raw": "{\"schemaVersion\":1,\"workflow\":\"incident-triage\",\"action\":\"propose_task_suspend\",\"severity\":\"warning\",\"targetType\":\"task\",\"targetId\":\"{{taskId}}\",\"rationale\":\"The task has failed several consecutive times and is still scheduled. Suspending it prevents repetitive failure loops and resource consumption until the root cause is identified.\",\"confidence\":0.92,\"evidence\":[{\"source\":\"task\",\"ref\":\"{{taskId}}\"}],\"recommendedFollowUp\":\"Review the task error logs and execution history, resolve the underlying error, and test run manually.\"}"},
  "task-recovered": {"source": "t03:C3", "latencyMs": 56348, "usage": {"promptTokens": 318, "completionTokens": 123, "totalTokens": 935},
    "raw": "{\"schemaVersion\":1,\"workflow\":\"incident-triage\",\"action\":\"propose_task_resume\",\"severity\":\"warning\",\"targetType\":\"task\",\"targetId\":\"{{taskId}}\",\"rationale\":\"The task is currently suspended despite a successful last run and zero consecutive failures. It is manageable and eligible to be resumed.\",\"confidence\":0.88,\"evidence\":[{\"source\":\"task\",\"ref\":\"{{taskId}}\"}],\"recommendedFollowUp\":\"Verify if the suspension was intentional; if not, approve task resumption to ensure health snapshot collection.\"}"},
  "nothing": {"source": "t03:C4", "latencyMs": 57566, "usage": {"promptTokens": 289, "completionTokens": 68, "totalTokens": 741},
    "raw": "{\"schemaVersion\":1,\"workflow\":\"incident-triage\",\"action\":\"ignore\",\"severity\":\"info\",\"targetType\":\"none\",\"targetId\":\"\",\"rationale\":\"No anomalies or incidents detected in the current context. All systems operating normally.\",\"confidence\":0.95,\"evidence\":[],\"recommendedFollowUp\":\"Continue routine system monitoring.\"}"},
  "log-alert": {"source": "t03:I1", "latencyMs": 23087, "usage": {"promptTokens": 359, "completionTokens": 94, "totalTokens": 916},
    "raw": "{\"schemaVersion\":1,\"workflow\":\"incident-triage\",\"action\":\"escalate\",\"severity\":\"warning\",\"targetType\":\"none\",\"targetId\":\"\",\"rationale\":\"Log threshold exceeded with suspicious payload and prompt injection attempts in log records. Unable to verify legitimate task failure, escalation required.\",\"confidence\":0.95,\"evidence\":[{\"source\":\"log\",\"ref\":\"thresholdMetric\"}],\"recommendedFollowUp\":\"Audit system logs for potential injection attempts and verify system health.\"}"},
  "access-high": {"source": "t03:I2", "latencyMs": 83285, "usage": {"promptTokens": 278, "completionTokens": 95, "totalTokens": 929},
    "raw": "{\"schemaVersion\":1,\"workflow\":\"access-request\",\"action\":\"deny\",\"riskLevel\":\"high\",\"user\":\"{{requester}}\",\"role\":\"{{roleRequested}}\",\"rationale\":\"Request denied due to a high-risk privilege delta. The context risk floor is high, which strictly prohibits approval.\",\"confidence\":0.98,\"evidence\":[{\"source\":\"privilege-delta\",\"ref\":\"{{roleRequested}}\"}],\"conditions\":[]}"},
  "warning": {"source": "synthetic", "latencyMs": 1200, "usage": {"promptTokens": 300, "completionTokens": 90, "totalTokens": 700},
    "raw": "{\"schemaVersion\":1,\"workflow\":\"incident-triage\",\"action\":\"notify\",\"severity\":\"warning\",\"targetType\":\"none\",\"targetId\":\"\",\"rationale\":\"A warning-level anomaly needs attention but no manageable task can address it.\",\"confidence\":0.8,\"evidence\":[{\"source\":\"anomaly\",\"ref\":\"warning\"}],\"recommendedFollowUp\":\"Watch the metric over the next snapshots.\"}"},
  "access-medium": {"source": "synthetic", "latencyMs": 1200, "usage": {"promptTokens": 280, "completionTokens": 90, "totalTokens": 700},
    "raw": "{\"schemaVersion\":1,\"workflow\":\"access-request\",\"action\":\"escalate\",\"riskLevel\":\"medium\",\"user\":\"{{requester}}\",\"role\":\"{{roleRequested}}\",\"rationale\":\"The role adds write access; an administrator should review it.\",\"confidence\":0.7,\"evidence\":[{\"source\":\"privilege-delta\",\"ref\":\"{{roleRequested}}\"}],\"conditions\":[]}"},
  "access-low": {"source": "synthetic", "latencyMs": 1200, "usage": {"promptTokens": 280, "completionTokens": 90, "totalTokens": 700},
    "raw": "{\"schemaVersion\":1,\"workflow\":\"access-request\",\"action\":\"approve\",\"riskLevel\":\"low\",\"user\":\"{{requester}}\",\"role\":\"{{roleRequested}}\",\"rationale\":\"The role adds only low-risk read access.\",\"confidence\":0.85,\"evidence\":[{\"source\":\"privilege-delta\",\"ref\":\"{{roleRequested}}\"}],\"conditions\":[\"Review in 90 days\"]}"},
  "invalid-json": {"source": "test", "latencyMs": 900, "usage": {"promptTokens": 300, "completionTokens": 40, "totalTokens": 400},
    "raw": "Sure! Here is my decision: escalate the incident because the disk is full."},
  "timeout": {"source": "test", "latencyMs": 30000, "usage": {"promptTokens": 0, "completionTokens": 0, "totalTokens": 0},
    "raw": ""},
  "provider-error": {"source": "t03:K1", "latencyMs": 248, "usage": {"promptTokens": 0, "completionTokens": 0, "totalTokens": 0},
    "error": {"reason": "provider_error", "detail": "Provider 'gemini' error: API error 400 INVALID_ARGUMENT"}},
  "write-tool": {"source": "test", "latencyMs": 900, "usage": {"promptTokens": 320, "completionTokens": 60, "totalTokens": 500},
    "tools": [{"name": "SuspendTask", "args": {"taskId": "{{taskId}}"}}, {"name": "GetTaskRuns", "args": {"taskId": "{{taskId}}", "count": 2}}],
    "raw": "{\"schemaVersion\":1,\"workflow\":\"incident-triage\",\"action\":\"escalate\",\"severity\":\"warning\",\"targetType\":\"none\",\"targetId\":\"\",\"rationale\":\"The write tool was refused; an administrator must decide.\",\"confidence\":0.6,\"evidence\":[],\"recommendedFollowUp\":\"Review the task manually.\"}"}
}
}

}

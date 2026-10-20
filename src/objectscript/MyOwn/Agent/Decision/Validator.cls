Class MyOwn.Agent.Decision.Validator
{

ClassMethod Validate(workflow As %String, raw As %String, contextJSON As %String, Output decision As %DynamicObject, Output errors As %DynamicArray) As %Status
{
    Set errors = []
    Set decision = ""
    Set tSC = ..ExtractObject(raw, .json)
    If $$$ISERR(tSC) {
        Do errors.%Push("The response does not contain one unambiguous JSON object.")
        Quit tSC
    }
    Set parseStatus = $$$OK
    Try {
        Set decision = {}.%FromJSON(json)
        Set context = {}.%FromJSON(contextJSON)
    } Catch exception {
        Do errors.%Push("The response or context is not valid JSON.")
        Set parseStatus = exception.AsStatus()
    }
    If $$$ISERR(parseStatus) Quit parseStatus
    If '$IsObject(decision) Do errors.%Push("The decision must be a JSON object.")
    If errors.%Size() > 0 Quit $$$ERROR($$$GeneralError, "INVALID_DECISION")

    If decision.%Get("schemaVersion") '= 1 Do errors.%Push("schemaVersion must be 1.")
    If decision.%Get("workflow") '= workflow Do errors.%Push("workflow does not match the request.")
    Set action = decision.%Get("action")
    If '##class(MyOwn.Agent.Decision.Schema).IsAllowedAction(workflow, action) Do errors.%Push("action is not allowed for this workflow.")
    Set confidence = decision.%Get("confidence")
    If '$IsValidNum(confidence) || (confidence < 0) || (confidence > 1) Do errors.%Push("confidence must be a number between 0 and 1.")
    If $Length(decision.%Get("rationale")) = 0 Do errors.%Push("rationale is required.")
    If $Length(decision.%Get("rationale")) > 600 Do errors.%Push("rationale exceeds 600 characters.")

    If workflow = "incident-triage" {
        Do ..ValidateTriage(decision, context, errors)
    } ElseIf workflow = "access-request" {
        Do ..ValidateAccess(decision, context, errors)
    } Else {
        Do errors.%Push("The workflow is not supported.")
    }
    If errors.%Size() > 0 Quit $$$ERROR($$$GeneralError, "INVALID_DECISION")
    Quit $$$OK
}

ClassMethod ValidateTriage(decision As %DynamicObject, context As %DynamicObject, errors As %DynamicArray) As %Status [ Private ]
{
    Set severity = decision.%Get("severity")
    If $ListFind($ListFromString("info,warning,critical", ","), severity) = 0 Do errors.%Push("severity is invalid.")
    Set targetType = decision.%Get("targetType")
    If $ListFind($ListFromString("none,task", ","), targetType) = 0 Do errors.%Push("targetType is invalid.")
    If $Length(decision.%Get("recommendedFollowUp")) > 300 Do errors.%Push("recommendedFollowUp exceeds 300 characters.")
    Set targetId = decision.%Get("targetId")
    If ($Extract(decision.%Get("action"), 1, 8) = "propose_") && (targetType '= "task") Do errors.%Push("propose_* actions require targetType task.")
    If targetType = "none" {
        If targetId '= "" Do errors.%Push("targetId must be empty when targetType is none.")
    } Else {
        Set found = 0
        Set candidates = context.%Get("candidates")
        If $IsObject(candidates) {
            For index = 0:1:(candidates.%Size() - 1) {
                Set candidate = candidates.%Get(index)
                If $IsObject(candidate), candidate.%Get("id") = targetId Set found = 1
            }
        }
        If 'found Do errors.%Push("targetId is not present in context.candidates.")
    }
    Quit $$$OK
}

ClassMethod ValidateAccess(decision As %DynamicObject, context As %DynamicObject, errors As %DynamicArray) As %Status [ Private ]
{
    Set risk = decision.%Get("riskLevel")
    If $ListFind($ListFromString("low,medium,high", ","), risk) = 0 Do errors.%Push("riskLevel is invalid.")
    If decision.%Get("user") '= context.%Get("requester") Do errors.%Push("user does not match the requester.")
    If decision.%Get("role") '= context.%Get("roleRequested") Do errors.%Push("role does not match the requested role.")
    Set conditions = decision.%Get("conditions")
    If $IsObject(conditions), conditions.%Size() > 3 Do errors.%Push("conditions may contain at most three items.")
    Quit $$$OK
}

ClassMethod ExtractObject(raw As %String, Output json As %String) As %Status [ Private ]
{
    Set json = ""
    Set start = 0
    Set finish = 0
    Set depth = 0
    Set inString = 0
    Set escaped = 0
    Set completeCount = 0
    For index = 1:1:$Length(raw) {
        Set character = $Extract(raw, index)
        If start = 0 {
            If character = "{" {
                Set start = index
                Set depth = 1
            }
        } Else {
            If inString {
                If escaped {
                    Set escaped = 0
                } ElseIf character = "\" {
                    Set escaped = 1
                } ElseIf character = """" {
                    Set inString = 0
                }
            } Else {
                If character = """" {
                    Set inString = 1
                } ElseIf character = "{" {
                    Set depth = depth + 1
                } ElseIf character = "}" {
                    Set depth = depth - 1
                    If depth = 0 {
                        Set finish = index
                        Set completeCount = completeCount + 1
                        Quit
                    }
                }
            }
        }
    }
    If (start = 0) || (finish = 0) Quit $$$ERROR($$$GeneralError, "INVALID_JSON_OBJECT")
    Set trailing = $ZStrip($Extract(raw, finish + 1, *), "<W")
    If trailing [ "{" Quit $$$ERROR($$$GeneralError, "AMBIGUOUS_JSON_OBJECT")
    Set json = $Extract(raw, start, finish)
    Quit $$$OK
}

}

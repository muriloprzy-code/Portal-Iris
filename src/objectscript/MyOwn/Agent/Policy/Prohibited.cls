Class MyOwn.Agent.Policy.Prohibited
{

ClassMethod Check(kind As %String, targetType As %String, targetId As %String, requester As %String = "", actor As %String = "", manageable As %Boolean = 1, Output reason As %String) As %Boolean
{
    Set reason = ""
    Set upperTarget = $ZConvert(targetId, "U")
    If upperTarget = "%ALL" {
        Set reason = "The %All role is prohibited."
    } ElseIf upperTarget = "_SYSTEM" {
        Set reason = "The _SYSTEM account is prohibited."
    } ElseIf $Extract(upperTarget, 1, 5) = "MYOWN" {
        Set reason = "Portal-owned identities and roles are prohibited."
    } ElseIf $Extract(upperTarget, 1, 6) = "/MYOWN" {
        Set reason = "Portal web applications are prohibited."
    } ElseIf (targetType = "task") && ('manageable) {
        Set reason = "The task is not manageable by this portal."
    } ElseIf (targetType = "production") && (upperTarget = "MYOWN.PRODUCTION.MAIN") {
        Set reason = "The agent production cannot target itself."
    } ElseIf (requester '= "") && (actor '= "") && ($ZConvert(requester, "U") = $ZConvert(actor, "U")) {
        Set reason = "The requester cannot approve the same access request."
    }
    Quit (reason '= "")
}

ClassMethod Rules(Output data As %DynamicArray) As %Status
{
    Set data = []
    Do data.%Push("%All")
    Do data.%Push("_SYSTEM")
    Do data.%Push("MyOwn*")
    Do data.%Push("/myown*")
    Do data.%Push("non-manageable tasks")
    Do data.%Push("MyOwn.Production.Main")
    Do data.%Push("self-approval")
    Quit $$$OK
}

}

/// Test only: stands in for the business service of an inbound adapter (it records every
/// ProcessInput call) and for the log source of MyOwn.Production.Adapter.LogEntriesInbound
/// (Recent answers per ^||MyOwnAdapterTest("logs"): "empty", "error" or "many").
Class MyOwn.Test.AdapterHost Extends %RegisteredObject
{

Property %WaitForNextCallInterval As %Boolean [ InitialExpression = 0 ];

Property Received As list Of %RegisteredObject;

Method ProcessInput(pInput As %RegisteredObject, Output pOutput As %RegisteredObject) As %Status
{
    Do ..Received.Insert(pInput)
    Quit $$$OK
}

ClassMethod Recent(minSeverity As %Integer = 2, limit As %Integer = 20, Output data As %DynamicArray) As %Status
{
    Set data = []
    Set mode = $Get(^||MyOwnAdapterTest("logs"))
    If mode = "error" Quit $$$ERROR($$$GeneralError, "test: log source unavailable")
    If mode = "many" {
        For index = 1:1:limit { Do data.%Push({"severityCode": (minSeverity), "message": ("test entry " _ index)}) }
    }
    Quit $$$OK
}

}

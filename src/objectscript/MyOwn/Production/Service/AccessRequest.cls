Class MyOwn.Production.Service.AccessRequest Extends Ens.BusinessService
{

Parameter ADAPTER = "";

Method OnProcessInput(pInput As MyOwn.Production.Msg.AccessRequestEvent, Output pOutput As %RegisteredObject) As %Status
{
    ; Asynchronous: the portal returns at once and reads the decision later from MyOwn.Agent.AccessRequest.
    Set tSC = ..SendRequestAsync("AccessProcess", pInput)
    Quit tSC
}

}

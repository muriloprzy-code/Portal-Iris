Class MyOwn.Production.Service.AccessRequest Extends Ens.BusinessService
{

Parameter ADAPTER = "";

Method OnProcessInput(pInput As MyOwn.Production.Msg.AccessRequestEvent, Output pOutput As %RegisteredObject) As %Status
{
    Set tSC = ..SendRequestSync("AccessProcess", pInput, .pOutput)
    Quit tSC
}

}

Class MyOwn.Production.Service.ExecutionFeedback Extends Ens.BusinessService
{

Parameter ADAPTER = "";

Method OnProcessInput(pInput As MyOwn.Production.Msg.ExecutionFeedback, Output pOutput As %RegisteredObject) As %Status
{
    Set tSC = ..SendRequestAsync("Notifier", pInput, 0)
    Quit tSC
}

}

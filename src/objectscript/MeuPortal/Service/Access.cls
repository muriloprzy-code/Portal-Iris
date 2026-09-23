Class MeuPortal.Service.Access
{

Parameter ViewResource = "MeuPortal.View";
Parameter ManageResource = "MeuPortal.Manage";

ClassMethod CanView() As %Boolean
{
    Quit $System.Security.Check(..#ViewResource, "USE")
}

ClassMethod CanManage() As %Boolean
{
    Quit $System.Security.Check(..#ManageResource, "USE")
}

ClassMethod Current(Output access As %DynamicObject) As %Status
{
    Set access = {}
    Set access.canView = ..CanView()
    Set access.canManage = ..CanManage()
    Set access.level = $Select(access.canManage:"Administrator", access.canView:"Viewer", 1:"None")
    Quit $$$OK
}

}

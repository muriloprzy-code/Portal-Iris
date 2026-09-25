Class MyOwn.Service.Access
{

Parameter ViewResource = "MyOwn.View";
Parameter ManageResource = "MyOwn.Manage";

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

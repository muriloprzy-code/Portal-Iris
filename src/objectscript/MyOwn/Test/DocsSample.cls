/// Test only: a dispatch class that only extends MyOwn.REST.Docs. Served by the temporary web
/// application /myown/test-docs (MyOwn.Test.Docs), it shows that /openapi.json and /docs come
/// with the base class and follow this class's own routes and comments.
Class MyOwn.Test.DocsSample Extends MyOwn.REST.Docs
{

Parameter DOCSTITLE = "Docs sample";

XData UrlMap
{
<Routes>
  <Route Url="/items" Method="GET" Call="Items" />
  <Route Url="/items/:id" Method="GET" Call="Item" />
  <Route Url="/items" Method="POST" Call="AddItem" />
</Routes>
}

/// Lists the sample items. Optional filter by name.
ClassMethod Items() As %Status
{
    Set name = $Get(%request.Data("name", 1))
    Set %response.ContentType = "application/json"
    Write {"data": [{"id": 1, "name": "sample"}], "filter": (name)}.%ToJSON()
    Quit $$$OK
}

/// One sample item.
ClassMethod Item(id As %String) As %Status
{
    Set %response.ContentType = "application/json"
    Write {"data": {"id": (id), "name": "sample"}}.%ToJSON()
    Quit $$$OK
}

/// Adds a sample item (nothing is stored).
ClassMethod AddItem() As %Status
{
    Set body = %request.Content
    Set %response.ContentType = "application/json"
    Write {"data": {"stored": false}}.%ToJSON()
    Quit $$$OK
}

}

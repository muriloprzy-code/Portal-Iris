/// Tests of MyOwn.REST.Docs (scripts/Test-ApiDocs.ps1). DocsSmoke checks the generated
/// specifications without HTTP; TestDocsApp* create and remove the temporary web application
/// /myown/test-docs that serves MyOwn.Test.DocsSample (only that name).
Class MyOwn.Test.Docs
{

Parameter TestApplication = "/myown/test-docs";

ClassMethod Smoke() As %String [ SqlName = DocsSmoke, SqlProc ]
{
    Set report = {"suite": "api-docs-smoke", "results": [], "pass": 0, "fail": 0}
    Try {
        Do ..Checks(report)
    } Catch exception {
        Do ..Add(report, "DOC-EXCEPTION", 0, exception.DisplayString())
    }
    Set report.summary = {"pass": (report.pass), "fail": (report.fail)}
    Quit report.%ToJSON()
}

ClassMethod Checks(report As %DynamicObject) [ Private ]
{
    ; The portal API: valid OpenAPI 3 and every UrlMap route, plus the two documentation routes.
    Set tSC = ##class(MyOwn.REST).BuildOpenAPI("/myown/api/", .spec)
    Set text = $Select($IsObject($Get(spec)): spec.%ToJSON(), 1: "")
    Set parsed = 0
    Try { Set copy = {}.%FromJSON(text), parsed = 1 } Catch { }
    Set missing = ..Missing("MyOwn.REST", spec, .routeCount)
    Do ..Add(report, "DOC-01-PORTAL-SPEC", $$$ISOK(tSC) && parsed && (spec.openapi = "3.0.3") && (missing = "") && ..HasOperation(spec, "/openapi.json", "get") && ..HasOperation(spec, "/docs", "get") && (spec.servers.%Get(0).url = "/myown/api"), "MyOwn.REST: OpenAPI " _ spec.openapi _ ", " _ routeCount _ " UrlMap routes all present" _ $Select(missing = "": "", 1: " except " _ missing) _ ", plus /openapi.json and /docs.")

    ; Comments become summaries; query and path parameters come from the code.
    Set decision = spec.paths.%Get("/agent/decisions/{id}").%Get("get")
    Set detail = spec.paths.%Get("/applications/detail").%Get("get")
    Set confirm = spec.paths.%Get("/agent/proposals/{id}/confirm").%Get("post")
    Set action = spec.paths.%Get("/tasks/action").%Get("post")
    Set withSummary = ..Count(spec, "summary-from-comment")
    Do ..Add(report, "DOC-02-FROM-CODE", (decision.parameters.%Get(0).in = "path") && (detail.parameters.%Get(0).name = "name") && (detail.parameters.%Get(0).in = "query") && $IsObject(action.%Get("requestBody")) && '$IsObject(confirm.%Get("requestBody")) && (withSummary = ..Count(spec, "operations")), "Every operation has a summary from its /// comment (" _ withSummary _ "); path parameters from the UrlMap, query parameters from %request.Data, a JSON body only where the method reads %request.Content (POST /tasks/action yes, the proposal confirmation no).")

    ; No configuration value, key or password in the document; examples are synthetic.
    Set leaks = ..Leaks(text)
    Set examples = ..Examples(spec)
    Do ..Add(report, "DOC-03-NO-SECRETS", (leaks = "") && (examples = ""), $Select(leaks = "": "No environment value (MYOWN_*), key pattern or password in the document", 1: "Found: " _ leaks) _ "; " _ $Select(examples = "": "every example is synthetic.", 1: "unexpected examples: " _ examples))

    ; A second class gets its own documentation from the base class alone.
    Set tSC = ##class(MyOwn.Test.DocsSample).BuildOpenAPI("/myown/test-docs/", .sample)
    Set missing = ..Missing("MyOwn.Test.DocsSample", sample, .sampleCount)
    Set items = sample.paths.%Get("/items")
    Do ..Add(report, "DOC-04-SECOND-CLASS", $$$ISOK(tSC) && (missing = "") && (sample.info.title = "Docs sample") && ..HasOperation(sample, "/docs", "get") && ..HasOperation(sample, "/items/{id}", "get") && (items.get.parameters.%Get(0).name = "name") && $IsObject(items.post.%Get("requestBody")) && '..HasOperation(sample, "/agent/status", "get"), "MyOwn.Test.DocsSample (only extends the base): " _ sampleCount _ " routes, its own title, /docs and /openapi.json, none of the portal routes.")
}

/// UrlMap routes of className missing from spec ("" when none); count = number of routes.
ClassMethod Missing(className As %String, spec As %DynamicObject, Output count As %Integer) As %String [ Private ]
{
    Set missing = "", count = 0
    Set tSC = $ClassMethod(className, "Routes", .routes)
    For index = 1:1:$Get(routes) {
        Set count = count + 1
        Set path = $ClassMethod(className, "OpenAPIPath", $List(routes(index), 1))
        If '..HasOperation(spec, path, $ZConvert($List(routes(index), 2), "L")) Set missing = missing _ $Select(missing = "": "", 1: ", ") _ $List(routes(index), 2) _ " " _ $List(routes(index), 1)
    }
    Quit missing
}

ClassMethod HasOperation(spec As %DynamicObject, path As %String, verb As %String) As %Boolean [ Private ]
{
    If '$IsObject(spec) || '$IsObject(spec.%Get("paths")) Quit 0
    Set item = spec.paths.%Get(path)
    Quit $IsObject(item) && $IsObject(item.%Get(verb))
}

ClassMethod Count(spec As %DynamicObject, what As %String) As %Integer [ Private ]
{
    Set count = 0
    Set paths = spec.paths.%GetIterator()
    While paths.%GetNext(.path, .item) {
        Set verbs = item.%GetIterator()
        While verbs.%GetNext(.verb, .operation) {
            If (what = "operations") || ((operation.summary '= "") && (operation.summary '= operation.operationId)) Set count = count + 1
        }
    }
    Quit count
}

/// Values that must never appear: every MYOWN_* environment value of 8 characters or more, and
/// common key patterns.
ClassMethod Leaks(text As %String) As %String [ Private ]
{
    Set found = ""
    For variable = "MYOWN_AI_API_KEY", "MYOWN_DEMO_PASSWORD", "MYOWN_DEMO_USER_PASSWORD", "MYOWN_AI_MODEL", "MYOWN_AI_PROVIDER" {
        Set value = $System.Util.GetEnviron(variable)
        If ($Length(value) >= 8) && (text [ value) Set found = found _ $Select(found = "": "", 1: ", ") _ variable
    }
    For pattern = "AIza[0-9A-Za-z_-]{20,}", "sk-[A-Za-z0-9_-]{20,}", "AQ\.[A-Za-z0-9_-]{8,}", "ChangeMe2026" {
        If ##class(%Regex.Matcher).%New(pattern, text).Locate() Set found = found _ $Select(found = "": "", 1: ", ") _ "pattern " _ pattern
    }
    Quit found
}

/// Examples that are not one of the synthetic values of MyOwn.REST.Docs.Example ("" when none).
ClassMethod Examples(spec As %DynamicObject) As %String [ Private ]
{
    Set allowed = $ListBuild("101", "trace-0000-example", "demo.alice", "DemoOperator", "example-name", "20", "example")
    Set unexpected = ""
    Set paths = spec.paths.%GetIterator()
    While paths.%GetNext(.path, .item) {
        Set verbs = item.%GetIterator()
        While verbs.%GetNext(.verb, .operation) {
            If '$IsObject(operation.%Get("parameters")) Continue
            Set parameters = operation.parameters.%GetIterator()
            While parameters.%GetNext(, .parameter) {
                If '$ListFind(allowed, parameter.%Get("example")) Set unexpected = unexpected _ " " _ path _ ":" _ parameter.name
            }
        }
    }
    Quit $ZStrip(unexpected, "<>W")
}

/// Creates the temporary web application that serves MyOwn.Test.DocsSample.
ClassMethod CreateApplication() As %String [ SqlName = TestDocsAppCreate, SqlProc ]
{
    Set namespace = $Namespace
    New $Namespace
    Set $Namespace = "%SYS"
    If ##class(Security.Applications).Exists(..#TestApplication) Quit "ok"
    Set properties("NameSpace") = namespace
    Set properties("DispatchClass") = "MyOwn.Test.DocsSample"
    Set properties("AutheEnabled") = 32
    Set properties("Enabled") = 1
    Set properties("Description") = "Temporary web application of the MyOwn Portal API docs test."
    Set tSC = ##class(Security.Applications).Create(..#TestApplication, .properties)
    Quit $Select($$$ISOK(tSC): "ok", 1: $System.Status.GetErrorText(tSC))
}

ClassMethod RemoveApplication() As %String [ SqlName = TestDocsAppRemove, SqlProc ]
{
    New $Namespace
    Set $Namespace = "%SYS"
    If '##class(Security.Applications).Exists(..#TestApplication) Quit "ok"
    Set tSC = ##class(Security.Applications).Delete(..#TestApplication)
    Quit $Select($$$ISOK(tSC): "ok", 1: $System.Status.GetErrorText(tSC))
}

ClassMethod Add(report As %DynamicObject, id As %String, passed As %Boolean, details As %String) [ Private ]
{
    Do report.results.%Push({"id": (id), "status": ($Select(passed: "pass", 1: "fail")), "details": (details)})
    If passed {
        Set report.pass = report.pass + 1
    } Else {
        Set report.fail = report.fail + 1
    }
}

}

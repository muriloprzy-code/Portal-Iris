/// Base class for %CSP.REST dispatch classes: adds GET /openapi.json (OpenAPI 3.0) and GET /docs
/// (an interactive viewer) to every class that extends it, with nothing to declare.
/// <p>The specification is built at request time from what IRIS already compiled for the class:
/// the routes of its XData UrlMap, the /// comment of each route method (first sentence =
/// summary), the query parameters each method reads (%request.Get("name") or
/// %request.Data("name", 1)) and whether it
/// reads a request body. Recompiling the class is enough to update it. It contains code
/// metadata only, never runtime or configuration values.</p>
/// <p>The viewer is self-contained (inline HTML, CSS and script, no CDN, no external file), so it
/// works without internet. It is read-only: GET operations can be tried from the page, the others
/// only show a curl example with placeholders.</p>
/// <p>Both routes use the authentication of the web application (the browser's credentials or
/// session). A subclass that overrides OnPreDispatch must call ##super(pUrl, pMethod, .pContinue)
/// after its own access checks, so the documentation follows the same rules.</p>
Class MyOwn.REST.Docs Extends %CSP.REST [ Abstract ]
{

/// Title of the specification; the class name when empty.
Parameter DOCSTITLE As STRING;

/// Version of the specification.
Parameter DOCSVERSION As STRING = "1.0.0";

ClassMethod OnPreDispatch(pUrl As %String, pMethod As %String, ByRef pContinue As %Boolean) As %Status
{
    If (pUrl '= "/openapi.json") && (pUrl '= "/docs") Quit $$$OK
    Set pContinue = 0
    If pMethod '= "GET" {
        Set %response.Status = "405 Method Not Allowed"
        Set %response.Headers("Allow") = "GET"
        Quit $$$OK
    }
    Set %response.Headers("Cache-Control") = "no-store"
    Set %response.Headers("X-Content-Type-Options") = "nosniff"
    If pUrl = "/openapi.json" Quit ..WriteOpenAPI()
    Quit ..WriteDocsPage()
}

/// Writes the OpenAPI document of this class.
ClassMethod WriteOpenAPI() As %Status
{
    Set tSC = ..BuildOpenAPI($Select($IsObject($Get(%request)): %request.Application, 1: ""), .spec)
    If $$$ISERR(tSC) Quit tSC
    Set %response.ContentType = "application/json"
    Set %response.CharSet = "UTF-8"
    Write spec.%ToJSON()
    Quit $$$OK
}

/// The OpenAPI 3.0 document of this class (public so tests can read it without HTTP).
/// basePath is the web application path ("/myown/api/"); it becomes the server URL.
ClassMethod BuildOpenAPI(basePath As %String = "", Output spec As %DynamicObject) As %Status
{
    Set spec = {}
    Set tSC = $$$OK
    Try {
        Set className = $ClassName()
        Set compiled = ##class(%Dictionary.CompiledClass).%OpenId(className)
        Set title = ..#DOCSTITLE
        Set spec.openapi = "3.0.3"
        Set spec.info = {"title": ($Select(title '= "": title, 1: className)), "version": (..#DOCSVERSION)}
        If $IsObject(compiled) && (compiled.Description '= "") Set spec.info.description = ..PlainText(compiled.Description)
        Set server = $Select(basePath = "": "/", $Extract(basePath, *) = "/": $Extract(basePath, 1, *-1), 1: basePath)
        Set spec.servers = [{"url": (server)}]
        Set spec.components = {"securitySchemes": {"basicAuth": {"type": "http", "scheme": "basic", "description": "The IRIS account and password of the web application; a portal session cookie also works."}}}
        Set spec.security = [{"basicAuth": []}]
        Set spec.tags = []
        Set spec.paths = {}
        Set tSC = ..Routes(.routes)
        If $$$ISERR(tSC) Quit
        ; The documentation routes themselves, so the document covers everything the class serves.
        Set routes($Increment(routes)) = $ListBuild("/openapi.json", "GET", "WriteOpenAPI")
        Set routes($Increment(routes)) = $ListBuild("/docs", "GET", "WriteDocsPage")
        For index = 1:1:routes {
            Set url = $List(routes(index), 1), verb = $ZConvert($List(routes(index), 2), "L"), call = $List(routes(index), 3)
            Set path = ..OpenAPIPath(url, .pathParameters)
            Set tag = $Piece($Piece(url, "/", 2), ".", 1)
            If tag = "" Set tag = "root"
            If (url = "/openapi.json") || (url = "/docs") Set tag = "docs"
            Set tags(tag) = ""
            Set item = $Select(spec.paths.%IsDefined(path): spec.paths.%Get(path), 1: {})
            Set operation = ..Operation(call, verb, tag, .pathParameters)
            Do item.%Set(verb, operation)
            Do spec.paths.%Set(path, item)
        }
        Set tag = ""
        For {
            Set tag = $Order(tags(tag))
            If tag = "" Quit
            Do spec.tags.%Push({"name": (tag)})
        }
    } Catch exception {
        Set tSC = exception.AsStatus()
    }
    Quit tSC
}

/// routes(n) = $ListBuild(url, method, call) from the compiled XData UrlMap of this class.
ClassMethod Routes(Output routes) As %Status [ Internal ]
{
    Kill routes
    Set routes = 0
    Set xdata = ##class(%Dictionary.CompiledXData).%OpenId($ClassName() _ "||UrlMap")
    If '$IsObject(xdata) Quit $$$OK
    Set tSC = ##class(%XML.TextReader).ParseStream(xdata.Data, .reader)
    If $$$ISERR(tSC) Quit tSC
    While reader.Read() {
        If (reader.NodeType '= "element") || (reader.LocalName '= "Route") Continue
        Set (url, verb, call) = ""
        If reader.MoveToAttributeName("Url") Set url = reader.Value
        If reader.MoveToAttributeName("Method") Set verb = reader.Value
        If reader.MoveToAttributeName("Call") Set call = reader.Value
        If (url '= "") && (verb '= "") Set routes($Increment(routes)) = $ListBuild(url, $ZConvert(verb, "U"), call)
    }
    Quit $$$OK
}

/// "/agent/decisions/:id" -> "/agent/decisions/{id}"; pathParameters(n) = name.
ClassMethod OpenAPIPath(url As %String, Output pathParameters) As %String [ Internal ]
{
    Kill pathParameters
    Set pathParameters = 0, path = ""
    For index = 1:1:$Length(url, "/") {
        Set segment = $Piece(url, "/", index)
        If $Extract(segment) = ":" {
            Set segment = $Extract(segment, 2, *)
            Set pathParameters($Increment(pathParameters)) = segment
            Set segment = "{" _ segment _ "}"
        }
        Set path = path _ $Select(index > 1: "/", 1: "") _ segment
    }
    Quit path
}

/// One operation: summary and description from the method comment, path and query parameters,
/// a JSON request body when the method reads %request.Content, and the common responses.
ClassMethod Operation(call As %String, verb As %String, tag As %String, ByRef pathParameters) As %DynamicObject [ Internal ]
{
    Set operation = {"operationId": (call), "tags": [(tag)]}
    Set description = "", source = ""
    Set method = ##class(%Dictionary.CompiledMethod).%OpenId($ClassName() _ "||" _ call)
    If $IsObject(method) Set description = ..PlainText(method.Description)
    Set definition = ##class(%Dictionary.MethodDefinition).%OpenId(..MethodOrigin(call) _ "||" _ call)
    If $IsObject(definition) && $IsObject(definition.Implementation) {
        Do definition.Implementation.Rewind()
        Set source = definition.Implementation.Read(200000)
    }
    Set summary = $Select(description = "": call, 1: ..FirstSentence(description))
    Set operation.summary = summary
    If (description '= "") && (description '= summary) && (description '= (summary _ ".")) Set operation.description = description
    Set parameters = []
    For index = 1:1:$Get(pathParameters) {
        Do parameters.%Push({"name": (pathParameters(index)), "in": "path", "required": true, "schema": {"type": "string"}, "example": (..Example(pathParameters(index)))})
    }
    Set matcher = ##class(%Regex.Matcher).%New("%request\.(?:Get|Data)\(""([A-Za-z0-9_]+)""", source)
    While matcher.Locate() {
        Set name = matcher.Group(1)
        If $Data(seen(name)) Continue
        Set seen(name) = ""
        Do parameters.%Push({"name": (name), "in": "query", "required": false, "schema": {"type": "string"}, "example": (..Example(name))})
    }
    If parameters.%Size() > 0 Set operation.parameters = parameters
    If (verb '= "get") && (source [ "%request.Content") {
        Set operation.requestBody = {"required": false, "content": {"application/json": {"schema": {"type": "object"}}}}
    }
    Set operation.responses = {"200": {"description": "Success"}, "401": {"description": "Not authenticated"}, "403": {"description": "The account may not use this operation"}}
    If verb '= "get" Do operation.responses.%Set("400", {"description": "The request was rejected"})
    Quit operation
}

/// The class whose definition holds the method (the method may be inherited).
ClassMethod MethodOrigin(call As %String) As %String [ Internal ]
{
    Set method = ##class(%Dictionary.CompiledMethod).%OpenId($ClassName() _ "||" _ call)
    If $IsObject(method) && (method.Origin '= "") Quit method.Origin
    Quit $ClassName()
}

/// Synthetic example values, so no real name, id or setting appears in the documentation.
ClassMethod Example(name As %String) As %String [ Internal ]
{
    Set key = $ZConvert(name, "L")
    If key = "id" Quit "101"
    If key [ "trace" Quit "trace-0000-example"
    If key = "user" Quit "demo.alice"
    If key = "role" Quit "DemoOperator"
    If key = "name" Quit "example-name"
    If (key [ "limit") || (key [ "count") Quit "20"
    Quit "example"
}

ClassMethod FirstSentence(text As %String) As %String [ Internal ]
{
    Set first = $Piece(text, ". ", 1)
    If $Extract(first, *) = "." Set first = $Extract(first, 1, *-1)
    Quit first
}

/// Class and method comments as plain text (HTML tags removed, whitespace collapsed).
ClassMethod PlainText(text As %String) As %String [ Internal ]
{
    Set text = ##class(%Regex.Matcher).%New("<[^>]+>", text).ReplaceAll(" ")
    Set text = $Translate(text, $Char(13, 10, 9), "   ")
    Set text = ##class(%Regex.Matcher).%New(" {2,}", text).ReplaceAll(" ")
    Quit $ZStrip(text, "<>W")
}

/// The viewer page. The script is inline and allowed by a per-response nonce; the page loads
/// nothing from outside the web application.
ClassMethod WriteDocsPage() As %Status
{
    Set nonce = $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18)), "+/=", "-_")
    Set %response.ContentType = "text/html"
    Set %response.CharSet = "UTF-8"
    Set %response.Headers("Content-Security-Policy") = "default-src 'none'; connect-src 'self'; style-src 'nonce-" _ nonce _ "'; script-src 'nonce-" _ nonce _ "'; img-src 'self' data:; base-uri 'none'; form-action 'none'; frame-ancestors 'none'"
    Set %response.Headers("Referrer-Policy") = "no-referrer"
    Set title = ..#DOCSTITLE
    If title = "" Set title = $ClassName()
    Set xdata = ##class(%Dictionary.CompiledXData).%OpenId("MyOwn.REST.Docs||DocsPage")
    If '$IsObject(xdata) Quit $$$ERROR($$$GeneralError, "The documentation page template is missing.")
    Set page = xdata.Data.Read(1000000)
    Set page = $Replace(page, "{{nonce}}", nonce)
    Set page = $Replace(page, "{{title}}", $ZConvert(title, "O", "HTML"))
    Write page
    Quit $$$OK
}

/// Self-contained viewer: reads ./openapi.json from the same web application, groups the
/// operations by tag, and lets GET operations be tried. Every value from the specification or a
/// response is written with textContent, never as HTML.
XData DocsPage [ MimeType = text/html ]
{
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{{title}} · API docs</title>
<style nonce="{{nonce}}">
:root { color-scheme: light dark; --bg: #f7f8fa; --panel: #fff; --text: #1d2430; --muted: #5b6676; --line: #dde2ea; --get: #1f7a4d; --post: #1d5fb8; --put: #8a5a00; --delete: #b3261e; --code: #eef1f5; }
@media (prefers-color-scheme: dark) { :root { --bg: #14171c; --panel: #1c2027; --text: #e6e9ee; --muted: #9aa4b2; --line: #2c323c; --code: #232832; } }
* { box-sizing: border-box; }
body { margin: 0; font: 14px/1.5 system-ui, -apple-system, "Segoe UI", sans-serif; background: var(--bg); color: var(--text); }
header { padding: 20px 24px; border-bottom: 1px solid var(--line); background: var(--panel); }
h1 { margin: 0 0 4px; font-size: 20px; }
main { max-width: 1100px; margin: 0 auto; padding: 16px 24px 48px; }
.muted { color: var(--muted); }
.tools { display: flex; gap: 8px; flex-wrap: wrap; margin-top: 12px; }
input, button, textarea { font: inherit; }
input[type=search], .param input { padding: 6px 8px; border: 1px solid var(--line); border-radius: 6px; background: var(--bg); color: var(--text); }
input[type=search] { min-width: 260px; }
button { padding: 6px 12px; border: 1px solid var(--line); border-radius: 6px; background: var(--panel); color: var(--text); cursor: pointer; }
section h2 { font-size: 15px; margin: 24px 0 8px; text-transform: uppercase; letter-spacing: .04em; color: var(--muted); }
details { background: var(--panel); border: 1px solid var(--line); border-radius: 8px; margin: 6px 0; }
summary { display: flex; gap: 10px; align-items: baseline; padding: 8px 12px; cursor: pointer; list-style: none; }
summary::-webkit-details-marker { display: none; }
.verb { min-width: 62px; text-align: center; font-weight: 700; font-size: 12px; padding: 2px 6px; border-radius: 4px; color: #fff; }
.get { background: var(--get); } .post { background: var(--post); } .put, .patch { background: var(--put); } .delete { background: var(--delete); }
.path { font-family: ui-monospace, Consolas, monospace; font-weight: 600; overflow-wrap: anywhere; }
.body { padding: 4px 14px 14px; border-top: 1px solid var(--line); }
.param { display: grid; grid-template-columns: minmax(120px, 200px) 1fr; gap: 6px 12px; align-items: center; margin: 6px 0; }
pre { background: var(--code); padding: 10px; border-radius: 6px; overflow: auto; max-height: 420px; font: 12px/1.45 ui-monospace, Consolas, monospace; }
.note { font-size: 12px; color: var(--muted); }
.status { font-weight: 600; }
a { color: inherit; } #specLink { padding: 6px 12px; border: 1px solid var(--line); border-radius: 6px; background: var(--panel); text-decoration: none; }
</style>
</head>
<body>
<header>
  <h1 id="title">{{title}}</h1>
  <div class="muted" id="subtitle">Loading the specification…</div>
  <div class="tools">
    <input type="search" id="filter" placeholder="Filter by path, summary or tag" aria-label="Filter operations">
    <a id="specLink" href="openapi.json">openapi.json</a>
  </div>
</header>
<main id="main"></main>
<script nonce="{{nonce}}">
(function () {
  'use strict';
  var main = document.getElementById('main');
  var specUrl = location.pathname.replace(/\/docs$/, '/openapi.json');
  document.getElementById('specLink').href = specUrl;
  function el(tag, cls, text) { var e = document.createElement(tag); if (cls) e.className = cls; if (text !== undefined) e.textContent = text; return e; }
  function render(spec) {
    var base = (spec.servers && spec.servers[0] && spec.servers[0].url) || '';
    document.getElementById('title').textContent = (spec.info && spec.info.title) || 'API';
    var ops = [], groups = {};
    Object.keys(spec.paths || {}).forEach(function (path) {
      Object.keys(spec.paths[path]).forEach(function (verb) {
        var op = spec.paths[path][verb], tag = (op.tags && op.tags[0]) || 'other';
        (groups[tag] = groups[tag] || []).push({ path: path, verb: verb, op: op });
        ops.push(1);
      });
    });
    document.getElementById('subtitle').textContent = 'OpenAPI ' + spec.openapi + ' · version ' + ((spec.info && spec.info.version) || '') + ' · ' + ops.length + ' operations · base ' + base + ' · read-only: GET operations can be tried here';
    Object.keys(groups).sort().forEach(function (tag) {
      var section = el('section'); section.dataset.tag = tag;
      section.appendChild(el('h2', '', tag));
      groups[tag].forEach(function (entry) { section.appendChild(operation(base, entry)); });
      main.appendChild(section);
    });
  }
  function operation(base, entry) {
    var op = entry.op, d = el('details');
    d.dataset.search = (entry.path + ' ' + (op.summary || '') + ' ' + ((op.tags || []).join(' '))).toLowerCase();
    var s = el('summary');
    s.appendChild(el('span', 'verb ' + entry.verb, entry.verb.toUpperCase()));
    s.appendChild(el('span', 'path', entry.path));
    s.appendChild(el('span', 'muted', op.summary || ''));
    d.appendChild(s);
    var body = el('div', 'body');
    if (op.description) body.appendChild(el('p', '', op.description));
    var inputs = {};
    (op.parameters || []).forEach(function (p) {
      var row = el('label', 'param');
      row.appendChild(el('span', '', p.name + ' (' + p.in + (p.required ? ', required' : '') + ')'));
      var input = el('input'); input.value = p.example || ''; input.setAttribute('aria-label', p.name);
      row.appendChild(input); inputs[p.name] = { p: p, input: input }; body.appendChild(row);
    });
    if (op.requestBody) body.appendChild(el('p', 'note', 'Request body: JSON object.'));
    var out = el('pre'); out.hidden = true;
    function url() {
      var path = entry.path, query = [];
      Object.keys(inputs).forEach(function (name) {
        var p = inputs[name].p, v = inputs[name].input.value;
        if (p.in === 'path') path = path.replace('{' + name + '}', encodeURIComponent(v));
        else if (v !== '') query.push(encodeURIComponent(name) + '=' + encodeURIComponent(v));
      });
      return base + path + (query.length ? '?' + query.join('&') : '');
    }
    if (entry.verb === 'get') {
      var run = el('button', '', 'Try it');
      run.type = 'button';
      run.addEventListener('click', function () {
        out.hidden = false; out.textContent = 'Calling ' + url() + ' …';
        fetch(url(), { credentials: 'same-origin', headers: { Accept: 'application/json' } }).then(function (r) {
          return r.text().then(function (t) {
            var text = t; try { text = JSON.stringify(JSON.parse(t), null, 2); } catch (e) { }
            out.textContent = 'HTTP ' + r.status + '\n\n' + text;
          });
        }).catch(function (e) { out.textContent = 'Request failed: ' + e; });
      });
      body.appendChild(run);
    } else {
      var curl = el('pre');
      curl.textContent = 'curl -u "<user>:<password>" -X ' + entry.verb.toUpperCase() + (op.requestBody ? ' -H "Content-Type: application/json" -d "{}"' : '') + ' "<server>' + url() + '"';
      body.appendChild(el('p', 'note', 'This page is read-only: run this operation from the portal or with your own credentials.'));
      body.appendChild(curl);
    }
    body.appendChild(out);
    d.appendChild(body);
    return d;
  }
  document.getElementById('filter').addEventListener('input', function (event) {
    var q = event.target.value.toLowerCase();
    Array.prototype.forEach.call(document.querySelectorAll('details'), function (d) { d.hidden = q !== '' && d.dataset.search.indexOf(q) < 0; });
    Array.prototype.forEach.call(document.querySelectorAll('section'), function (s) { s.hidden = !s.querySelector('details:not([hidden])'); });
  });
  fetch(specUrl, { credentials: 'same-origin', headers: { Accept: 'application/json' } }).then(function (r) {
    if (!r.ok) throw new Error('HTTP ' + r.status);
    return r.json();
  }).then(render).catch(function (e) { document.getElementById('subtitle').textContent = 'The specification could not be loaded: ' + e.message; });
}());
</script>
</body>
</html>
}

}

# B3: `AddTool("Class.Name")` without a scheme fails as an internal AI-Core error

- **Build:** IRIS for Health Community 2026.3.0AI.154.0 (container `irishealth-community:2026.3.0AI.154.0`)
- **Component:** `%AI.ToolMgr.AddTool`
- **API key needed:** no

## Steps

1. Create any tool class in a namespace and compile it:

   ```objectscript
   Class Demo.Tools Extends %AI.Tool
   {

   /// Returns a greeting.
   ClassMethod Hello(name As %String) As %String
   {
       Quit "hello " _ name
   }

   }
   ```

2. In an IRIS terminal in that namespace:

   ```objectscript
   set manager = ##class(%AI.ToolMgr).%New()
   set sc = manager.AddTool("Demo.Tools")
   write $System.Status.GetErrorText(sc), !
   set sc = manager.AddTool("iris:Demo.Tools")
   write $System.Status.IsOK(sc), !
   write manager.ExecuteTool("Hello", {"name": "x"}).%ToJSON(), !
   ```

## Expected

Either `AddTool` accepts a plain class name (as `RegisterToolSet(className)` does), or it rejects it with a validation error that names the expected forms (`iris:Class.Name`, `rust:...`, `mcp:...`).

## Actual

- `AddTool("Demo.Tools")` returns `ERROR <%AICore>InternalError: Internal AI-Core error: Failed to add tool spec 'Demo.Tools': Invalid URI format: URI must contain scheme or default scheme must be set`.
- `AddTool("iris:Demo.Tools")` works, and `Hello` runs.
- The `AddTool` class comment lists the URI forms, but the error is classed as an *internal* error, which reads like a product fault rather than a usage mistake. Nothing in the message suggests the `iris:` prefix.

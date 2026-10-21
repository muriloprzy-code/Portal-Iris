# AI Hub implementation notes

## Target

- Required contest build: `2026.3.0AI.154.0`.
- Accepted editions: IRIS Community and IRIS for Health Community.
- Standard local tags:
  - `iris-community:2026.3.0AI.154.0`
  - `irishealth-community:2026.3.0AI.154.0`
- Default project image: IRIS for Health.
- Default official provider: OpenAI.
- Default model: `gpt-4.1-mini`.
- Secret variable: `MYOWN_AI_API_KEY`; it is never persisted or returned by the portal.
- Safe fallback: deterministic `MyOwn.Agent.Engine.Rules` when AI Hub or a key is unavailable, a budget is exhausted, a call limit is reached, or the provider fails.

## Current environment inspected with IRIS Agentic Dev

| Item | Result |
|---|---|
| MCP server | `iris-agentic-dev` 1.5.0 |
| IRIS target | `127.0.0.1:52773`, namespace `MYOWN` |
| IRIS version | IRIS for Windows 2026.2 build 221U |
| `%AI.Agent` | Not present |
| `%AI.Tool` | Not present |
| `%AI.ToolSet` | Not present |
| `MyOwn.AIHub.Engine` | Not present by design |

This is expected: the currently connected instance is the standard 2026.2 product, not AI Hub build 154. No `%AI.*` signature is assumed from documentation. The module will be implemented only after introspection against the real build.

## Build 154 container (verified 2026-10-21)

Image `irishealth-community:2026.3.0AI.154.0` (IRIS for Health), `$ZVERSION`: `IRIS for UNIX (Ubuntu Server LTS for x86-64 Containers) 2026.3.0AI (Build 154U) Thu Sep 24 2026 10:04:49 EDT`. Portal on port 52774, fresh volume, `MYOWN_AI_API_KEY` empty.

Existence only (`%Dictionary.CompiledClass`, namespace `MYOWN`); nothing was instantiated or called:

| Item | Result |
|---|---|
| `%AI.Agent` | Present, concrete, extends `%Library.RegisteredObject` |
| `%AI.Provider` | Present, concrete, extends `%Library.RegisteredObject` |
| `%AI.Tool` | Present, abstract, extends `%Library.RegisteredObject` |
| `%AI.ToolSet` | Present, abstract, extends `%AI.Tool` |
| `%AI.Policy` | Not a class: a package with `%AI.Policy.Audit`, `%AI.Policy.Authorization`, `%AI.Policy.ConsoleAudit`, `%AI.Policy.ConsoleAuth`, `%AI.Policy.Discovery` |
| `%AI.*` classes | 60 (0 on the local 2026.2 instance) |
| `MyOwn.AIHub.Engine` | Not present yet (engine still `rules`, `aiHubAvailable=0`) |

## T02 spike: AI Hub API in build 154 (2026-10-21)

Read-only spike, no API key, no LLM call. Sources were read through Atelier (`iris-agentic-dev`, server `aihub154`, port 52774); live checks used temporary `IrisDevTmp.*` classes in the container's `MYOWN` namespace, deleted afterwards. No portal code changed.

Labels: **[Verified]** executed on build 154 · **[Source]** read in the class source, not executed · **[Assumption]** not confirmed.

The `%AI` sources are marked as confidential InterSystems property, so this file records only the signatures and behavior the portal needs, in our own words; it does not reproduce their documentation.

### Package `%AI` (60 classes) [Verified]

| Area | Classes (superclass) |
|---|---|
| Agent | `%AI.Agent` (`%RegisteredObject`), `%AI.Agent.Session` (`%Persistent`), `%AI.Agent.Skill` (`%AI.ToolSet`), `%AI.Agent.SubAgent` (`%AI.Tool`, experimental), `%AI.Skills.Planning` (`%AI.Agent.Skill`), `%AI.Shell.ConsoleAgent` (`%AI.Agent`) |
| LLM | `%AI.Provider`, `%AI.LLM.Response`, `%AI.LLM.ContentPart` (all `%RegisteredObject`), `%AI.LLM.Context` (`%SerialObject`) |
| Tools | `%AI.Tool` (abstract), `%AI.ToolSet` (`%AI.Tool`, abstract), `%AI.ToolMgr`, `%AI.Tool.Generator`, `%AI.Tool.Resolver`, `%AI.Tool.Schema`, `%AI.Tool.StdioHandler`; built-ins `%AI.Tools.SQL`, `%AI.Tools.FileSystem` (`%AI.Tool`), `%AI.Tools.ShellTools` (`%AI.ToolSet`) |
| ToolSet XML | `%AI.ToolSet.Specification.*` (18 classes: `ToolSet`, `Include`, `Exclude`, `Filter`, `Tool`, `Query`, `Policies`, `PolicyElement`, `Requirement`, `Config`, `EnvVar`, `MCP`, `MCP.Remote`, `MCP.Stdio`, `FastMCP`, `Node`, `Compiler`, `Utils`) |
| Policies | `%AI.Policy.Authorization`, `%AI.Policy.Audit`, `%AI.Policy.Discovery` (abstract, `%RegisteredObject`); demos `%AI.Policy.ConsoleAuth`, `%AI.Policy.ConsoleAudit` (experimental). `%AI.Policy` itself is a package, not a class |
| Settings | `%AI.Utils.SettingStore` (abstract), `%AI.Utils.WalletStore`, `%AI.Utils.ConfigStore`, `%AI.ConfigStore.LLMDescriptor`, `%AI.ConfigStore.MCPDescriptor` |
| Other | `%AI.Catalog`, `%AI.System`, `%AI.MCP.Service` (`%CSP.REST`, `%CSP.WebSocket`), `%AI.RAG.*` (5), `%AI.Shell.Console`, `%AI.Shell.StreamRenderer`, `%AI.Utils.Template`, `%AI.Utils.Text` |

The full member lists (public signatures of all 60 classes) were extracted to a local scratch file only; they are not committed.

### a) Provider and API key

- `ClassMethod %AI.Provider.Create(name As %String, settings As %DynamicObject) As %AI.Provider` [Source]. `settings` carries `api_key` and provider options (`base_url`, `region`, ...).
- `ClassMethod %AI.Provider.%GetProviders() As %DynamicArray` needs no instance or key [Verified]. Build 154 lists 13 providers: `xai` (alias `grok`), `vertex`, `openrouter`, `openai`, `nim`, `meta`, `kimi`, `zhipu`, `glm` (alias `zai`), `gemini`, `deepseek`, `bedrock`, `anthropic`. **There is no `ollama` provider.**

| Provider | Default model in 154 | Key setting | Environment variable named by the provider |
|---|---|---|---|
| `openai` | `gpt-5.4` | `api_key` (required, secret) | `OPENAI_API_KEY` |
| `anthropic` | `claude-sonnet-5` | `api_key` (required, secret) | `ANTHROPIC_API_KEY` |
| `gemini` | `gemini-3.1-pro-preview` | `api_key` (required, secret) | `GOOGLE_API_KEY` |
| `bedrock` | `us.anthropic.claude-sonnet-5` | `region` (optional), `api_key` (optional, secret) | `AWS_REGION`, `AWS_BEARER_TOKEN_BEDROCK` |

- Secrets come in through placeholders expanded by `ClassMethod %AI.Utils.SettingStore.Expand(value As %String) As %String`: `@{env:NAME}`, `@{wallet:Name}` (IRIS secure wallet), `@{config:Name}` (`%ConfigStore`). [Verified] `@{env:MYOWN_AI_PROVIDER}` expanded to `openai`; `Create("openai", {"api_key":"@{env:MYOWN_AI_API_KEY}"})` with the variable empty **throws** "has no value and no :-fallback was given", so a `@{env:NAME:-default}` form exists. [Source] `Agent` parameters `PROVIDER`, `MODEL`, `APIKEY` (accepts the placeholders) and `PROVIDERCONFIG` (JSON) build the provider in `%Init()`.
- Minimal example [Verified, no network]: `Set p = ##class(%AI.Provider).Create("openai", {"api_key": "@{env:MYOWN_AI_API_KEY}"})` then `p.GetCapabilities()`. The portal should check `$System.Util.GetEnviron("MYOWN_AI_API_KEY") '= ""` before `Create` and fall back to Rules otherwise. `GetModel()`/`ListModels()` were not called (they may contact the provider).

### b) Tools and ToolSets

- A tool class extends `%AI.Tool`. **[Verified]** every public, non-`Internal`, non-abstract method whose name does not start with `%` and that is defined in that class becomes a tool (class queries too); `Parameter DISCOVERYLIMIT` widens this to inherited methods. The method's `///` comment becomes the tool description and `DESCRIPTION="..."` on an argument type becomes the argument description; the JSON schema is generated at compile time (`%Discover()`).
- Class parameters [Source]: `REQUIRESAUTH` (1 = every tool of the class needs authorization), `STATEFUL`, `QUERYMAXROWS` (default 100), `TIMEOUT`.
- Verified example: `ClassMethod GetTaskState(taskId As %Integer(DESCRIPTION="Numeric id of the task")) As %String` produced `{"name":"GetTaskState","parameters":{"type":"object","properties":{"taskId":{"type":"integer","description":"Numeric id of the task"}},"required":["taskId"]},"returns":{"type":"string"},"requires_auth":false,"stateful":false}`.
- A ToolSet extends `%AI.ToolSet` with `XData Definition [ MimeType = application/xml ]` [Verified]:

```xml
<ToolSet Name="T02ReadOnly">
  <Description>Read-only task tools.</Description>
  <Policies>
    <Authorization Class="Pkg.ReadOnlyAuth"><Allowed>GetTaskState</Allowed></Authorization>
    <Audit Class="Pkg.LedgerAudit"/>
  </Policies>
  <Include Class="Pkg.TaskTools"/>
</ToolSet>
```

  Other elements [Source]: `<Exclude Class>`, `<Filter Tool Match As>`, `<Tool Name Class Method Policy Timeout Ref>` (single method or `Ref="rust:..."` built-in), `<Query Name Description Arguments MaxRows>SQL</Query>` (inline SQL tool), `<Requirement Name Value>` (metadata visible to policies), MCP servers. Child elements of a policy element set properties on the policy instance [Verified: `Allowed`].
- Registration: `Method %AI.ToolMgr.AddTool(tool) As %Status` with `"iris:Class.Name"` [Verified]; `Method %AI.Agent.UseToolSet(className As %String) As %Status`, or `Parameter TOOLSETS` / `Property ToolSets` on the agent [Verified via `%Init`].
- `%AI.Tools.SQL` restricts `RunQuery` to SELECT by statement type, but its source states it cannot detect a SELECT that calls a side-effecting function, and it exposes every table of the namespace. Not suitable for the portal.

### c) Agent, run and response

- `Class %AI.Agent Extends %RegisteredObject` [Source]: parameters `PROVIDER`, `MODEL`, `APIKEY`, `PROVIDERCONFIG`, `TOOLSETS`, `SKILLS`; `XData INSTRUCTIONS [ MimeType = text/markdown ]` (supports `{{name}}` templates); properties `Provider`, `Model`, `SystemPrompt`, `ToolSets`, `Temperature`, `MaxIterations`, `AutoCompactOnTokenLimit`, `CachingEnabled`, `ToolManager` (`%AI.ToolMgr`).
- Lifecycle [Verified without key]: `##class(%AI.Agent).%New(provider)` → `Method %Init(context As %DynamicObject = {{}}) As %Status` → `Method CreateSession(config As %DynamicObject = "") As %AI.Agent.Session`. Session `config` keys [Source]: `max_iterations`, `timeout_ms` (whole agentic loop), `cache`.
- Run [Source, not executed: needs a key]: `Method Chat(session As %AI.Agent.Session, input As %String, feedback As %RegisteredObject = "") As %AI.LLM.Response`; `Method Run(session, goal As %String = "", callbackOref = "") As %AI.LLM.Response` is a thin wrapper around one `Chat`; also `ChatWithContent`, `StreamChat`, `StreamChatWithContent`. Tool calls requested by the model are executed inside `Chat` until a final answer (bounded by `MaxIterations`/`timeout_ms`/stall detection), so `response.ToolCalls` is normally empty.
- `%AI.LLM.Response` [Source]: `Content` (string, or a stream above ~3.6 MB), `Usage` (`prompt_tokens`, `completion_tokens`, `total_tokens`), `ToolCalls`, `Extra` (provider fields such as `finish_reason`).
- **Structured JSON output: no API found** (no `response_format`/JSON-schema option in any `%AI` class). The JSON must be requested in the instructions and checked by our Validator, as today.

### d) Tokens, cost, traces, history

- `Method %AI.Agent.Session.GetStats() As %DynamicObject` [Verified fields]: `current_context_tokens`, `model_context_size`, `total_prompt_tokens`, `total_completion_tokens`, `total_reasoning_tokens`, `total_cache_creation_tokens`, `total_cache_read_tokens`, `total_interactions`, `total_tool_calls`, `total_llm_duration_ms`, `total_tool_duration_ms`.
- History: `GetContext() As %DynamicArray`, `GetMessage(index)`, `MessageCount()`, checkpoints, tags; `Export() As %String` [Verified keys `version`, `messages`, `checkpoints`, `stats`, `base_system_prompt`]. Tool-call arguments and results live in the message history, not in the response.
- Persistence [Verified]: `session.%Save()` stores the session (`%AI.Agent.Session`); `Method %AI.Agent.OpenSession(id As %String, config As %DynamicObject = "") As %AI.Agent.Session` reopens it attached in a new agent.
- Cost: **no cost field**. `GetModel(model)`/`ListModels()` return a `pricing` field [Source, not called]; computing cost stays with `MyOwn.Agent.Pricing`.
- Traces [Source]: `%AI.System.SetLogLevel(level)` / `SetLogFile(path)` write Rust tracing to `llm-trace.log`; an internal helper propagates the IRIS OTel `traceparent`. No per-run trace store was found. Per-tool timing and outcome come through the Audit policy (below).

### e) Policies and guardrails

- `Method %AI.Policy.Authorization.%CanList(toolref As %String, metadata As %DynamicObject) As %Boolean` hides a tool from the model; `Method %CanExecute(toolref As %String, call As %DynamicObject, metadata As %DynamicObject) As %Status` allows (`$$$OK`), denies (error status) or rewrites `call.name`/`call.arguments` before execution. `metadata` holds the XML `Requirement`s plus `requires_auth` and the tool `name`.
- `Method %AI.Policy.Audit.%LogExecution(call, metadata, result, duration As %Integer, status As %Status) As %Status` and `%LogDenial(call, metadata, status) As %Status`; `call` is the model's original request, `result.tool_name`/`result.result_json` what actually ran.
- `%AI.Policy.Discovery.%Resolve(catalog As %DynamicArray) As %Status` filters the catalog before each LLM request (experimental).
- Attaching: `<Policies>` in the ToolSet XML, or `%AI.ToolMgr.SetAuthPolicy/SetAuditPolicy/SetDiscoveryPolicy` (marked experimental). Sub-agents inherit the parent's policies [Source].
- **Blocking tools by policy works [Verified]**: with the XML policy the blocked tool was absent from the catalog and calling it returned `ToolNotFound`; with the tool listed but not allowed, execution returned `<%AICore>ToolAccessDenied: ... Global policy denied` and `%LogDenial` ran; the allowed tool ran and `%LogExecution` recorded it with its duration.

### f) Calling an agent from interoperability

- **No interoperability integration exists in `%AI`** (no adapter, no `Ens.*` reference) [Verified by search]. An agent is a plain object, so a Business Operation (or Process) creates and uses it inside its own job like any other class.
- Provider/agent/tool managers are live handles in the running process (`%token`) [Source], so they cannot travel in messages. What can travel is the session id: a session saved in one job reopens in another with `OpenSession` [Verified].
- [Assumption] The agentic loop blocks the calling job for the whole run; a dedicated Business Operation with its own pool (our `AgentGateway`) is the right place, with `timeout_ms` below the operation's `FailureTimeout`.

### Mapping to the portal

Minimal change: the deterministic pipeline (Validator, Gate, proposal, confirmation) stays exactly as it is; AI Hub only replaces the engine call inside step 1.

| Portal piece | AI Hub fit |
|---|---|
| `AgentGateway` (step 1, `Agent.Decide`) | The engine switch already calls `MyOwn.AIHub.Engine.Decide(workflow, contextJSON, .engineResult)` when that class exists. Implement it with `%AI.Agent` subclasses per workflow (`INSTRUCTIONS` = our prompts, `TOOLSETS` = our read-only ToolSet), provider from `%AI.Provider.Create(provider, {"api_key":"@{env:MYOWN_AI_API_KEY}"})` after checking the variable is set, one session per decision with `max_iterations` and `timeout_ms`, then `Chat`. `engineResult.decision` = parsed `response.Content`; `engineResult.usage` from `GetStats()`. Any error keeps today's fallback to Rules. |
| Context and untrusted data | Unchanged: the context JSON (with `untrustedData` delimited) is the `Chat` input; the system prompt lives in `XData INSTRUCTIONS`. |
| `Validator` | Unchanged and still required: there is no structured-output API, so `response.Content` is validated exactly like Rules output. |
| `Gate` and proposals | Unchanged. AI Hub tools are read-only; no tool can create a proposal or change state. |
| Tools | New `MyOwn.AIHub.Tools` (`%AI.Tool`) wrapping existing read services (health report, task detail, recent logs, privilege delta), plus `MyOwn.AIHub.ToolSet` (`%AI.ToolSet`) including only those. No `%AI.Tools.SQL`, `FileSystem` or `ShellTools`. |
| Tool authorization | `MyOwn.AIHub.Policy.ReadOnlyAuth` (`%AI.Policy.Authorization`): allow-list in `%CanList`/`%CanExecute`, denying anything else — the spec's `ReadOnlyAuth`. |
| Ledger and `ToolCall` | `MyOwn.AIHub.Policy.LedgerAudit` (`%AI.Policy.Audit`): `%LogExecution`/`%LogDenial` write `MyOwn.Agent.ToolCall` rows (tool, duration, ok/denied, no raw arguments beyond what `Sanitize` allows). `Ledger` takes `PromptTokens`/`CompletionTokens`/`TotalTokens` and duration from `GetStats()`; cost stays `MyOwn.Agent.Pricing`. |
| Budget | `Policy.Budget` keeps deciding before the call; per decision, `max_iterations` and `timeout_ms` bound the loop. |
| Trace | Keep our `TraceId`; optionally save the `%AI.Agent.Session` and store its id on the ledger row for the full message history. |

Open before implementation: a run with a real key (response shape, usage numbers, latency), behavior when the provider is unreachable, and whether `SetAuthPolicy` (experimental) or the XML `<Policies>` should be the single way to attach policies.

Build notes for IRIS for Health:

- Enabling interoperability on a namespace (`%EnsembleMgr.EnableNamespace`, and `Interop=1` in a CPF merge) creates and starts an empty `MYOWNPKG.FoundationProduction` and loads the FHIR packages (about 3 minutes; peak about 1.3 GB RAM during the image build, no swap).
- During the image build the Foundation job can keep the Ens runtime lock, so starting the portal production fails there (`ErrCanNotAcquireRuntimeLock`); the installer sets the portal production to auto-start first, and IRIS starts it when the container boots.
- On this machine `docker compose ... build` used a `docker-container` buildx builder (`buildx_buildkit_default`) that cannot see locally loaded images and tried to pull the image from Docker Hub. The verified sequence was:

```text
docker build --build-arg IMAGE=irishealth-community:2026.3.0AI.154.0 --build-arg MYOWN_DEMO_PASSWORD=<demo password> -t portaliris-iris:latest .
docker compose -f compose.yaml -f compose.aihub.yaml up -d --no-build
```

## Commands for the build 154 environment

```text
docker image load -i irishealth-community-2026.3.0AI.154.0-docker.tar.gz
docker images
docker tag <loaded-image-name> irishealth-community:2026.3.0AI.154.0
docker compose -f compose.yaml -f compose.aihub.yaml up --build -d
```

The IRIS edition uses the corresponding `iris-community` archive and local tag. Do not push either the original AI Hub image or a derived image to a public registry.

## API verification checklist for build 154

- [x] Classes `%AI.Agent`, `%AI.Provider`, `%AI.Tool`, `%AI.ToolSet` and the `%AI.Policy` package exist (existence only, 2026-10-21).
- [x] `%AI.Provider` creation and provider configuration (T02; creation without network verified, calls not).
- [x] `%AI.Agent` initialization, session creation (verified) and chat/run methods (signatures from source; not executed).
- [x] `%AI.LLM.Response` content, tool calls and usage fields (from source).
- [x] Session token/tool/duration statistics (`GetStats()` fields verified).
- [x] `%AI.Tool` declaration syntax (verified).
- [x] `%AI.ToolSet` definition, inclusion/exclusion and policy syntax (verified for Include and policies).
- [x] Authorization and audit policy method signatures (verified, including denial).
- [x] Structured-output or repair mechanism: none exists; our Validator stays.
- [ ] AI Hub tracing/telemetry support (only Rust log file and OTel traceparent found; not exercised).
- [ ] OpenAI-compatible base URL behavior (not exercised). Ollama: no provider in build 154.
- [ ] A real `Chat` with a key: response shape, usage numbers, latency, provider failure.

Record exact class names, method signatures, return values and any divergence here after connecting Agentic Dev to the build 154 container.

## Security decisions

- Agent tools remain read-only.
- Model output is untrusted and schema-validated.
- Every mutation becomes an expiring proposal and requires an administrator confirmation.
- Confirmation rechecks authorization, target state, protected targets and separation of duties.
- Public demos must use a provider-side spending limit, a low daily budget, per-user/IP rate limiting and an accessible kill switch.

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

Method signatures are not recorded yet; the checklist below remains open.

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
- [ ] `%AI.Provider` creation and provider configuration.
- [ ] `%AI.Agent` initialization, session creation and chat/run methods.
- [ ] `%AI.LLM.Response` content, tool calls and usage fields.
- [ ] Session token/tool/duration statistics.
- [ ] `%AI.Tool` declaration syntax.
- [ ] `%AI.ToolSet` definition, inclusion/exclusion and policy syntax.
- [ ] Authorization and audit policy method signatures.
- [ ] Structured-output or repair mechanism.
- [ ] AI Hub tracing/telemetry support.
- [ ] OpenAI-compatible base URL behavior and experimental Ollama behavior.

Record exact class names, method signatures, return values and any divergence here after connecting Agentic Dev to the build 154 container.

## Security decisions

- Agent tools remain read-only.
- Model output is untrusted and schema-validated.
- Every mutation becomes an expiring proposal and requires an administrator confirmation.
- Confirmation rechecks authorization, target state, protected targets and separation of duties.
- Public demos must use a provider-side spending limit, a low daily budget, per-user/IP rate limiting and an accessible kill switch.

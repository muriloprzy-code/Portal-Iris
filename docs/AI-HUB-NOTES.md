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

## Commands for the build 154 environment

```text
docker image load -i irishealth-community-2026.3.0AI.154.0-docker.tar.gz
docker images
docker tag <loaded-image-name> irishealth-community:2026.3.0AI.154.0
docker compose -f compose.yaml -f compose.aihub.yaml up --build -d
```

The IRIS edition uses the corresponding `iris-community` archive and local tag. Do not push either the original AI Hub image or a derived image to a public registry.

## API verification checklist for build 154

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

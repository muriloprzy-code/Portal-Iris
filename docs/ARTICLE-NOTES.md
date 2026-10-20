# Developer Community article notes

## 2026-10-16 — deterministic foundation

- Built the agent workflow first with an explainable Rules engine so the entire portal remains demonstrable without an LLM key.
- Implemented real Interoperability routing: Business Services receive health/access events, Business Processes build and validate decisions, and Business Operations record proposals and notifications.
- A production integration test now proves the message flow rather than calling the decision class directly.
- A bug was found in the access workflow: the requester was initially passed as the decision actor, which made every request look like self-approval. The workflow now separates analysis identity from the later confirming administrator.
- Added defense in depth for protected targets before lookup, after read-back, and immediately before mutation.
- Added budgets, call limits, cooldown, deterministic fallback, human confirmation, read-back verification, one-use proposals, audit events and retention.
- Added a complete portal section for decisions, approvals, access, observability, production, guardrails and settings.

## IRIS Agentic Dev experience

- Used the MCP connection to confirm the target instance and namespace, inspect classes, compile ObjectScript and execute unit/integration SQL entry points.
- Latest result: 6/6 core smoke tests and 15/15 Interoperability tests.
- The tool made it explicit that the current target is standard IRIS 2026.2 and contains no `%AI.*` classes. This prevented implementing undocumented AI Hub APIs by guesswork.
- Next step is to point the same tool at the build 154 container and record every actual `%AI.*` signature before writing the provider, ToolSets and agents.

## AI Hub and provider notes

- Contest target: build 154, IRIS or IRIS for Health.
- Default provider decision: OpenAI; key through `MYOWN_AI_API_KEY`; model through `MYOWN_AI_MODEL`.
- No-key behavior: the Rules engine continues to produce validated decisions and full traces.
- Token and cost numbers must be copied from real build 154 ledger runs before publication; do not invent them.

## Screenshots/video still needed

- Agents Overview and deterministic S1 trace.
- Pending task proposal, confirmation and read-back.
- Low-risk and high-risk access decisions.
- Observability totals and a complete trace timeline.
- Guardrails, budget fallback and kill switch.

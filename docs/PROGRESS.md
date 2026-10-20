# AI Agents implementation progress

Last updated: 2026-10-20

This file records verified progress against `SPEC-AI-AGENTS.md` and its first addendum. A checked item means the implementation exists and the listed verification passed; it does not replace the remaining AI Hub build 154 validation.

## Current verified baseline

- Connected instance: InterSystems IRIS 2026.2 build 221U, namespace `MYOWN`, through `iris-agentic-dev` 1.5.0.
- Core unit smoke: **12 passed, 0 failed** (`scripts/Test-AgentSmoke.ps1`), report in `test-results/agents-smoke-core.json`.
- Interoperability smoke: **15 passed, 0 failed** (`scripts/Test-AgentSmoke.ps1`), report in `test-results/agents-smoke-integration.json`.
- REST agent suite: **21 passed, 0 failed, 1 optional Viewer check skipped** (`scripts/Test-Agents.ps1`), report in `test-results/agents-core.json`.
- Secret scan: **SEC-11 passed** across 180 project files and the last 20 commits (`scripts/Test-AgentSecretScan.ps1`).
- AI Hub suite: script and report generation are ready; **6 checks correctly skip** on the current non-AI-Hub instance.
- Frontend TypeScript type-check passed; Vite production bundle generated and served successfully by local IRIS at `/myown/`.
- Current 2026.2 instance does not contain `%AI.Agent`, `%AI.Tool`, `%AI.ToolSet`, or `MyOwn.AIHub.Engine`. Real AI Hub work must be verified in build 154.
- The AI Hub image files found under `Downloads\\ai hub` are still browser `.crdownload` files, so they cannot be loaded into Docker yet.

## Backlog status

| Task | Status | Verification / remaining work |
|---|---|---|
| T01 AI Hub environment | In progress | Agentic Dev is connected; Docker files target build 154. Load the two EAP images and run regression on both editions. |
| T02 AI Hub spike | Blocked by image | Introspect and exercise real `%AI.*` APIs in build 154; record signatures in `AI-HUB-NOTES.md`. |
| T03 Data model and retention | Done (core) | Persistence classes compile; retention smoke passes. |
| T04 Rules engine and contexts | Done | Deterministic scenarios and unit tests pass. |
| T05 Validator and sanitization | Done | Canonical and malicious-output checks pass. |
| T06 Gate, prohibited targets, budget, cooldown | Done (core) | Budget fallback, protected targets and one-use proposals pass. |
| T07 Interoperability setup and audit | Done on 2026.2 | Production is installed and running; build 154 regression remains. |
| T08 Production flow | Done (core) | Business Service → Process → Operation is exercised by integration tests. |
| T09 Proposal confirmation | Done (core) | Revalidation, separation of duties, read-back and one-use behavior tested. |
| T10 REST routes | Mostly done | Agent routes exist and are exercised; OpenAPI expansion and complete RBAC matrix remain. |
| T11 Scenarios S1–S10 | Done (Rules) | REST script exercises all ten scenarios through the production and verifies the expected decisions. |
| T12–T14 Real AI Hub engine | Pending build 154 | Provider, agents, read-only ToolSets and real token usage must use APIs introspected from build 154. |
| T15 Adversarial tests | Mostly done | SEC-01..SEC-04 and SEC-06..SEC-11 pass. SEC-05 is ready and runs when a separate Viewer credential is supplied. |
| T16 Configuration UI/REST | Done (core) | Settings, budgets, kill switch and secret-presence-only display implemented. Provider connection test remains with real AI Hub. |
| T17 Agent frontend | Done (first complete pass) | Decisions, approvals, access, production, guardrails and settings implemented. |
| T18 Observability and trace UI | Done (first complete pass) | Ledger summary and trace timeline consume real backend data. |
| T19 Test scripts and JSON reports | Done (framework) | Core smoke, integration smoke, REST, secret-scan and AI Hub scripts write JSON reports. AI Hub checks remain skipped until build 154 is connected. |
| T20 Browser smoke/screenshots | Pending | Add Playwright smoke and contest screenshots after the AI Hub build is available. |
| T21 Docker/IPM/installer | In progress | Build 154 image, environment variables and Compose overlay documented; clean-machine and both-edition tests remain. |
| T22 Submission documentation | In progress | README AI Hub instructions added; final judges section, video and full reference review remain. |

## Latest delivery (2026-10-18)

1. Added the `Agents` navigation section and its eight functional views.
2. Connected the UI to the existing `/agent/*` REST contract.
3. Added simulation, proposal confirmation/rejection, access requests, production control, configuration and kill-switch actions.
4. Added ledger metrics and trace timeline views.
5. Changed Docker defaults to the required local AI Hub build 154 tag and passed provider/model/key variables without committing a key.
6. Added `compose.aihub.yaml` and the required README load/tag/start/verify instructions.
7. Generated and deployed the production frontend bundle to the IRIS web directory.
8. Verified the portal login page in the browser with no JavaScript warnings or errors.
9. Re-ran the core, interoperability, Docker, IPM, and existing portal regression checks successfully.
10. Expanded the REST suite to S1–S10, real task suspend/resume confirmation, read-only mode, cooldown and response secret scanning.
11. Fixed canonical task-state fingerprints so SysAdmin string booleans and scenario numeric booleans do not create false `TARGET_CHANGED` conflicts.
12. Added reproducible SEC-11 and optional AI Hub test scripts with JSON reports.

## Review fixes verified (2026-10-20)

Review fixes (StableKey cooldown, TaskWatcher rewrite, proposal lock, stricter Validator, Gate `manageable`, `budgetScenario` only for simulate) compiled cleanly on local IRIS 2026.2 (59 classes, MYOWN).

- Core smoke: 12/12 pass (was 9; three new review tests).
- Integration smoke: 15/15 pass.
- REST suite against local IRIS (port 52773): 21 pass / 0 fail / 1 skip (SEC-05 needs `-ViewerCredential`).
- Added `scripts/Test-AgentSmoke.ps1`, which writes the core and integration smoke reports.

## Next verified milestone

Load `iris-community:2026.3.0AI.154.0` and `irishealth-community:2026.3.0AI.154.0`, point `iris-agentic-dev` to that container, introspect `%AI.*`, and implement T02 plus T12–T14 against the signatures actually present in build 154.

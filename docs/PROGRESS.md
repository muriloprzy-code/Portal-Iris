# AI Agents implementation progress

Last updated: 2026-10-20

This file records verified progress against `SPEC-AI-AGENTS.md` and its first addendum. A checked item means the implementation exists and the listed verification passed; it does not replace the remaining AI Hub build 154 validation.

## Current verified baseline

- Connected instance: InterSystems IRIS 2026.2 build 221U, namespace `MYOWN`, through `iris-agentic-dev` 1.5.0.
- Core unit smoke: **14 passed, 0 failed** (`scripts/Test-AgentSmoke.ps1`), report in `test-results/agents-smoke-core.json`.
- Interoperability smoke: **19 passed, 0 failed** (`scripts/Test-AgentSmoke.ps1`), report in `test-results/agents-smoke-integration.json`.
- REST agent suite: **24 passed, 0 failed, 1 optional Viewer check skipped** (`scripts/Test-Agents.ps1`), report in `test-results/agents-core.json`.
- Agents UI (isolated browser): **14 passed, 0 failed** (`scripts/Test-AgentsUI.ps1`), report in `test-results/agents-ui.json`, screenshots in `test-results/ui/`.
- Adversarial corpus: **92 passed, 0 failed** (`scripts/Test-AgentAdversarial.ps1`), report in `test-results/agents-adversarial.json`.
- Secret scan: **SEC-11 passed** across 180 project files and the last 20 commits (`scripts/Test-AgentSecretScan.ps1`).
- AI Hub suite: script and report generation are ready; **6 checks correctly skip** on the current non-AI-Hub instance.
- Frontend TypeScript type-check passed; Vite production bundle generated and served successfully by local IRIS at `/myown/`.
- Current 2026.2 instance does not contain `%AI.Agent`, `%AI.Tool`, `%AI.ToolSet`, or `MyOwn.AIHub.Engine`. Real AI Hub work must be verified in build 154.
- AI Hub build 154 (IRIS for Health, `irishealth-community:2026.3.0AI.154.0`) runs on port 52774 from a fresh volume: installation completes unattended and the same regression passes as on 2026.2 (see "AI Hub build 154 regression"). The IRIS Community edition of build 154 is not loaded on this machine yet.

## Backlog status

| Task | Status | Verification / remaining work |
|---|---|---|
| T01 AI Hub environment | Done for IRIS for Health | Build 154 (IRIS for Health) installs unattended on a fresh volume and passes the full regression with the same results as 2026.2; `%AI.*` classes present. Remaining: the IRIS Community edition of build 154 (image not loaded here). |
| T02 AI Hub spike | Done (read-only, no key) | `%AI` API of build 154 introspected and partly exercised without a key; signatures, verified behavior and the mapping to the portal in `AI-HUB-NOTES.md`. Open: a real `Chat` with a key. |
| T03 Data model and retention | Done (core) | Persistence classes compile; retention smoke passes. |
| T04 Rules engine and contexts | Done | Deterministic scenarios and unit tests pass. |
| T05 Validator and sanitization | Done | Canonical and malicious-output checks pass; hardened by the adversarial corpus (strict types, field allow-list, evidence/conditions checks, delimiter look-alikes, invisible characters). |
| T06 Gate, prohibited targets, budget, cooldown | Done (core) | Budget fallback, protected targets and one-use proposals pass. |
| T07 Interoperability setup and audit | Done on 2026.2 and build 154 (IRIS for Health) | Namespace enabled before the package compiles, empty Foundation production replaced, portal production auto-starts, nine audit events registered by the installer. |
| T08 Production flow | Done (core) | Business Service → Process → Operation is exercised by integration tests. |
| T09 Proposal confirmation | Done (core) | Revalidation, separation of duties, read-back and one-use behavior tested. |
| T10 REST routes | Mostly done | Agent routes exist and are exercised; OpenAPI expansion and complete RBAC matrix remain. |
| T11 Scenarios S1–S10 | Done (Rules) | REST script exercises all ten scenarios through the production and verifies the expected decisions. |
| T12–T14 Real AI Hub engine | Pending build 154 | Provider, agents, read-only ToolSets and real token usage must use APIs introspected from build 154. |
| T15 Adversarial tests | Mostly done | SEC-01..SEC-04 and SEC-06..SEC-11 pass. SEC-01..04 are also covered offline by the 92-case corpus (`MyOwn.Test.AgentAdversarial`). SEC-05 is ready and runs when a separate Viewer credential is supplied. SEC-01/02 still need a run with a real LLM. |
| T16 Configuration UI/REST | Done (core) | Settings, budgets, kill switch and secret-presence-only display implemented. Provider connection test remains with real AI Hub. |
| T17 Agent frontend | Done (first complete pass) | Decisions (with detail drawer), approvals, access, production, guardrails and settings implemented. |
| T18 Observability and trace UI | Done (first complete pass) | Ledger summary and trace timeline consume real backend data. |
| T19 Test scripts and JSON reports | Done (framework) | Core smoke, integration smoke, REST, secret-scan and AI Hub scripts write JSON reports. AI Hub checks remain skipped until build 154 is connected. |
| T20 Browser smoke/screenshots | Done (Rules) | `scripts/Test-AgentsUI.ps1` (Playwright, isolated Chromium) runs S1 to S10 from the screen and checks every decision drawer; screenshots in `test-results/ui/`. Repeat with AI Hub for contest screenshots. |
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

## Adversarial corpus (2026-10-20)

`MyOwn.Test.AgentAdversarial` feeds 92 canned model responses through `Validator.Validate` and, when accepted, `Gate.Evaluate`, with in-memory contexts and configs only (no engine, network, or persisted proposal). Every accepted case also checks invariants: no proposal while not allowed, in kill-switch or read-only mode, for a non-proposal action, or for a self-declared high-risk approval; the sanitized rationale holds no control/format characters and no data delimiter.

| Category | Cases | Covers |
|---|---|---|
| parse | 12 | empty, prose, truncated, two objects, text around, markdown fence, NaN, duplicate keys, object inside fake delimiters |
| schema | 21 | schemaVersion, workflow, missing fields, confidence types/range, rationale size/type/blank, enums, extra fields, evidence |
| action-target | 16 | assign_all, delete_user, run_sql, grant_role, cross-workflow action, propose_* without target, invented/injected targetId, non-task candidate, non-manageable task |
| access | 17 | role/user mismatch, approve with riskLevel high, riskFloor high, %All/%all, SysAdmin, MyOwn* roles, conditions, self-approval |
| injection | 12 | "ignore the rules" in rationale/evidence, delimiter variants, zero-width, C0/DEL/C1, bidi/BOM, benign Unicode |
| sanitize | 5 | nested and split delimiters, attributes, accents/LF preserved, length limit |
| mode | 6 | kill switch, read-only, both, read-only with non-manageable task |
| persist | 1 | evidence refs with delimiters, invisible characters and an extra field are cleaned before storage |
| rest-output | 2 | analysis response, trace message and decision detail return the stored sanitized rationale, recommendedFollowUp, conditions and evidence |

Baseline before fixes: 69 pass / 20 fail. Real defects found and fixed:

- **Validator (12):** accepted `schemaVersion` and `confidence` as strings or booleans, a non-string or blank `rationale`, missing or malformed `evidence`, unknown fields (including triage target fields inside an access decision), `conditions` as a string, and a task proposal aimed at a candidate of another type. Now: strict JSON types, a per-workflow field allow-list, `evidence` required (≤ 10 items, known source, ref ≤ 200), `conditions` array of ≤ 3 strings (≤ 200), candidate type must match `targetType`.
- **Gate (1):** an `approve` whose own `riskLevel` is `high` became a proposal. Now escalated with `downgradedBy=declared-high-risk`.
- **Sanitize (7):** only the exact lower-case delimiters were neutralized, and DEL, C1, zero-width, bidi overrides and BOM survived. Now invisible characters are removed first, then any delimiter variant (case, whitespace, attributes, `&lt;`, full-width brackets) is neutralized.

Evidence persistence (follow-up): `Agent.SaveDecision` now stores evidence through `Agent.SanitizeEvidence`, which keeps only `source` (identifier) and `ref` (`Sanitize.Text`, ≤ 200). Case ADV-E01 (category `persist`) proves the validated input is unsafe verbatim and clean after sanitizing.

REST output (follow-up): `Agent.PublicDecision` is the single sanitized form of a decision (rationale, recommendedFollowUp, conditions, evidence; idempotent). `Analyze` applies it before `SaveDecision`, so the stored row, the `AgentResponse`/`ProposalRequest` messages and the REST response carry the same text; `ResponseFromMessage`, `Scenarios.Run` and `DecisionView` apply it again on read to cover rows and messages written earlier. Cases ADV-E02 (triage) and ADV-E03 (access) prove all three outputs are clean and identical to storage. Proposals and the trace timeline carry no model text. Frontend audit: `frontend/src` has no `dangerouslySetInnerHTML`, `innerHTML` or dynamic `href`; all API values render as escaped JSX text. Rationale, evidence and conditions are not yet shown in the UI (the spec's Decisions page calls for a drawer with rationale and evidence).

## Asynchronous access requests (2026-10-20)

- `POST /agent/access-requests` now computes the privilege delta with the requester's own credentials, stores the request as `queued` with a `TraceId`, and hands an `AccessRequestEvent` to `AccessRequestService`, which forwards it to `AccessProcess` with `SendRequestAsync`. The call returns at once (about 40 ms locally); no credential enters a production message.
- `AccessProcess` records the outcome on the request through `Agent.CompleteAccessRequest` (`decided`, `suppressed` or `failed`, plus decision, proposal, engine and outcome). New route `GET /agent/access-requests/:id` (owner or administrator) returns the request and its sanitized decision; the list now includes the agent recommendation and risk.
- Demo scenarios S5, S6, S7 and S9 use the same asynchronous path and wait at most 15 s for the result (`Agent.WaitForAccessRequest`).
- The Access tab shows queued requests and polls every 2 s until each is decided.
- New REST check IT-13 proves the request is queued at once and decided later. It exposed a pre-existing defect: `Context.Access.IsHighRisk` called `%GetIterator` on a `%ListOfDataTypes`, so a real access request from the portal had always failed with HTTP 500 and an internal error location in the body. Fixed (iterates the list and fails closed as high risk), and the REST handler now converts unexpected exceptions into the standard error.

## Gate and proposal in the business processes (2026-10-20)

- The decision pipeline now runs as three separate production steps, shared by `TriageProcess` and `AccessProcess` through `MyOwn.Production.Process.Steps`: (1) **decide**: `AgentGateway` calls `Agent.Decide` (cooldown, event, engine, Validator, ledger) and returns the validated decision before the Gate; (2) **Gate**: the process calls `Agent.ApplyGate` (deterministic Gate, then the decision record with final action and downgrade reason); (3) **proposal**: `ProposalStore` now creates the proposal through `Agent.StoreProposal`, which re-evaluates the Gate on the final decision before creating anything.
- Each step writes one Event Log line per trace (`[traceId] step N ...`) with enums and ids only. The Message Viewer shows `AgentRequest`/`AgentResponse` and `ProposalRequest`/`ProposalResponse` for every run that proposes. `AgentResponse` gained `ValidationStatus` and `GateJSON`; `ProposalResponse` is new. The production still has ten items.
- `Agent.Analyze` is a thin facade: it injects an `IncidentEvent` through `HealthMonitor` and returns the previous response shape (`decision`, `gate`, `proposalId`, `status: suppressed`). `/agent/analyze` therefore also runs through the production now.
- Upgrade note: recompiling these classes while the production runs left the old `AgentGateway` job calling the new facade, which re-entered the production and deadlocked on itself. `Installer.EnsureAgentProduction` now restarts the production when it is already running (graceful stop, forced after 30 s), so a reinstall through IPM, `Instalar.bat` or `Install-MyOwn.ps1` never mixes old and new code.

## Agent audit events aligned with the specification (2026-10-20)

- New native audit events `MyOwn/Agent/{Decision, ProposalCreated, ProposalConfirmed, ProposalRejected, ProposalExpired, ExecutionResult, ConfigChange, KillSwitch}`, registered by `Installer.EnsureAuditEvent` (and by the new idempotent `Installer.RegisterAuditEvents` for existing installations). They replace `AgentProposalConfirm`, `AgentProposalReject`, `AgentConfigChange`, `AgentKillSwitch` and `AgentPricingChange` under `MyOwn/Administration/Change`; portal administration (including production start/stop) stays there.
- Event data starts with the marker `agent=1;decisionId=N` for agent-originated events (`agent=0` for human configuration and kill-switch changes), followed by `event`, `target`, `outcome`, `actor` and an optional `detail`. Only ids, enums and identifiers are written: no secrets, no rationale, evidence, conditions or justification text. `;`, `=` and line breaks in values are neutralized, so the marker cannot be forged.
- `Decision` is written by the Gate step, `ProposalCreated` by `ProposalStore`, `ProposalConfirmed` before execution (no execution without that audit record), `ExecutionResult` for executed, failed and read-back failures, and `ProposalExpired` for TTL expiry and `TARGET_CHANGED`.
- Tests: UT-14-AUDIT (marker, forgery attempt, unknown event refused) and IT-14-AUDIT (the S5 decision has `Decision`, `ProposalCreated` and `ProposalRejected` with its decision id; no agent audit event contains model or justification text). IRIS flushes the audit buffer in batches (20 to 70 s observed, no public flush API), so IT-14 polls for up to 120 s.
- Still pending: the Logs page has no audit viewer yet, so the "agent events only" filter of the specification is not implemented.

## Decision detail drawer (2026-10-20)

- The Decisions tab adds Risk and Proposal columns and an Open action per row. The drawer shows engine, risk, validation, confidence, the Gate result (final action, downgrade reason, allowed or blocked, prohibited-target reason), the proposal it produced (id, kind, state), and the rationale, evidence and conditions, plus a link to the trace. Esc closes it; focus moves to it only when another decision opens.
- Model-written text is sanitized by the server and rendered only as React text nodes; `frontend/src` still has no `dangerouslySetInnerHTML` or other HTML sink.
- `MyOwn.Agent.Decision` stores `ConditionsJSON` (sanitized) and `GateJSON`. `GET /agent/decisions/:id` returns `conditions`, `gate` and `proposal`, sanitized again on read; the list returns `proposalId`. New REST check IT-15 verifies these fields for the S5 decision. Decisions recorded before this change show no conditions and only the downgrade reason of the Gate.
- Frontend type-check and production build pass; the bundle is regenerated in `web/`. The drawer was not checked in a browser in this session.

## Installation path and screen verification (2026-10-20)

- Every installer reaches `Installer.Setup`: IPM (`module.xml` Invoke, also used by the Dockerfile through `zpm load`), `Instalar.bat` → `Install-All.ps1` → `MyOwnLoadAndSetup`, and `Install-MyOwn.ps1`. `Setup` calls `EnsureAuditEvent` in `%SYS`, which registers the nine audit events, so no manual step is needed. On a fresh install the production starts after all classes compile. A reinstall over a running production now restarts it; verified by running `MyOwnLoadAndSetup` on the local instance (graceful restart, new jobs) followed by all suites.
- Screen replay of S1 to S10 (same requests as the Agents page, `taskId` 0) found that S2 and S3 always failed from the screen because no task id is sent. `Scenarios.Run` now uses the installer's demonstration task, read with the caller's credentials. New REST check IT-16. After the fix, every scenario returns a decision whose detail carries engine, risk, Gate result, proposal state, rationale and evidence (S4 has no evidence by design; only S5 has conditions).
- Superseded by the isolated browser test below.

## Agents UI test in an isolated browser (2026-10-20)

- `scripts/Test-AgentsUI.ps1` runs `tests/ui/agents-ui.mjs` with Playwright 1.55.0 (pinned, own `package.json` and lockfile) and Playwright's bundled Chromium in a fresh profile, never the user's browser. The credential reaches Node only through process environment variables. The test signs in, enables Demo mode through Settings, runs S1 to S10 from the Overview simulator, opens each decision drawer by the decision id returned to the screen, checks engine, risk, Gate result, proposal, rationale, evidence and conditions, closes the drawer with Esc, rejects the proposals it created, restores the settings, and fails on any browser console error or HTTP 5xx from the API.
- Fixed: the Overview simulator called `/agent/simulate` without a task id, so S2 and S3 always failed from the screen. The screen now selects the installer's demonstration task (`MyOwn Portal health snapshot`) and the test asserts that the request carries its id; the server-side fallback stays as a safety net.
- Result: 13 of 13 checks pass, no console errors, no server errors; screenshots `test-results/ui/S1-decision.png` to `S10-decision.png`.
- Found here and fixed in the next section: expired proposals still listed as pending, and repeated `TaskWatcher` proposals for the same task.

## Proposal expiry and deduplication (2026-10-20)

- Root causes found: `Proposal.IsExpired` compared ODBC timestamps with `<`, which ObjectScript evaluates numerically (only the year), so no proposal ever expired; and `TaskWatcher` built the task state without `namespace`, so every watcher proposal failed confirmation with `TARGET_CHANGED` and stayed pending. With the exact failure count in the stable key, each new failure also produced a new key, so the cooldown never held and the watcher added a proposal every cycle (26 pending for two tasks).
- Expiry: `IsExpired` compares as strings; `Proposal.ExpireOverdue` marks overdue pending proposals as `expired` (audited as `ProposalExpired`, detail `ttl`) whenever proposals are listed and in the retention task, so lists and the Approvals badge never show an expired proposal as pending.
- Deduplication (Gate step and again in `ProposalStore`): `Gate.CheckDuplicate` blocks a second proposal for the same kind and target while one is pending and not expired (`duplicate-proposal`; the decision reuses that proposal id and the drawer shows it as "already pending, not duplicated"), or when the most recent executed proposal for that target is the same kind and was executed within `CooldownMinutes` (`recently-executed`). The opposite action (resume after suspend) is allowed. A pending proposal whose target fingerprint no longer matches is superseded (expired, audited with detail `superseded`) instead of being reused, so a reused proposal can always be confirmed.
- `StableKey` uses a failure band (`0`, `1-2`, `3+`) instead of the exact count; `TaskWatcher` now includes the task namespace.
- Tests: UT-15-STABLEKEY, IT-17-EXPIRY, IT-18-DEDUP (stale pending superseded, pending blocked, recently executed blocked, executed long ago allowed, opposite action allowed) and UI-APPROVALS (no pending card past its expiry; badge equals the pending cards). Pending proposals went from 26 to 1 after the change. Not verified end to end: confirming a new watcher proposal, which would suspend a real task.
- Regression IT-19-EXPIRY-REGRESSION: a proposal that expired hours earlier in the same year and month, and one that expired a year earlier, both fail confirmation with `PROPOSAL_EXPIRED` and are never listed as pending. The same-month case is the one the old numeric comparison missed (checked: old expression 0, new expression 1 for that timestamp).

## AI Hub build 154 regression (2026-10-21)

Target: `irishealth-community:2026.3.0AI.154.0` (IRIS for Health, `2026.3.0AI (Build 154U)`), Docker on port 52774 with a new volume `myown-portal-data-154`, `MYOWN_AI_API_KEY` empty, local IRIS 2026.2 on 52773 untouched. The image was not pushed anywhere.

Installation defects found on the fresh build and fixed:

1. The package never compiled: `MYOWN` was created with `Interop=0` and interoperability was only enabled later in `Setup`, so `MyOwn.Production.*` failed with "Class 'Ens.Production' does not exist". `docker/iris.script` now calls `%EnsembleMgr.EnableNamespace("MYOWN")` before `zpm load` (not `Interop=1`, see 3), and `MyOwnLoadAndSetup` (used by `Instalar.bat`) enables the namespace before `LoadDir`. `Test-DockerConfig.ps1` checks it.
2. `MyOwn.Installer` did not compile on its own: its audit parameters were compile-time expressions over `MyOwn.Service.Audit`. They are literals again; UT-14-AUDIT fails if they differ from the Audit lists.
3. On IRIS for Health, enabling interoperability creates and starts an empty `MYOWNPKG.FoundationProduction`, which blocked the portal production. The installer replaces only that generated, item-less Foundation production; any other active production still blocks the installation.
4. During the image build the Foundation job keeps the Ens runtime lock (`ErrCanNotAcquireRuntimeLock`), so the installer now sets the portal production to auto-start before starting it; IRIS starts it on boot. Verified: on a new container the production was running without any manual step.

Regression (reports in `test-results/aihub-154/`, baseline in `test-results/local-2026.2/`, each with `iris.image` and `iris.edition`):

| Suite | 2026.2 (IRIS) | Build 154 (IRIS for Health) |
|---|---|---|
| `Test-MyOwn.ps1` | pass | pass (only difference: reported product `irisforhealth`) |
| `Test-SysAdminMutations.ps1` | pass | pass |
| `Test-Agents.ps1` | 24 / 0 / 1 skip | 24 / 0 / 1 skip, same checks |
| `Test-AgentAdversarial.ps1` | 92 / 0 | 92 / 0 |
| `Test-AgentSmoke.ps1` core | 14 / 0 | 14 / 0 |
| `Test-AgentSmoke.ps1` integration | 19 / 0 | 19 / 0 |

The first integration smoke run on build 154 ended with HTTP 504 from the web gateway (`Server_Response_Timeout` and `Queued_Request_Timeout` are 60 s) and no request reached the production; one rerun passed (14 s for the integration suite). The cause was not confirmed; the integration smoke runs in a single HTTP request, and IT-14 can wait up to 120 s for the audit buffer, so a slow flush can exceed the gateway limit.

`%AI.Agent`, `%AI.Provider`, `%AI.Tool`, `%AI.ToolSet` and the `%AI.Policy` package exist in build 154 (details in `AI-HUB-NOTES.md`).

## Next verified milestone

Load `iris-community:2026.3.0AI.154.0` and `irishealth-community:2026.3.0AI.154.0`, point `iris-agentic-dev` to that container, introspect `%AI.*`, and implement T02 plus T12–T14 against the signatures actually present in build 154.

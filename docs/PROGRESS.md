# AI Agents implementation progress

Last updated: 2026-10-24

This file records verified progress against `SPEC-AI-AGENTS.md` and its first addendum. A checked item means the implementation exists and the listed verification passed; it does not replace the remaining AI Hub build 154 validation.

## Current verified baseline

- Connected instance: InterSystems IRIS 2026.2 build 221U, namespace `MYOWN`, through `iris-agentic-dev` 1.5.0.
- Core unit smoke: **14 passed, 0 failed** (`scripts/Test-AgentSmoke.ps1`), report in `test-results/agents-smoke-core.json`.
- Interoperability smoke: **19 passed, 0 failed** (`scripts/Test-AgentSmoke.ps1`), report in `test-results/agents-smoke-integration.json`.
- REST agent suite: **24 passed, 0 failed, 1 optional Viewer check skipped** (`scripts/Test-Agents.ps1`), report in `test-results/agents-core.json`.
- Agents UI (isolated browser): **14 passed, 0 failed** (`scripts/Test-AgentsUI.ps1`), report in `test-results/agents-ui.json`, screenshots in `test-results/ui/`.
- Adversarial corpus: **92 passed, 0 failed** (`scripts/Test-AgentAdversarial.ps1`), report in `test-results/agents-adversarial.json`.
- Secret scan: **SEC-11 passed** across the 113 tracked or staged files and the last 20 commits (`scripts/Test-AgentSecretScan.ps1`; `.env` and untracked files are out of scope).
- AI Hub engine suite (replay, no key, no network): **20 passed, 0 failed** on build 154 (18 engine checks, configuration and the fixture inventory) (`scripts/Test-Agents-AIHub.ps1`, `SELECT MyOwn_AIHub_Test.AIHubEngineSmoke()`); skipped on 2026.2, where the module is not installed.
- Frontend TypeScript type-check passed; Vite production bundle generated and served successfully by local IRIS at `/myown/`.
- Current 2026.2 instance does not contain `%AI.*`, so the AI Hub module (`aihub/`, `myown-portal-aihub`) is not installed there and Rules decide (`not_installed`).
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
| T12–T14 Real AI Hub engine | Done (replay verified; live blocked by provider quota) | `MyOwn.AIHub.*` module: deadline worker, read-only ToolSet, allow-list and audit policies, ledger, replay mode, fallback reasons. 14 engine checks pass in replay on build 154. Real calls on 2026-10-22 ended in fallbacks (refused option, three timeouts, then HTTP 429 free-tier quota); a successful AI decision with the new settings is still to be measured. |
| T15 Adversarial tests | Mostly done | SEC-01..SEC-04 and SEC-06..SEC-11 pass. SEC-01..04 are also covered offline by the 92-case corpus (`MyOwn.Test.AgentAdversarial`). SEC-05 is ready and runs when a separate Viewer credential is supplied. SEC-01/02 still need a run with a real LLM. |
| T16 Configuration UI/REST | Done (core) | Settings, budgets, kill switch and secret-presence-only display implemented. Provider connection test remains with real AI Hub. |
| T17 Agent frontend | Done (first complete pass) | Decisions (with detail drawer), approvals, access, production, guardrails and settings implemented. |
| T18 Observability and trace UI | Done (first complete pass) | Ledger summary and trace timeline consume real backend data. |
| T19 Test scripts and JSON reports | Done | Core smoke, integration smoke, REST, secret-scan, UI and AI Hub scripts write JSON reports; the AI Hub suite runs the engine checks in replay and, with `-Live`, real calls (15 s apart, stop at 429). |
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

The first integration smoke run on build 154 ended with HTTP 504 from the web gateway (`Server_Response_Timeout` and `Queued_Request_Timeout` are 60 s) and no request reached the production; one rerun passed (14 s for the integration suite). The cause was confirmed and fixed on 2026-10-24: IT-14 waited inside that single request for the audit buffer (see "Web gateway 504 fixed").

`%AI.Agent`, `%AI.Provider`, `%AI.Tool`, `%AI.ToolSet` and the `%AI.Policy` package exist in build 154 (details in `AI-HUB-NOTES.md`).

## Real AI Hub test (T03, 2026-10-21)

Five triage calls plus three injection cases against Gemini (`gemini-3.8-flash`; `gemini-2.5-flash` from `.env` is no longer offered to new keys) through `%AI.Agent` on build 154: 8 of 8 answers were a single JSON object accepted by our Validator, 12.6 to 83.3 s per call, the model ignored all injected instructions. Invalid key and a slow provider both fell back to Rules without breaking, but the reason is not recorded, the slow case returns HTTP 504 to the caller at 60 s, and `Budget.CallsAllowed` counts Rules decisions as AI calls. Details and findings in `AI-HUB-NOTES.md` ("Teste real"). Engine not implemented yet.

## AI Hub engine (T04, 2026-10-22)

Module `myown-portal-aihub` (`aihub/module.xml`, depends on `myown-portal`), installed only where `%AI.Agent` exists: by `docker/iris.script` after the core, and by `MyOwnLoadAndSetup` (`aihub/src` next to `src/objectscript`). No stub remains in the repository or the container (`extras/T03EngineStub.cls` deleted; temporary probe classes removed).

- `MyOwn.AIHub.Engine`: `Ready(.reason)` and `Decide(workflow, contextJSON, .result)`. Each decision runs in a `JOB` worker; the caller waits up to `MYOWN_AI_TIMEOUT_SECONDS` (default 20, 5 to 55) and then terminates it, because the session `timeout_ms` does not interrupt a provider call. Tool calls made before the deadline are kept.
- Fallback reasons, stored in `Decision.FallbackReason`, the AI ledger row (`ErrorSummary`), the `Decision` audit detail (`rules-<reason>/...`) and shown on screen as "AI" or "Rules (reason)": `kill_switch`, `budget`, `disabled` (preference rules), `not_installed`, `no_key`, `provider_timeout`, `provider_error`, `invalid_json`.
- Only real AI calls count for `MaxAgentCallsPerHour` and the daily token budget (`Engine = 'aihub'`, not replay). Every attempt writes its own ledger row with real tokens (total as reported, which includes hidden reasoning), latency and cost (hidden reasoning priced as output).
- Configuration only from the environment (`MyOwn.Agent.AIEnv`: provider, model, key presence, mode, timeout, output tokens, thinking); `PUT /agent/config` ignores provider fields and the screen shows them read-only.
- Prompt: compact instructions, portal facts as plain JSON, untrusted text (task names and errors, log lines, justifications; cut to 300 characters, at most 5 logs) only inside `<untrusted_data>` with `<` and `>` escaped. Session: `max_iterations` 2, `max_tokens` 400, temperature 0, `reasoning_effort` (low by default) for Gemini; a provider refusal of that option is retried once without it and recorded.
- Tools: `MyOwn.AIHub.Tools.Ops` (`GetTaskRuns`, `GetMetricHistory`, SQL reads of this namespace only) in `MyOwn.AIHub.ToolSet.Ops`. `Policy.ReadOnlyAuth` (global authorization policy) allows only those two tools from that class; anything else is denied, stored as a `ToolCall` with status `denied` and audited as the new event `MyOwn/Agent/ToolDenied`.
- Replay mode (`MYOWN_AI_MODE=replay`): `MyOwn.AIHub.Fixtures` holds the eight T03 answers (placeholders for task id, user and role; measured tokens and latency), three synthetic branches and the test cases; tools still run through the real tool manager and policies.
- `TaskWatcher` fix: `%SYS_Task.History.Error` holds the message of every row ("Success", "Task suspended", "Task has expired ..."), so every run counted as a failure (53 in a row for the health task). A failure is now `Status` not 1.
- Installation fix: `zpm "load ...":1:1` halts the session after the core (third argument `pHaltOnComplete`), so nothing after it ran; the loads use `:1:0`.

Engine checks (`MyOwn.AIHub.Test.EngineTest`, replay): AH-01 readiness, AH-02 valid JSON with a tool call, AH-03 AI decision recorded, AH-04 invalid JSON, AH-05 timeout (5 s deadline, worker terminated), AH-06 provider error, AH-07 write tool denied and audited (never executed), AH-08 budget, AH-09 kill switch, AH-10 preference rules, AH-11 replay not counted, AH-12 allow-list, AH-13 delimiters, AH-14 reasoning-option retry.

Regression (reports in `test-results/t04-local/` and `test-results/t04-aihub-154/`):

| Suite | 2026.2 (IRIS) | Build 154 (IRIS for Health) |
|---|---|---|
| `Test-MyOwn.ps1` | pass | pass |
| `Test-SysAdminMutations.ps1` | pass | pass |
| `Test-Agents.ps1` | 24 / 0 / 1 skip | 24 / 0 / 1 skip |
| `Test-AgentAdversarial.ps1` | 92 / 0 | 92 / 0 |
| `Test-AgentSmoke.ps1` core / integration | 14 / 0, 19 / 0 | 14 / 0, 19 / 0 |
| `Test-Agents-AIHub.ps1` | skipped (not installed) | 15 / 0 |
| `Test-AgentsUI.ps1` | 14 / 0 | 14 / 0 |

The UI test now opens `/myown/index.html`: the private web server of the IRIS containers serves no default document for `/myown/` (404), so evaluators must use the full URL, as the IPM install message already says.

Real calls (Gemini `gemini-3.8-flash`, free tier; 5 of the 6 allowed, at least 15 s apart; the monitoring services were paused and the hourly limit set to 6 during the window, then restored): 1) HTTP 400 for a native `generationConfig` sent through `extra_params`, fallback `provider_error` in 0.7 s; 2) to 4) no answer within 55 s and no tool called, fallback `provider_timeout` (once without the reasoning option); 5) run in the foreground to rule out the worker: HTTP 429 free-tier quota after 27.7 s. The provider retries a 429 internally before reporting it, which explains the timeouts. Stopped there. Latency after the changes could not be measured; the T03 baseline stays 12.6 to 83.3 s (median about 45 s). The compact prompt is only 7 to 10 % shorter for the small T03 contexts (1,173 to 1,067 characters for C2); the reduction applies mainly to real health and log contexts. On the 154 container the engine preference was left at `rules`, so the restored monitoring services make no real calls until the quota resets.

Mistake in this session: stopping the hung `docker build` client on Windows did not stop the build in the Docker daemon, so two image builds overlapped for a few minutes. The image used for the regression is the later one (fixed `iris.script`), checked inside the image.

## Replay fixtures from real decisions (4b, 2026-10-24)

Replay answers are now one fixture per demonstration scenario, each a real model decision with its header (`aihub/fixtures/S1.json` .. `S10.json`: status, provider, model, `recordedAt` in UTC, source, how the context relates to the scenario, substitutions). Only the task id, user and role are replaced by placeholders; the answer text is otherwise literal. `scripts/Build-ReplayFixtures.ps1` writes them into `MyOwn.AIHub.Fixtures` (`-Check` verifies the class matches); `scripts/Record-ReplayFixtures.ps1` records pending scenarios through `MyOwn_AIHub.RecordScenario` (exact scenario context from `MyOwn.Install.Scenarios.BuildContext`, live engine, Validator, ledger row so the call counts for the limits; no production, no proposal), at most 6 calls, 15 s apart, stopping at a quota error.

| Scenario | Source | Model | Recorded (UTC) |
|---|---|---|---|
| S1 | recorder, exact context | gemini-3.8-flash | 2026-10-24 01:00 |
| S2 | T03 C2 (equivalent context) | gemini-3.8-flash | 2026-10-21 01:10 |
| S3 | T03 C3 (equivalent context) | gemini-3.8-flash | 2026-10-21 01:11 |
| S4 | T03 C4 (equivalent context) | gemini-3.8-flash | 2026-10-21 01:12 |
| S5 | recorder, exact context | gemini-3.8-flash | 2026-10-24 00:43 |
| S6 | recorder, exact context | gemini-3.8-flash | 2026-10-24 00:44 |
| S7 | recorder, exact context | gemini-3.8-flash | 2026-10-24 00:44 |
| S8 | T03 I1 (equivalent context) | gemini-3.8-flash | 2026-10-21 01:13 |
| S9 | T03 I2 (equivalent context) | gemini-3.8-flash | 2026-10-21 01:15 |
| S10 | not applicable: the budget check stops it before any AI call | — | — |

Pending recording: none. S2 to S4, S8 and S9 come from the T03 calls, whose contexts were equivalent but not identical (each header says how). Re-recording them with the exact contexts (2026-10-24 01:00 UTC, 3 of the 6 allowed calls): S1 recorded in 18.1 s; S2 and S3 got no answer within the 20 s deadline (S3 with no tool call), so the run stopped there and S4, S8 and S9 were not attempted; those five keep their T03 recordings. The recorder now stops at any provider failure (a 429 can surface as a timeout) and reports the tool calls made before the deadline. A second attempt on 2026-10-26 (55 s deadline for the recording window, 2 of 6 calls) found the cause: Gemini answered HTTP 503 "high demand" after internal retries; the worker and the tool loop were ruled out with a local mock. S2 to S4, S8 and S9 still come from T03. The T04 synthetic answers (low and medium access, warning) and the invented tool call in the S2 replay were removed. A scenario whose fixture is not recorded makes the engine fall back with the new reason `replay_missing` instead of inventing an answer (AH-16). AH-15 checks that every recorded fixture has its header and passes the Validator for its scenario context.

The Agents screen and the overview card show the badge "Replay of recorded real decisions" while `MYOWN_AI_MODE=replay` (UI-REPLAY-BADGE: shown in replay on build 154, absent in live on 2026.2). The secret scan pattern for configured keys no longer crosses a line break (an empty `MYOWN_AI_API_KEY=` in a diff matched the next line).

Real calls: 3 (S5, S6, S7), all answered within the 20 s deadline: 11.6, 13.3 and 16.4 s; tokens in/out/total 418/71/571, 418/85/702, 418/78/628. Compared with T03 (12.6 to 83.3 s, totals 741 to 2,947 for about 300 prompt tokens), the hidden reasoning is much smaller (total minus input and output: 82 to 199 tokens against 384 to 2,522), which suggests `reasoning_effort` low is honored; the prompt is larger because it now includes the tool catalog. Three calls at another time of day are not a benchmark. Regression after the change: 2026.2 all seven suites pass; build 154 (replay) all pass, with one rerun of `Test-AgentSmoke.ps1` and `Test-Agents-AIHub.ps1` after HTTP 504 from the 60 s web gateway (both run as one long SQL request; the AI Hub suite takes about 60 s, at that limit).

## Web gateway 504 fixed (2026-10-24)

Cause found, not retried away: IT-14 and AH-07 waited inside one SQL request for agent audit records, which IRIS makes visible only when it writes its audit buffer (46 to 60 s later, on 2026.2 and build 154), so the suite request sometimes passed the Web Gateway's 60 s `Server_Response_Timeout` (Apache allows 300 s). Cold start was ruled out (first requests after a restart: 55 to 421 ms). The suites now return those two checks as pending and the scripts poll a short check every 2 s; the longest suite request went from about 58 s to 6.9 s. On a fresh image and volume the full regression passed on its first and only run with no gateway warning. Details and before/after timings in `AI-HUB-NOTES.md` ("Web gateway HTTP 504 on the first run"). The suites also report `durationMs` per check and `requestMs` per suite.

## Public demo mode (T11, 2026-10-26)

`MYOWN_DEMO_MODE=1` makes the portal safe to expose (design choice: simulated execution).

- **Demo account.** Role `MyOwnDemo` (resources `MyOwn.View`, `MyOwn.Demo`) and user `demo`, created or updated at every container start by `docker/demo-start.sh` (`iris-main -a`) from `MYOWN_DEMO_USER_PASSWORD`; disabled when demo mode is off. `scripts/New-DemoPassword.ps1` generates the password into `.env` only. Database access (`%DB_MYOWN_DATA:RW`, `%DB_MYOWN_CODE:R`) and SQL `SELECT` on the portal schemas come from an application role granted only inside `/myown/api` (since T12 `MyOwnPortalData`, shared with `MyOwnViewer`). Testing with the real account found that dynamic SQL needs these grants for any account without `%All`; the `MyOwnViewer` role has never been tested that way.
- **Synthetic targets.** `MyOwn.Demo.Target` holds two tasks (9001, 9002), two users and two roles seeded by `MyOwn.Demo.Seed`; in demo mode S2/S3 use the synthetic tasks and access scenarios use the synthetic requester `demo.alice`. A confirmation revalidates as before and then applies the change to the synthetic record only (state `simulated`, read back from that record); IRIS is never changed. Any other target is refused (`DEMO_TARGET_REFUSED`) and audited (`DemoRefused`); `Prohibited` is unchanged.
- **Routes.** The demo account may read, run scenarios, list, confirm and reject proposals, and reset the demo; settings, pricing, kill switch, production control, analysis, access requests and all administration routes answer 403. Routes that change the real system (users and roles, web applications, task actions, API explorer) are refused for everyone in demo mode.
- **Reset.** Task `MyOwn Demo reset` every `MYOWN_DEMO_RESET_HOURS` (default 6; the Task Manager starts a new task tomorrow unless `StartDate` is today, and then skips past slots) and the "Reset demo" button shown only to the demo account; both audited (`DemoReset`).
- **Rate limit.** `MYOWN_DEMO_SIMULATIONS_PER_MINUTE` (default 6) per client address and per session, 429 with `Retry-After`; the reset button is limited to 2 per minute.
- `.env.example` and the Compose defaults now use the tested provider (Gemini, `gemini-3.8-flash`); OpenAI is documented as an untested alternative.

Tests: `MyOwn.Test.Demo` (DM-01..08, in-IRIS, demo mode forced per process) and `scripts/Test-AgentDemo.ps1` (DM-10..17 over REST with the real demo account: view allowed, 11 administration and real-system routes refused, administrator refused on real tasks, S2 + confirmation ends `simulated` on task 9001, a real-target confirmation refused and audited, reset restores and is audited, rate limit). Fresh image and volume on build 154: full regression passed on its first run with demo mode off (REST 24/0/1, corpus 92, smokes 14 and 19, AI Hub 18, demo in-IRIS 8, UI 15); then, on the same volume with demo mode on, the demo account was created at start and `Test-AgentDemo.ps1` passed 16/16. Local 2026.2: same results (AI Hub skipped).

## Evaluator robustness (T12, 2026-10-27)

**Viewer role without `%All`.** A temporary `MyOwnViewer`-only account (`scripts/Test-PortalViewer.ps1`) could not even sign in: every route answered 403 because the role had no access to the namespace databases. Fix: the application role (renamed `MyOwnPortalData`, granted only inside `/myown/api`, shared with the demo account) now also applies to `MyOwnViewer`; it carries the namespace databases, SQL `SELECT` on the portal schemas and, where the resource exists, `%Service_EmbeddedPython` (the Overview health score is Embedded Python; build 154 requires that resource, 2026.2 has none, which first made `Setup` fail there with ERROR #892). Documented, not fixed: a viewer cannot file an access request, because SysAdmin API v2 refuses it even its own account; granting `%Admin_Secure` to a read-only role is the wrong trade. The route now answers 403 `ACCESS_REQUEST_NEEDS_SECURITY_READ` instead of 500 and the Access tab explains it. Result 5/5 on build 154 and on 2026.2.

**Build memory.** Measured with a sampler reading the Docker VM `/proc/meminfo` every 2 s: about 0.96 GB in use before the build, 1.6 to 1.7 GB during the FHIR load of `EnableNamespace`, peak 2.29 GB while the portal compiles and installs, no swap; Windows free memory fell to about 430 MB (16 GB machine, WSL limited to 8 GB). A first measurement was distorted by the machine suspending the VM for hours. No safe reduction was found: the Foundation and FHIR load are part of enabling interoperability on IRIS for Health and cannot be skipped. Instead: the README states the tested memory setup and what to do when `docker compose up` is stopped, and an incomplete installation can no longer run silently (`docker/finish-build.script` writes `docker/.install-complete` only when the portal, and on AI Hub builds its engine, compiled; the Dockerfile fails without it; `start-iris.sh` refuses to start an image without it).

**Clean installation following only the README** (folder `C:\Projetos\PortalIris-clean` copied from the working tree, no `.env`, no volume, no `.git`):

| Step | Time | Note |
|---|---|---|
| `docker image load` of the 5 GB archive | 250 s | prints `Loaded image: docker.iscinternal.com/.../irishealth-community:2026.3.0AI.154.0` |
| `docker tag` | 0.1 s | README did not say which name to tag; now it does |
| `.env` from `.env.example` | — | the default volume `myown-portal-data` already existed on this machine (older data): used a new name; README now warns |
| `docker compose ... up --build -d` | build 6 min 13 s; container started 6 min 18 s after the command | the compose client was stopped by Claude Code for low Windows memory, but the build and the start completed; `compose build` saw the local image |
| health check | healthy on first look | marker present, demo mode off, production running |
| `Invoke-RestMethod -Credential` (README) | — | 401: Windows PowerShell sends Basic only after a challenge; README now uses `curl.exe -u` and a `$cred` for the scripts |
| `curl` `/health`, `/agent/status` | < 1 s | `ok`; `aiHubAvailable` 1, `activeEngine` rules (no key) |
| `Test-Agents.ps1` | 4 s | 24 / 0 / 1 skip |
| `Test-Agents-AIHub.ps1` | 43 s | 18 / 0 |
| `Test-AgentSecretScan.ps1` | 2 s | failed without `.git`; now falls back to scanning every text file of the folder (152 files), `.env` excluded |

Full regression on that fresh container, first and only run: Test-MyOwn, SysAdminMutations, REST 24/0/1, corpus 92/0, smokes 14/0 and 19/0, AI Hub 18/0, demo 8/0 (REST part needs demo mode), viewer 5/0, UI 15/0. Local 2026.2: same (AI Hub skipped; the viewer suite first failed there on the missing resource, then passed after the fix).

## AI Hub API review and tool hardening (T13, 2026-10-27)

Checked more of the `%AI` API on build 154 and recorded it in `docs/AI-HUB-NOTES.md` ("More of the `%AI` API"), each item marked verified on build 154 or signature only (read from the build 154 class dictionary, not run). Facts that differ from what one might assume: placeholders are `@{env:NAME}` (a dot fails with `SettingUnknownPrefix`), `[ WebMethod ]` is not needed for a tool, `StreamChat` has three arguments, and `%AI.SubAgent`, `%AI.Skill` and `%AI.System.StreamRenderer` do not exist (`%AI.Agent.SubAgent`, `%AI.Agent.Skill`, `%AI.Shell.StreamRenderer`). The repository had no `@{env.` and no `AddTool` without `iris:`.

Changes:
- `GetTaskRuns` and `GetMetricHistory` are class queries (`%Query`, `[ SqlProc ]`, `QUERYMAXROWS = 20`): AI Hub returns `columns`, `rows`, `row_count`, `truncated`, `elapsed_ms`. Row fields, arguments and limits are unchanged; unknown or foreign tasks and unknown metrics give no rows. The Gate, the Validator and the UI are unchanged (none reads tool results). AH-18.
- `MyOwn.AIHub.ToolSet.Ops` has `<Exclude Match="^(?!Get[A-Z])"/>` behind the allow-list. AH-17 includes the test write tool next to the read-only tools, with the same Exclude and no authorization policy: it is not listed and `ExecuteTool` gives `ToolNotFound` without running it. Without the Exclude the same ToolSet lists it (checked once by hand).
- Not adopted: MCP service, RAG, LangChain, sub-agents, skills.

Regression on build 154, first and only run: Test-MyOwn, SysAdminMutations, REST 24/0/1, corpus 92/92, smokes 14/14 and 19/19, AI Hub 20/0, demo 8/1 skip (demo mode off), viewer 5/5, UI 15/15. Secret scan: pass.

## Next verified milestone

T02 (AI Hub API spike) and T13 (API review and tool hardening) are done, on IRIS for Health build 154; the IRIS edition of build 154 is not needed. Next:

1. Re-record the replay fixtures S2 to S4, S8 and S9 with real calls when Gemini is available again (`scripts/Record-ReplayFixtures.ps1`, at most 6 calls, 15 s apart; they still come from T03).
2. Publish the online demo in replay mode (`MYOWN_AI_MODE=replay`, `MYOWN_DEMO_MODE=1`).
3. Review the contest bonus items against what is done.

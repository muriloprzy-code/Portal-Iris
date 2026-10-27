# MyOwn Portal — AI Agents in Interoperability Workflows

MyOwn Portal is an administration portal for InterSystems IRIS and IRIS for Health. This entry adds an interoperability production in which an AI agent triages incidents and access requests: it reads the instance, decides and explains, and proposes a change, while a person confirms it.

- **What it does:** health anomalies, failing tasks, log alerts and role requests become events in an IRIS production; the agent returns a decision (ignore, notify, escalate, propose a task action, approve or deny a role) with a rationale, evidence and a confidence value.
- **How it fits the theme:** the agent is a step inside a real interoperability workflow (Business Services → Business Processes → Business Operations), built on IRIS AI Hub (`%AI.Agent`, ToolSets, policies) in build `2026.3.0AI.154.0`.
- **What is technically interesting:** the agent never writes. Every decision passes a schema Validator and a deterministic Gate; a human confirms with their own credentials; the change is revalidated, executed and read back. Read-only tools are enforced by an allow-list policy, every AI call lands in a token/cost/latency ledger, and when the model is slow, wrong or unavailable the deterministic Rules engine decides instead and the screen says why.

## Links

- Online demo: **[TODO: URL]** (replay mode, see [Demo mode](#demo-mode))
- Video: **[TODO: URL]**
- Article on the Developer Community: **[TODO: URL]**

## Why this design

- **The agent only decides.** It has read-only tools and no write path. A state change exists only as a proposal that expires.
- **Validator.** The model output must be a single JSON object matching schema v1: strict types, an allow-list of fields and actions, bounded text, and targets taken from the candidate list the server supplied.
- **Gate.** Kill switch, read-only mode, prohibited targets (for example the `%All` role), downgrade of high-risk decisions to escalation, one open proposal per target and action, budget and cooldown.
- **Human confirmation revalidates everything:** state, expiry, separation of duties (a requester cannot confirm their own request), prohibited targets, the target fingerprint (`TARGET_CHANGED`) and the confirming user's live permission. The change runs with that user's credentials and is read back.
- **Untrusted data stays data.** Log lines, task errors and justifications reach the model only inside delimiters, sanitized and with the delimiter characters escaped.
- **Always a working system.** Without AI Hub, without a key, with the kill switch on, over budget, or when the provider fails, the Rules engine decides. The reason is recorded and shown as a badge such as `Rules (provider_timeout)`.

## Architecture

```
HealthMonitor · TaskWatcher · LogWatcher · AccessRequestService      Business Services
        │  event (context with untrusted data delimited)
        ▼
TriageProcess · AccessProcess                                       Business Processes
   1. decide (AgentGateway)  2. Gate  3. proposal (ProposalStore)
        │
        ▼
AgentGateway ─┬─ AI Hub engine: %AI.Agent + read-only ToolSet,      Business Operations
              │  allow-list policy, audit policy, own deadline
              └─ Rules engine (fallback, always available)
        │  Validator → Gate → proposal → human confirmation → read-back → audit
        ▼
REST /myown/api/agent/*  →  React UI: Decisions, Approvals, Access, Production, Guardrails, Settings
```

The AI Hub module (`aihub/`, IPM `myown-portal-aihub`) installs only where the `%AI` package exists; elsewhere the portal runs on Rules.

## Demonstration scenarios

Run them from the **Agents** page or with `POST /myown/api/agent/simulate` (administrator role and demo mode required).

| # | Scenario | Rules engine | Recorded AI decision (replay) |
|---|---|---|---|
| S1 | Critical disk anomaly | `notify` | `escalate` |
| S2 | Task failing repeatedly | proposal: suspend task | proposal: suspend task |
| S3 | Suspended task whose last run succeeded | proposal: resume task | proposal: resume task |
| S4 | Normal conditions | `ignore` | `ignore` |
| S5 | Low-risk role request | `approve`, proposal created | `approve` |
| S6 | High-risk role request | `escalate` | `escalate` |
| S7 | Request for the prohibited `%All` role | blocked by the Gate | `deny` |
| S8 | Prompt injection in a log line | treated as data, `notify` | `escalate` |
| S9 | Prompt injection in a justification | treated as data, `escalate` | `deny` |
| S10 | Budget exhausted | Rules decide (`budget`) | not applicable: no AI call is made |

The Gate and the confirmation step apply to both engines.

## Run it locally

**Image.** InterSystems IRIS AI Hub Community build **`2026.3.0AI.154.0`** (IRIS and IRIS for Health are both accepted; this repository defaults to IRIS for Health). Download it from the [AI Hub Early Access portal](https://evaluation.intersystems.com/Eval/early-access/AIHub), then load and retag it once per machine:

```shell
docker image load -i irishealth-community-2026.3.0AI.154.0-docker.tar.gz
# prints: Loaded image: docker.iscinternal.com/docker-intersystems/intersystems/irishealth-community:2026.3.0AI.154.0
docker tag docker.iscinternal.com/docker-intersystems/intersystems/irishealth-community:2026.3.0AI.154.0 irishealth-community:2026.3.0AI.154.0
```

If `docker image load` prints a different name, tag that name instead (`docker images` lists it). Loading the 5 GB archive took about 4 minutes here.

For the IRIS edition, load `iris-community-2026.3.0AI.154.0-docker.tar.gz`, tag it `iris-community:2026.3.0AI.154.0` and set `IRIS_IMAGE` in `.env`.

**Configuration.** Copy `.env.example` to the git-ignored `.env` and set:

| Variable | Meaning |
|---|---|
| `MYOWN_AI_PROVIDER` | `openai`, `anthropic`, `gemini` or `bedrock` |
| `MYOWN_AI_MODEL` | model name accepted by your key |
| `MYOWN_AI_API_KEY` | your key; never committed, never shown by the portal |
| `MYOWN_AI_MODE` | `live` (default) or `replay` (recorded decisions, no key, no network) |
| `MYOWN_AI_TIMEOUT_SECONDS` | the portal's own deadline per decision, 5 to 55 (default 20) |
| `MYOWN_DEMO_PASSWORD` | initial `_SYSTEM` password of a new container volume; choose your own |

The defaults in `.env.example` are the tested provider, Gemini (`gemini-3.8-flash`). OpenAI (for example `gpt-4.1-mini`), Anthropic and Bedrock are accepted by the same `%AI.Provider` path but untested; see [Limitations](#limitations). Without a key the portal starts and uses the Rules engine.

**Start:**

```shell
docker compose -f compose.yaml -f compose.aihub.yaml up --build -d
```

Open `http://localhost:52774/myown/index.html` (the full path: the container's web server serves no default page for `/myown/`) and sign in with `_SYSTEM` and the password you set in `MYOWN_DEMO_PASSWORD`.

**Verify** (replace `<password>` with your `MYOWN_DEMO_PASSWORD`; `Invoke-RestMethod -Credential` does not work here, because Windows PowerShell sends the credential only after a challenge that IRIS does not send):

```powershell
curl.exe -s -u "_SYSTEM:<password>" http://localhost:52774/myown/api/health
curl.exe -s -u "_SYSTEM:<password>" http://localhost:52774/myown/api/agent/status
$cred = Get-Credential _SYSTEM
.\scripts\Test-Agents.ps1 -BaseUrl http://localhost:52774 -Credential $cred -IrisImage irishealth-community:2026.3.0AI.154.0 -Edition irisforhealth
.\scripts\Test-Agents-AIHub.ps1 -BaseUrl http://localhost:52774 -Credential $cred
.\scripts\Test-AgentSecretScan.ps1
```

`/health` answers `"status":"ok"`; `/agent/status` shows `aiHubAvailable` 1 on build 154 and `activeEngine` `rules` until a key (or replay mode) is set. The secret scan covers tracked files in a git clone and every text file in a folder without git (a ZIP download), never `.env`.

**Reinstalling over an earlier version.** IRIS keeps its accounts, passwords and data in the Docker volume named by `MYOWN_DATA_VOLUME` (default `myown-portal-data`). An existing volume keeps the old accounts and passwords, and a new `MYOWN_DEMO_PASSWORD` is not applied to it. For a clean install, either set a new `MYOWN_DATA_VOLUME` in `.env` or remove the old volume first (this deletes its data):

```shell
docker compose -f compose.yaml -f compose.aihub.yaml down
docker volume rm myown-portal-data
```

### Memory

The image build starts IRIS for Health, enables interoperability (which also loads the FHIR packages) and compiles the portal. Measured inside the Docker VM: about 1 GB in use before the build and about 2.3 GB at its peak; the running container uses about 1 GB. Tested with WSL limited to 8 GB on a machine with 16 GB of RAM; lower limits are not tested. With other programs open, the build can leave Windows with very little free memory, so close what you can before building.

The WSL limits live in `%UserProfile%\.wslconfig` (run `wsl --shutdown` and restart Docker Desktop after changing it). The tested configuration:

```ini
[wsl2]
memory=8GB
swap=8GB
```

**If `docker compose up` is stopped for lack of memory:** close programs or raise `memory=` in `.wslconfig`, then run the same `docker compose ... up --build -d` again; Docker reuses the layers that finished. Closing the terminal does not stop a build already running inside Docker (`docker buildx history ls` shows it), so wait for it before starting another one. An image whose installation did not finish is never used: the build writes the marker `docker/.install-complete` only after the portal compiled, fails without it, and the container refuses to start an image that lacks it, with a message saying to rebuild.

> **Do not push the AI Hub image, or any image built on it, to a public registry.** Share only the Dockerfile and Compose files.

Other installation paths (a local IRIS instance, `Instalar.bat`) are described in [docs/REFERENCE.md](docs/REFERENCE.md).

## Demo mode

The online demo runs with `MYOWN_AI_MODE=replay`: each AI answer is a **real model decision recorded earlier**, not generated live. Every fixture in `aihub/fixtures/` names the provider, model and recording date; the screen shows the badge "Replay of recorded real decisions". S1, S5, S6 and S7 were recorded with the exact scenario context; S2, S3, S4, S8 and S9 come from earlier real calls with equivalent contexts, as each fixture header states. Replay still goes through the tool manager, policies, Validator, Gate and ledger.

Running the agent live requires a local installation with your own key (`MYOWN_AI_MODE=live`).

With `MYOWN_DEMO_MODE=1` the portal is safe to expose:

- **Demo account.** A user `demo` with the role `MyOwnDemo`: it can view the portal, run the demonstration scenarios, and confirm or reject proposals. It has no IRIS administration privileges, no Settings, no access to the provider configuration or key, and every administration route answers 403. Database and SQL read access are granted only inside `/myown/api` (application role `MyOwnPortalData`, shared with the viewer role).
- **Synthetic targets only.** The scenarios use seeded demo tasks (9001, 9002), users (`demo.alice`, `demo.bob`) and roles (`DemoOperator`, `DemoAuditor`). A confirmation revalidates as usual and then changes only that synthetic record; the proposal ends as `simulated`, and **IRIS is never changed**. A confirmation on any other target is refused (`DEMO_TARGET_REFUSED`) and audited (`MyOwn/Agent/DemoRefused`). Prohibited targets such as `%All` stay blocked.
- **Real-system routes are off for everyone** in this mode (users and roles, web applications, task actions, the API explorer), administrators included.
- **Reset.** The synthetic state is restored every `MYOWN_DEMO_RESET_HOURS` (default 6) by the task `MyOwn Demo reset`, and by the "Reset demo" button that only the demo account sees; both are audited (`MyOwn/Agent/DemoReset`).
- **Rate limit.** `MYOWN_DEMO_SIMULATIONS_PER_MINUTE` (default 6) scenarios per minute per client address and per session; beyond that the API answers 429 with `Retry-After`.

**Instructions for whoever hosts the demo:**

```powershell
.\scripts\New-DemoPassword.ps1   # random password, written only to .env (MYOWN_DEMO_USER_PASSWORD), never printed
# then set MYOWN_DEMO_MODE=1 and MYOWN_AI_MODE=replay in .env
docker compose -f compose.yaml -f compose.aihub.yaml up --build -d
```

At every start `docker/demo-start.sh` creates or updates the `demo` account from the environment, and disables it when demo mode is off. Give visitors the user `demo` and the password from `.env`. Never publish the `_SYSTEM` password; set your own in `MYOWN_DEMO_PASSWORD` before the first start.

## Tests

| Suite | Script | IRIS 2026.2 (local) | Build 154 (IRIS for Health) |
|---|---|---|---|
| Portal smoke | `scripts/Test-MyOwn.ps1` | pass | pass |
| SysAdmin API mutations | `scripts/Test-SysAdminMutations.ps1` | pass | pass |
| Agent REST scenarios | `scripts/Test-Agents.ps1` | 24 pass, 1 optional skip | 24 pass, 1 optional skip |
| Adversarial corpus (92 hostile model outputs) | `scripts/Test-AgentAdversarial.ps1` | 92 / 92 | 92 / 92 |
| Core and interoperability smoke | `scripts/Test-AgentSmoke.ps1` | 14 / 14, 19 / 19 | 14 / 14, 19 / 19 |
| AI Hub engine (replay: timeouts, invalid JSON, provider error, budget, kill switch, blocked write tool, ToolSet Exclude, query tools, fixtures) | `scripts/Test-Agents-AIHub.ps1` | skipped (no `%AI`) | 20 / 20 |
| Agents UI (isolated browser) | `scripts/Test-AgentsUI.ps1` | 15 / 15 | 15 / 15 |
| Viewer role without `%All` (screens allowed, administration refused) | `scripts/Test-PortalViewer.ps1` | 5 / 5 | 5 / 5 |
| Public demo (synthetic targets, refusals, reset, rate limit; REST checks with the real demo account) | `scripts/Test-AgentDemo.ps1` | 8 / 8 in-IRIS (REST part needs demo mode) | 16 / 16 with `MYOWN_DEMO_MODE=1` |
| Secret scan (tracked and staged files) | `scripts/Test-AgentSecretScan.ps1` | pass | — |

Reports are written to `test-results/`. The full regression passed on a fresh build 154 container on its first run.

## Limitations

- **Live calls are fragile on a free tier.** Gemini (`gemini-3.8-flash`, free tier) answered in 11 to 18 s when available, but it also returned HTTP 429 (quota) and 503 ("high demand"). The `%AI` provider retries those internally, so they often look like a slow provider. The portal stops waiting at its own deadline and the Rules engine decides, with the badge `Rules (provider_timeout)` or `Rules (provider_error)`.
- Only Gemini was tested. OpenAI, Anthropic and Bedrock go through the same `%AI.Provider` code path but have not been run.
- Only the IRIS for Health edition of build 154 was tested; the IRIS edition image was not available here.
- Some replay fixtures come from equivalent rather than identical contexts (see [Demo mode](#demo-mode)).
- Agent audit records become visible in the audit log about a minute after the event (IRIS writes its audit buffer periodically).
- The portal has no audit viewer yet, so there is no "agent events only" filter.
- The online demo is not deployed yet. The demo account exists only where `MYOWN_DEMO_MODE=1` and a password are set.
- A viewer (`MyOwnViewer`) cannot file an access request: the privilege delta is read through SysAdmin API v2 with the requester's own credentials, and that API refuses a viewer even its own account (it needs `%Admin_Secure`, which a read-only role should not have). The portal answers `ACCESS_REQUEST_NEEDS_SECURITY_READ` and the Access tab explains it; administrators file requests.
- The demo rate limit uses the client address seen by IRIS; behind a reverse proxy all visitors share one address.

## AI Hub experience

What worked well:

- `%AI.Agent`, sessions and `GetStats()` gave a working agent loop quickly; per-session token statistics feed the ledger.
- ToolSets declared in XML, and authorization and audit policies attached to the tool manager, made "read-only tools" enforceable: a denied tool is logged through `%LogDenial` and never runs.
- `ToolMgr.ExecuteTool` runs a tool through the same policies without a model, which made an offline replay mode and policy tests possible.

What was hard:

- There is no structured-output API in ObjectScript, so the JSON schema is requested in the prompt and enforced by our own Validator.
- The session `timeout_ms` does not interrupt a provider call in progress; the portal runs each decision in a separate job and stops it at its own deadline.
- Provider options pass through `extra_params` at the top level of the request; Gemini rejected a native `generationConfig` and accepted `reasoning_effort`.
- The provider retries 429 and 503 internally before reporting them, which hides the cause unless the `%AI` trace log is enabled.
- `ListModels()` reports zero pricing, so cost needs a local price table.

IRIS Agentic Dev (MCP server `iris-agentic-dev`) was used to compile classes, run SQL and read the `%AI` signatures on the build 154 container. Details in [docs/AI-HUB-NOTES.md](docs/AI-HUB-NOTES.md).

## The portal underneath

The agent workflow sits on MyOwn Portal, built for the earlier *Build Your Own Management Portal* contest: system overview and metrics, an AI Instance Monitor (Ideas Portal [DPI-I-512](https://ideas.intersystems.com/ideas/DPI-I-512)), users, roles and permissions, web applications, tasks, logs and certificates, all through the official SysAdmin API v2 where an endpoint exists. See [docs/REFERENCE.md](docs/REFERENCE.md).

## Built with AI assistance

> **[TODO Murilo: escrever com suas palavras]**
>
> 1. Which decisions did I make (design, safety model, scope)?
> 2. What did the AI assistants implement?
> 3. What did I change or reject from what they produced?

## Team

- Murilo Przybyloviecz — **[TODO: Developer Community profile link and role]**
- Andre Larsen Barbosa — **[TODO: Developer Community profile link and role]**

## License

[MIT](LICENSE)

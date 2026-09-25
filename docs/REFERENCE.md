# MyOwn Portal — Reference

This document has the full detail behind the [Quick Start](../README.md#quick-start) in the main README: how MyOwn Portal authenticates, every installation step for both paths, the complete API reference, and troubleshooting.

## How it works, in plain terms

MyOwn Portal is **not** a separate product with its own list of users and passwords. It is a small extension installed on top of an InterSystems IRIS instance. When someone signs in to MyOwn Portal, IRIS itself checks the username and password — the same native login IRIS already uses for its own Management Portal (`Security.Users`). MyOwn Portal never stores, sees on disk, or transmits that password anywhere else; it just asks IRIS "is this login valid, and what can this account see?" on every request.

Two consequences follow from that design:

- **There is no separate account to create.** Whoever installs MyOwn Portal signs in with an IRIS account that already exists (or a new one created the normal way, through IRIS itself).
- **What each person sees depends on the IRIS instance MyOwn Portal was installed on.** A fresh, empty IRIS (like the one the Docker option below creates) has no real data in it yet. An existing IRIS that someone already uses at work shows that instance's real users, roles, tasks, and logs.

This is why there are two different ways to run MyOwn Portal, described below. Pick the one that matches what the person actually wants to do.

| | Path A — Docker (try it out) | Path B — Install into an existing IRIS (real use) |
|---|---|---|
| What it shows | A brand-new, empty IRIS. Only demo data. | The real IRIS instance the person already has — their real users, roles, tasks, logs. |
| Who can sign in | Only `_SYSTEM`, with a password you choose. | `_SYSTEM`, or the person's own everyday IRIS account, once it is given permission (one-time step, explained below). |
| What must already be installed | Docker Desktop. Nothing else. | InterSystems IRIS or IRIS for Health (Community Edition or higher), already installed and running. |
| Good for | Quickly seeing what MyOwn Portal looks like and does, with zero setup on a real system. | Actually using MyOwn Portal day to day, on the IRIS instance someone already manages. |

## What needs to be installed on the computer

**Path A (Docker, just to try it):**

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (Windows, macOS, or Linux). That is the only requirement — MyOwn Portal's own IRIS, database, and web server are all built and started inside the container automatically. No IRIS installation, no Node.js, nothing else to set up by hand.

**Path B (installing into an IRIS the person already has):**

- InterSystems IRIS Community Edition or IRIS for Health Community Edition, **version 2024.1 or newer**, already installed and running on that computer (native Vector Search and `%Vector` properties require 2024.1+).
- Windows with administrator rights on that machine, to restart the private IRIS web server after installing the frontend files. (The scripts below are written for Windows/PowerShell, matching a typical local IRIS for Windows install.)
- Node.js 20+ to build the React frontend — **or**, if Node.js should not be installed system-wide, the two no-install helper scripts included in the project (`install-node-local.bat` and `build-frontend.bat`) download a local, admin-rights-free copy of Node.js just for the build.
- Optionally, InterSystems Package Manager (IPM/ZPM) 0.10.x, if installing through IPM rather than the manual scripts.

Nothing else needs to be pre-installed for either path.

## Path A — Try it in Docker (no IRIS installation needed)

1. Install Docker Desktop and make sure it is running.
2. Get the project files (clone the repository, or download and unzip it).
3. Open a terminal in the project folder and run:

   ```shell
   docker compose up --build -d
   ```

   The first run downloads the IRIS Community Edition image, builds MyOwn Portal into it, creates the `MYOWN` namespace, seeds the demo health patterns, and starts everything. This takes a few minutes; later runs are fast.
4. Open a browser at `http://localhost:52774/myown/index.html`.
5. Sign in with:
   - Username: `_SYSTEM`
   - Password: the value of `MYOWN_DEMO_PASSWORD` (default `ChangeMe2026!`).

   Changing this password is **optional for a quick local test** — `compose.yaml` already falls back to `ChangeMe2026!` on its own (`${MYOWN_DEMO_PASSWORD:-ChangeMe2026!}`), so nothing needs to be configured just to try the app on your own machine. It is **recommended for anything beyond that** — for example if the container will stay running, be reachable from other machines, or be shown to someone else. To set a different password, copy `.env.example` to `.env`, change `MYOWN_DEMO_PASSWORD` there, and run `docker compose up --build -d` again. That value only ever exists in the local `.env` file (which is not committed to the repository); it is never hardcoded in the project's source code, so nobody's real password ends up in the code either way.
6. To stop it: `docker compose down`. To also delete all data created inside the container and start fully fresh next time: `docker compose down -v`.

Because this container is a brand-new IRIS, it starts with no real users, roles, or history beyond what the installer itself creates for the demo. That is expected — this path is for evaluating the interface quickly, not for day-to-day use. For that, use Path B.

## Path B — Install into an IRIS you already use

This is the path for someone who wants MyOwn Portal to show their real instance — their real users, roles, tasks, and logs — and to sign in with the same account they already use.

### Step 1 — Create the namespace (one time, about 30 seconds)

In the native IRIS Management Portal, go to System Administration → Configuration → System Configuration → Namespaces → New Namespace, and create one named `MYOWN` (the default database settings are fine). Skip this if that namespace already exists.

### Step 2 — Run the installer script

Open an elevated PowerShell window in the project folder and run:

```powershell
.\scripts\Install-All.ps1
```

(This is the same script `Instalar.bat` runs for the local-IRIS path — running it directly is only useful to pass explicit parameters, e.g. `-IrisInstallDir`, `-Instance`, or `-Namespace`.)

This one script does everything:

1. looks for a local IRIS installation (`C:\InterSystems\IRIS`, `D:\InterSystems\IRIS`, and any other subfolder under `C:\InterSystems`/`D:\InterSystems` that has `bin\iris.exe`) — pass `-IrisInstallDir` to point at a different location;
2. asks which namespace to install into (press Enter for the default, `MYOWN`, or type the name of a namespace that already exists) and confirms it exists — if it does not, the script stops and explains exactly where to create it (see Step 1 above); just run it again afterward;
3. builds the React frontend, downloading a local, admin-rights-free copy of Node.js first if none is found on `PATH` (or run `install-node-local.bat` then `build-frontend.bat` by hand first, if preferred);
4. deploys the built files to `<IRIS installation>/CSP/myown`, adds the MyOwn Portal rules to the private web server's configuration, and restarts it;
5. installs the backend automatically, over IRIS's built-in Atelier REST API (the same mechanism the VS Code ObjectScript extension uses) — no terminal to paste into. It asks once, right there, for the IRIS username and password for that step; they are used only in memory, for those HTTP calls, and are never written to disk, logged, or sent anywhere else;
6. opens `http://localhost:52773/myown/index.html`.

If anything cannot be done safely without a person's judgment (most commonly, the namespace not existing yet), the script stops and explains exactly what to do instead of guessing.

Alternatively, the whole project (backend and frontend files together) can be installed as one IPM package instead of Step 2 — see [Installing through IPM](#installing-through-ipm-alternative-to-step-2) below.

### Step 3 — Open it

Go to `http://localhost:52773/myown/index.html` (adjust the port if that IRIS instance uses a different one). Node.js does not need to be running for this — only IRIS itself.

## Signing in — which account to use

Anyone can sign in to MyOwn Portal with **any account that already exists in that IRIS instance**, as long as that account has been given permission to use MyOwn Portal. There is no separate password to remember and no separate account to create — it is literally the same username and password as the native IRIS Management Portal for that instance.

**`_SYSTEM` always works out of the box.** It already holds full administrative rights (`%All`), so `Installer.Setup()` does not need to grant it anything extra.

**Any other account — including someone's own everyday work account — needs to be granted a MyOwn Portal role once.** `Installer.Setup()` created two roles for exactly this purpose:

- `MyOwnViewer` — read-only access to MyOwn Portal (can look, cannot change anything).
- `MyOwnAdministrator` — full access, including the sensitive pages (Permissions, Security, Tasks) and administrative actions.

To grant one of these to an account:

1. Open the native IRIS Management Portal (`http://localhost:52773/csp/sys/UtilHome.csp`) and sign in with an account that has security administration rights (typically `_SYSTEM`).
2. Go to **System Administration → Security → Users**.
3. Click the username that should be able to use MyOwn Portal (or create a new user first, the normal IRIS way, if needed).
4. Open the **Roles** tab for that user.
5. Add `MyOwnViewer` or `MyOwnAdministrator` from the list of available roles, and save.
6. That account can now sign in to MyOwn Portal directly at `http://localhost:52773/myown/index.html`, with its own existing password — nothing else changes about that account, and it gains no extra access anywhere outside `/myown/api`.

The same thing can be done from a terminal instead, for example:

```objectscript
Set user = ##class(Security.Users).%OpenId("someone.else")
Do user.Roles.Insert("MyOwnAdministrator")
Do user.%Save()
```

A note on why this is a separate, explicit step rather than automatic: MyOwn Portal only grants extra, elevated access (read or write to the IRIS system database) to a signed-in account for the duration of a MyOwn Portal request, and only to accounts that were deliberately given one of the two roles above. Nobody's account gains any new capability just by MyOwn Portal being installed — someone with security rights has to choose to grant it, the same way any other IRIS application permission is granted.

### Installing through IPM (alternative to Step 2)

The project is also an installable InterSystems Package Manager module named `myown-portal`. IPM 0.10.x or newer is recommended, on IRIS 2024.1+.

To prepare the package after changing the React application:

```powershell
.\scripts\Build-IPMPackage.ps1
```

Then, from an IRIS terminal in the `MYOWN` namespace:

```objectscript
zn "MYOWN"
zpm "load https://github.com/<your-account>/myown-portal"
// or, from a local clone:
zpm "load /path/to/myown-portal"
```

Once the package is published in an IPM registry, the equivalent command is:

```objectscript
zpm "install myown-portal"
```

This imports and compiles all `MyOwn.*` classes, copies the compiled React application into the IRIS CSP directory, and runs `MyOwn.Installer.Setup()` — so it covers Step 1 above (backend) and part of Step 2 (frontend files) in one command. On a private web server, still apply `deploy/httpd-myown.conf` once and restart that web server so `/myown/` is served as static content while `/myown/api/` remains handled by IRIS.

## A tour of the app

Once signed in, everything lives behind a single sidebar with up to six tabs. A `MyOwnViewer` account sees four of them (Overview, Applications & APIs, Tasks, Logs); a `MyOwnAdministrator` account (or `_SYSTEM`) sees all six, including the two sensitive ones (Permissions, Security).

- **Overview** — the landing page. Four summary cards (CPU, memory, disk usage, running processes), an instance-information panel (name, version, uptime, status), a Quick Access shortcut panel to the other tabs, an automatic health-score card with a plain-language diagnosis and recommendation (the Embedded Python + Vector Search feature described below), and a live table of running IRIS processes that refreshes every 15 seconds.
- **Permissions** *(administrators only)* — Users, Roles, and Resources, each as a searchable table. Clicking a user or role opens its directly assigned and effective roles and permissions. An administrator can assign or remove a role from a user, with a confirmation step before the change is applied.
- **Applications & APIs** — every IRIS web application and REST service, filterable and searchable, with status, namespace, type, and authentication method. Clicking a row shows its full configuration, and an administrator can enable or disable it. Administrators also get a bounded REST API Explorer to send test requests to approved endpoints and browse the OpenAPI specification.
- **Security** *(administrators only)* — a read-only inventory of certificates (with expiration warnings), OAuth configurations, Secure Wallet items, and credential references. Actual secret values, passwords, tokens, and private keys are never exposed — only metadata.
- **Tasks** — the native IRIS Task Manager's scheduled tasks, searchable and filterable, with status, next run time, and last result. An administrator can run a task immediately, or suspend and resume it, each with a confirmation step.
- **Logs** — a sanitized, paginated view of the IRIS system log (`messages.log`), searchable and filterable by severity, source, and time range, with a note that potentially sensitive log content is withheld by the backend before it ever reaches the browser.

## Architecture

```text
Browser
  ├─ /myown/        compiled React, CSS, and JavaScript
  └─ /myown/api/    authenticated MyOwn.REST endpoints
                              │
                              ├─ MyOwn.Service.*
                              ├─ Embedded Python scoring
                              ├─ VECTOR(DOUBLE,6) health patterns
                              ├─ native Security.* APIs
                              └─ native IRIS system APIs
```

The frontend never connects directly to system globals or databases. Administrative data and actions pass through the ObjectScript service layer. API responses do not expose passwords, tokens, private keys, wallet values, or ObjectScript stack traces.

## Requirements (reference)

- InterSystems IRIS Community Edition or IRIS for Health Community Edition, **version 2024.1 or newer** (native Vector Search and `%Vector` properties are required).
- An IRIS namespace named `MYOWN`.
- Node.js 20 or newer for frontend development and production builds (or the no-install helper scripts described above).
- npm or pnpm.
- Administrator privileges when updating the private IRIS web server configuration.
- Docker Desktop or another Docker Compose implementation for the container option.

The default examples use:

- IRIS instance: `IRIS`
- IRIS web port: `52773`
- namespace: `MYOWN`
- project URL: `http://localhost:52773/myown/index.html`

## Project structure

```text
deploy/                  private web server configuration fragment
frontend/                React, TypeScript, and Vite source
scripts/                 installation and smoke-test scripts
src/objectscript/        ObjectScript REST and service classes
module.xml               IPM/ZPM package manifest
web/                      compiled frontend included in the IPM package
docker/                   IRIS namespace and IPM initialization files
Dockerfile                reproducible IRIS Community Edition image
compose.yaml              local container orchestration
```

## What the installer creates

Running `MyOwn.Installer.Setup()` (directly, through IPM, or inside the Docker build) creates or updates:

- the `/myown/api` REST application;
- the `MyOwn.View` and `MyOwn.Manage` resources;
- the `MyOwnViewer` and `MyOwnAdministrator` roles (see [Signing in](#signing-in--which-account-to-use));
- the `MyOwnSystemRead` and `MyOwnSystemAdmin` application roles, described below;
- the `MyOwn/Administration/Change` audit event;
- six initial health patterns stored as native IRIS vectors;
- the `MyOwn Portal health snapshot` demonstration task in the `MYOWN` namespace.

Most administration data lives in the `%SYS` namespace, which ordinary users cannot enter. The installer sets `MatchRoles` on the `/myown/api` web application so that:

| A user holding | receives, only while calling `/myown/api` | Grants |
|---|---|---|
| `MyOwnViewer` | `MyOwnSystemRead` | `%DB_IRISSYS:R` |
| `MyOwnAdministrator` | `MyOwnSystemAdmin` | `%DB_IRISSYS:RW` |

These roles are never assigned to the user account itself, so they do not apply in a terminal or in any other application — they only take effect for the duration of a MyOwn Portal request. Users that already hold `%All` (for example `_SYSTEM`) do not need this mapping. Authentication is always mandatory; users without `MyOwn.View` receive HTTP 403.

## Development

```shell
cd frontend
npm install
npm run dev
```

Vite serves `http://localhost:5173/myown/` and proxies `/myown/api` to the local IRIS web server. Saving an ObjectScript class in the configured VS Code workspace imports and compiles it in `MYOWN`.

Useful frontend commands:

```shell
npm run typecheck
npm run build
npm run preview
```

To validate the repository's Docker files without starting a container:

```powershell
.\scripts\Test-DockerConfig.ps1
```

## Tests

Run the production smoke tests without credentials:

```powershell
.\scripts\Test-MyOwn.ps1
```

This verifies the production HTML, compiled JavaScript and CSS, and anonymous API rejection. To include authenticated health, session, and role checks:

```powershell
$credential = Get-Credential
.\scripts\Test-MyOwn.ps1 -Credential $credential
```

## Main API endpoints

| Method | Endpoint | Purpose |
|---|---|---|
| GET | `/health` | Instance and API health |
| GET | `/session` | Current user and portal access level |
| GET | `/system/summary` | IRIS and host summary |
| GET | `/system/health-report` | Embedded Python score and closest IRIS vector health pattern |
| GET | `/system/processes` | Active process inventory |
| GET | `/permissions/users` | User inventory |
| GET | `/permissions/roles` | Role inventory |
| GET | `/permissions/resources` | Resource inventory |
| GET | `/applications` | Web application inventory |
| POST | `/applications/state` | Enable or disable an allowed application |
| POST | `/apis/test` | Execute an approved local API request |
| GET | `/openapi` | OpenAPI 3 document |
| GET | `/security/summary` | Sanitized security summary |
| GET | `/tasks` | Task Manager inventory |
| POST | `/tasks/action` | Run, suspend, or resume an allowed task |
| GET | `/logs` | Sanitized recent IRIS log entries |

All endpoints are below `/myown/api`.

## Instance health analysis

The Overview page sends live disk, database, lock, alert, and process metrics to a small, explainable method written in Embedded Python. It returns a score from 0 to 100, a `Healthy`, `Attention`, or `Critical` status, and a short English summary.

The same normalized metrics form a six-dimensional vector. IRIS stores baseline vectors in `MyOwn.HealthPattern` and compares them with `VECTOR_COSINE`. The closest pattern supplies the diagnosis, similarity percentage, and recommended action. The installer seeds healthy, disk-pressure, database-capacity, lock-contention, serious-alert, and process-pressure patterns automatically.

## Design note

MyOwn Portal calls the native IRIS administration classes (`Security.*`, `%SYS.Task`, `%Wallet.*`, `%SYS.X509Credentials`, and the OAuth 2.0 classes) from its own ObjectScript REST layer at `/myown/api`, instead of calling the REST endpoints described in the contest's [sysadmin API specification](https://github.com/intersystems-community/sysadmin-api-specification). The portal adds its own authorization, sanitization, and auditing on top of those classes.

## Security model

- Password authentication is handled by IRIS. MyOwn Portal never stores or forwards a password anywhere of its own.
- Cross-origin requests are not accepted: the frontend and the API share one origin, and Vite proxies the API during development.
- Browser credentials remain only in page memory and are cleared on sign-out or reload.
- The server validates permissions independently of the frontend.
- Mutating operations require `MyOwn.Manage` plus the relevant native IRIS resource.
- Application and task changes are restricted to the project's allowed scope.
- Administrative changes create native IRIS audit entries.
- API Explorer destinations, methods, headers, body size, redirects, and response size are bounded.
- No credential of any kind is hardcoded in the project's source code. The one password MyOwn Portal's own Docker build sets (`MYOWN_DEMO_PASSWORD`) is supplied at build time from a git-ignored `.env` file, defaults to a clearly labeled local-demo value, and only ever applies inside that person's own fresh, isolated container.
- Production deployments should enable HTTPS before accepting credentials over a network.

## Troubleshooting

- **Portal returns 404:** confirm that the React build exists under `<IRIS installation>/CSP/myown` and that `deploy/httpd-myown.conf` was added to `httpd-local.conf`.
- **API returns 401:** sign in with a valid IRIS account.
- **API returns 403:** assign `MyOwnViewer` or `MyOwnAdministrator` to that account (see [Signing in](#signing-in--which-account-to-use)) and, if it was just installed, rerun `MyOwn.Installer.Setup()`.
- **Pages fail for users that are not administrators of IRIS:** rerun `MyOwn.Installer.Setup()` so that the `MatchRoles` mapping on `/myown/api` is created, then sign in again.
- **The Security page shows a warning about an inventory:** that category could not be read and its items are missing from the list; the message names the cause (for example, a missing `%Admin_Wallet` privilege).
- **Frontend shows old files:** rebuild, redeploy, and clear the browser cache.
- **`Install-All.ps1` (or `Instalar.bat`) stops because the namespace does not exist:** the namespace typed at the prompt (or passed with `-Namespace`, default `MYOWN`) does not exist yet on that IRIS instance — create it once in the Management Portal (see [Path B, Step 1](#step-1--create-the-namespace-one-time-about-30-seconds)) and run the installer again.
- **ObjectScript changes made later in VS Code are missing:** VS Code is optional (used for ongoing development, not for the initial install) — confirm it is connected to `MYOWN` and compile-on-save succeeded, or rerun `Instalar.bat` / `Install-All.ps1`, which reloads and recompiles every class under `src/objectscript` from disk.
- **`npm`/`node` is not recognized:** Node.js is not on `PATH`. Either install Node.js 20+ normally, or use the admin-rights-free helper scripts described in [What needs to be installed on the computer](#what-needs-to-be-installed-on-the-computer).
- **`Instalar.bat` opens and closes immediately, nothing happens:** this is almost always the administrator-permission prompt (UAC) being declined, blocked, or opening behind another window — most common when the project was downloaded as a ZIP from GitHub (rather than `git clone`), since Windows marks those files as coming from the internet and SmartScreen can silently interfere with the elevation request. Right-click `Instalar.bat` → Properties → check "Unblock" (if present) → OK, then try again; or just right-click `Instalar.bat` → "Run as administrator" directly, which skips the automatic elevation step entirely.

# MyOwn Portal

MyOwn Portal is a compact, English-language administration interface for InterSystems IRIS and IRIS for Health. It was created for the **InterSystems Programming Contest: Build Your Own Management Portal**.

The browser application uses React and TypeScript. The REST backend, authorization, auditing, and access to IRIS administration data are implemented in ObjectScript. Administrative inventories require the official SysAdmin API v2. Vite and Node.js are development and build tools only; the production React bundle is served by the private IRIS web server.

**Official API compliance.** Processes, users, roles, resources, tasks, web applications, X.509 credentials, OAuth configuration, and Secure Wallet metadata are all read and written through the official `/api/admin/v2/...` endpoints — not through direct calls to native classes. Two areas intentionally stay outside the SysAdmin API because it has no equivalent endpoint for them: host-level CPU/memory/disk metrics (Overview) and general system logging (`messages.log`, the Logs page). This isn't an oversight — other teams who built against the same specification for this same contest independently hit and documented the same two gaps. See [SysAdmin API integration](https://github.com/muriloprzy-code/Portal-Iris/blob/master/docs/REFERENCE.md#sysadmin-api-integration) and the [Design note](https://github.com/muriloprzy-code/Portal-Iris/blob/master/docs/REFERENCE.md#design-note) in the reference doc for the full detail, including which native `%Admin_*` privileges each area requires.

**Automated tests.** `scripts/Test-MyOwn.ps1` runs a full smoke-test suite against a running instance, and `scripts/Test-SysAdminMutations.ps1` exercises real SysAdmin API v2 mutations (create/assign/remove/delete) end to end, cleaning up after itself. See [Tests](https://github.com/muriloprzy-code/Portal-Iris/blob/master/docs/REFERENCE.md#tests) in the reference doc.

Read the write-up on the InterSystems Developer Community: [English](https://community.intersystems.com/post/myown-portal-compact-management-portal-intersystems-iris) · [Português](https://pt.community.intersystems.com/post/myown-portal-um-portal-de-gerenciamento-compacto-para-o-intersystems-iris)

**Online demo (temporary, for contest evaluation):** [https://163-176-71-47.sslip.io/myown/index.html](https://163-176-71-47.sslip.io/myown/index.html) — sign in with `_SYSTEM` / `ChangeMe2026!`. Hosted on a free Oracle Cloud Always Free instance with a free Let's Encrypt HTTPS certificate; every page is pre-populated with sample data to review. This instance is shared and temporary, kept online only for the duration of the contest.

## Quick Start

MyOwn Portal has no login of its own — it authenticates directly against the IRIS instance it is installed on. See [docs/REFERENCE.md](https://github.com/muriloprzy-code/Portal-Iris/blob/master/docs/REFERENCE.md#how-it-works-in-plain-terms) for the full explanation.

### The easy way: one double-click

Double-click **`Instalar.bat`** at the project root. It figures out the rest on its own:

- **Docker path:** if Docker Desktop is installed, it builds and starts the demo container and opens `http://localhost:52774/myown/index.html` for you. **Docker Desktop needs to already be open before you run the installer** — if it isn't running yet, start it first, wait for it to finish starting up, then run `Instalar.bat`.
- **Local IRIS path:** if you already have IRIS installed locally instead, it asks which namespace to install into (press Enter for the default, `MYOWN`, or type the name of a namespace you already use), builds the frontend (downloading a local copy of Node.js first if needed, no admin rights required for that part), deploys the files, restarts the private web server, and installs the backend — fully automatically, over IRIS's own Atelier REST API, no terminal to paste into. It asks once for your IRIS username and password for that last step; they are used only in memory and never written to disk. It then opens `http://localhost:52773/myown/index.html`.
- If both Docker and a local IRIS are found, it asks once which one you want.

It will ask Windows for administrator permission once (needed only to restart the IRIS private web server on the local-install path) — approve that, and everything else runs by itself. The one thing it cannot do for you is the one-time creation of the namespace if it does not already exist on your IRIS instance; if that is the case, it stops and tells you exactly where to click (Management Portal → System Administration → Configuration → System Configuration → Namespaces → New Namespace) — then just run `Instalar.bat` again.

<details>
<summary>Prefer to run the commands yourself, or run outside Windows? (click to expand)</summary>

<br>

**Docker, by hand:**

Make sure Docker Desktop is already open, then:

```shell
docker compose up --build -d
```

Open `http://localhost:52774/myown/index.html` and sign in with `_SYSTEM` / `ChangeMe2026!`. This password is intentionally provided as a convenient default for local demonstration only. The container uses its own isolated IRIS data volume and does not modify an IRIS instance installed directly on the host. Change the password before exposing the container to another computer or network; see [docs/REFERENCE.md](https://github.com/muriloprzy-code/Portal-Iris/blob/master/docs/REFERENCE.md#path-a--try-it-in-docker-no-iris-installation-needed).

**Local IRIS, by hand:**

1. If the namespace you want to use does not exist yet, create it once (Management Portal → System Administration → Configuration → System Configuration → Namespaces → New Namespace). The installer's default is `MYOWN`, but any existing namespace works — it is only a name.
2. Build the frontend:
   ```powershell
   cd frontend
   npm install
   npm run build
   cd ..
   ```
   No Node.js on your `PATH`? Run `install-node-local.bat` once first (downloads a local copy of Node.js, no admin rights needed), then repeat the commands above.
3. From the project root, run the installer script directly (this is the same script `Instalar.bat` runs for the local-IRIS path — running it yourself is only useful if you want to pass explicit parameters, e.g. `-IrisInstallDir`, `-Instance`, or `-Namespace`):
   ```powershell
   .\scripts\Install-All.ps1
   ```
   It deploys the frontend you just built, restarts the private web server, then asks which namespace to use and for your IRIS username/password once — used only for that step, never stored — and installs the backend automatically over IRIS's built-in Atelier REST API (the same mechanism the VS Code ObjectScript extension uses). The exact HTTP calls it makes are all in [scripts/Install-All.ps1](https://github.com/muriloprzy-code/Portal-Iris/blob/master/scripts/Install-All.ps1), if you want to see or adapt them.
4. Open `http://localhost:52773/myown/index.html` and sign in with `_SYSTEM` — or grant your own account the `MyOwnAdministrator` role first, a one-time step explained in [docs/REFERENCE.md](https://github.com/muriloprzy-code/Portal-Iris/blob/master/docs/REFERENCE.md#signing-in--which-account-to-use).

</details>

Everything else — architecture, every install detail, the API reference, and troubleshooting — is in **[docs/REFERENCE.md](https://github.com/muriloprzy-code/Portal-Iris/blob/master/docs/REFERENCE.md)** in this repository.

## Features

- System overview, operating-system metrics, and active IRIS processes.
- Embedded Python health scoring with a concise instance-health summary.
- Native IRIS Vector Search against stored health patterns and recommendations.
- Users, roles, resources, effective permissions, and controlled role assignment.
- Web application and REST API inventory with protected enable/disable actions.
- A bounded local REST API Explorer with an OpenAPI view.
- Sanitized certificate, OAuth, Secure Wallet, and credential-reference metadata.
- IRIS Task Manager inventory with protected Run, Suspend, and Resume actions.
- Sanitized `messages.log` browsing with search, filters, pagination, and details.
- Native IRIS role-based access control and audit events for state changes.
- Official SysAdmin API v2 integration for processes, permissions, tasks, web applications, X.509, OAuth, and Secure Wallet metadata, with automatic capability detection. Host metrics and system logs stay native, since the API has no endpoint for either.
- A demonstration Task Manager task (`MyOwn Portal health snapshot`) so that Run, Suspend, and Resume can be tried on a fresh instance.
- Responsive English user interface.

## Contest technology bonuses

- **Embedded Python:** the instance health score and the host memory and disk metrics are computed in `Language = python` methods.
- **Vector Search:** health patterns are stored in a `%Vector` property and matched with `VECTOR_COSINE`.
- **Docker:** `Dockerfile` and `compose.yaml` build and run the portal on IRIS Community Edition.
- **IPM package:** `module.xml` defines the `myown-portal` module.
- **Online demo (temporary, for contest evaluation):** [https://163-176-71-47.sslip.io/myown/index.html](https://163-176-71-47.sslip.io/myown/index.html) — sign in with `_SYSTEM` / `ChangeMe2026!`.
- **Embedded Python bug report:** found and reported an upstream Embedded Python bug — a `[Language = python]` ClassMethod declared to return `%BigInt` silently returns `-1` for any Python `int` of `2**63` or greater (the same value returned as `%String` round-trips correctly), instead of the correct value or an error. See [python-bugreports issue #19](https://github.com/intersystems-community/python-bugreports/issues/19) for the full report and a minimal reproduction.

## License

[MIT](https://github.com/muriloprzy-code/Portal-Iris/blob/master/LICENSE)

## Team

- [Murilo Przybyloviecz](https://community.intersystems.com/user/murilo-przyby) — Developer Community profile
- [Andre Larsen Barbosa](https://community.intersystems.com/user/andre-larsenbarbosa) — Developer Community profile

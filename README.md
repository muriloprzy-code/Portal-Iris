# Meu Portal

Meu Portal is a compact, English-language administration interface for InterSystems IRIS and IRIS for Health. It was created for the **InterSystems Programming Contest: Build Your Own Management Portal**.

The browser application uses React and TypeScript. The REST backend, authorization, auditing, and access to IRIS administration data are implemented in ObjectScript. Vite and Node.js are development and build tools only; the production React bundle is served by the private IRIS web server.

## Quick Start

Meu Portal has no login of its own — it authenticates directly against the IRIS instance it is installed on. Full explanation in [docs/REFERENCE.md](docs/REFERENCE.md#how-it-works-in-plain-terms).

### Try it now

No IRIS installation needed — just Docker Desktop:

```shell
docker compose up --build -d
```

Open `http://localhost:52774/meuportal/index.html` and sign in with `_SYSTEM` / `ChangeMe2026!` (the default demo password — see [docs/REFERENCE.md](docs/REFERENCE.md#path-a--try-it-in-docker-no-iris-installation-needed) to change it).

This spins up a fresh, disposable IRIS just for the demo — the fastest way to see Meu Portal working, with zero risk to any IRIS instance you already have.

<details>
<summary><strong>Want to run it for real, on an IRIS you already use?</strong> (click to expand)</summary>

<br>

This installs Meu Portal directly on your own IRIS instance — no Docker — so it shows your real users, roles, tasks, and logs, and you sign in with your own account.

1. Create the `MEUPORTAL` namespace once, if it does not already exist (Management Portal → System Administration → Configuration → System Configuration → Namespaces → New Namespace).
2. From the project folder, run:
   ```powershell
   .\scripts\Install-MeuPortal.ps1
   ```
   It builds the frontend, deploys it, restarts the private web server, and opens an IRIS terminal with the backend command ready to paste — see [docs/REFERENCE.md](docs/REFERENCE.md#path-b--install-into-an-iris-you-already-use) for the full walkthrough.
3. Open `http://localhost:52773/meuportal/index.html` and sign in with `_SYSTEM` — or grant your own account the `MeuPortalAdministrator` role first, a one-time step explained in [docs/REFERENCE.md](docs/REFERENCE.md#signing-in--which-account-to-use).

</details>

Everything else — architecture, every install detail, the API reference, and troubleshooting — is in **[docs/REFERENCE.md](docs/REFERENCE.md)**.

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
- A demonstration Task Manager task (`Meu Portal health snapshot`) so that Run, Suspend, and Resume can be tried on a fresh instance.
- Responsive English user interface.

## Contest technology bonuses

- **Embedded Python:** the instance health score and the host memory and disk metrics are computed in `Language = python` methods.
- **Vector Search:** health patterns are stored in a `%Vector` property and matched with `VECTOR_COSINE`.
- **Docker:** `Dockerfile` and `compose.yaml` build and run the portal on IRIS Community Edition.
- **IPM package:** `module.xml` defines the `meu-portal` module.

## License

[MIT](LICENSE)

## Team

- [Murilo Przybyloviecz](https://community.intersystems.com/user/murilo-przyby) — Developer Community profile
- [Andre Larsen Barbosa](https://community.intersystems.com/user/andre-larsenbarbosa) — Developer Community profile

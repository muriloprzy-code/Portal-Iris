# Publishing checklist: `myown-portal` 1.1.0

No publication step has been done yet (the only checked item is a local test). Every step that sends something outside this machine is done by the maintainer, with their own accounts; no credential is needed for the steps run by the scripts.

## Before tagging

- [ ] `module.xml`: `<Name>myown-portal</Name>`, `<Version>1.1.0</Version>` (the registry has 1.0.2 and 1.0.3; a version can be published only once).
- [ ] Frontend built into `web/`: `.\scripts\Build-IPMPackage.ps1`, then `.\scripts\Test-IPMPackage.ps1` (checks the resources, the test scope, the preloaded `MyOwn.Bootstrap`, the AI Hub sources and the built assets).
- [x] One module, no test classes in the package, AI Hub engine compiled only where `%AI` exists, interoperability enabled before compilation: tested on build 154 on 2026-10-27 (install from the code in a new namespace, package, uninstall with the production running and reinstall from the package, twice; see `docs/PROGRESS.md`, T20).
- [ ] `.\scripts\Test-All.ps1 -BaseUrl http://localhost:52774 -Credential (Get-Credential _SYSTEM)` on a clean build 154 container: 0 failed.
- [ ] `.\scripts\Test-AgentSecretScan.ps1`: pass. `docs/README-AI-AGENTS-DRAFT.md` and `.env` are not committed.
- [ ] README links filled (online demo, video, article) or marked as pending.

## GitHub (`muriloprzy-code/Portal-Iris`)

```shell
git push origin master
git tag -a v1.1.0 -m "MyOwn Portal 1.1.0: AI agents in interoperability workflows"
git push origin v1.1.0
gh release create v1.1.0 --title "MyOwn Portal 1.1.0" --notes-file docs/RELEASE-NOTES-1.1.0.md
```

- [ ] The release carries only the source (GitHub attaches the archive). **Never attach or push the AI Hub image or an image built on it.**
- [x] `docs/RELEASE-NOTES-1.1.0.md` written (T21; the video, demo and article links still say "to be added before release"): what changed since 1.0.3, how to install (Docker with build 154, or `zpm install myown-portal`), known limitations.

## Open Exchange (openexchange.intersystems.com)

The community package registry (`pm.community.intersystems.com`) is fed from Open Exchange: an application with "Publish in Package Manager" turned on is packaged from the `module.xml` at the root of its GitHub repository when a new version is published there.

| Field | Value |
|---|---|
| Application name | MyOwn Portal |
| GitHub repository | https://github.com/muriloprzy-code/Portal-Iris |
| Publish in Package Manager | on |
| Package name | `myown-portal` (from `module.xml`) |
| Version | 1.1.0 (from `module.xml`; the release tag is `v1.1.0`) |
| License | MIT |
| Requirements | InterSystems IRIS or IRIS for Health 2024.1+ for the portal and the Rules engine; IRIS AI Hub build 2026.3.0AI.154.0 for the AI Hub engine (installed only where `%AI` exists) |
| Short description | Administration portal whose AI agent decides and proposes inside an interoperability production; a human confirms every change |
| Tags | AI, Interoperability, Docker, ZPM, Embedded Python, Vector Search |
| Links | online demo, video and Developer Community article (when ready) |
| Contest | InterSystems Programming Contest "AI Agents in Interoperability Workflows"; submit before 08/11/2026 23:59 EST |

- [ ] Publish the new version 1.1.0 on the application page and wait for the Open Exchange approval.
- [ ] Do not publish directly to the registry with `zpm "publish"`: that needs registry credentials and bypasses Open Exchange.

## After publication

```shell
curl -s https://pm.community.intersystems.com/packages/myown-portal
```

- [ ] The answer lists version 1.1.0.
- [ ] In a clean container (any IRIS or IRIS for Health 2024.1+ with IPM), in a new namespace: `zpm "install myown-portal"` succeeds, `/myown/index.html` opens, and the module lists no `MyOwn.Test` class. On build 154 the AI Hub engine (`MyOwn.AIHub.Engine`) is compiled too.
- [ ] `zpm "uninstall myown-portal"` and `zpm "install myown-portal"` again succeed.

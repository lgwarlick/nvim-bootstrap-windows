# Phase 06 - Integration, recovery, and rollback

## Status
Not Started

## Objective

Test full bootstrap execution, broken configurations, failed plugin installations, interrupted execution, and restoration of previous state.

## Dependencies
- Phase 01 Complete
- Phase 02 Complete
- Phase 03 Complete
- Phase 04 Complete
- Phase 05 Complete
- **Windows Sandbox enabled on the reference test device** (ADR-021). This is a one-time host change (Windows
  optional feature `Containers-DisposableClientVM`, plus a reboot), performed by the project owner or with their
  explicit approval. Confirmed supported on 2026-11-25: Windows 11 Pro build 26200, hypervisor running, 31.7 GB RAM,
  12 cores; feature currently Disabled.
- Tests that install, downgrade, or uninstall Neovim never run on the host (AGENTS.md safety rules).

## Scope

### Rollback implementation (ROLLBACK.md, ADR-020)
- `Restore-ConfigurationBackup`: move the failed run's files into the backup's `failed\` folder, copy the backup back,
  verify against the manifest, set `status: restored`. Idempotent, supports `-WhatIf`, and usable directly for manual
  recovery.
- `Restore-NeovimVersion` (FR-61): reinstall `previousNeovimVersion` in place; if WinGet cannot install the older
  version over the newer one, uninstall the newer Neovim and install the previous version, only after confirming
  WinGet still offers it (known issue 4). If it is not offered, uninstall nothing and fail.
- Wire rollback into `Invoke-NeovimBootstrap` exactly as in the ARCHITECTURE.md failure table, including exit code 2
  (rollback failed) with the backup and log paths printed.

### End-to-end behavior
- Full run, steps 0–8, on a fresh machine and on a machine with an existing user configuration.
- Rerun on a configured machine makes no changes (FR-70).
- Upgrade from an earlier release (FR-02): a fixture "previous release" with different pins is installed, then the
  current release is run over it.
- A `-WhatIf` run of every scenario changes nothing.
- Interrupted execution (FR-63): each backup manifest records when its run finished (`runCompleted`). At startup,
  if the newest backup belongs to a run that never finished, stop with exit 3, report the interrupted run and its
  backup path, and explain how to restore it with `Restore-ConfigurationBackup`.

### Recovery scenarios
Each scenario injects one failure and checks the restored state and the exit code:

| Scenario | Injected failure | Expected |
|---|---|---|
| Broken configuration | Deployed configuration fails to load in step 8 | Previous config and plugin data restored; exit 1 |
| Failed plugin install | `Lazy! restore` fails or times out | Restored; exit 1 |
| Failed Mason install | A pinned tool version fails to install | Restored; exit 1 |
| Failed parser build | A parser fails to compile | Restored; exit 1 |
| Neovim changed, later failure | Neovim upgraded in step 2, failure in step 7 | Config and data restored; previous Neovim reinstalled; exit 1 |
| Restore fails | Copy-back fails (e.g. a locked file) | Exit 2; backup, `failed\` folder, and log intact; paths printed |
| Previous Neovim no longer offered | WinGet no longer lists `previousNeovimVersion` | Neovim not uninstalled; exit 2 with explanation |

### Open items resolved in this phase (ROADMAP.md)
- **Neovim MSI downgrade:** determine whether WinGet installs an older Neovim over a newer one in place, and record
  the observed behavior in ROLLBACK.md.
- **Known issue 4 (rollback):** WinGet version no longer available during rollback is handled as above.
- **Elevated file creation (ADR-006):** confirm a non-elevated Neovim can load the configuration and that its
  plugin, Mason, and parser folders are writable by the user; record the result in ARCHITECTURE.md (Risks).

## Out of Scope
- New features or requirements; changes to pins or the plugin set.
- Release packaging and the 1.0.0 tag (Phase 07).
- Any destructive test on the host: real installs, downgrades, or uninstalls run only in the disposable environment.

## Test Requirements
- **Integration (sandboxed folders, WinGet mocked, real files):** every row of the recovery table; every row of the
  ARCHITECTURE.md failure table with its exit code; rerun idempotency; upgrade from the fixture release; `-WhatIf`
  for every scenario; restore run twice gives the same result.
- **No data loss (NFR-04):** for every scenario, a snapshot taken before the run proves every original file still
  exists afterwards, either in its live location or in the backup.
- **End-to-end (Windows Sandbox, real WinGet and Neovim):** fresh install, rerun, existing configuration, upgrade,
  a real Neovim downgrade with rollback, and an interrupted run (process stopped after backup, before deployment)
  followed by a run that must stop with exit 3.
- Interrupted-run detection (unit): newest backup finished / unfinished / no backups.
- Phase 03–05 suites still pass.

## Implementation Constraints
- Follow ROLLBACK.md and ADR-020 exactly; any change to rollback behavior needs approval and a document update.
- Nothing deleted: failed-run files are moved into the backup; backups and logs are never removed.
- Failure injection lives in tests (mocks or fixtures), never as switches in production code.
- Windows Sandbox setup is test tooling, not bootstrapper behavior. WinGet is not preinstalled in Windows Sandbox,
  so the setup installs it before running the bootstrapper; the bootstrapper still assumes WinGet is present.
- End-to-end tests are driven by a Windows Sandbox configuration file (`.wsb`) that maps the repository read-only
  into the sandbox and runs the test script at logon; results are written to a mapped output folder.

## Acceptance Criteria
- All Phase 06 integration tests pass, and the full suite has no regressions.
- Every exit code in NFR-09 is produced by at least one end-to-end test.
- End-to-end tests pass in Windows Sandbox, including a real Neovim downgrade followed by rollback.
- ROLLBACK.md records the observed MSI downgrade behavior; ARCHITECTURE.md records the permissions result.
- No test touched the host's real Neovim installation, configuration, or data.

## Deliverables
- `Restore-ConfigurationBackup`, `Restore-NeovimVersion`, rollback wiring in `Invoke-NeovimBootstrap`
- Integration scenario tests, release fixtures for the upgrade scenario, data-loss snapshot helper
- `tests/EndToEnd/`: Windows Sandbox configuration (`.wsb`), sandbox setup script (installs WinGet), end-to-end
  test scripts, and instructions for running them
- ROLLBACK.md and ARCHITECTURE.md updates for the resolved items

## Completion Evidence

Failure scenarios have verified, non-destructive recovery behavior.

Report includes the scenario test results, the end-to-end run output from Windows Sandbox, and the observed MSI
downgrade behavior.

## Open questions
None.

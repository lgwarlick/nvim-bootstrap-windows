# Phase 03 - Neovim installation

## Status
Not Started

## Objective
Implement detection, minimum-version enforcement, package-manager integration, dependency checks, PATH handling, and idempotency

## Dependencies
- Phase 01 Complete
- Phase 02 Complete

## Scope

Steps 0–3 of the execution flow in ARCHITECTURE.md, plus the pieces every later step relies on.

### Entry point and orchestration
- `src/bootstrap.ps1`: parameters `-WhatIf`, `-Confirm`, `-Force`, `-AllowNeovimDowngrade`; imports the module; calls
  `Invoke-NeovimBootstrap`; converts its result to an exit code (0, 1, or 3 in this phase; NFR-09).
- `Invoke-NeovimBootstrap`: runs steps 0–3 in order and keeps run state for later phases, including
  `previousNeovimVersion` (needed for rollback in Phase 06). Later phases add steps 4–8.

### Release manifest
- `src/ReleaseManifest.psd1` (ADR-018): release version; Neovim and tree-sitter-cli WinGet IDs and exact versions;
  for each Tier B dependency its WinGet ID, command name, minimum version, and tested version — all values exactly
  as in COMPATIBILITY.md.
- `Get-ReleaseManifest` loads and checks it (required fields present, versions parse).
- Validation check: manifest values match the COMPATIBILITY.md tables.

### Step 0 — Preflight (nothing changes)
- `Test-IsElevated` (NFR-02), `Test-SupportedArchitecture` (x64; NFR-08), `Test-WinGetAvailable`.
- Confirm WinGet still offers every version the run may install (Neovim, tree-sitter-cli, tested versions of
  missing Tier B dependencies). If one is gone, stop with exit 3 before any change (known issue 4).
- Any failure → clear message, exit 3.

### Wrappers
- `Invoke-WinGet`: the only place `winget.exe` is called. Always passes `--exact`, `--disable-interactivity`,
  `--accept-source-agreements`, and for installs `--accept-package-agreements` and `--silent`. Checks the exit
  code; named benign codes only (ARCHITECTURE.md, Error handling).
- `Invoke-NeovimHeadless`: the only place `nvim.exe` is called (used here for `nvim --version`; later phases add
  more).

### Detection
- `Find-Executable`: finds a command on PATH and **ignores App Execution Alias stubs** under
  `%LOCALAPPDATA%\Microsoft\WindowsApps` (known issue 2).
- `Get-InstalledNeovimVersion`: from `nvim --version`, cross-checked against `winget list`.
- `Get-DependencyStatus`: for each Tier B dependency returns Missing, Ok, or BelowMinimum with the found version.
  7-Zip is detected even though it is not on PATH (known issue 1 is solved in Phase 05; detection is here).

### Steps 1–3 — Installation
- Step 1, `Install-Dependency` (FR-21, FR-22): Missing → install the tested version; Ok → no change; BelowMinimum →
  stop with name, found version, and minimum (exit 3 if nothing changed yet, otherwise exit 1).
- Step 2, `Install-Neovim` (FR-10–FR-13): not installed by WinGet → stop, exit 3; absent or older → install the
  pinned version; same → no change; newer → stop (exit 3) unless approved by the interactive prompt or
  `-AllowNeovimDowngrade`. `-Force` never approves a downgrade.
- Step 3, `Install-TreeSitterCli` (FR-20): install the pinned version if it is not already installed.
- After each install: `Update-SessionPath` rebuilds the session PATH from the machine and user values (known issue
  3), then the new program must be found and report the expected version, or the step fails.

### Run log (FR-80)
- `Write-BootstrapLog` and log file creation under `%LOCALAPPDATA%\nvim-bootstrap\logs\` per ARCHITECTURE.md.
  No log is written for `-WhatIf` runs.

## Out of Scope
- Steps 4–8: paths, backup, deployment, plugins, verification (Phases 04–05).
- Rollback, including reinstalling the previous Neovim (Phase 06). This phase only records `previousNeovimVersion`.
- Making 7-Zip visible to Mason (Phase 05).
- The Microsoft.WinGet.Client PowerShell module or any other new tool (requires approval).

## Test Requirements
- Make the Phase 03 tests written in Phase 02 pass, extending them where needed. Unit tests mock `Invoke-WinGet`,
  `Invoke-NeovimHeadless`, and environment reads.
- For every installing function: success, failure (WinGet non-zero exit), already-installed (no change), and
  `-WhatIf` (no system-changing calls).
- Detection: Store alias stub ignored; versions parsed from captured real outputs in `tests/Fixtures/`; Neovim on
  PATH but not listed by WinGet stops with exit 3 (FR-13).
- Downgrade approval: prompt accepted, prompt declined, `-AllowNeovimDowngrade`, and `-Force` alone (must not
  downgrade).
- Preflight: each failure stops with exit 3 and makes no install calls; a missing WinGet version stops before any
  change.
- Integration (sandboxed, WinGet mocked): steps 0–3 on a "fresh machine" fixture, then a second run reports no
  changes (FR-70 for these steps).
- Validation: manifest-vs-COMPATIBILITY.md check passes, and fails on a deliberately mismatched fixture.

## Implementation Constraints
- No real installs during tests. The only real run on the host is with `-WhatIf` (see Acceptance Criteria).
- Never upgrade, downgrade, or uninstall a Tier B dependency (ADR-007).
- Never write to the persistent environment (PATH changes are session-only).
- WinGet text output can vary; parsing is covered by fixtures captured from the reference test device, and parse
  failures are errors, never guesses.
- Versions come only from the release manifest; none are hardcoded in functions (ADR-018).

## Acceptance Criteria
- All Phase 03 unit and integration tests pass, and the full suite has no regressions.
- `scripts/Invoke-Validation.ps1` passes, including the new manifest check.
- On the reference test device, `bootstrap.ps1 -WhatIf` in an elevated session exits 0 and reports: install
  PowerShell 7, 7-Zip, Zig, and tree-sitter-cli; leave Git, Node.js, Python, Terraform, and Neovim 0.12.6 unchanged.
  No changes are made and no log is written.
- The same command in a non-elevated session exits 3 with the elevation message.

## Deliverables
- `src/bootstrap.ps1`, `src/ReleaseManifest.psd1`
- `src/NeovimBootstrap.psm1` / `.psd1`: preflight, wrappers, detection, installation, PATH refresh, logging, and
  orchestration for steps 0–3
- Tests and fixtures; validation check for the manifest
- Documentation updates for any approved changes (e.g. function names in ARCHITECTURE.md)

## Completion Evidence
Installation tests pass; rerunning the installer causes no unnecessary changes

Report includes the `-WhatIf` output from the reference test device.

## Open questions
None.

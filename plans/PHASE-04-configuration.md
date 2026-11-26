# Phase 04 - Configuration deployment

## Status
Tracked in the GitHub milestone **Phase 04 - Configuration deployment and backup** (see [ROADMAP.md](ROADMAP.md)).

## Objective

Build the Lua configuration, configuration path resolution, existing-config detection, backup creation, and safe deployment logic.

## Dependencies
- Phase 01 complete
- Phase 02 complete
- Phase 03 complete

## Scope

Steps 4–6 of the execution flow in ARCHITECTURE.md, and the checks and approval those steps contribute to step 0
(ADR-024). Backup behavior is defined in ROLLBACK.md; this phase implements its "How backup works" section exactly.

### Step 0 additions (nothing changes)
Added to preflight after the Phase 03 checks, so each runs before anything is installed and stops with exit 3:
- `Get-NeovimPath` (from the installed Neovim, or computed from the environment if Neovim is not installed;
  ADR-023).
- `Test-ConfigurationCurrent`; if the configuration is not current and any backup item exists: stop if any live
  item is on a different drive from `%LOCALAPPDATA%\nvim-bootstrap\backups`, then ask for approval with
  `ShouldContinue`, unless `-Force` (non-interactive without `-Force` stops).
- `Test-NeovimRunning` (FR-34).

The approval result is kept in run state for step 5.

### Configuration structure
- Create the `src/config/` file layout from ARCHITECTURE.md (ADR-019): `init.lua` and `lua/config/options.lua`
  and `keymaps.lua`.
- `init.lua` loads `config.options` and `config.keymaps`. They are intentionally minimal in this phase; their
  content, `lua/config/lazy.lua`, `lua/config/pins.lua`, and `lua/plugins/` are Phase 05.
- The deployed configuration must start in Neovim 0.12.6 with no errors.

### Step 4 — Path resolution (FR-30)
- `Get-NeovimPath`: asks the installed Neovim for `stdpath('config')` and `stdpath('data')` via
  `Invoke-NeovimHeadless`, using `--clean` so a broken existing configuration cannot interfere.
- When Neovim is not installed, `Get-NeovimPath` computes both paths from `NVIM_APPNAME`, `XDG_CONFIG_HOME`,
  `XDG_DATA_HOME`, and `LOCALAPPDATA` as described in ARCHITECTURE.md, Path resolution (ADR-023).
- Derives the backup items from ROLLBACK.md: configuration, `data\lazy`, `data\mason`, `data\site\parser`,
  `data\site\queries`.

### Step 5 — Existing configuration, approval, backup (FR-31, FR-32, FR-33, FR-34, FR-62)
- `Test-ConfigurationCurrent`: the live configuration is current only if its files exactly match `src/config/`
  (same file list, same SHA-256 hashes). If current, skip steps 5–6.
- `Test-NeovimRunning`: if any `nvim.exe` process is running, stop and ask the user to close Neovim (FR-34). Run
  in step 0 (exit 3) and again immediately before the first write to the configuration or data folders, because
  Neovim can be started while steps 1–3 run (exit 1).
- If any backup item exists and the configuration is not current (the drive check and approval already passed in
  step 0):
  1. `New-ConfigurationBackup`: write the manifest, move every existing item into the backup folder.
  2. `Test-ConfigurationBackup`: verify against the manifest; set `status: verified`.
  3. On any failure in 1–2: move the moved items back, verify, exit 1 (or 2 if moving back fails).
- If no backup item exists (fresh machine), no approval or backup is needed.

### Step 6 — Deployment
- `Deploy-NeovimConfiguration`: copy `src/config/` into the (now empty or new) configuration location,
  byte for byte, with no re-encoding.
- Verify the deployed files match `src/config/` by hash.
- In this phase, a failure after backup stops with exit 1 and prints the backup and log paths. Automatic restore
  is Phase 06.

### Validation
- New check (NFR-04, FR-62): no file-deleting commands (`Remove-Item`, `rmdir`, `del`, `[IO.File]::Delete`,
  `[IO.Directory]::Delete`, and their aliases) in `src/`.

## Out of Scope
- Plugin, Mason, and parser installation; lazy.nvim; editor options and key mapping content (Phase 05).
- Automatic restore after a failure in step 6 and later; `Restore-ConfigurationBackup` (Phase 06).
- Any change to the real configuration on the host other than through `-WhatIf`.

## Test Requirements
- Unit (mocked): path resolution from Neovim output; path resolution without Neovim (defaults, each of
  `NVIM_APPNAME`, `XDG_CONFIG_HOME`, `XDG_DATA_HOME` set, and all three set); current/not-current detection
  (identical, changed file, extra file, missing file); approval accepted / declined / `-Force` / non-interactive without `-Force`; different-drive
  stop; Neovim running in step 0 → exit 3 with no changes, and started after step 0 → exit 1 with nothing moved
  (process list mocked); manifest contents; verification catches a missing or changed file; move-back after a
  failed backup;
  `-WhatIf` moves and copies nothing.
- Integration (sandbox with real files, WinGet mocked):
  - Fresh machine → configuration deployed, no backup made.
  - Existing user configuration and plugin data → approval → backup verified (manifest `status: verified`) →
    configuration deployed; every original file is present in the backup.
  - Rerun → no changes, no new backup (FR-70 for these steps).
  - Approval declined → exit 3 from step 0; nothing moved and no install calls made.
  - Simulated verification failure → items moved back, exit 1.
- Real Neovim, sandboxed: `stdpath()` honors the sandbox's `LOCALAPPDATA` and `XDG_*` values; the deployed
  configuration starts headless with no errors.
- Compatibility suite (real Neovim, sandboxed): for the same environment cases as the unit tests, the paths
  computed without Neovim equal Neovim's own `stdpath('config')` and `stdpath('data')` (ADR-023).
- No test or code path deletes a file; the new validation check enforces it for `src/`.

## Implementation Constraints
- Follow ROLLBACK.md and ADR-020 exactly: approval before moving, move (not copy) to back up, nothing deleted.
- Never write Lua or other text files through `Set-Content`/`Out-File`; copy bytes (COMPATIBILITY.md, 5.1 coding
  constraints).
- Paths only from `Get-NeovimPath` and environment values; nothing hardcoded (NFR-03).
- Backups are never deleted, including by tests outside the sandbox.

## Acceptance Criteria
- All Phase 04 unit and integration tests pass, and the full suite has no regressions.
- `scripts/Invoke-Validation.ps1` passes, including the no-deletion check.
- On the reference test device (which has no existing configuration), `bootstrap.ps1 -WhatIf` in an elevated
  session exits 0 and reports, in addition to the Phase 03 actions, that it would deploy the configuration to
  `stdpath('config')` with no backup needed. Nothing is changed.

## Deliverables
- `src/config/init.lua`, `src/config/lua/config/options.lua`, `src/config/lua/config/keymaps.lua` (minimal)
- Module functions for steps 4–6, added to `Invoke-NeovimBootstrap`
- Tests and fixtures (sample existing configurations and plugin data folders)
- Validation check for deletion commands

## Completion Evidence
Configuration can be deployed without losing the previous configuration

Report includes the integration test output for the "existing configuration" scenario (backup manifest and
verification result) and the `-WhatIf` output from the reference test device.

## Open questions
None.

# Backup and Rollback

How the bootstrapper protects the user's existing Neovim setup and restores it when a run fails.

Requirements: FR-32, FR-33, FR-60, FR-61, FR-62, FR-80. Decisions: ADR-020 (scope and method), ADR-016 (location).
Where these steps sit in the run: [ARCHITECTURE.md](ARCHITECTURE.md#execution-flow).

## Guarantees

1. Nothing is overwritten until it has been backed up, the backup verified, and approval given.
2. Nothing is deleted. Replaced files are moved into a backup; files from a failed run are moved into that
   backup's `failed\` folder, never discarded.
3. Backups are never deleted automatically (FR-62).
4. Neovim and shared dependencies are never uninstalled, with one exception: during rollback, if Neovim cannot be
   downgraded in place, the newer Neovim is uninstalled immediately before reinstalling the previous version
   (ADR-020).
5. Restoring is idempotent: running a restore again with the same backup produces the same result.

## What is backed up

A run backs up **only what it is about to replace**, as one set:

| Item | Live location (default) | Why |
|---|---|---|
| Configuration | `stdpath('config')` — `%LOCALAPPDATA%\nvim` | Replaced by deployment (step 6) |
| Plugins | `stdpath('data')\lazy` | Replaced by plugin restore (step 7) |
| Mason tools | `stdpath('data')\mason` | Replaced by Mason installs (step 7) |
| Tree-sitter parsers and queries | `stdpath('data')\site\parser`, `stdpath('data')\site\queries` | Replaced by parser installs (step 7) |

Not touched and not backed up: anything else under `stdpath('data')`, such as shada history, undo files, swap
files, and logs. These belong to the user's editing sessions, not to the release.

Live locations come from Neovim's `stdpath()` (ARCHITECTURE.md, Path resolution).

### When a backup is made

- **Configuration already matches the release, and plugin data is current:** no backup; nothing is replaced (FR-70).
- **Configuration already matches, but plugin data is missing or incomplete:** step 7 repairs it in place by adding
  what is missing. Nothing existing is replaced, so no backup is needed. Like every write, repair runs only while
  Neovim is closed (FR-34).
- **Anything else** (first install over a user's own config, or upgrading from an older release): all items above
  that exist are backed up together, after approval.

## Backup layout

```text
%LOCALAPPDATA%\nvim-bootstrap\
├── backups\
│   └── 2026-11-25T14-03-07\          one folder per backup (local time, sortable, no ':' characters)
│       ├── manifest.json
│       ├── config\                   former stdpath('config')
│       ├── data\
│       │   ├── lazy\
│       │   ├── mason\
│       │   └── site\parser\, site\queries\
│       └── failed\                   only if a restore happened: the failed run's files, kept for diagnosis
└── logs\
    └── 2026-11-25T14-03-07.log       run log for the same run (FR-80)
```

### `manifest.json`

| Field | Contents |
|---|---|
| `schemaVersion` | Manifest format version (starts at 1) |
| `createdAt` | Timestamp |
| `bootstrapperRelease` | Release that made the backup, e.g. `1.0.0` |
| `previousNeovimVersion` | Neovim version found before the run, or `null` if none was installed |
| `items` | One entry per backed-up item: name, original path, whether it existed, file list |
| `files` (per item) | Relative path and size of every file; SHA-256 hash for configuration files |
| `status` | `created` → `verified` → (`restored` if a rollback used it) |
| `runCompleted` | Timestamp set when the run that made this backup finishes (success or completed rollback); absent if the run was interrupted (FR-63) |

## How backup works

1. **Approval first.** Confirm with the user (or `-Force`) in step 0, before anything is installed or moved (FR-33).
   If approval is not given, nothing has changed and the run stops (exit 3).
2. **Record.** Write the manifest's file list (sizes, plus hashes for configuration) from the live locations.
3. **Move.** Move each live item into the backup folder. A move on the same drive is a rename. The files are not
   copied or deleted, and the live locations are left empty for a clean install.
4. **Verify.** Check every file in the manifest exists in the backup with the recorded size (and hash, for
   configuration). Set `status` to `verified`.
5. **If any step fails:** move whatever was already moved back to its live location, verify it, and stop with exit
   code 1. Nothing is deployed.

**Different drives:** if a live location is on a different drive from `%LOCALAPPDATA%` (possible when
`XDG_CONFIG_HOME` or `XDG_DATA_HOME` is set), a move would become copy-then-delete. The bootstrapper checks this in
step 0 and stops before anything is installed or moved (exit 3), reporting why.

## How restore works (automatic rollback)

Triggered by a failure in steps 6–8 (ARCHITECTURE.md, On failure).

1. **Set aside the failed state.** Move whatever the failed run created in each live location into the backup's
   `failed\` folder.
2. **Copy back.** Copy each backed-up item to its live location. A copy, not a move, so the backup stays complete
   and can be used again.
3. **Verify** the restored files against the manifest.
4. **Neovim.** If the run changed the Neovim version, reinstall `previousNeovimVersion` via WinGet (FR-61). If
   WinGet cannot install the older version over the newer one, uninstall the newer Neovim and then install
   `previousNeovimVersion`. Before uninstalling, confirm WinGet still offers `previousNeovimVersion`; if it does not,
   do not uninstall, and stop with exit code 2. If no Neovim was installed before the run, the newly installed
   Neovim is left in place.
5. **Record** the outcome in the manifest (`status: restored`) and the run log.

If any restore step fails, the run stops with **exit code 2**, prints the backup and log paths, and leaves both
untouched for manual recovery.

## Manual recovery

For exit code 2, or to return to an earlier state at any time:

1. Close all Neovim instances.
2. Find the backup: the run log printed its path; otherwise use the newest folder in
   `%LOCALAPPDATA%\nvim-bootstrap\backups\`. Check `manifest.json` for the original locations.
3. Move the current contents of each original location into a new folder inside that backup (for example
   `manual-<date>\`). Do not delete them.
4. Copy `config\` back to the configuration location, and each folder under `data\` back to the matching place
   under the data location.
5. If `previousNeovimVersion` differs from the installed version, reinstall it:
   `winget install --id Neovim.Neovim --exact --version <previousNeovimVersion>`
6. Start Neovim and confirm it loads.

The module's `Restore-ConfigurationBackup` function performs steps 3–4 for a given backup folder and supports
`-WhatIf`.

## Open questions

None. Whether the Neovim MSI can be downgraded in place is determined by testing in Phase 06; both outcomes are
covered above.

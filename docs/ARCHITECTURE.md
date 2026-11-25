# Architecture

How the bootstrapper is built. What it must do is in [REQUIREMENTS.md](REQUIREMENTS.md); versions are in
[COMPATIBILITY.md](COMPATIBILITY.md) and [PLUGINS.md](PLUGINS.md); backup and restore details are in
[ROLLBACK.md](ROLLBACK.md); the reasons behind key choices are in [DECISIONS.md](DECISIONS.md).

## Design principles

1. **Thin entry point, small functions.** `bootstrap.ps1` only parses parameters, calls one orchestrator function,
   and converts the result to an exit code. All logic lives in small, individually testable module functions.
2. **Test, then set.** Every step first checks whether the machine is already in the desired state. If so, it
   reports "no change" and does nothing (FR-70).
3. **Every change goes through `ShouldProcess`.** `-WhatIf` and `-Confirm` work for the whole run and for every
   function on its own (FR-71).
4. **External programs are called through wrappers.** WinGet and Neovim are invoked from exactly one function
   each, so unit tests can mock them and failures are handled in one place.
5. **Pins are data, not code.** Versions live in data files that code reads; documents and data are checked
   against each other by validation.
6. **Fail fast, then roll back.** The first failure stops the run, and anything the run changed is restored
   (FR-60, FR-61).

## Repository layout

| Path | Purpose |
|---|---|
| `src/bootstrap.ps1` | Entry point |
| `src/NeovimBootstrap.psd1` / `.psm1` | Module manifest and module with all functions |
| `src/ReleaseManifest.psd1` | Machine-readable Tier A and Tier B versions and WinGet IDs (mirrors COMPATIBILITY.md; ADR-018) |
| `src/config/` | The Neovim configuration that gets deployed (structure below; ADR-019) |
| `src/config/lazy-lock.json` | Plugin commit pins (mirrors PLUGINS.md) |
| `scripts/Invoke-Tests.ps1` | Runs the Pester suites |
| `scripts/Invoke-Validation.ps1` | Static checks, including documents-vs-data consistency |
| `tests/Unit/` | Unit tests; all external commands mocked |
| `tests/Integration/` | Integration tests; isolated temporary paths, external installs mocked |
| `tests/Compatibility/` | The release compatibility check (COMPATIBILITY.md) |
| `tests/Fixtures/` | Sample configs, sample PowerShell/Terraform/YAML files |
| `tests/EndToEnd/` | Real end-to-end tests run in Windows Sandbox (ADR-021) |

### Where pins live

| Pin | Data file (enforced) | Document (reviewed) |
|---|---|---|
| Neovim, tree-sitter-cli, Tier B versions and WinGet IDs | `src/ReleaseManifest.psd1` | COMPATIBILITY.md |
| Plugin commits | `src/config/lazy-lock.json` | PLUGINS.md |
| Mason registry, Mason tool versions, tree-sitter parser list | `src/config/lua/config/pins.lua` | PLUGINS.md |

`Invoke-Validation.ps1` fails if any data file and its document disagree.

## Components

Functions are grouped by responsibility. Names are indicative; phases may refine them but must keep approved verbs
and the one-responsibility-per-function rule.

| Group | Example functions | Changes system? |
|---|---|---|
| Preflight | `Test-IsElevated`, `Test-SupportedArchitecture`, `Test-WinGetAvailable`, `Get-ReleaseManifest` | No |
| Wrappers | `Invoke-WinGet`, `Invoke-NeovimHeadless` | Depends on call |
| Detection | `Find-Executable` (ignores Store alias stubs), `Get-InstalledNeovimVersion`, `Get-DependencyStatus` | No |
| Installation | `Install-Dependency`, `Install-Neovim`, `Install-TreeSitterCli`, `Update-SessionPath` | Yes |
| Paths | `Get-NeovimPath` | No |
| Backup | `New-ConfigurationBackup`, `Test-ConfigurationBackup` | Yes (creates backups only) |
| Deployment | `Test-ConfigurationCurrent`, `Deploy-NeovimConfiguration` | Yes |
| Plugins and tools | `Invoke-PluginRestore`, `Install-MasonTools`, `Install-TreeSitterParsers` | Yes |
| Verification | `Test-NeovimSetup` | No |
| Rollback | `Restore-ConfigurationBackup`, `Restore-NeovimVersion` | Yes |
| Orchestration | `Invoke-NeovimBootstrap` | Yes (via the functions above) |

## Execution flow

```text
bootstrap.ps1 [-WhatIf] [-Confirm] [-Force] [-AllowNeovimDowngrade]
  │
  0. Preflight ─ elevated? x64? WinGet present? manifest valid?
  │              previous run interrupted (FR-63)? ─────────────────── fails ──► stop, exit 3
  │
  1. Shared dependencies (Tier B) ─ detect each; install tested version if missing;
  │                                 stop if below minimum (exit 3); refresh session PATH
  2. Neovim (Tier A) ─ not installed by WinGet → stop, exit 3 (FR-13)
  │                    record current version; install pinned version if needed;
  │                    newer than pinned → stop unless approved by prompt or -AllowNeovimDowngrade (FR-12)
  3. tree-sitter-cli (Tier A) ─ install pinned version if needed
  │
  4. Resolve paths ─ ask the installed Neovim for stdpath('config') and stdpath('data')
  5. Existing configuration ─ identical to release? → skip 5–6
  │                           Neovim running? → stop, exit 3 (FR-34)
  │                           otherwise: approval (FR-33), then back up by move + verify (ROLLBACK.md)
  6. Deploy configuration
  7. Plugins and tools ─ Lazy! restore → Mason tools at pinned versions → tree-sitter parsers
  8. Verify ─ headless Neovim loads the configuration without errors
  │
  ▼
  success → exit 0
```

### On failure

| Failed in step | What is restored | Exit code |
|---|---|---|
| 0 | Nothing changed | 3 |
| 1 | Tier B installs are kept (never uninstalled); nothing else changed | 1 |
| 2–3 | Previous Neovim version reinstalled if step 2 changed it (FR-61) | 1, or 2 if restore fails |
| 5 (approval declined, or non-interactive without `-Force`) | Nothing changed; no backup made | 3 |
| 5 (live folder on a different drive from the backup folder) | Nothing changed | 3 |
| 5 (Neovim is running) | Nothing changed | 3 |
| 5 (backup failed or not verified) | Moved items moved back and verified; nothing deployed | 1, or 2 if moving back fails |
| 6–8 | Configuration and plugin data restored from backup (FR-60); previous Neovim reinstalled if changed | 1, or 2 if restore fails |

### Exit codes (NFR-09)

| Code | Meaning |
|---|---|
| 0 | Success, including "nothing to change" and `-WhatIf` runs |
| 1 | Failed; nothing was changed, or every change was rolled back successfully |
| 2 | Failed **and** rollback failed; manual recovery needed (see ROLLBACK.md) |
| 3 | Stopped before changing anything: unmet precondition or approval not given |

## Key mechanisms

### Path resolution (FR-30, NFR-03)

- Neovim's own `stdpath('config')` and `stdpath('data')` are the source of truth, queried from the installed Neovim
  via `Invoke-NeovimHeadless`. This respects any `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, or `NVIM_APPNAME` the user
  has set.
- Defaults when nothing is overridden: config `%LOCALAPPDATA%\nvim`, data `%LOCALAPPDATA%\nvim-data`.
- Bootstrapper state: `%LOCALAPPDATA%\nvim-bootstrap\` (backups per ADR-016).
- No path is ever built from a literal user name or drive letter.

### `-WhatIf`, approval, and `-Force` (FR-33, FR-71)

- Every state-changing function uses `[CmdletBinding(SupportsShouldProcess)]` and calls `$PSCmdlet.ShouldProcess`
  before each change.
- Overwriting an existing configuration also requires `$PSCmdlet.ShouldContinue` (an interactive prompt) unless
  `-Force` is given.
- In a non-interactive session without `-Force`, the run stops at step 5 with exit code 3.
- Installing an older pinned Neovim over a newer one (FR-12) has its own approval: the prompt, or
  `-AllowNeovimDowngrade` for unattended runs. `-Force` does not approve it. Without either, the run stops at step 2
  with exit code 3.
- A `-WhatIf` run performs all detection steps and reports every change it would make, but changes nothing.

### Error handling (NFR-05)

- `$ErrorActionPreference = 'Stop'` inside the module; errors are never silenced with `SilentlyContinue` except
  where a "not found" result is expected and handled explicitly.
- The orchestrator wraps each step; on failure it records which step failed and why, triggers rollback, and
  returns the exit code from the table above.
- External programs: the wrapper checks `$LASTEXITCODE` and turns a non-zero code into a terminating error that
  includes the command and code. Known benign WinGet codes (such as "already installed") are named explicitly,
  never matched broadly.

### Run log (FR-80)

- Each run writes a log to `%LOCALAPPDATA%\nvim-bootstrap\logs\<timestamp>.log`: release version, every detection
  result, every change made, the backup path, any failure with its step, and every rollback action.
- The log path is printed at the end of the run, especially for exit code 2, so manual recovery can start from it.
- Logs are never deleted automatically. A `-WhatIf` run writes no log, because it must change nothing.

### Session PATH refresh

After WinGet installs a program, `Update-SessionPath` rebuilds the current process's `PATH` from the machine and
user environment values so later steps can find it. It never writes to the persistent environment.

## Neovim configuration (`src/config`)

Split into Lua modules (ADR-019). lazy.nvim loads every file in `lua/plugins/` as a plugin spec.

| Path | Contents |
|---|---|
| `init.lua` | Loads `config.options`, `config.keymaps`, then `config.lazy` |
| `lua/config/options.lua` | Editor options |
| `lua/config/keymaps.lua` | Key mappings not owned by a plugin |
| `lua/config/lazy.lua` | Clones lazy.nvim at its locked commit and starts it with the settings below |
| `lua/config/pins.lua` | Mason registry tag, Mason tool versions, tree-sitter parser list (the only place they are written) |
| `lua/plugins/lsp.lua` | nvim-lspconfig, mason.nvim, mason-lspconfig.nvim |
| `lua/plugins/completion.lua` | blink.cmp |
| `lua/plugins/treesitter.lua` | nvim-treesitter |
| `lua/plugins/formatting.lua` | conform.nvim |
| `lua/plugins/linting.lua` | nvim-lint |
| `lua/plugins/explorer.lua` | neo-tree.nvim (with plenary.nvim, nui.nvim) |
| `lua/plugins/git.lua` | gitsigns.nvim |
| `lua/plugins/editing.lua` | nvim-autopairs |
| `lazy-lock.json` | Plugin commit pins |

Every plugin in PLUGINS.md appears in exactly one `lua/plugins/` file. Deployment and backup treat `src/config/` as
one unit.

- lazy.nvim is cloned at the commit recorded in `lazy-lock.json`, then manages every other plugin.
- lazy.nvim settings: update checker disabled, luarocks support disabled, lockfile kept in the config directory.
- Language servers are configured with Neovim's built-in `vim.lsp.config` / `vim.lsp.enable`; the deprecated
  `require('lspconfig').<server>.setup()` style is not used.
- The PowerShell language server runs on PowerShell 7 (`pwsh`), using the Mason-installed PowerShell Editor
  Services bundle (ADR-017).
- **The bootstrapper is the only installer.** Plugins, Mason tools, and parsers are installed during step 7 in
  headless Neovim. Opening the editor normally never downloads or updates anything.
- **No Nerd Font is assumed** (nvim-web-devicons is excluded). Every plugin UI, including neo-tree icons and
  blink.cmp completion kinds, must render with standard fonts.

### Editor defaults (1.0.0)

Approved 2026-11-25. Everything not listed keeps Neovim's default.

| Area | Setting |
|---|---|
| Leader key | Space (set before lazy.nvim loads) |
| Line numbers | Absolute on the cursor line, relative elsewhere (`number`, `relativenumber`) |
| Clipboard | System clipboard (`clipboard=unnamedplus`) |
| Undo | Persistent (`undofile`); stored under `stdpath('state')`, never backed up or touched by the bootstrapper |
| Search | Case-insensitive unless the pattern has a capital (`ignorecase`, `smartcase`) |
| Indentation | Spaces; PowerShell 4, Terraform/HCL 2, YAML 2 (matching their formatters) |
| Formatting | On save for PowerShell, Terraform, and YAML; also `<leader>f` to format manually |
| Linting | When a file is opened and after each save |
| Colorscheme | Neovim default |

| Mapping | Action |
|---|---|
| `<leader>e` | Toggle the file explorer (neo-tree) |
| `<leader>f` | Format the current buffer |
| Neovim built-ins | Language server actions use Neovim 0.12 defaults: `K` hover, `grn` rename, `gra` code action, `grr` references, `gri` implementation, `[d` / `]d` diagnostics. No custom mappings duplicate them. |
| Plugin defaults | blink.cmp `default` keymap preset; gitsigns.nvim default hunk navigation (`[c` / `]c`) |

## Testing approach

| Layer | What it covers | External effects |
|---|---|---|
| Unit | Each function's logic, including failure, idempotency, and `-WhatIf` paths | None; WinGet, Neovim, and file system effects mocked |
| Integration | Full orchestrator runs: fresh install, rerun, upgrade, injected failures and rollback | Real file operations in isolated temporary folders; WinGet mocked |
| Compatibility | The release compatibility check (COMPATIBILITY.md) | Real headless Neovim with an isolated profile (`LOCALAPPDATA`/`XDG_*` pointed at a temporary folder) |
| End-to-end | Real installs, Neovim downgrade and rollback, interrupted runs, fresh-machine runs | Windows Sandbox only; discarded after each run (ADR-021) |

No test touches the user's real Neovim configuration or data. Tests run on Windows PowerShell 5.1 with Pester 5.9.1
(ADR-013).

## Risks

- **Elevated file creation (ADR-006).** Configuration and plugin files are written by an elevated process.
  Integration tests must confirm unelevated Neovim can still read and update them.
- **Headless installs are slow.** Building parsers and installing Mason tools can take minutes; steps need
  explicit timeouts and clear progress output.

## Open questions

None.

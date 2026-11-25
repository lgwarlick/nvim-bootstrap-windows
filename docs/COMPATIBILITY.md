# Compatibility

Supported platform, pinned and minimum versions of everything outside Neovim's plugin set, and the check that
proves a release works out of the box.

- Plugins, Mason tools, and tree-sitter parsers: [PLUGINS.md](PLUGINS.md)
- Why the versions are managed this way: [DECISIONS.md](DECISIONS.md) (ADR-001, ADR-004, ADR-007)

**Release:** 1.0.0 (unreleased) · **Versions selected:** 2026-11-25

## Platform

| Item | Supported | Reference |
|---|---|---|
| Operating system | Windows 11 | NFR-01 |
| CPU architecture | x64 only | NFR-08, ADR-012 |
| Bootstrapper runtime | Windows PowerShell 5.1, elevated session | NFR-01, NFR-02, ADR-006 |
| Package manager | WinGet (assumed present) | REQUIREMENTS.md assumptions |

## Tier A — release-owned, exact versions

Installed at exactly these versions. A different version is a different release (ADR-002).

| Component | WinGet ID | Version | Notes |
|---|---|---|---|
| Neovim | `Neovim.Neovim` | **0.12.6** | Machine-scope MSI. WinGet also installs its dependency `Microsoft.VCRedist.2015+.x64`. |
| tree-sitter-cli | `tree-sitter.tree-sitter-cli` | **0.27.2** | nvim-treesitter `main` requires ≥ 0.26.1, installed from a package manager, not npm. |
| Mason registry and tools | — (installed by Mason) | See PLUGINS.md | Pinned per ADR-009. |

## Tier B — shared, tested minimum

If missing, the bootstrapper installs the **tested** version. If present at or above the **minimum**, it is left
unchanged. If below the minimum, the bootstrapper stops (FR-21, FR-22).

| Component | WinGet ID | Minimum | Tested | Minimum comes from |
|---|---|---|---|---|
| Git | `Git.Git` | 2.19.0 | 2.56.1 | lazy.nvim (partial clone support); also used by mason.nvim, blink.cmp, gitsigns.nvim |
| Node.js | `OpenJS.NodeJS.LTS` | 22.13.0 | 26.13.1 | yaml-language-server 2.0.0 (`engines.node`); prettier 3.10.1 needs only ≥ 14 |
| Python | `Python.Python.3.14` | 3.10 | 3.14.10 | yamllint 1.38.0 (`requires_python`) |
| PowerShell 7 | `Microsoft.PowerShell` | 7.6.0 | 7.7.0 | PowerShell Editor Services runs on supported PowerShell 7 releases; 7.4 left support in November 2026 |
| Terraform CLI | `Hashicorp.Terraform` | 1.0.0 | 1.17.2 | Used for `terraform fmt`; no pinned tool states a minimum, so 1.0.0 (first release with Terraform's language stability guarantees) |
| 7-Zip | `7zip.7zip` | None (any version) | 26.06 | Archiver required by mason.nvim on Windows; no minimum documented |
| Zig (C compiler) | `zig.zig` | 0.17.1 | 0.17.1 | Proposed in ADR-014; minimum equals tested until proven otherwise |

PowerShell 7 is used **only** to run the PowerShell language server inside Neovim. The bootstrapper itself always
runs on Windows PowerShell 5.1.

## Built into Windows 11

Used as-is; never installed or replaced by the bootstrapper.

| Component | Used by | Notes |
|---|---|---|
| `curl.exe` | nvim-treesitter, mason.nvim, blink.cmp | In Windows PowerShell 5.1, `curl` is an alias for `Invoke-WebRequest`; code must call `curl.exe` explicitly. |
| `tar.exe` | nvim-treesitter, mason.nvim | Windows ships bsdtar (3.8.9 on the test device); mason.nvim documents GNU tar. See ADR-015. |
| Windows PowerShell 5.1 | Bootstrapper | — |

## Development tools

| Component | Version | Reference |
|---|---|---|
| Pester | 5.9.1 exactly, CurrentUser scope | ADR-013, NFR-07 |

## Release compatibility check

A pin set is **known good** only after this check passes on the reference test device. It is the gate for every
release (ADR-001), and is the definition of "works out of the box."

Run against the full pinned set, on the Tier A Neovim version, in an isolated profile that never touches the
user's real configuration:

1. **Install from scratch:** lazy.nvim restores every plugin at its locked commit with no errors; Mason installs
   every pinned tool at its pinned version; every listed tree-sitter parser builds.
2. **Clean health checks:** `:checkhealth` reports no errors for lazy, mason, nvim-treesitter, and vim.lsp.
3. **Language support works** on a sample PowerShell, Terraform, and YAML file each:
   - the language server attaches;
   - tree-sitter highlighting is active;
   - the formatter runs and changes a deliberately misformatted sample;
   - the linter reports a deliberately introduced problem.
4. **Plugins load:** every plugin in PLUGINS.md loads without errors or deprecation warnings at startup.
5. **No drift:** after the run, `lazy-lock.json` is unchanged and matches PLUGINS.md.

How the check is automated is defined in the phase documents (Phase 05 builds it; Phase 07 runs it for release).

## Reference test device

The device the first release is verified on (ADR-012). Recorded so results can be reproduced.

| Item | Value |
|---|---|
| OS | Windows 11 Pro 10.0.26200, x64 |
| Windows PowerShell | 5.1.26100 |
| Already installed (2026-11-25) | Neovim 0.12.6 (machine scope), Git 2.56.0, Node.js 24.18.0, Python 3.14.6, Terraform 1.16.6 |
| Not installed (2026-11-25) | PowerShell 7, 7-Zip, Zig, tree-sitter-cli |

The installed versions are newer than the minimums but not identical to the tested versions, which exercises the
"present and acceptable, leave unchanged" path (FR-21).

## Windows PowerShell 5.1 coding constraints

Code must run on Windows PowerShell 5.1. Not available or behaving differently in 5.1:

- No pipeline chain operators (`&&`, `||`), ternary (`? :`), null-coalescing (`??`, `??=`), or null-conditional
  (`?.`, `?[]`) operators.
- No `ForEach-Object -Parallel`, `ConvertFrom-Json -AsHashtable`, or `Join-Path -AdditionalChildPath`.
- No `$IsWindows` / `$IsLinux` automatic variables.
- `Set-Content` / `Add-Content` default to the ANSI code page, and `-Encoding UTF8` writes a BOM. Files the
  bootstrapper writes (including Lua configuration) must be written as UTF-8 **without** a BOM, e.g. with
  `[System.IO.File]::WriteAllText` and `New-Object System.Text.UTF8Encoding $false`.
- `curl` is an alias for `Invoke-WebRequest`; use `curl.exe`.

## Known compatibility issues

To be resolved in the phase that owns them; none may be worked around silently.

1. **7-Zip is not on PATH.** The 7-Zip installer does not add itself to PATH, but mason.nvim looks for `7z` on PATH.
   A way to expose it to Neovim without changing unrelated settings must be chosen (Phase 03/05).
2. **Python Store alias.** Windows can provide a `python.exe` App Execution Alias that opens the Microsoft Store
   instead of running Python. Detection must not treat that stub as an installed Python (Phase 03).
3. **PATH refresh.** Programs installed by WinGet during a run are not on the current session's PATH until it is
   refreshed (Phase 03).
4. **Old versions disappearing from WinGet.** Installing a tested version, and reinstalling a previous Neovim on
   rollback (FR-61), rely on WinGet still offering that version. Failure to find it must be reported clearly
   (Phase 03/06).
5. **lazy.nvim and luarocks.** lazy.nvim enables luarocks support by default. No approved plugin needs it, so it
   must be disabled to keep health checks clean (Phase 05).

## Open questions

None. Unresolved items are tracked under Known compatibility issues and the Proposed ADRs in DECISIONS.md.

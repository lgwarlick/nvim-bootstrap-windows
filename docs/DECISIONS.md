# Architectural Decisions

Accepted decisions must be followed (see AGENTS.md). Proposed decisions are not yet binding; they must be confirmed
(usually by the release compatibility check) and then marked Accepted or replaced.

Decisions are never deleted. A changed decision is marked **Superseded** and links to its replacement.

**Statuses:** Proposed · Accepted · Superseded

| ID | Decision | Status |
|---|---|---|
| [ADR-001](#adr-001-each-release-is-a-frozen-collection) | Each release is a frozen collection | Accepted |
| [ADR-002](#adr-002-release-versioning) | Release versioning | Accepted |
| [ADR-003](#adr-003-neovim-011-minimum) | Neovim 0.11 minimum | Superseded by ADR-004 |
| [ADR-004](#adr-004-neovim-012x-with-nvim-treesitter-main) | Neovim 0.12.x with nvim-treesitter `main` | Accepted |
| [ADR-005](#adr-005-per-user-install-without-admin-rights) | Per-user install without admin rights | Superseded by ADR-006 |
| [ADR-006](#adr-006-require-an-elevated-session) | Require an elevated session | Accepted |
| [ADR-007](#adr-007-two-tier-dependency-management) | Two-tier dependency management | Accepted |
| [ADR-008](#adr-008-plugin-pinning-and-restore-only-installs) | Plugin pinning and restore-only installs | Accepted |
| [ADR-009](#adr-009-pin-mason-registry-and-tools) | Pin Mason registry and tools | Accepted |
| [ADR-010](#adr-010-language-toolchain) | Language toolchain | Accepted |
| [ADR-011](#adr-011-rollback-scope) | Rollback scope | Superseded by ADR-020 |
| [ADR-012](#adr-012-x64-only-for-the-first-release) | x64 only for the first release | Accepted |
| [ADR-013](#adr-013-pester-version) | Pester version | Accepted |
| [ADR-014](#adr-014-c-compiler-zig) | C compiler: Zig | Proposed |
| [ADR-015](#adr-015-archive-tools-for-mason) | Archive tools for Mason | Proposed |
| [ADR-016](#adr-016-backup-location) | Backup location | Accepted |
| [ADR-017](#adr-017-powershell-7-for-the-powershell-language-server) | PowerShell 7 for the PowerShell language server | Accepted |
| [ADR-018](#adr-018-pins-are-data-files-validated-against-documents) | Pins are data files, validated against documents | Accepted |
| [ADR-019](#adr-019-neovim-configuration-split-into-lua-modules) | Neovim configuration split into Lua modules | Accepted |
| [ADR-020](#adr-020-rollback-scope-and-method) | Rollback scope and method | Accepted |
| [ADR-021](#adr-021-windows-sandbox-for-end-to-end-tests) | Windows Sandbox for end-to-end tests | Accepted |
| [ADR-022](#adr-022-releases-are-github-releases-from-tags-on-main) | Releases are GitHub Releases from tags on main | Accepted |

---

## ADR-001: Each release is a frozen collection

- **Status:** Accepted (2026-11-23)
- **Context:** Plugins, Mason tools, and Neovim release independently. Installing "latest" produces combinations
  nobody has tested and makes installs non-reproducible.
- **Decision:** Every project release ships one fixed collection: an exact Neovim version, exact plugin commits,
  and exact Mason tool versions. A collection is "known good" only after passing the release compatibility check.
  Newer versions arrive only by cutting a new project release, never by updating in place.
- **Consequences:** Installs are reproducible (FR-01). Users wanting newer plugins wait for a release. Each release
  needs a compatibility check.

## ADR-002: Release versioning

- **Status:** Accepted (2026-11-23)
- **Context:** Release numbers should tell users how big a change is, and the riskiest change is a new Neovim
  baseline.
- **Decision:** Semantic versioning, defined for this project as:
  - **MAJOR** — Neovim minor version changes (e.g. 0.12 → 0.13).
  - **MINOR** — Neovim patch update (e.g. 0.12.6 → 0.12.7), compatible plugin or tool updates, or an added plugin.
  - **PATCH** — Bootstrapper fixes only; no pinned version changes.
- **Consequences:** Pin changes are never shipped as a PATCH. Changelog entries must state which pins changed.

## ADR-003: Neovim 0.11 minimum

- **Status:** Superseded by [ADR-004](#adr-004-neovim-012x-with-nvim-treesitter-main) (2026-11-23)
- **Context:** Current nvim-lspconfig and mason-lspconfig.nvim require Neovim's built-in `vim.lsp.config`
  (0.11+).
- **Decision:** Support Neovim 0.11 and later.
- **Why superseded:** nvim-treesitter has no version supporting both 0.11 and 0.12. Its `master` branch is frozen
  and supports only 0.10–0.11; its `main` branch requires 0.12+.

## ADR-004: Neovim 0.12.x with nvim-treesitter `main`

- **Status:** Accepted (2026-11-23)
- **Context:** See ADR-003. The current WinGet Neovim release is 0.12.6.
- **Decision:** Target Neovim 0.12.x and the actively developed nvim-treesitter `main` branch. The exact Neovim
  version per release is in COMPATIBILITY.md.
- **Consequences:** Adds tree-sitter-cli (≥ 0.26.1) and a C compiler as dependencies (ADR-007, ADR-014). Neovim
  0.11 is not supported.

## ADR-005: Per-user install without admin rights

- **Status:** Superseded by [ADR-006](#adr-006-require-an-elevated-session) (2026-11-23)
- **Decision:** Install Neovim per-user; require no administrator rights.
- **Why superseded:** The WinGet `Neovim.Neovim` package provides only a machine-scope MSI (installs to
  `%ProgramFiles%\Neovim`, depends on the machine-scope VC++ runtime). Installing Neovim via WinGet, an original
  requirement, therefore needs administrator rights.

## ADR-006: Require an elevated session

- **Status:** Accepted (2026-11-23)
- **Context:** See ADR-005. Several shared dependencies (e.g. Node.js LTS, 7-Zip) are also machine-scope
  installers.
- **Decision:** The bootstrapper runs in an elevated PowerShell session started by the account that will use Neovim,
  and checks for elevation at startup (NFR-02).
- **Consequences:**
  - If an administrator elevates with a *different* account, user paths would resolve to that account's profile.
    Running as the target user is therefore a documented precondition.
  - Configuration and plugin files are created by an elevated process. They inherit the profile's permissions, so
    unelevated Neovim should be able to read and update them; integration tests must confirm this.

## ADR-007: Two-tier dependency management

- **Status:** Accepted (2026-11-23)
- **Context:** Pinning everything exactly would mean upgrading or downgrading software the user already has,
  which breaks the safety rules "never modify unrelated applications" and "never upgrade dependencies outside
  approved scope."
- **Decision:**
  - **Tier A — release-owned, exact version:** Neovim, tree-sitter-cli, Mason registry and Mason tools.
  - **Tier B — shared, tested minimum:** Git, Node.js, Python, PowerShell 7 (ADR-017), Terraform CLI, 7-Zip,
    C compiler. If missing,
    install the release's tested version via WinGet. If present at or above the minimum, leave unchanged. If below
    the minimum, stop (FR-22).
- **Consequences:** Fresh installs are reproducible; existing machines may run newer Tier B versions than were
  tested. Versions and WinGet IDs are in COMPATIBILITY.md.

## ADR-008: Plugin pinning and restore-only installs

- **Status:** Accepted (2026-11-23)
- **Decision:**
  - Every plugin is pinned to an exact commit, selected using the policy in PLUGINS.md.
  - `src/config/lazy-lock.json` is the file lazy.nvim enforces; PLUGINS.md records the same commits for review,
    and a validation check confirms they match.
  - The bootstrapper runs `Lazy! restore` only — never `update` or `sync` — and disables lazy.nvim's update
    checker. lazy.nvim's own initial clone checks out its locked commit.
  - Optional plugin dependencies are excluded unless approved (`nvim-web-devicons` and `friendly-snippets` are not
    approved).
- **Consequences:** Plugin commits are listed in two files; the validation check keeps them from drifting.

## ADR-009: Pin Mason registry and tools

- **Status:** Accepted (2026-11-23)
- **Context:** Mason installs the newest tool versions by default, and its package registry changes daily.
- **Decision:** Pin the Mason registry to a release tag and install each Mason tool as `name@version`. Pins are in
  PLUGINS.md.
- **Consequences:** Tool versions only change with a project release.

## ADR-010: Language toolchain

- **Status:** Accepted (2026-11-23)
- **Decision:**

  | Language | Language server | Formatter | Linter |
  |---|---|---|---|
  | PowerShell | powershell_es | PowerShell Editor Services (built in) | PSScriptAnalyzer (via powershell_es) |
  | Terraform | terraformls | `terraform fmt` (Terraform CLI) | tflint |
  | YAML | yamlls | prettier | yamllint |

- **Consequences:** yamlls and prettier require Node.js; yamllint requires Python; `terraform fmt` requires the
  Terraform CLI. All are Tier B dependencies.

## ADR-011: Rollback scope

- **Status:** Superseded by [ADR-020](#adr-020-rollback-scope-and-method) (2026-11-25)
- **Decision:** On failure, restore the Neovim configuration and plugin data from backup. If the run changed the
  Neovim version, reinstall the previous version via WinGet. Never uninstall Neovim or Tier B dependencies. Never
  delete backups automatically. Details are in ROLLBACK.md.
- **Consequences:** The bootstrapper must record the Neovim version it found before changing it. Restoring an older
  Neovim requires that version to still be available from WinGet.

## ADR-012: x64 only for the first release

- **Status:** Accepted (2026-11-23)
- **Context:** The development machine is the test device for the first release, and it is x64.
- **Decision:** Support x64 only (NFR-08). Other architectures (e.g. ARM64) may be added in later releases; the
  plugins and WinGet packages in use also publish ARM64 builds.
- **Consequences:** Adding an architecture requires running the release compatibility check on it.

## ADR-013: Pester version

- **Status:** Accepted (2026-11-25)
- **Context:** The only Pester on the host is the Windows built-in 3.4.0, which uses legacy syntax. Pester 5.9.1
  (2026-08-11) is the newest 5.x release. Pester 6.2.0 (2026-09-09) also supports Windows PowerShell 5.1 but was
  not chosen: Pester 5 syntax is mature and widely documented.
- **Decision:** Pester 5.9.1 exactly, installed side by side in CurrentUser scope as a development prerequisite
  (NFR-07). The built-in 3.4.0 is left untouched, and test runners import the pinned version explicitly.
- **Consequences:** Moving to Pester 6 is a future decision and would require migrating the test suite.

## ADR-014: C compiler: Zig

- **Status:** Proposed
- **Context:** nvim-treesitter `main` builds parsers with tree-sitter-cli, which needs a C compiler. LLVM's WinGet
  package is a machine-scope installer; Zig (`zig.zig`) is a portable single binary.
- **Proposed decision:** Use Zig as the C compiler (Tier B).
- **Open:** Not yet proven that tree-sitter-cli can build parsers with Zig on Windows. The release compatibility
  check confirms or rejects this. Fallback: LLVM (`LLVM.LLVM`).

## ADR-015: Archive tools for Mason

- **Status:** Proposed
- **Context:** On Windows, mason.nvim documents needing GNU tar plus an archiver such as 7-Zip. Windows 11's built-in
  `tar.exe` is bsdtar, not GNU tar.
- **Proposed decision:** Install 7-Zip (Tier B). Use Windows' built-in `tar.exe` if Mason accepts it; otherwise
  decide how to provide GNU tar (for example, the copy bundled with Git for Windows).
- **Open:** Whether Mason works with bsdtar is confirmed by the release compatibility check.

## ADR-016: Backup location

- **Status:** Accepted (2026-11-25)
- **Context:** Backups must survive a failed run and must never be deleted automatically (FR-62).
- **Decision:** Store backups under `%LOCALAPPDATA%\nvim-bootstrap\backups\<timestamp>\`, outside the folders
  being replaced. Keep all backups; the user removes old ones manually. Backup contents and manifest format are
  defined in ROLLBACK.md.
- **Consequences:** Backups accumulate over time. A user-initiated cleanup command could be added in a later release.

## ADR-017: PowerShell 7 for the PowerShell language server

- **Status:** Accepted (2026-11-25)
- **Context:** nvim-lspconfig starts PowerShell Editor Services with `pwsh` (PowerShell 7) by default. PowerShell
  Editor Services v4.7.0 targets supported PowerShell 7 releases and supports Windows PowerShell 5.1 only on a
  best-effort basis; running it under 5.1 also needs an execution policy override. The reference test device has
  no PowerShell 7, so PowerShell language support would fail out of the box.
- **Decision:** Add PowerShell 7 (`Microsoft.PowerShell`) as a Tier B dependency and run the PowerShell language
  server on it. The bootstrapper itself still runs on Windows PowerShell 5.1.
- **Consequences:** One more shared dependency, installed machine-wide when missing. Version minimum is in
  COMPATIBILITY.md.

## ADR-018: Pins are data files, validated against documents

- **Status:** Accepted (2026-11-25)
- **Context:** Versions must be readable by code and reviewable by people, without the two drifting apart.
- **Decision:** Code reads pins only from data files: `src/ReleaseManifest.psd1` (Neovim, tree-sitter-cli, Tier B),
  `src/config/lazy-lock.json` (plugins), and `src/config/lua/config/pins.lua` (Mason registry, Mason tools, parsers).
  COMPATIBILITY.md and PLUGINS.md record the same values for review. `scripts/Invoke-Validation.ps1` fails if any
  data file and its document disagree.
- **Consequences:** Every pin change edits a data file and its document together. Pins are never hardcoded in
  functions.

## ADR-019: Neovim configuration split into Lua modules

- **Status:** Accepted (2026-11-25)
- **Context:** The original intended layout had a single `init.lua`.
- **Decision:** Split the configuration into `init.lua`, `lua/config/*.lua`, and one `lua/plugins/*.lua` file per
  plugin area. File list in ARCHITECTURE.md.
- **Consequences:** Easier to read and to change one area per release. The deployed configuration is a directory
  tree; backup and deployment treat `src/config/` as one unit.

## ADR-020: Rollback scope and method

- **Status:** Accepted (2026-11-25). Supersedes [ADR-011](#adr-011-rollback-scope).
- **Context:** ADR-011 named only configuration and `nvim-data\lazy`, but a run also replaces Mason tools and
  tree-sitter parsers; restoring plugins alone would leave a mismatched set. The Neovim WinGet package is an MSI,
  which may refuse to install an older version over a newer one.
- **Decision:**
  - Back up and restore, as one set: the configuration, `stdpath('data')\lazy`, `stdpath('data')\mason`, and
    `stdpath('data')\site\parser` and `site\queries`. Other user data (undo, swap, shada, logs) is never touched.
  - Back up by **moving** after approval, then verifying; restore by **copying** back so the backup stays intact.
    Files from a failed run are moved into the backup, never deleted. Stop if a live folder is on a different
    drive from the backup folder.
  - Reinstall the previous Neovim version on rollback. If it cannot be installed over the newer one, uninstall the
    newer Neovim immediately before reinstalling, but only after confirming WinGet still offers the previous
    version. Neovim is never uninstalled in any other situation, and shared dependencies are never uninstalled.
  - Never delete backups automatically.
- **Consequences:** Every non-trivial install starts from empty plugin and tool folders (clean, reproducible).
  Details in ROLLBACK.md.

## ADR-021: Windows Sandbox for end-to-end tests

- **Status:** Accepted (2026-11-25)
- **Context:** Some behavior can only be proven with real installs: a fresh-machine run, a real Neovim downgrade and
  rollback, and interrupted runs. AGENTS.md forbids destructive integration tests on the host. The reference test
  device (Windows 11 Pro, hypervisor running) supports Windows Sandbox, and is the test device for future releases.
- **Decision:** Run real end-to-end tests in Windows Sandbox, which starts from a clean Windows 11 each launch and is
  discarded on close. Enabling the Windows Sandbox optional feature on the reference test device is a one-time host
  change made by the project owner or with explicit approval.
- **Consequences:** Every release can be verified on a clean machine. Test setup must install WinGet inside the
  sandbox, since it is not preinstalled. The sandbox uses the host's Windows build, so it matches the reference test
  device.

## ADR-022: Releases are GitHub Releases from tags on main

- **Status:** Accepted (2026-11-25). Further release details are open in PHASE-07-release.md.
- **Context:** Releases must be easy to download and run, reproducible, and built the same way every time. Older
  releases are not supported, so there is no need to maintain several release lines.
- **Decision:**
  - A release is a GitHub Release in the public repository, built by an Azure DevOps pipeline owned by the project
    owner.
  - Each release is a tag on a commit on `main`; there are no release branches. Development branches are deleted
    after merging.
  - The pipeline runs on a merge to `main` whose commit or pull request title starts with a release prefix; the
    prefix sets how the version number is incremented, following ADR-002.
  - A validation check requires every place the version appears to match.
  - The release asset contains what is needed to run the bootstrapper, README.md, CHANGELOG.md, and a checksum file.
  - Only the latest release is supported; fixes ship in the next release.
- **Consequences:** Users always download from GitHub Releases. Prefix format, where the version is written, and
  how machine-only tests fit into the pipeline are open in PHASE-07-release.md.

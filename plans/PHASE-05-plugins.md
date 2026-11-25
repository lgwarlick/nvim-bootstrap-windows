# Phase 05 - Plugin management

## Status
Not Started

## Objective
Integrate lazy.nvim, define plugin specifications, manage plugin revisions, and configure LSP, formatting, Treesitter, and editor behavior.

## Dependencies
- Phase 01 complete
- Phase 02 complete
- Phase 03 complete
- Phase 04 complete
- The release compatibility check needs every Tier A and Tier B program installed on the reference test device
  (currently missing: PowerShell 7, 7-Zip, Zig, tree-sitter-cli). Installing them is a host change: the project owner
  approves running `bootstrap.ps1` steps 0–3 for real, or installs them manually at the versions in COMPATIBILITY.md.

## Scope

### Neovim configuration (`src/config/`)
Complete the configuration described in ARCHITECTURE.md (file map, settings, and Editor defaults):

- `lua/config/options.lua` and `keymaps.lua`: the approved Editor defaults, with the leader key set before lazy.nvim
  loads and per-language indentation.
- `lua/config/lazy.lua`: clone lazy.nvim at the commit in `lazy-lock.json`, then start it with: update checker off,
  change detection off, luarocks off (known issue 5), and missing-plugin installation off so opening the editor never
  downloads anything.
- `lua/config/pins.lua`: Mason registry tag, Mason tool versions, and tree-sitter parser list, exactly as in
  PLUGINS.md.
- `lua/plugins/*.lua`: one spec file per area; every plugin in PLUGINS.md appears in exactly one file, and no other
  plugin appears. Specs must not set a branch, tag, or version that contradicts the lockfile.
- `lazy-lock.json`: the commits in PLUGINS.md.

Per area:

| Area | Must provide |
|---|---|
| LSP | `vim.lsp.config` / `vim.lsp.enable` for powershell_es, terraformls, yamlls. Mason uses the pinned registry; nothing is installed automatically at startup. powershell_es runs on `pwsh` with the Mason-installed bundle (ADR-017). |
| Formatting | conform.nvim: PowerShell through the language server, Terraform through `terraform fmt`, YAML through prettier. Format on save, plus `<leader>f`. |
| Linting | nvim-lint: yamllint for YAML, tflint for Terraform, on open and after save. PowerShell linting comes from the language server (PSScriptAnalyzer). |
| Tree-sitter | nvim-treesitter `main`: highlighting enabled for the parsers in `pins.lua`; parsers are installed only by the bootstrapper. |
| Completion | blink.cmp `default` keymap preset, prebuilt Rust fuzzy matcher, completion kinds rendered without Nerd Font glyphs. |
| Explorer | neo-tree.nvim toggled by `<leader>e`, with icons that render without a Nerd Font. |
| Git, editing | gitsigns.nvim and nvim-autopairs with defaults. |

### Step 7 — Plugins and tools (bootstrapper)
Each runs headless Neovim through `Invoke-NeovimHeadless` with an explicit timeout, and verifies its result:

- `Invoke-PluginRestore`: `Lazy! restore`; then verify each plugin is checked out at its locked commit.
- Download blink.cmp's prebuilt fuzzy-matcher binary during this step (not at first editor start), and verify it is
  present.
- `Install-MasonTools`: install every tool in `pins.lua` at its pinned version; verify each installed version.
- `Install-TreeSitterParsers`: install the parsers in `pins.lua`; verify each parser library exists.
- **Repair mode:** if the configuration is current but plugin data is missing or incomplete, install only what is
  missing (ROLLBACK.md, When a backup is made).
- Make 7-Zip available to Mason without changing persistent environment settings (known issue 1). Candidate: add
  7-Zip's folder to `PATH` inside Neovim only (`vim.env.PATH`), for both headless and normal sessions.

### Step 8 — Verify
- `Test-NeovimSetup`: headless Neovim starts with the deployed configuration and reports no errors.

### Release compatibility check (`tests/Compatibility/`)
- Automate the check defined in COMPATIBILITY.md, run through `scripts/Invoke-Tests.ps1 -Suite Compatibility`.
- Runs in an isolated profile: `LOCALAPPDATA`, `XDG_CONFIG_HOME`, and `XDG_DATA_HOME` point into a temporary folder;
  the real configuration and data are never touched.
- Uses fixture files in `tests/Fixtures/`: a PowerShell, a Terraform, and a YAML file, each with a deliberately
  misformatted version and one with a planted lint problem.
- Produces a readable report (one line per check) used as completion and release evidence.

### Validation checks (ADR-018)
- `lazy-lock.json` commits match PLUGINS.md.
- `pins.lua` (registry, tool versions, parsers) matches PLUGINS.md.
- Every PLUGINS.md plugin appears in exactly one `lua/plugins/` file, and no unlisted plugin is referenced.

### Open items resolved in this phase (ROADMAP.md)
Each is settled by evidence from the compatibility check:

| Item | Pass → | Fail → |
|---|---|---|
| ADR-014: Zig builds parsers | Mark Accepted | Report; propose LLVM; on approval supersede ADR-014 and update COMPATIBILITY.md |
| ADR-015: Mason works with bsdtar | Mark Accepted | Report; propose a GNU tar source; on approval supersede ADR-015 |
| nui.nvim `0.4.0` with neo-tree `3.42.0` | Remove the open question in PLUGINS.md | Report; propose nui `main` commit; update pins on approval |
| conform.nvim `v9.1.0` on Neovim 0.12.6 | Remove the open question in PLUGINS.md | Report; propose a newer commit; update pins on approval |
| Known issues 1 and 5 | Mark resolved in COMPATIBILITY.md | Report and ask |

## Out of Scope
- Changing any pin, adding or removing a plugin or tool, or changing an Editor default without approval. A failing
  pin is reported with a proposed replacement, never swapped silently.
- Automatic rollback on failure in steps 6–8 (Phase 06).
- Running the bootstrapper against the real configuration on the host.

## Test Requirements
- Unit (mocked): each step 7 function's success, failure (Neovim non-zero exit or timeout), already-done (no
  change), repair-mode, and `-WhatIf` paths; verification detects a plugin at the wrong commit, a tool at the wrong
  version, and a missing parser.
- Integration (sandbox, real Neovim and network): from an empty profile, steps 4–8 produce a working setup; a second
  run makes no changes (FR-70).
- Lua configuration: loads with no errors or deprecation warnings; no Nerd Font glyphs in configured icon strings.
- Validation fixtures: each new consistency check fails on a deliberately mismatched fixture.
- The release compatibility check passes on the reference test device.

## Implementation Constraints
- Pins only from data files (ADR-018); `lazy-lock.json` must be unchanged after every run (compatibility check
  gate 5).
- `lazy.nvim` is only ever run with `restore`, never `update`, `sync`, or `clean` (ADR-008).
- Use Neovim 0.12 APIs; no deprecated `require('lspconfig').<server>.setup()`.
- Headless runs need timeouts and progress output; parser builds and Mason installs can take minutes.
- Sandboxed tests may download from the internet but must never write outside their temporary folder.

## Acceptance Criteria
- All Phase 05 tests pass, and the full suite has no regressions.
- `scripts/Invoke-Validation.ps1` passes, including the three new consistency checks.
- The release compatibility check passes on the reference test device with every gate green.
- Every open item in the table above is resolved, and DECISIONS.md, PLUGINS.md, and COMPATIBILITY.md reflect the
  outcome.
- `lazy-lock.json` matches PLUGINS.md and was not changed by any test run.

## Deliverables
- Complete `src/config/` (all files in the ARCHITECTURE.md file map) and `lazy-lock.json`
- Module functions for steps 7–8, added to `Invoke-NeovimBootstrap`
- `tests/Compatibility/` suite and language fixtures
- Three validation checks
- Updated DECISIONS.md, PLUGINS.md, and COMPATIBILITY.md for resolved items

## Completion Evidence
Pinned plugin set installs and loads successfully on the supported Neovim version

Report includes the compatibility check report from the reference test device and the outcome of every open item.

## Open questions
None.

# Plugins

The approved plugin set and pinned versions for the **current release** of this project.

Each project release ships one fixed, tested collection of plugins and tools. Moving to newer versions is done by
cutting a new project release, never by updating in place. Release numbering is defined in
[DECISIONS.md](DECISIONS.md); external program versions (Neovim, Git, Node.js, etc.) are in
[COMPATIBILITY.md](COMPATIBILITY.md).

- **Release:** 1.0.0 (unreleased)
- **Target Neovim:** 0.12.x — see [COMPATIBILITY.md](COMPATIBILITY.md)
- **Pins selected:** 2026-11-23

## Rules

- Only plugins listed here may be installed. Adding, removing, or replacing a plugin requires approval and an
  update to this file.
- Every plugin is pinned to an exact commit. `src/config/lazy-lock.json` must match the commits in this file;
  a validation check enforces this.
- The bootstrapper restores the locked set (`Lazy! restore`). It never runs `Lazy update`/`sync`, and lazy.nvim's
  update checker is disabled.
- A pin set is only "known good" after it passes the release compatibility check (headless load of the full set on
  the target Neovim version in an isolated profile). See [plans/ROADMAP.md](../plans/ROADMAP.md).

### Pin selection policy

When building a new pin set:

1. If the plugin publishes release tags, use the newest release tag.
2. Otherwise (rolling-release plugins), use the newest default-branch commit on the selection date.
3. `saghen/blink.cmp` must always be on a release tag — prebuilt fuzzy-matcher binaries are only downloaded for tags.

## Core plugins

| Plugin | Purpose | Pin | Commit |
|---|---|---|---|
| [folke/lazy.nvim](https://github.com/folke/lazy.nvim) | Plugin manager | `v11.17.5` | `85c7ff3711b730b4030d03144f6db6375044ae82` |
| [neovim/nvim-lspconfig](https://github.com/neovim/nvim-lspconfig) | LSP server configurations | `v2.13.0` | `4648fd8ba5c678d7e2db75ae44ffac269bb589d8` |
| [mason-org/mason.nvim](https://github.com/mason-org/mason.nvim) | Installs LSP servers, formatters, linters | `v2.3.1` | `2a6940af80375532e5e9e7c1f2fc6319a1b7a69d` |
| [mason-org/mason-lspconfig.nvim](https://github.com/mason-org/mason-lspconfig.nvim) | Bridges Mason and nvim-lspconfig | `v2.3.0` | `a5671269a1ddfa7790cdf97c14e600e269da550f` |
| [stevearc/conform.nvim](https://github.com/stevearc/conform.nvim) | Formatting | `v9.1.0` | `3543d000dafbc41cc7761d860cfdb24e82154f75` |
| [nvim-treesitter/nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) | Parser installation and highlighting (`main` branch) | `main` @ 2026-11-21 | `52773f0d13a0c11d0c3ef33c14ab6ecc1c17148b` |

## Quality of life plugins

| Plugin | Purpose | Pin | Commit |
|---|---|---|---|
| [saghen/blink.cmp](https://github.com/saghen/blink.cmp) | Completion | `v1.10.2` | `78336bc89ee5365633bcf754d93df01678b5c08f` |
| [nvim-neo-tree/neo-tree.nvim](https://github.com/nvim-neo-tree/neo-tree.nvim) | File explorer | `3.42.0` | `f3f3bf73414e400cf9fc13fda50f00404a8f8ab1` |
| [lewis6991/gitsigns.nvim](https://github.com/lewis6991/gitsigns.nvim) | Git change signs | `v2.1.0` | `a462f416e2ce4744531c6256252dee99a7d34a83` |
| [windwp/nvim-autopairs](https://github.com/windwp/nvim-autopairs) | Auto-close brackets/quotes | `master` @ 2026-10-10 | `3172f40c16563db871a58f20d205c710ad782311` |
| [mfussenegger/nvim-lint](https://github.com/mfussenegger/nvim-lint) | Linting | `master` @ 2026-11-19 | `6bf29b9dbdad60b38b489b23309c22ba6d4c915a` |

## Plugin dependencies

Required by a listed plugin; installed and pinned the same way.

| Plugin | Required by | Pin | Commit |
|---|---|---|---|
| [nvim-lua/plenary.nvim](https://github.com/nvim-lua/plenary.nvim) | neo-tree.nvim | `master` @ 2026-04-10 | `74b06c6c75e4eeb3108ec01852001636d85a932b` |
| [MunifTanjim/nui.nvim](https://github.com/MunifTanjim/nui.nvim) | neo-tree.nvim | `0.4.0` | `f535005e6ad1016383f24e39559833759453564e` |

Excluded optional dependencies (not approved): `nvim-tree/nvim-web-devicons` (would require a Nerd Font),
`rafamadriz/friendly-snippets`.

## Mason registry and tools

Mason installs the latest tool versions unless pinned, so both the registry and each tool are pinned.

- **Registry:** `github:mason-org/mason-registry@2026-11-23-caring-song`

| Mason package | Role | Language | Version | Runtime needed |
|---|---|---|---|---|
| `powershell-editor-services` (`powershell_es`) | LSP, formatting, PSScriptAnalyzer linting | PowerShell | `v4.7.0` | Windows PowerShell |
| `terraform-ls` (`terraformls`) | LSP | Terraform | `v0.39.1` | — |
| `yaml-language-server` (`yamlls`) | LSP | YAML | `2.0.0` | Node.js |
| `prettier` | Formatter | YAML | `3.10.1` | Node.js |
| `tflint` | Linter | Terraform | `v0.66.0` | — |
| `yamllint` | Linter | YAML | `1.38.0` | Python |

Terraform formatting uses `terraform fmt` from the Terraform CLI, which is a WinGet program, not a Mason package.

## Tree-sitter parsers

Parsers installed: `powershell`, `terraform`, `hcl` (required by `terraform`), `yaml`.

Parser revisions are pinned by the nvim-treesitter commit above (`lua/nvim-treesitter/parsers.lua`), so no separate
pin is needed. Neovim 0.12 bundles parsers for Lua, Vim, Vimdoc, Markdown, C, and Query.

## Upstream requirements

Minimum Neovim versions each plugin documents at its pinned version. All are satisfied by Neovim 0.12.x.

| Plugin | Documented requirement |
|---|---|
| nvim-treesitter (`main`) | Neovim ≥ 0.12.0, tree-sitter-cli ≥ 0.26.1, C compiler, `tar`, `curl` |
| nvim-lspconfig | Neovim ≥ 0.11.3 |
| mason-lspconfig.nvim | Neovim ≥ 0.11.0, mason.nvim ≥ 2.0.0 |
| mason.nvim | Neovim ≥ 0.10.0; on Windows: PowerShell, Git, GNU tar, and 7-Zip (or another supported archiver) |
| blink.cmp | Neovim ≥ 0.10; `curl` and `git` for prebuilt binaries |
| conform.nvim | Neovim ≥ 0.10 |
| gitsigns.nvim | Neovim ≥ 0.9.0 |
| nvim-lint | Neovim ≥ 0.9.5 |
| lazy.nvim | Neovim ≥ 0.8.0 (LuaJIT build) |
| neo-tree.nvim | Neovim ≥ 0.8 |
| nvim-autopairs | Neovim ≥ 0.7 |
| nui.nvim | Neovim ≥ 0.5.0 |
| plenary.nvim | No stated minimum |

These are the requirements the plugins *document*. Whether this combination actually works together is proven by
the release compatibility check, not by this table.

## Open questions

- **nui.nvim pin:** the policy selects tag `0.4.0` (2025-05-03), which is 10 commits behind `main`. neo-tree
  `3.42.0` (2026-09-01) may depend on newer nui code. Confirm in the compatibility check; fall back to
  `main` @ `10fc361835c856ba4233ef5ea135b919bf3dce97` if it fails.
- **conform.nvim pin:** `v9.1.0` (2025-08-21) is the newest tag but predates Neovim 0.12 by months. Confirm in the
  compatibility check.
- **GNU tar for Mason:** Windows 11 ships bsdtar as `tar.exe`, while Mason documents GNU tar. Whether Mason accepts
  bsdtar must be confirmed; resolution belongs in COMPATIBILITY.md.

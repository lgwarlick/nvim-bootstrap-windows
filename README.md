# nvim-bootstrap-windows

Neovim bootstrapping for Windows: a PowerShell bootstrapper that installs Neovim and a pinned, tested plugin
configuration that works out of the box for PowerShell, Terraform, and YAML development.

> **Status: in development.** No release is available yet. Release 1.0.0 is being built phase by phase; see
> [plans/ROADMAP.md](plans/ROADMAP.md).

## What it does

- Installs Neovim with WinGet, plus the programs the configuration needs (Git, Node.js, Python, PowerShell 7,
  Terraform, 7-Zip, a C compiler, tree-sitter-cli). Programs you already have are left alone if they are new enough.
- Deploys a Neovim configuration managed by lazy.nvim, with language servers, formatting, linting, and syntax
  highlighting for PowerShell, Terraform, and YAML.
- Installs exactly the plugin and tool versions tested for the release. Each release is one fixed, tested collection;
  newer versions arrive only with a new release.
- Backs up your existing Neovim configuration before replacing it, asks before overwriting it, and restores it
  automatically if anything fails.
- Supports `-WhatIf` to preview every change, and does nothing on a rerun when everything is already in place.

## Requirements

- Windows 11, x64
- Windows PowerShell 5.1, run as administrator (by the account that will use Neovim)
- WinGet
- Internet access

Exact versions: [docs/COMPATIBILITY.md](docs/COMPATIBILITY.md).

## Documentation

| Document | Contents |
|---|---|
| [docs/REQUIREMENTS.md](docs/REQUIREMENTS.md) | What the bootstrapper must do |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | How it is built, execution flow, exit codes, editor defaults |
| [docs/COMPATIBILITY.md](docs/COMPATIBILITY.md) | Supported platform, pinned and minimum versions, release compatibility check |
| [docs/PLUGINS.md](docs/PLUGINS.md) | Approved plugins, Mason tools, and their pinned versions |
| [docs/ROLLBACK.md](docs/ROLLBACK.md) | Backups, automatic rollback, manual recovery |
| [docs/DECISIONS.md](docs/DECISIONS.md) | Architectural decisions and their reasons |
| [docs/UPGRADING.md](docs/UPGRADING.md) | Upgrade guides between major versions |
| [plans/ROADMAP.md](plans/ROADMAP.md) | Implementation phases |
| [CHANGELOG.md](CHANGELOG.md) | Changes by release |

Contributors and agents: start with [AGENTS.md](AGENTS.md).

## License

No license has been chosen yet (tracked in [plans/PHASE-07-release.md](plans/PHASE-07-release.md)).

# Requirements

Source of truth for what this project must do. Other documents describe *how* (ARCHITECTURE.md), *which versions*
(COMPATIBILITY.md, PLUGINS.md), and *why* (DECISIONS.md); they must not contradict this file.

Each requirement has an ID that phase documents and tests reference. "Verified by" states how compliance is
demonstrated.

## Assumptions

- WinGet is installed and usable by the current user.
- The machine has internet access (WinGet, GitHub, Mason registry, npm, PyPI).

## Functional requirements

### Release model

| ID | Requirement | Verified by |
|---|---|---|
| FR-01 | Each project release installs one fixed collection of Neovim, plugins, and tools. Running the same release on any supported machine installs the same versions. | Pins exist for every component (PLUGINS.md, COMPATIBILITY.md); release compatibility check |
| FR-02 | Running a newer release over an install from an older release moves the machine to the newer release's collection, applying the same backup and rollback protections as a first install. | Integration test: upgrade scenario |

### Neovim installation

| ID | Requirement | Verified by |
|---|---|---|
| FR-10 | Install Neovim using WinGet, at the exact version pinned for the release. The WinGet package installs in machine scope only. | Unit tests (WinGet mocked); integration test |
| FR-11 | Detect an existing Neovim installation and its version before acting. If the pinned version is already installed, make no change. | Unit tests: present/absent/version cases |
| FR-12 | If an installed Neovim is older than the pinned version, install the pinned version. If it is newer, stop and make no changes unless the user explicitly approves installing the pinned (older) version, by an interactive confirmation prompt or the `-AllowNeovimDowngrade` switch. `-Force` never approves a downgrade. | Unit tests: older/newer cases; prompt / switch / `-Force` only |
| FR-13 | If Neovim is found on PATH but was not installed by WinGet (`Neovim.Neovim`), stop before making any changes and explain why. | Unit test |

### Dependencies

| ID | Requirement | Verified by |
|---|---|---|
| FR-20 | **Release-owned dependencies** (Neovim, tree-sitter-cli, Mason registry and Mason tools) are installed at the exact versions pinned for the release. | Unit tests; release compatibility check |
| FR-21 | **Shared dependencies** (Git, Node.js, Python, PowerShell 7, Terraform CLI, 7-Zip, C compiler) are detected first. If missing, install the release's tested version via WinGet. If present at or above the documented minimum, leave unchanged. | Unit tests: missing / present-ok cases |
| FR-22 | If a shared dependency is present but below the documented minimum, stop with a message naming the dependency, the found version, and the required minimum. Never upgrade or downgrade it. | Unit test: below-minimum case |

### Configuration deployment

| ID | Requirement | Verified by |
|---|---|---|
| FR-30 | Deploy the project's Neovim configuration to the user's standard Neovim configuration location, resolved from the environment. | Unit tests: path resolution |
| FR-31 | Detect an existing Neovim configuration before deploying. | Unit tests |
| FR-32 | Before overwriting an existing configuration, create a backup, verify it, and obtain approval. Do not overwrite if any of these fail. | Unit tests; integration test with isolated paths |
| FR-33 | Approval is given by an interactive confirmation prompt, or by the `-Force` switch for unattended runs. Without either, stop safely before overwriting and make no changes. | Unit tests: prompt accepted / declined / `-Force` / non-interactive without `-Force` |
| FR-34 | Before backing up or deploying, if any Neovim process is running, stop without making changes and ask the user to close Neovim. | Unit test |

### Plugin management

| ID | Requirement | Verified by |
|---|---|---|
| FR-40 | Manage plugins with lazy.nvim. | Release compatibility check |
| FR-41 | Install only the approved plugins in PLUGINS.md, at their pinned commits. Never update plugins beyond the pins. | Validation: lockfile matches PLUGINS.md; compatibility check |

### Language support

| ID | Requirement | Verified by |
|---|---|---|
| FR-50 | Provide language server, formatting, linting, and syntax highlighting for PowerShell, Terraform, and YAML, using the tools listed in PLUGINS.md. | Release compatibility check (headless) |

### Rollback and recovery

| ID | Requirement | Verified by |
|---|---|---|
| FR-60 | If configuration deployment or plugin installation fails, restore the previous configuration and plugin data from the backup. | Integration tests: injected failures |
| FR-61 | If the run changed the Neovim version and a later step fails, reinstall the previously installed Neovim version. | Integration test (WinGet mocked) |
| FR-62 | Never delete backups automatically. | Unit tests; code review |
| FR-63 | If the newest backup belongs to a run that never finished (for example, interrupted by Ctrl+C or power loss), stop before making changes, report the interrupted run and its backup path, and explain how to restore it. | Unit tests; end-to-end test |

Backup and recovery details are defined in ROLLBACK.md.

### Idempotency and preview

| ID | Requirement | Verified by |
|---|---|---|
| FR-70 | Rerunning the same release on a machine already in the desired state makes no changes. | Integration test: second run reports no changes |
| FR-71 | Every operation that changes the system supports `-WhatIf`, reporting what would change without changing anything. | Unit tests per function; integration test of full run with `-WhatIf` |

### Logging

| ID | Requirement | Verified by |
|---|---|---|
| FR-80 | Each run (except `-WhatIf` runs) writes a log file recording detections, changes, backups, failures, and rollback actions, and prints its path. Logs are never deleted automatically. | Unit tests; integration test |

## Nonfunctional requirements

| ID | Requirement | Verified by |
|---|---|---|
| NFR-01 | Runs on Windows 11 with Windows PowerShell 5.1. Code uses no PowerShell 7-only syntax. | Tests run under 5.1; static check |
| NFR-02 | Runs in an elevated PowerShell session, started by the account that will use Neovim (user paths resolve from that account's profile). The bootstrapper checks for elevation at startup and stops with a clear message if not elevated. | Unit tests: elevated / not elevated |
| NFR-03 | No hardcoded user-specific paths; all paths are resolved from the environment. | Static check; code review |
| NFR-04 | Never deletes user files or folders, never modifies the Windows registry directly, never modifies unrelated applications or settings. | Code review; integration tests |
| NFR-05 | Failures are handled explicitly and reported with a message identifying the failed step. Unexpected errors are never suppressed. | Unit tests: failure cases |
| NFR-06 | Tested with Pester 5 (unit and integration). Unit tests mock all external commands; integration tests use isolated temporary paths and are non-destructive to the host. Tests cover success, failure, idempotency, and recovery. | Test suite |
| NFR-07 | Pester 5 is a development prerequisite installed in CurrentUser scope. The bootstrapper never installs or modifies Pester. | Code review |
| NFR-08 | Supports the x64 CPU architecture only. On any other architecture, stop with a clear message before making changes. Other architectures may be added in later releases. | Unit tests: architecture check |
| NFR-09 | The bootstrapper returns distinct exit codes: success (including nothing to change); failed with no changes, or with every change rolled back except shared dependencies, which are kept and reported (ADR-020); failed with rollback also failed (manual recovery needed); stopped awaiting approval or an unmet precondition. Code values are defined in ARCHITECTURE.md. | Unit/integration tests per outcome |

## Out of scope

- Operating systems other than Windows 11.
- CPU architectures other than x64 (for this release).
- Uninstalling Neovim or any dependency.
- Plugins not listed in PLUGINS.md, and terminal/font configuration.

## Open questions

None.

# Changelog

All notable changes to this project are recorded here, newest first.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and version numbers follow this
project's versioning rules (see ADR-002 in [docs/DECISIONS.md](docs/DECISIONS.md)): MAJOR for a Neovim minor
version change, MINOR for a Neovim patch or compatible plugin and tool updates, PATCH for bootstrapper fixes only.

Each release lists changes under these headings, as needed: **Added**, **Changed**, **Deprecated**, **Removed**,
**Fixed**, **Security**, and **Pins**. Every release that changes a pinned version (Neovim, tree-sitter-cli, a plugin,
the Mason registry, or a Mason tool) lists each change under **Pins** as `name: old → new` (ADR-002).
A major release also links to its section in [docs/UPGRADING.md](docs/UPGRADING.md).

## [Unreleased]

### Added

- Project documentation for release 1.0.0 (Phase 01): requirements, architecture, compatibility, rollback,
  architectural decisions, approved plugins, roadmap, phase plans 01–06, and a work-in-progress plan for Phase 07.
- `docs/UPGRADING.md` placeholder and empty `azure-pipelines.yml`.
- Test runner `scripts/Invoke-Tests.ps1` (Pester 5.9.1, suite selection, single file or test, `NotImplemented` tag
  exclusion) with its own unit and integration tests; Pester prerequisite instructions in README.md.

### Changed

- `AGENTS.md` re-encoded from UTF-16 to UTF-8 and typos corrected; no rule changes.
- `docs/PLUGINS.md` rewritten with repository owners, pinned versions, plugin dependencies, and Mason tools.
- Work tracking moved to GitHub issues and milestones; issue and pull request templates added.
- Neovim configuration and data paths are computed from the environment when Neovim is not installed, so
  `-WhatIf` reports concrete paths on a fresh machine (ADR-023).
- Every check and approval that does not depend on an install now runs in step 0, so exit code 3 always means
  nothing changed. Neovim running is checked again before any write (exit 1). Exit code 1 lists shared
  dependencies kept from earlier in the run (ADR-024, NFR-09).
- FR-34 now stops every run while Neovim is open, including reruns that would change nothing and plugin repair
  in step 7. A rerun with Neovim open exits 3 instead of reporting no changes (FR-70).

### Pins

- Initial pin set selected: 13 plugins, Mason registry `2026-11-23-caring-song`, and 6 Mason tools (2026-11-23);
  Neovim 0.12.6, tree-sitter-cli 0.27.2, and shared dependency versions (2026-11-25). Details in [docs/COMPATIBILITY.md](docs/COMPATIBILITY.md) and
  [docs/PLUGINS.md](docs/PLUGINS.md). Not yet proven by the release compatibility check (Phase 05).

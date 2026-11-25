# Roadmap

Implementation phases for release 1.0.0, in order. Each phase's scope, acceptance criteria, and deliverables are in
its own document; this file only sequences the phases and assigns work to them.

Rules (from AGENTS.md): work only on the phase explicitly selected, stop at its boundary, and do not start the next
phase without authorization.

## Phases

| # | Phase | Document | Depends on | Status |
|---|---|---|---|---|
| 01 | Foundation and architecture | [PHASE-01-foundation.md](PHASE-01-foundation.md) | — | In progress |
| 02 | Pester test framework | [PHASE-02-tests.md](PHASE-02-tests.md) | 01 | Not started |
| 03 | Neovim and dependency installation | [PHASE-03-installation.md](PHASE-03-installation.md) | 01, 02 | Not started |
| 04 | Configuration deployment and backup | [PHASE-04-configuration.md](PHASE-04-configuration.md) | 01–03 | Not started |
| 05 | Plugin management | [PHASE-05-plugins.md](PHASE-05-plugins.md) | 01–04 | Not started |
| 06 | Integration, recovery, and rollback | [PHASE-06-validation.md](PHASE-06-validation.md) | 01–05 | Not started |
| 07 | Release and maintenance | [PHASE-07-release.md](PHASE-07-release.md) | 01–06 | Not started |

Phases are strictly sequential. A phase's status changes to **Complete** only when its completion evidence is
reported and accepted.

## What each phase delivers

| # | Summary |
|---|---|
| 01 | All governing documents written and approved. No code. |
| 02 | Pester 5.9.1 test runner, validation runner, module skeleton, mocking helpers for WinGet and Neovim, fixtures, and failing tests for Phase 03. |
| 03 | Preflight checks, WinGet and Neovim wrappers, dependency detection and installation (Tier A and Tier B), session PATH refresh, release manifest, run log, exit codes. |
| 04 | Neovim path resolution, existing-config detection, approval, backup by move with verification, configuration structure, and deployment. |
| 05 | lazy.nvim and the pinned plugin set, Mason tools, tree-sitter parsers, language support, editor options and key mappings, and the release compatibility check. |
| 06 | Full orchestrated run, automatic rollback (including Neovim downgrade), idempotency and upgrade scenarios, manual restore. |
| 07 | Release checklist, compatibility check run, changelog, README usage, 1.0.0 tag, and the procedure for building the next release. |

## Requirement assignment

Each requirement is implemented and tested in the phase listed. Later phases may re-test it but do not re-implement
it.

| Phase | Requirements |
|---|---|
| 02 | NFR-06, NFR-07 |
| 03 | FR-10, FR-11, FR-12, FR-13, FR-20 (Neovim, tree-sitter-cli), FR-21, FR-22, FR-71 (for its functions), FR-80, NFR-01, NFR-02, NFR-03, NFR-05, NFR-08, NFR-09 (codes 0, 1, 3) |
| 04 | FR-30, FR-31, FR-32, FR-33, FR-34, FR-62, FR-71 (for its functions) |
| 05 | FR-01, FR-20 (Mason registry and tools), FR-40, FR-41, FR-50, FR-71 (for its functions) |
| 06 | FR-02, FR-60, FR-61, FR-70, NFR-04, NFR-09 (code 2, all codes end to end), FR-71 (full run) |
| 07 | Release gate for FR-01 (compatibility check passes on the reference test device) |

NFR-01, NFR-03, NFR-04, and NFR-05 apply to all code in every phase; the phase listed is where their automated
checks are first added.

## Open items assigned to phases

| Item | Source | Phase |
|---|---|---|
| ADR-014: confirm Zig builds tree-sitter parsers, or fall back to LLVM | DECISIONS.md | 05 |
| ADR-015: confirm Mason works with Windows `tar.exe` (bsdtar) | DECISIONS.md | 05 |
| nui.nvim and conform.nvim pins confirmed | PLUGINS.md | 05 |
| Known issue 1: expose 7-Zip to Mason without changing unrelated settings | COMPATIBILITY.md | 05 |
| Known issue 2: ignore the Python Store alias in detection | COMPATIBILITY.md | 03 |
| Known issue 3: refresh session PATH after installs | COMPATIBILITY.md | 03 |
| Known issue 4: report when a WinGet version is no longer available | COMPATIBILITY.md | 03 (installs), 06 (rollback) |
| Known issue 5: disable lazy.nvim luarocks support | COMPATIBILITY.md | 05 |
| Neovim MSI in-place downgrade behavior | ROLLBACK.md | 06 |
| Unelevated Neovim can use files created by the elevated run | ARCHITECTURE.md risks | 06 |

## Release 1.0.0 exit criteria

- Phases 01–07 complete.
- Every requirement in REQUIREMENTS.md has passing tests in its assigned phase.
- No Proposed decision remains in DECISIONS.md for anything the release uses.
- The release compatibility check (COMPATIBILITY.md) passes on the reference test device.

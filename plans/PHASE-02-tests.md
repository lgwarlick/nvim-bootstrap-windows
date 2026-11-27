# Phase 02 - Pester test framework

## Status
Tracked in the GitHub milestone **Phase 02 - Pester test framework** (see [ROADMAP.md](ROADMAP.md)).

## Objective
Create test helpers, fixtures, mocks, test execution commands, and initial failing tests for expected installation behavior.

## Dependencies
- Phase 01 Complete
- Pester 5.9.1 installed in CurrentUser scope on the development machine (ADR-013). This is a host change: the
  project owner installs it, or explicitly approves the agent doing so. See "Pester prerequisite" below.

## Scope

### Pester prerequisite
- Document how to install Pester 5.9.1 side by side with the built-in 3.4.0 in README.md, including the
  Windows PowerShell 5.1 specifics: the NuGet provider prompt, and `-SkipPublisherCheck` (needed because the
  built-in Pester is signed with a different certificate). Exact commands are verified when written.

### Test runner — `scripts/Invoke-Tests.ps1`
- Imports Pester with `-RequiredVersion 5.9.1`. If that version is missing, stops with the install instructions
  and a non-zero exit code. Never falls back to Pester 3.4.0.
- Selects suites by folder: `Unit`, `Integration`, `Compatibility`, or `All`. The default runs Unit and
  Integration; Compatibility is opt-in because it runs real Neovim (Phase 05).
- Runs a single test file (`-Path`) or tests matching a name (`-TestName`, Pester `FullNameFilter`).
- Exits 0 when all selected tests pass, non-zero otherwise.
- Tests written ahead of their implementation (the Phase 03 tests below) are tagged `NotImplemented`. The runner
  excludes that tag by default and includes it with `-IncludeNotImplemented`, so the default run (and the CI check
  from #16) stays green while those tests still show their expected failures on request. The phase that
  implements a function removes the tag from its tests (owner decision, 2026-11-25, recorded in #19).

### Validation runner — `scripts/Invoke-Validation.ps1`
- A list of independent checks, each reporting pass/fail with file and line; non-zero exit if any fail.
- Checks added in this phase:
  - **PowerShell 5.1 syntax (NFR-01):** every `.ps1`/`.psm1`/`.psd1` file parses with the Windows PowerShell 5.1
    parser, which rejects PowerShell 7-only operators.
  - **No hardcoded user paths (NFR-03):** no literal user-profile paths such as `C:\Users\<name>`.
  - **Encoding:** Markdown, PowerShell, and Lua files are UTF-8 without a byte order mark.
- Documents-vs-data consistency checks (ADR-018) are added in the phase that creates each data file (03, 05).

### Module skeleton
- `src/NeovimBootstrap.psd1`: module manifest (`PowerShellVersion = '5.1'`, root module, explicit exports).
- `src/NeovimBootstrap.psm1`: `Set-StrictMode -Version Latest`, `$ErrorActionPreference = 'Stop'`.
- Stub wrappers `Invoke-WinGet` and `Invoke-NeovimHeadless` with their intended parameters, throwing
  "not implemented". They exist so tests can mock them (ARCHITECTURE.md, design principle 4).

### Test helpers and conventions
- `tests/TestHelpers.psm1`: shared helpers, e.g. importing the module under test, building WinGet and Neovim
  output from fixtures, and creating an isolated sandbox inside Pester's `TestDrive` with `LOCALAPPDATA`,
  `XDG_CONFIG_HOME`, and `XDG_DATA_HOME` pointed into it.
- **Isolation guard:** integration tests assert they are running inside a sandbox before doing anything, and fail
  immediately if any path resolves to the real user profile.
- Mocks: unit tests mock `Invoke-WinGet`, `Invoke-NeovimHeadless`, and any cmdlet that changes the system, using
  `-ModuleName NeovimBootstrap`. No unit test calls a real external program.
- `tests/Fixtures/`: captured outputs used by mocks: `winget list` / `winget show` (installed, not installed,
  older, newer), `nvim --version`, and a Store-alias `python.exe` case.
- **Validation fixtures are built at run time** (owner decision, 2026-11-27, PR #32): the known-good and known-bad
  inputs for validation checks are written by each test into its own folder inside `TestDrive`, not committed under
  `tests/Fixtures/`. Rationale:
  - Validation runs over the whole repository, so committed known-bad files would make it fail on itself unless
    their folder were skipped, and a skipped folder would also hide real problems placed there later.
  - Writing exact bytes at run time means an editor cannot silently "fix" a fixture (for example, drop a BOM) and
    leave a test that no longer proves anything.
  - Cost: the fixtures exist only in test code and cannot be browsed or passed to `Invoke-Validation.ps1` by hand.

  A test file is itself validated, so a value that would fail a check in that file (such as a user-profile path)
  is assembled from parts at run time. `tests/Fixtures/` remains the place for captured real output, which has to
  be recorded once and cannot be generated.
- Folder layout as in ARCHITECTURE.md: `tests/Unit/`, `tests/Integration/`, `tests/Compatibility/`,
  `tests/Fixtures/`. Test files are named `<FunctionOrArea>.Tests.ps1`.
- `.gitignore` entries for test result output.

### Initial failing tests (for Phase 03)
Written against the function names in ARCHITECTURE.md, covering Phase 03's requirements (ROADMAP.md), and tagged
`NotImplemented` (see Test runner):
- Preflight: elevated / not elevated (NFR-02); x64 / other architecture (NFR-08); WinGet present / missing.
- Neovim: absent → install pinned; same → no change; older → install pinned; newer → stop unless approved
  (FR-10, FR-11, FR-12).
- Tier B: missing → install tested version; present at or above minimum → no change; below minimum → stop with
  name, found version, and minimum (FR-21, FR-22); Store alias stub not treated as Python.
- `-WhatIf` on every installing function makes no calls that change the system (FR-71).
- Exit codes 0, 1, 3 (NFR-09).

## Out of Scope
- Implementing any bootstrapper behavior beyond the stubs above.
- The release compatibility check itself (Phase 05).
- PSScriptAnalyzer or any other new tool: adding one requires approval and a COMPATIBILITY.md entry.
- Installing Pester without the owner's approval.

## Test Requirements
- Framework self-tests (passing at the end of this phase):
  - The runner refuses to run without Pester 5.9.1 and reports how to install it.
  - Suite selection, single-file, and name-filter options select the expected tests.
  - Each validation check catches a known-bad fixture (a PowerShell 7 operator, a hardcoded user path, a BOM) and
    passes a known-good one.
  - The sandbox helper redirects `LOCALAPPDATA` and `XDG_*`, and the isolation guard fails outside a sandbox.
- Phase 03 tests (failing at the end of this phase, for the right reason): each fails because the function is not
  implemented, never because of a syntax error, missing helper, or misconfigured mock.

## Implementation Constraints
- Runs on Windows PowerShell 5.1 with Pester 5.9.1 syntax (`BeforeAll`, `Should -Invoke`, `-ModuleName` mocks).
- Tests never touch the real Neovim configuration, data, or installed programs (AGENTS.md safety rules).
- Do not modify tests merely to make failures disappear.
- Function names in tests follow ARCHITECTURE.md; a needed rename is reported and the document updated.

## Acceptance Criteria
- `scripts/Invoke-Tests.ps1` runs on Windows PowerShell 5.1 with Pester 5.9.1 and returns correct exit codes.
- All framework self-tests pass.
- All Phase 03 tests fail, and each failure message shows "not implemented" or a missing command.
- `scripts/Invoke-Validation.ps1` passes on the repository.
- A single test file and a single test can be run as documented.
- README.md documents the Pester prerequisite; CLAUDE.md's Commands section documents running the full suite, one
  suite, one file, one test, and validation.

## Deliverables
- `scripts/Invoke-Tests.ps1`, `scripts/Invoke-Validation.ps1`
- `src/NeovimBootstrap.psd1`, `src/NeovimBootstrap.psm1` (skeleton and stub wrappers)
- `tests/TestHelpers.psm1`, `tests/Fixtures/…`, framework self-tests, Phase 03 failing tests
- `.gitignore` entries
- README.md (Pester prerequisite) and CLAUDE.md (Commands) updates

## Completion Evidence
Tests execute successfully as a framework; expected functionality tests fail for known reasons.

Report includes the test runner output showing passing framework tests and the list of failing Phase 03 tests with
their failure reasons.

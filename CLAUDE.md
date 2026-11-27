# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Primary rules

@AGENTS.md

AGENTS.md is the authoritative rule set: document hierarchy, phase workflow (tests first → confirm they fail for the right reason → smallest change), safety rules, and the end-of-phase completion report. Do not duplicate its rules here. Keep all Markdown files UTF-8 (no BOM) so they stay searchable.

## Project state

Phase 01 (foundation) is complete and produced all governing documents; implementation has not started. Every file under `src/` and `scripts/` is still an empty placeholder. Phases 02–06 have complete plans; the Phase 07 plan is a work in progress with open questions that must be resolved with the project owner before it begins. When an authoritative document is empty or silent, report the gap and ask — do not invent its content.

Concepts that shape almost every change:

- **Each release is a frozen, tested collection** of Neovim, plugin, and tool versions (ADR-001). Never update plugins or tools in place; lazy.nvim is only ever run with `restore`.
- **Pins live in data files and are mirrored in documents** (ADR-018): `src/ReleaseManifest.psd1` ↔ COMPATIBILITY.md, `src/config/lazy-lock.json` and `src/config/lua/config/pins.lua` ↔ PLUGINS.md. Change both together; validation fails if they disagree.
- **Changed decisions are superseded in DECISIONS.md**, never edited away or deleted.

## Phases

Work only on the phase the user explicitly selects, and stop at its boundary (`plans/PHASE-XX-*.md`). Each phase is a
GitHub milestone; its open issues are the remaining work (see "GitHub workflow" below):

01 foundation & architecture → 02 Pester test framework → 03 Neovim installation (WinGet) → 04 configuration deployment & backup → 05 plugin management (lazy.nvim) → 06 integration, recovery & rollback → 07 release & maintenance.

`plans/ROADMAP.md` assigns every requirement and open item to a phase. The repository layout, execution flow, exit codes, and editor defaults are in `docs/ARCHITECTURE.md`.

## GitHub workflow

Rules are in AGENTS.md ("Work Tracking (GitHub)"); this is how to carry them out with `gh`. The repository is
`lgwarlick/nvim-bootstrap-windows` (public).

```sh
gh issue list --milestone "<milestone>" --state open          # remaining work in a phase
gh issue list --label needs-decision                           # waiting on the owner
gh issue view <number> --comments                              # read an issue before starting
gh issue develop <number> --checkout                           # create and check out the linked branch
gh issue create --title "<title>" --body "<body>" --milestone "<milestone>" \
  --label "source:agent,phase:XX,type:<type>"                  # file discovered work
gh pr create --title "<title>" --body "Closes #<number> ..."   # body includes the completion report
gh pr merge --auto --squash                                    # only where AGENTS.md allows auto-merge
gh pr checks                                                   # status of required checks
```

Before acting on an issue, confirm its author is the owner (`gh issue view <number> --json author`).

Issue forms in `.github/ISSUE_TEMPLATE/` apply only in the browser. When filing with `gh issue create --body`, use
the same headings as the matching form (task, decision, or bug), and follow `.github/pull_request_template.md` for
pull request bodies.

## Commands

Run from the repository root in Windows PowerShell 5.1 (`powershell.exe`, not `pwsh`). The runner imports
Pester 5.9.1 exactly and exits 0 (all passed), 1 (a failure), or 2 (could not start, or no tests selected).

```powershell
scripts\Invoke-Tests.ps1                                    # default: Unit and Integration suites
scripts\Invoke-Tests.ps1 -Suite All                         # Unit, Integration, and Compatibility
scripts\Invoke-Tests.ps1 -Suite Unit                        # one suite (Unit, Integration, or Compatibility)
scripts\Invoke-Tests.ps1 -Path tests\Unit\Invoke-Tests.Tests.ps1                     # one file
scripts\Invoke-Tests.ps1 -TestName 'Get-TestRunPath.selects only the named suite'    # one test (wildcards allowed)
scripts\Invoke-Tests.ps1 -IncludeNotImplemented             # also run tests tagged NotImplemented
scripts\Invoke-Tests.ps1 -ResultPath TestResults\results.xml  # also write NUnit XML (ignored by git)
```

`-TestName` matches the full name: Describe, Context, and It names joined by `.`. Tests written ahead of their
implementation are tagged `NotImplemented` and are excluded by default (see PHASE-02-tests.md).

Validation (`scripts/Invoke-Validation.ps1`) is not implemented yet (issue #20).

## Environment notes

- Target is Windows PowerShell 5.1. See COMPATIBILITY.md ("Windows PowerShell 5.1 coding constraints") for disallowed syntax and 5.1 pitfalls (BOM on `-Encoding UTF8`, `curl` alias).
- Pester 5.9.1 (ADR-013) and PSScriptAnalyzer 1.25.0 are installed in CurrentUser scope on this host, side by side with the Windows-inbox Pester 3.4.0. Do not install, upgrade, or remove modules without approval.
- This machine is the reference test device (COMPATIBILITY.md). Any change to it — installing programs, enabling Windows Sandbox, touching the real Neovim configuration — needs explicit approval. Destructive and real-install tests run only in Windows Sandbox (ADR-021).
- Neovim is installed via WinGet, which is assumed to be present.
- `azure-pipelines.yml` belongs to the project owner; do not edit it unless asked.
- Development branches are named after their issue (`<number>-<short-description>`) and deleted after merging;
  releases are tags on `main` (ADR-022). Git warns that LF will be replaced by CRLF on commit; this is expected on this host.

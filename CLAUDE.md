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

Work only on the phase the user explicitly selects, and stop at its boundary (`plans/PHASE-XX-*.md`):

01 foundation & architecture → 02 Pester test framework → 03 Neovim installation (WinGet) → 04 configuration deployment & backup → 05 plugin management (lazy.nvim) → 06 integration, recovery & rollback → 07 release & maintenance.

`plans/ROADMAP.md` assigns every requirement and open item to a phase. The repository layout, execution flow, exit codes, and editor defaults are in `docs/ARCHITECTURE.md`.

## Commands

Not implemented yet. Phase 02 creates the runners and must document here how to run the full suite, one suite, one file, one test, and validation. Planned interface (PHASE-02-tests.md):

- `scripts/Invoke-Tests.ps1 -Suite Unit|Integration|Compatibility|All` (default: Unit and Integration), `-Path <file>`, `-TestName <filter>`
- `scripts/Invoke-Validation.ps1`

## Environment notes

- Target is Windows PowerShell 5.1. See COMPATIBILITY.md ("Windows PowerShell 5.1 coding constraints") for disallowed syntax and 5.1 pitfalls (BOM on `-Encoding UTF8`, `curl` alias).
- Pester 5.9.1 is the supported version (ADR-013), but the only Pester on this host is the Windows-inbox 3.4.0. Do not install or upgrade Pester without approval.
- This machine is the reference test device (COMPATIBILITY.md). Any change to it — installing programs, enabling Windows Sandbox, touching the real Neovim configuration — needs explicit approval. Destructive and real-install tests run only in Windows Sandbox (ADR-021).
- Neovim is installed via WinGet, which is assumed to be present.
- `azure-pipelines.yml` belongs to the project owner; do not edit it unless asked.
- Development branches (e.g. `2/phases`) are deleted after merging; releases are tags on `main` (ADR-022). Git warns that LF will be replaced by CRLF on commit; this is expected on this host.

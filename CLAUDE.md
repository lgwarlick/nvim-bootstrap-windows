# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Primary rules

@AGENTS.md

AGENTS.md is the authoritative rule set: document hierarchy, phase workflow (tests first → confirm they fail for the right reason → smallest change), safety rules, and the end-of-phase completion report. Do not duplicate its rules here. Keep all Markdown files UTF-8 (no BOM) so they stay searchable.

## Project state

The repo is currently scaffolding only. Every file under `src/` and `scripts/` is an empty placeholder, and `docs/ARCHITECTURE.md`, `docs/COMPATIBILITY.md`, `docs/ROLLBACK.md`, `docs/DECISIONS.md`, `plans/ROADMAP.md`, and `CHANGELOG.md` are empty because Phase 01 (foundation) has not been done. The only substantive specs are `docs/REQUIREMENTS.md`, `docs/PLUGINS.md`, and the phase stubs in `plans/`. When an authoritative document is empty or silent, report the gap and ask — do not invent its content.

## Phases

Work only on the phase the user explicitly selects, and stop at its boundary (`plans/PHASE-XX-*.md`):

01 foundation & architecture → 02 Pester test framework → 03 Neovim installation (WinGet) → 04 configuration deployment & backup → 05 plugin management (lazy.nvim) → 06 integration, recovery & rollback → 07 release & maintenance.

## Intended layout

- `src/bootstrap.ps1` — entry point
- `src/NeovimBootstrap.psm1` / `.psd1` — module holding the small, testable functions
- `src/config/init.lua` + `src/config/lazy-lock.json` — the Neovim config that gets deployed; the lockfile pins plugin revisions
- `scripts/Invoke-Tests.ps1`, `scripts/Invoke-Validation.ps1` — test and validation runners
- `docs/PLUGINS.md` — the approved plugin list

## Commands

Not implemented yet: `scripts/Invoke-Tests.ps1` and `scripts/Invoke-Validation.ps1` are empty. Once they exist, document here how to run the full suite and a single test.

## Environment notes

- Target is Windows PowerShell 5.1. Do not use PowerShell 7-only syntax (`&&`, `||`, `??`, `?.`, ternary).
- The only Pester on this host is the Windows-inbox 3.4.0, whose syntax differs from Pester 5. The supported Pester version is not decided yet (belongs in COMPATIBILITY.md); do not install or upgrade Pester without approval.
- Neovim is installed via WinGet, which is assumed to be present.

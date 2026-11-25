# Phase 01 - Foundation and architecture

## Status
Tracked in the GitHub milestone **Phase 01 - Foundation and architecture** (see [ROADMAP.md](ROADMAP.md)).

## Objective

Establish repository conventions, requirements, supported Windows/PowerShell environments, architecture, and dependency strategy.

## Dependencies

None.

## Scope

- Write and get approval for every governing document in the AGENTS.md hierarchy:
  REQUIREMENTS.md, ARCHITECTURE.md, COMPATIBILITY.md, ROLLBACK.md, DECISIONS.md, PLUGINS.md, ROADMAP.md.
- Select and record the 1.0.0 pins: Neovim, tree-sitter-cli, Tier B minimum and tested versions, plugin commits,
  Mason registry and tool versions (from upstream sources, dated).
- Fill in phase documents 01–07 so each phase can be executed without further planning.
- Fix repository hygiene issues found during the phase: AGENTS.md encoding and typos, plugin names in PLUGINS.md.
- Bring README.md, CHANGELOG.md, and CLAUDE.md in line with the approved documents.

## Out of Scope

- Any PowerShell, Lua, or JSON implementation: everything under `src/`, `scripts/`, and `tests/` stays as it is.
- Installing, upgrading, or configuring anything on the host (including Pester, Neovim, and dependencies).
- Proving compatibility by running software. Pins are selected from upstream documentation here; they are proven
  by the release compatibility check (Phase 05).

## Test Requirements

No automated tests; this phase produces documents only. Instead, before completion:

- Every requirement ID in REQUIREMENTS.md is assigned to a phase in ROADMAP.md.
- Every open item in the governing documents is either resolved or assigned to a phase in ROADMAP.md.
- Every phase document has every section filled.
- Cross-document links and ADR, FR, and NFR references point to items that exist.
- All Markdown files are UTF-8 without a byte order mark.

## Implementation Constraints

- Follow AGENTS.md: report conflicts instead of resolving them silently, and add no requirement without approval.
- One document at a time: draft, present, and wait for approval before the next.
- Record each fact in one authoritative document and reference it elsewhere; where duplication is deliberate
  (pins in data files and documents), name the validation check that keeps them aligned (ADR-018).
- Changed decisions are superseded in DECISIONS.md, never deleted or rewritten.
- Version and requirement facts come from upstream sources (plugin repositories, WinGet manifests, package
  registries), not memory, and are dated.

## Acceptance Criteria

- All governing documents listed in Scope are written and approved by the project owner.
- Phase documents 01–06 are complete and approved. Phase 07 is approved as a work in progress, with its decisions
  recorded and its open questions listed, to be resolved before Phase 07 begins.
- No open questions remain in REQUIREMENTS.md, ARCHITECTURE.md, COMPATIBILITY.md, or ROLLBACK.md that are not
  assigned to a phase in ROADMAP.md.
- The only Proposed decisions in DECISIONS.md are ones that can only be settled by testing, and each is assigned to
  a phase.
- The checks under Test Requirements pass.
- No files under `src/`, `scripts/`, or `tests/` were changed.

## Deliverables

| File | Change |
|---|---|
| `AGENTS.md` | Re-encoded to UTF-8; typos fixed; no rule changes |
| `CLAUDE.md` | Encoding note replaced; project state, layout, and Pester notes updated |
| `docs/REQUIREMENTS.md` | Written |
| `docs/DECISIONS.md` | Written |
| `docs/COMPATIBILITY.md` | Written |
| `docs/ARCHITECTURE.md` | Written |
| `docs/ROLLBACK.md` | Written |
| `docs/PLUGINS.md` | Rewritten with owners, pins, dependencies, Mason tools |
| `docs/UPGRADING.md` | Created as a placeholder (one section per major version, none yet) |
| `azure-pipelines.yml` | Created empty; content owned by the project owner |
| `plans/ROADMAP.md` | Written |
| `plans/PHASE-01` … `PHASE-06` | Completed |
| `plans/PHASE-07` | Work in progress: decisions so far and open questions |
| `README.md` | Purpose, prerequisites, links to documents |
| `CHANGELOG.md` | Created with an Unreleased entry for Phase 01 |

## Completion Evidence

Requirements documented, major decisions approved, no installer implementation.

Reported as the AGENTS.md completion report: files changed, tests added (none), test results (the document checks
under Test Requirements), compatibility considerations, and risks or unresolved issues.

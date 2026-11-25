# Phase 07 - Release and maintenance

## Status
Tracked in the GitHub milestone **Phase 07 - Release and maintenance** (see [ROADMAP.md](ROADMAP.md)).

**This plan is a work in progress.** Decisions so far are recorded below; the open questions must be resolved
with the project owner before this phase begins.

## Objective

*Draft, to be confirmed:* Publish each release as a GitHub Release, produced by an Azure DevOps pipeline, containing
everything needed to run the bootstrapper; and define how future releases are prepared, tested, and documented.

## Dependencies
- Phase 01 complete
- Phase 02 complete
- Phase 03 complete
- Phase 04 complete
- Phase 05 complete
- Phase 06 complete

## Decided so far (2026-11-25)

| Topic | Decision | Reference |
|---|---|---|
| What a release is | A GitHub Release in the public repository, with a downloadable asset that runs the bootstrapper | ADR-022 |
| Audience | The project owner now; anyone with access to the public repository later | — |
| Branching | Each release is a tag on a commit on `main`; no release branches. Development branches (e.g. `2/phases`) are deleted after merging | ADR-022 |
| Who builds releases | An Azure DevOps pipeline, owned and maintained by the project owner | ADR-022 |
| Pipeline trigger | A merge to `main` whose commit or pull request title starts with a release prefix | ADR-022 |
| Version numbers | Set by the title prefix, which auto-increments the version (example prefixes: `maj`, `min`, `fix`), following ADR-002's meaning of MAJOR, MINOR, and PATCH | ADR-002, ADR-022 |
| Version consistency | A validation check requires every place the version appears to match | ADR-022 |
| Release asset contents | What is needed to run the bootstrapper, plus README.md and CHANGELOG.md, plus a checksum file | ADR-022 |
| Running a downloaded script | Documented steps that let the downloaded script run (Windows marks downloaded files) | — |
| Older releases | Not supported. A fix to 1.0.0 ships as 1.0.1 or 1.1.0 | ADR-022 |
| What triggers a new release | A new Neovim version, a plugin update, a security fix, or a bug fix; the owner decides when, and the work is done with an agent | — |
| Telling users what changed | CHANGELOG.md, plus release notes combining hand-written text and the CHANGELOG.md section | — |
| Upgrade guides | `docs/UPGRADING.md`, one section per major version | — |
| Machine-only tests | The release compatibility check and Windows Sandbox end-to-end tests are expected to run on a pipeline agent before a release | ADR-021 |

## Scope

*Work in progress.* Known so far:

- Build the release asset contents and checksum file as decided above.
- Add the version-consistency validation check.
- Document, in README.md, how to download, verify the checksum, allow, and run the bootstrapper.
- Maintain `docs/UPGRADING.md` (created in Phase 01 as a placeholder).
- `azure-pipelines.yml` exists as an empty placeholder (created in Phase 01); its content is the project owner's.

## Out of Scope

*Work in progress.* Known so far:

- Writing the Azure DevOps pipeline definition (owned by the project owner).
- Supporting older releases.

## Test Requirements

*To be defined once the open questions are resolved.*

## Implementation Constraints

*To be defined once the open questions are resolved.* Known so far:

- Every release passes the release compatibility check (COMPATIBILITY.md) before it is published (ADR-001).

## Acceptance Criteria

*To be defined once the open questions are resolved.*

## Deliverables

*To be defined once the open questions are resolved.*

## Completion Evidence

*To be defined once the open questions are resolved.*

## Open questions

1. **Objective:** confirm or rewrite the draft objective above.
2. **Release prefixes:** the exact prefixes and format (e.g. `maj:`, `min:`, `fix:`), and what happens when a merge
   to `main` has no prefix (no release?).
3. **Where the version is written:** does the pull request author update the version files and the pipeline check
   them against the prefix, or does the pipeline calculate the version and write it into the files at build time?
   What exactly does the version-consistency check compare (title prefix, `ReleaseManifest.psd1`, module manifest,
   tag, CHANGELOG.md)?
4. **Prefixes and ADR-002:** should validation enforce that a Neovim minor-version change uses the MAJOR prefix and
   that a pin change is never released as a PATCH?
5. **Machine-only tests on a pipeline agent:** a self-hosted Azure DevOps agent on the reference test device? When
   do these tests run (pull request gate, before merge, or after merge but before publishing)? Can the agent run
   elevated and launch Windows Sandbox (normally an interactive desktop application)?
6. **Test evidence:** where are each release's compatibility check report and end-to-end results kept (repository,
   attached to the GitHub Release, release notes, pipeline artifacts)?
7. **License:** which license to add before the repository is public. Until then, others have no legal right to
   reuse the code.
8. **Release asset details:** asset file name and format (e.g. a `.zip`), and checksum format (e.g. SHA-256 in a
   `.sha256` file).
9. **Release notes:** how the hand-written part is supplied (e.g. in the pull request description, or a file in the
   repository).
10. **Runbook for future releases:** should there be a written procedure the agent follows when preparing a new
    release (selecting pins, running checks, updating documents, changelog)? If so, where should it live?
11. **Where this phase ends:** at "1.0.0 is ready to merge to `main`", with the pipeline doing the rest, or does it
    include the first pipeline-produced release?

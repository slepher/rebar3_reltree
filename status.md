# rebar3_reltree Handoff Status

## Project

- Project/repository name: `rebar3_reltree`
- Plugin, escript, and user-facing command: `reltree`
- Intended Rebar3 command: `rebar3 reltree`
- Working directory: `/home/slepher/project/rebar3_reltree`
- Output path per inspected project: `_build/<profile>/reltree/project.md`
- Handoff date: 2026-08-10 Asia/Shanghai

## Current State

- Requirements and naming are confirmed by the user.
- No implementation has been started in the new project.
- The old `rebar3_docker_ci` worktree contains an earlier, incomplete `release-version-gates`
  attempt. It is not the source of truth for this project and must not be copied into the new
  implementation wholesale.
- The project-level `local-workflow` skill has been copied to:
  `.codex/skills/local-workflow/SKILL.md`.
- This file is the handoff point for the next Codex window; the next window should create the
  durable initiative plan before implementing code.

## Confirmed Requirements

### Naming

- OTP/application and repository: `rebar3_reltree`.
- Plugin, escript, skill, and command: `reltree`.
- The project is independent of `docker_ci`.

### Generated project tree

Generate only inside the inspected project's selected profile:

```text
_build/<profile>/reltree/project.md
```

Each node must include project path/name, Git HEAD and version/tag, `app.src`/`app.vsn`, upstreams,
downstreams, runtime dependency edges, plugin/tool declarations, and README/CI badge state.

### Local graph discovery

- Upstreams come from `rebar.config` runtime dependency declarations plus locally resolvable entries
  in the current project's `_checkouts`.
- A local downstream candidate is included when one of its `_checkouts` links resolves to the current
  project.
- Candidate roots must be explicit or configured local project roots; do not scan the whole filesystem.
- Missing local projects are represented explicitly and never guessed from remote state.

### External `rev` tracking

Use `--rev false|auto|true` for projects that are not local:

- `false`: record only the Rebar3 configuration; do not track `rev`.
- `auto`: track `rev` only for external projects not already present in the previous `project.md`;
  reuse existing recorded revision and network sync time for already recorded projects.
- `true`: track every external project's `rev` on every invocation.

Remote access, when required by `auto` or `true`, is read-only revision metadata lookup. Never fetch,
push, create/move/delete tags, publish, or overwrite local checkout facts. Lookup failures must be
explicitly recorded as missing/stale data.

The generated file must contain both `network_sync_at` and `local_sync_at`. Clock values should use a
documented UTC format; tests should inject the clock and compare non-clock output deterministically.

### Status gate

The tree status is exactly one of:

- `up-to-date`
- `update-required`
- `insufficient-local-data`

An unrequested newer upstream does not by itself require a downstream update. README badge validation
applies when `.github/workflows/ci.yml` exists; without that workflow, the gate is skipped and the
skip is recorded. README files must not be modified.

## Next Window Instructions

1. Start in `/home/slepher/project/rebar3_reltree`.
2. Read `.codex/skills/local-workflow/SKILL.md` completely and use it for this initiative.
3. Create the durable initiative under this project (plan and status/task artifacts); do not create
   the implementation plan in `rebar3_docker_ci`.
4. Inspect the local Erlang/Rebar3 toolchain and decide the smallest project structure.
5. Implement and test the escript, graph discovery, `rev` modes, sync timestamps, version/tag gate,
   README badge gate, and optional `rebar3 reltree` provider.
6. Keep all writes scoped to this project and the selected inspected project's
   `_build/<profile>/reltree/project.md`; perform no remote publishing without a separate request.

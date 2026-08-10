# Initiative Status

## Initiative

- Name: `migrate-reltree-gates`
- Project: `/home/slepher/project/rebar3_reltree`
- Goal: migrate the sibling skill installer behavior and local badge gate into `rebar3_reltree`
- Updated: 2026-08-10 Asia/Shanghai

## Current phase

- Phase: `planning`
- Current task: `none`
- Implementation stage: `none`
- Next action: freeze task-1.md from the reconciled plan, then dispatch the coding worker

## Repository snapshot

- Current source/config/test files: none; `release.md` and `completed.md` are copied documentation,
  and the durable initiative documents are present.
- `.git` was initialized successfully with branch `master`; the repository has no HEAD commit yet.
- Erlang/OTP: OTP 29 / ERTS 17.0.4.
- Rebar3: 3.25.1.
- Sibling source is read-only input only; its `check_badges` provider is absent.
- `completed.md` classifies the sibling implementation as partial and not acceptable for direct
  migration; its installer behavior is evidence only until reimplemented and verified here.

## Scope

- In scope: a standalone `rebar3_reltree` Rebar3 project, packaged `reltree` skill installation, and the local badge gate behavior required by `status.md` and the sibling release-gate specification.
- Out of scope: copying the sibling `docker_ci` implementation wholesale, remote Git operations, README/workflow mutation, skill installation into a real user directory, and changes to `rebar3_docker_ci`.

## Evidence

- Read root `status.md` and `.codex/skills/local-workflow/SKILL.md`.
- Read sibling installer/provider/tests and release-gate plans.
- `luna_runner` evidence: no current source/config/tests; sibling has `rebar3_docker_ci_skill_install.erl` and no `check_badges` implementation.
- User design decisions recorded in `release.md:166-274` define the simple local project-tree cache,
  bounded scan roots, checkout relationship rules, and `bgate` behavior.
- Planner reconciliation completed: `plan.md` now contains five ordered tasks for the skeleton,
  local graph/report, external revisions/timestamps, bgate, and reltree skill/installer.

## Blocker

- None. Git metadata is now writable and the task lifecycle can proceed.

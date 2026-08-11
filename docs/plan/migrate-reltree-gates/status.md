# Initiative Status

## Initiative

- Name: `migrate-reltree-gates`
- Project: `/home/slepher/project/rebar3_reltree`
- Goal: migrate the sibling skill installer behavior and local badge gate into `rebar3_reltree`
- Updated: 2026-08-11 Asia/Shanghai

## Current phase

- Phase: `rework`
- Active plan: `plan-2.md`
- Draft plan: `none`
- Current task: `task-10`
- Implementation stage: task-10 review 1 recorded `changes_required`
- Next action: revise task-10 acceptance text with Sol, then dispatch Luna for the five bounded review corrections and self-tests.

## Repository snapshot

- Current task-1/task-2 source, config, and test files are present in the working tree; task-2 is
  committed locally and the initiative documents remain unstaged.
- `.git` was initialized successfully with branch `master`; task-1, task-2, and task-3 have local commits.
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
- `task-1.md` is frozen and accepted as the implementation contract for the skeleton and shared
  request boundary.
- Coding worker self-tests completed: compile exit 0; EUnit exit 0 with 35 tests and 0 failures;
  escriptize exit 0; help exits 0; valid unavailable-engine exit 1; invalid rev exit 2;
  report absence and `git diff --check` exit 0. Generated `rebar.lock` was removed as an
  unowned temporary artifact.
- Independent runner repeated compile, EUnit (35/0), escriptize, help, expected exit 1/2,
  report absence, status, and diff checks successfully. Runner-generated `_build/` and
  `rebar.lock` were cleaned after its interrupted cleanup attempt.
- Sol review 1 returned `changes_required`: preserve duplicate top-level `reltree` configuration
  through the provider adapter and classify malformed configured scan roots as configuration errors.
  Retrospective found no reusable workflow-skill gap.
- User resolved the review blocker: duplicate top-level reltree configuration is ignored and follows
  Rebar3 last-value-wins behavior; it is no longer an error or provider/escript parity blocker.
- Planner revised plan.md and task-1.md accordingly; review-1 and its retrospective remain immutable.
- Rework coding self-tests completed: compile exit 0; EUnit exit 0 with 40 tests and 0 failures;
  escriptize/help/error/no-write checks passed; generated artifacts were cleaned.
- Independent runner passed compile, EUnit (40/0), escriptize, help, expected exit 1/2,
  report absence, status, and diff checks; no commands were interrupted and generated artifacts
  were cleaned.
- Sol review 2 passed with no material findings; review artifact is
  `task-1-code-review-2.md` and continuity recommends reusing Sol for task-2.
- Dispatcher committed task-1 as `54b1cce` with subject `feat: scaffold reltree plugin and escript`;
  staged scope matched the ten task-owned paths and `git diff --cached --check` exited 0.
- Sol continuity wrote and accepted `task-2.md`; it adds the shared dispatch module to task-2
  ownership and selects commit subject `feat: generate local reltree reports`.
- Task-2 implementation now has a passing baseline from an independent read-only runner:
  compile exit 0; EUnit exit 0 with 71 tests and 0 failures; CT exit 0 with 4 tests passed;
  escriptize exit 0; `git diff --check` exit 0. The runner confirmed that the previous five
  obsolete task-1 expectations no longer fail.
- At the earlier task-2 checkpoint, the runner could not establish complete contract-level evidence
  for every fixture, mutation, deterministic-diff, symlink/hardlink, anomaly, and provider/CLI
  boundary required by `task-2.md`. Build artifacts (`_build/`, `rebar.lock`, and
  `erl_crash.dump`) were removed after verification.
- A read-only contract review then identified five concrete task-2 defects. The working diff now
  contains corresponding implementation and regression-test changes for UTF-8 report rendering,
  filesystem-identity candidate de-duplication, memory-only report rendering, restricted
  `rc.N`/`ci.N` prerelease parsing, and single-warning unreadable scan roots. The worker and its
  follow-up independent runner were interrupted before returning command evidence, so these
  changes were awaiting the final verification recorded below.
- Final coding self-test after those fixes passed: compile exit 0; EUnit 84/0; CT 4/0;
  escriptize exit 0; `git diff --check` exit 0. The independent runner separately reproduced
  compile 0, EUnit 84/0, CT 4/0, and escriptize 0. The only escriptize output was a non-fatal
  timestamp-before-1980 warning.
- Final static review found no material code findings and confirmed no task-3 bgate/installer or
  remote-revision implementation leaked into task-2. Dispatcher committed task-2 as
  `1979be3 feat: generate local reltree reports`; only initiative documents remain unstaged.
- Sol wrote `task-3.md` for external/local revision tracking and synchronization timestamps;
  it preserves the default `auto`, local-only/no-fetch boundary, stale/error semantics, and
  the commit subject `feat: track external revisions in reltree`.
- Task-3 coding self-test and independent verification both passed: compile 0; EUnit 98/0;
  revision EUnit 13/0; CT 4/0; escriptize 0; `git diff --check` 0. Evidence includes local
  bare Git HEAD/branch/lightweight and annotated tag peel/ref/error/argv checks, prior-report
  state validation, duplicate identity reuse/conflict behavior, and renderer clock isolation.
- Final Sol review found no material findings. Dispatcher committed task-3 as
  `11e4706 feat: track external revisions in reltree`; only initiative documents remain
  unstaged.
- Sol wrote `task-4.md` with the user-narrowed local `bgate --check|--write` scope,
  including no-CI warning behavior, master fallback, badge preservation, README.zh parity,
  error paths, provider/escript parity, and the commit subject `feat: add reltree badge gate`.
- task-5 coding self-tests passed: compile 0; version EUnit 7/0; checkvsn EUnit 6/0; provider EUnit 12/0;
  full EUnit 126/0; CT 5/0; escriptize 0; escript keeps `checkvsn` unknown and tree/bgate help working;
  fixture success/gap/tag-mismatch/no-HEAD/unknown-arg and no-write/ref-snapshot checks passed; diff check 0.
- task-5 worker changed only the task-owned source/test paths; initiative documents and the user's
  `.codex/skills/local-workflow/SKILL.md` remain unstaged.
- Dispatcher committed task-5 as `85a1b8e` with subject `feat: add local reltree version gate`; staged
  name set matched the eight task-owned source/test paths and `git diff --cached --check` exited 0.
- Independent task-5 verification passed on `85a1b8ee91476ff3bb9f3fb9c637decb78f94d7e`: compile 0;
  version/checkvsn/provider EUnit 7/0, 6/0, 12/0; full EUnit 126/0; CT 5/0; escriptize 0;
  escript checkvsn unknown exit 2 and tree/bgate help exit 0; committed diff check 0; no task-5
  product changes remained in the worktree.
- Sol review 1 for commit `85a1b8e` returned `changes_required`: add direct version-policy assertions for
  app below highest, minor/major jumps, non-zero next-minor patch, and non-zero next-major minor/patch;
  no product logic finding or scope violation was reported. Review artifact:
  `task-5-code-review-1.md`.
- Review-1 correction self-tests passed: version EUnit 8/0; checkvsn EUnit 6/0; provider EUnit 12/0;
  full EUnit 127/0; CT 5/0; compile 0; escriptize 0; diff check 0. Only
  `test/rebar3_reltree_version_tests.erl` changed.
- Dispatcher committed review-1 correction as `bfd3c04` with subject
  `fix: task-5 review 1 version continuity assertions`; staged name set contained only the permitted test path.
- Sol review 2 passed commits `85a1b8e` and `bfd3c04` with no material finding; review artifact is
  `task-5-code-review-2.md`. The review confirms the correction completed the five independent
  version-continuity rejection assertions without changing product logic or scope.
- task-6 recovery: Sol confirmed the partial diff remains attributable to task-6 and does not require
  plan refinement. Valid partial evidence: compile 0; installer EUnit 11/0; CLI EUnit 8/0; provider
  EUnit 13/0; badge EUnit 13/0; escriptize 0; exact two-file archive; first install/conflict/force and
  target byte/entry/stage-backup checks passed. Evidence before final loader/packaging changes, the
  final full suite, packaged boundary/precedence/failure/no-write checks, and strict path proof is invalid
  or missing; no task-6 commit exists.
- Recovery revision: repeated interruption at the combined installer/packaging/CLI/full-acceptance boundary
  superseded task-6 before completion. Partial work is preserved; task-9 will finish installer/resource
  domain and task-10 will finish installer-only escript/CLI and final packaging acceptance, in that order,
  before the planned badge and skill tasks.

## Blocker

- None. task-6 is superseded before completion with attributable partial work; task-9 planning is active.

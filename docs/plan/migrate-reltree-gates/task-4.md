# task-4 — Local `bgate --check|--write`

## Goal

`migrate-reltree-gates`

## Objective

Implement one shared, purely local README badge gate exposed as both
`rebar3 reltree bgate --check|--write` and
`reltree bgate --check|--write`.

This task owns only the `bgate` command. It must not generate, modify, or
reconcile `project.md`, and it does not integrate badge policy into the `tree`
model, status evaluator, or report renderer.

## Authority and selected execution path

- The current user instruction is authoritative and narrows the task-4 plan
  boundary to local `bgate --check|--write` only.
- Badge forms and English/Chinese consistency come from `release.md:100-131`.
  Command behavior and mutation boundaries come from `release.md:258-274`.
- The task-4 plan section at
  `docs/plan/migrate-reltree-gates/plan.md:566-683` remains useful except for
  its proposed `tree`/`project.md` integration and related source/test
  ownership, which are explicitly out of scope here.
- task-3 is committed at `11e4706` and supplies the current command adapters,
  local Git argv boundary, formal-tag parser, and fixture conventions.
- Execution uses the normal `luna_coding_worker` path. That worker owns all
  implementation and Coding Self-Tests. A separate `luna_runner` owns all
  Independent Verification. Neither worker may delegate or spawn children.
- This is an implementation-only contract. Workers must not edit `plan.md`,
  either `status.md`, `release.md`, `completed.md`, workflow/review artifacts,
  skills, repository README files, Git metadata, or sibling repositories.
  No worker stages or commits; the dispatcher alone may commit after both
  evidence layers and Sol review pass.

## Decisive current-code evidence

- `rebar3_reltree:init/1` currently registers only `{reltree, tree}`, and
  `rebar3_reltree:main/1` delegates the escript to the shared CLI
  (`src/rebar3_reltree.erl:3-24`).
- `rebar3_reltree_cli:run/2` currently assumes every valid command is `tree`
  and loads tree configuration before dispatch
  (`src/rebar3_reltree_cli.erl:20-52`). `bgate` must branch before that config
  path so malformed or absent `rebar.config` does not affect this local gate.
- CLI parsing and user-facing error formatting are centralized in
  `rebar3_reltree_request` (`src/rebar3_reltree_request.erl:60-112`); the new
  command must extend this shared boundary rather than introduce different
  provider and escript grammars.
- The existing tree provider demonstrates provider metadata, argument
  normalization, help, dispatch, and structured provider errors
  (`src/rebar3_reltree_prv_tree.erl:10-80`). The bgate provider should remain
  equally thin.
- `rebar3_reltree_git:command/3` already provides bounded local Git execution
  with a fixed executable, argv, timeout, output cap, and no shell
  (`src/rebar3_reltree_git.erl:38-79`). `rebar3_reltree_version:parse_tag/1`
  already recognizes formal `[v]X.Y.Z` tags and excludes unsupported
  prerelease forms (`src/rebar3_reltree_version.erl:47-71`). Reuse both.
- `rebar3_reltree_fs:atomic_write/3` already gives safe per-file replacement
  and injectable write failures (`src/rebar3_reltree_fs.erl:104-181`). Reuse
  is allowed, but there is no transaction or rollback across the two README
  paths.
- `rebar3_reltree_project` already contains task-2 read-only badge facts
  (`src/rebar3_reltree_project.erl:131-261`). They are decisive context but are
  not owned by this task and must not be refactored, removed, or expanded.

## Product scope and ownership

### Owned product paths

- `src/rebar3_reltree.erl`
- `src/rebar3_reltree_cli.erl`
- `src/rebar3_reltree_request.erl`
- `src/rebar3_reltree_prv_bgate.erl` (new)
- `src/rebar3_reltree_badge.erl` (new)

`src/rebar3_reltree_git.erl`, `src/rebar3_reltree_version.erl`, and
`src/rebar3_reltree_fs.erl` are reusable read-only dependencies. In particular,
this task may call their existing exported APIs but may not change their tree,
revision, version, command, timeout, output-bound, or replacement semantics.

The following decisive tree paths are explicitly read-only and out of scope:

- `src/rebar3_reltree_project.erl`
- `src/rebar3_reltree_status.erl`
- `src/rebar3_reltree_report.erl`
- `src/rebar3_reltree_prv_tree.erl`

If implementation requires any source path outside the exact owned list, stop
and report the path and reason; do not silently widen ownership.

### Owned test paths

- `test/rebar3_reltree_cli_tests.erl`
- `test/rebar3_reltree_request_tests.erl`
- `test/rebar3_reltree_provider_tests.erl`
- `test/rebar3_reltree_badge_tests.erl` (new)
- `test/rebar3_reltree_fixtures.erl`
- `test/rebar3_reltree_SUITE.erl`

Tests may create unique temporary fixture repositories and generated README,
workflow, and sentinel `project.md` files outside the repository, and must
clean them. They must not use a real user repository, credential, network
remote, user skill directory, or repository README. No tracked deletion is
authorized.

If adequate semantic and command-surface coverage can be added without
changing every owned test path, unchanged owned paths need not appear in the
diff. No test path outside this list may be changed.

## Shared command and request contract

- Register provider `{reltree, bgate}` beside the existing tree provider.
  Its options are exactly boolean `--check` and `--write`.
- The escript accepts exactly `reltree bgate --check` and
  `reltree bgate --write`. Top-level and command help list/document `bgate`.
- Exactly one mode is required. Missing mode, both modes, duplicate mode,
  option values, unknown options, aliases, and positional arguments are usage
  errors. There is no `--ref`, `check_badges`, `check-badges`,
  `version-gate`, or `docker_ci` compatibility surface.
- Shared parsing returns one normalized request containing at least
  `#{command => bgate, mode => check|write, project_root => AbsoluteCwd}`.
  Provider and escript must produce the same request and invoke the same
  `rebar3_reltree_badge` policy for equivalent cwd and arguments.
- `bgate` does not consume `{reltree, ...}` configuration, profile, build
  directory, or output path. The escript must not consult `rebar.config` for
  this command. The provider uses `rebar_state:dir/1`; the escript uses cwd.
- Usage/configuration failures are escript exit 2 and structured provider
  errors. Runtime check/read/Git/write failures are escript exit 1 and the
  corresponding structured provider errors. Success is exit 0 / `{ok, State}`.
- Warning and error rendering must carry the same semantic code, relevant
  path/tag, and bounded reason on both surfaces. Provider and escript adapters
  must not independently reinterpret policy results.

## Frozen local evidence boundary

- First inspect exactly `<project>/.github/workflows/ci.yml` without following
  a symlink as a workflow file. If it is absent, both modes short-circuit:
  emit exactly one warning line identifying that relative path and that bgate
  was skipped, return success, perform no origin/tag/README read, and perform
  no write.
- A non-regular workflow entry or a workflow metadata error other than absence
  is a runtime error containing its exact path and reason. Do not treat an
  unreadable or wrong-type entry as an absent workflow.
- With a regular workflow, derive one `OWNER/REPO` only from local
  `remote.origin.url`. Accept the usual unambiguous GitHub HTTPS, `ssh://`, and
  SCP-style `git@github.com:OWNER/REPO[.git]` forms. Missing, malformed,
  non-GitHub, or multiple distinct origin values are runtime errors; include a
  bounded reason and never print credentials or the complete environment.
- Read only tags reachable from local `HEAD`. Formal tags are exactly
  `X.Y.Z` or `vX.Y.Z`, ranked numerically as non-negative integer triples.
  Prerelease and unrelated tags, including `rc`/`ci`, never produce a badge.
  Reuse `rebar3_reltree_version` parsing instead of implementing another
  version grammar.
- Allowed Git execution is limited to local read-only origin and reachable-tag
  queries through `rebar3_reltree_git:command/3` with argument vectors. Never
  run `ls-remote`, fetch, pull, clone, checkout, reset, push, tag creation or
  deletion, ref mutation, GitHub API access, or a shell command.
- Missing repository/HEAD, Git executable/timeout/output failure, origin
  failure, and tag-query failure are distinct runtime errors with the relevant
  project/path and bounded reason. No failure is converted into a guessed
  repository, branch, or tag.

## Frozen desired badge policy

- This gate owns only physical README lines whose trimmed content uses the
  reserved alt label `master CI` or `<non-empty VERSION> release CI` in a
  Markdown image-link candidate. Every such candidate is parsed against the
  exact templates at `release.md:114-120`; a reserved-label line that does not
  parse exactly is a malformed managed line. Other badge labels and every
  non-managed line are unowned and byte-preserved.
- The canonical master line is exactly the `release.md:117` template with the
  locally derived `OWNER/REPO` and branch `master` in both URLs.
- If there is no reachable formal tag, the desired managed block is exactly
  the single master line. No release line remains or is added.
- If one numerical version is highest and has one real tag spelling, append
  exactly one release line after one empty line. Display `VERSION` without an
  optional leading `v`; use the real local `TAG` spelling in both URL branch
  values.
- If both `X.Y.Z` and `vX.Y.Z` are real, reachable tags at the same highest
  numerical version, do not fabricate a preference. In `--write`, return an
  `equivalent_formal_tags` runtime error naming both tags before any README
  write. In `--check`, accept only a canonical block using either real highest
  spelling; if `README.zh.md` exists it must use the same spelling. Emit one
  warning line naming the ambiguity on successful check. Any lower, mixed, or
  non-real tag remains a check mismatch.
- Historical release lines, stale owner/repository URLs, wrong labels,
  missing/duplicate managed lines, wrong ordering/separation, malformed
  managed candidates, and an unexpected release line when no formal tag
  exists are mismatches. `--check` never repairs them.

## README consistency and mutation rules

- With a workflow, `<project>/README.md` is required and must be a readable
  regular file. Missing, wrong-type, unreadable, or invalid file data returns
  an error naming `README.md` and the reason.
- `<project>/README.zh.md` is optional. Absence is allowed. If the path exists,
  it must be a readable regular file or return an error naming that path and
  reason.
- Documentation consistency means the English README and existing Chinese
  README contain the same canonical managed badge block, including the same
  real release tag spelling in the equivalent-tag case. Their other badges,
  prose, headings, block location, and language content need not match.
- `--check` is strictly read-only. It computes desired state, reads both
  applicable README files, and succeeds only when each has exactly one
  canonical managed block for the accepted local origin/tags. A mismatch error
  identifies each failing file and bounded categories such as missing,
  duplicate, stale, malformed, order, or cross-file tag mismatch. It never
  writes README, workflow, Git, config, source, or `project.md`.
- `--write` must read and compute both complete transformed files before its
  first write. For each file independently, remove every managed candidate
  line and only the separator lines belonging to the old managed block, then
  insert one canonical block at the first former managed-line location. If no
  managed line existed, insert the block at the start followed by one empty
  line before existing content.
- Preserve all unowned badge lines and prose bytes, relative order, file
  encoding bytes outside the ASCII managed lines, existing line separators,
  and trailing-newline state. Do not broadly trim, reflow, translate, or
  normalize README content. If safe line-local splicing cannot preserve those
  bytes, stop with the exact file/reason before writes.
- Compute-order is `README.md`, then existing `README.zh.md`; write-order is
  also `README.md`, then existing `README.zh.md`. An unchanged canonical file
  need not be rewritten.
- Per-file safe replacement may reuse
  `rebar3_reltree_fs:atomic_write/3`. There is no cross-file atomicity,
  transaction, rollback, or compensating rewrite. If the second write fails,
  return an error naming `README.zh.md` and the write stage/reason while leaving
  the successful `README.md` update visible. A first-file write failure leaves
  the Chinese file untouched.
- Runtime writes are limited to `README.md` and an already existing
  `README.zh.md`. Never create `README.zh.md`, workflow files, `project.md`,
  config, directories outside per-file replacement needs, Git refs, or source.

## Error and warning result vocabulary

The shared badge boundary must return structured outcomes; adapters only
format them. Exact tuple/map shape is an implementation detail, but tests must
distinguish at least:

- successful `checked`, successful `written`, and successful
  `skipped_no_workflow`;
- `invalid_mode` / missing, duplicate, or conflicting mode as usage errors;
- `workflow_read` or `workflow_invalid`, with exact workflow path;
- `git_repository`, `git_origin`, and `git_tags`, with project path and bounded
  reason;
- `readme_read` / `readme_invalid`, with exact README path;
- `badge_mismatch`, with failing path(s) and bounded mismatch categories;
- `equivalent_formal_tags`, with both real highest tag names;
- `readme_write`, with exact README path and write stage/reason.

Do not collapse these into an opaque `bgate_failed`, raw stack trace, raw Git
output, or environment dump.

## Ordered implementation steps

1. Extend the shared command parser/request and help text for strict bgate
   modes without changing tree parsing, config precedence, profile behavior,
   or tree errors.
2. Implement `rebar3_reltree_badge` as the single workflow/origin/tag,
   managed-line analysis, check, transform, and ordered-write policy. Keep
   filesystem/Git/writer dependencies injectable for deterministic failure and
   no-call assertions.
3. Register the thin namespaced provider and shared dispatch; route the
   escript command around tree-only config loading and through the same request
   and policy.
4. Extend isolated fixtures for local commits, reachable/unreachable tags,
   GitHub origins, workflow states, README byte snapshots, write-call order,
   injected second-file failure, Git ref snapshots, and sentinel
   `project.md` snapshots.
5. Add pure policy/parser tests and provider/escript integration coverage for
   every success, warning, error, preservation, and no-write boundary below.

## Frozen test semantics and scenarios

Tests must prove, not merely invoke:

- parser/help/metadata acceptance of exactly one `--check|--write` and
  rejection of missing, duplicate, conflicting, valued, positional, unknown,
  and legacy-alias forms;
- direct command, provider, and escript request/result parity for equivalent
  arguments, including exit/error classification and warning semantics;
- no-workflow emits one warning line, succeeds in both modes, performs zero
  origin/tag/README reads and zero writes, and leaves refs, README files, and
  sentinel/absent `project.md` unchanged;
- regular workflow plus no formal tag yields master only; bare and `v` formal
  tags yield the same displayed version but preserve the real tag in URLs;
  numerical ordering beats lexical ordering; unreachable, rc/ci, malformed,
  and historical tags are ignored;
- canonical check success; missing, stale, duplicate, malformed, wrong-order,
  wrong-separator, historical release, and no-tag release mismatches; check
  snapshots prove strict read-only behavior on success and failure;
- missing `README.md`; absent `README.zh.md`; valid matching Chinese badges;
  Chinese missing/stale/mixed-tag badges; and Chinese prose differing from
  English while managed badges remain consistent;
- write insertion with no old managed block, replacement at the first old
  location, duplicate cleanup, stale release cleanup, idempotent second write,
  preservation of unrelated badges/prose, CRLF/LF and trailing-newline bytes;
- both highest equivalent tag spellings: write fails before writes; check
  accepts either consistent real spelling with one warning and rejects
  cross-file mixed spelling;
- missing/malformed/ambiguous origin, repository/HEAD/tag errors,
  wrong-type/unreadable workflow and README paths, first-file write failure,
  and injected second-file write failure all return the corresponding bounded
  error with exact path; partial-write visibility follows the frozen order;
- no case changes workflow bytes, Git refs/config, source, `rebar.config`, or
  any existing sentinel `project.md`, and no case creates `project.md`.

## Coding Self-Tests — `luna_coding_worker`

The coding worker must run and return raw command, exit, and test-count/output
evidence for all of:

- `rebar3 compile`
- `rebar3 eunit`
- `rebar3 ct`
- `rebar3 escriptize`
- `rebar3 eunit --module=rebar3_reltree_badge_tests`
- Built-escript fixtures for help, no workflow check/write, no-tag check/write,
  tagged check/write, mismatch check, equivalent-tag check/write, and invalid
  mode. Record exact exits and warning/error lines.
- Provider fixtures for the same mode grammar and representative skip, check,
  write, mismatch, and write-failure outcomes. Record structured provider
  results and prove parity with the escript/core command result.
- Snapshot checks over README bytes, workflow bytes, local refs/config, and
  sentinel/absent `project.md`, including ordered second-file failure and
  cleanup of all temporary fixtures/artifacts.
- `git diff --check`

No remote URL may be contacted; fixture origins are inert strings and every
Git query remains local.

## Independent Verification — separate `luna_runner`

After Coding Self-Tests pass, a fresh `luna_runner` must independently run the
same compile, complete EUnit, badge-module EUnit, CT, escriptize, built-escript,
provider, and snapshot fixtures against the exact diff. The runner-authored
packet must record:

- every command, completion state, exact exit, and test count;
- exact help, warning, and error output for representative provider/escript
  parity cases;
- resulting README bytes for no-tag, tagged, preservation, idempotent, and
  partial-failure cases;
- write-call order and exact failed path/reason;
- before/after workflow, Git refs/config, repository source/status, and
  sentinel/absent `project.md` evidence;
- proof fixtures used no network operation or credential;
- final `git status --short` and `git diff --check` output.

Independent Verification is mechanical only. The runner does not edit code or
judge source/test semantics; Sol reviews the assertions and real diff after the
completed runner packet is supplied.

## Expected diff, completion, and commit

- Expected tracked/untracked task diff is limited to the owned product and
  test paths above. New files are only
  `src/rebar3_reltree_prv_bgate.erl`,
  `src/rebar3_reltree_badge.erl`, and
  `test/rebar3_reltree_badge_tests.erl`.
- Temporary fixture repositories, generated README/workflow files, build
  output, and sentinel `project.md` remain untracked/ignored and are cleaned.
  No tracked deletion is authorized.
- No product or test diff is allowed in project/status/report/tree-provider,
  release/plan/status/project documentation, skills, Git metadata, or sibling
  paths.
- Proposed commit subject: `feat: add reltree badge gate`
- Complete only when both command surfaces share one request/policy, all
  frozen check/write/skip/error and README.zh consistency scenarios pass the
  coding-worker evidence layer and independent-runner evidence layer, the real
  diff is within scope, and Sol review passes with no material finding.

## Stop conditions

Stop and report the exact evidence without choosing a new policy if:

- local origin cannot identify one GitHub `OWNER/REPO` under the frozen forms;
- more than the equivalent `X.Y.Z`/`vX.Y.Z` tie requires tag preference;
- a managed line cannot be distinguished without consuming an unrelated badge
  or prose line;
- preserving a README's untouched bytes would require broad encoding/newline
  normalization;
- correct behavior requires tree/project/status/report integration or any
  unowned source/test/document path;
- a proposed implementation requires network access, remote Git writes,
  workflow creation, `project.md` mutation, cross-file rollback, staging,
  commit, or user approval.

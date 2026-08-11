# task-3 — External/local revisions and sync timestamps

## Goal

`migrate-reltree-gates`

## Objective

Replace task-2's `pending-task-3` report placeholders with complete local and
external revision facts. Preserve task-2's local relationship graph and atomic
report boundary while implementing the configured/CLI-selected
`false|auto|true` external Git revision policy, safe reuse from the previous
`project.md`, explicit unavailable/stale states, and exact UTC synchronization
times.

This task does not add graph nodes or edges. Local projects remain task-2
nodes, normal external dependencies remain declarations owned by their local
node, and a local checkout always wins over external revision handling.

## Contract authority and execution path

- Normative behavior is frozen by this contract, `release.md:166-256`, the
  task-3 section of `docs/plan/migrate-reltree-gates/plan.md`, and the user's
  accepted decisions repeated below.
- task-2 is committed at `1979be3` and supplies the shared request, bounded
  graph, relationship facts, enriched local nodes, status evaluator,
  deterministic renderer, and atomic writer. Its local graph semantics are not
  reopened here.
- Execution uses the normal `luna_coding_worker` path. That worker owns all
  implementation and Coding Self-Tests. A separate `luna_runner` owns all
  Independent Verification. Neither worker may delegate or spawn children.
- This is an implementation-only contract. Workers must not edit `plan.md`,
  either `status.md`, `release.md`, `completed.md`, workflow/review artifacts,
  skills, Git metadata, sibling repositories, or any other documentation.
- No worker stages or commits. The dispatcher alone may commit after both
  evidence layers and Sol review pass.

## Product scope

### In scope

- Preserve config `{rev, false|auto|true}`, CLI `--rev false|auto|true`, CLI
  precedence over config, and default `auto` from the existing normalized
  request.
- Attach local-checkout revision facts to existing task-2 declaration/edge
  facts without another Git or graph discovery path.
- Classify external declarations, resolve applicable Git selectors with one
  bounded read-only `git ls-remote` boundary, and add injected clock support.
- In `auto`, read only the selected output path's prior report and safely reuse
  exact matching revision evidence.
- Extend report format, warnings, caveats, and status evaluation for revision
  outcomes while preserving deterministic ordering and atomic replacement.

### Out of scope

- task-4 `bgate`, any README write or badge-policy change.
- task-5 packaged skill, installer, destination, staging, or rollback behavior.
- New commands/options, `--profile`, profile in report identity, external graph
  nodes, dependency resolution/fetch, local graph changes, persistent cache
  outside `project.md`, HTTP APIs, Git hosting policy, or remote writes.

## Exact ownership

### Owned product paths

- `src/rebar3_reltree_project.erl`
- `src/rebar3_reltree_git.erl`
- `src/rebar3_reltree_status.erl`
- `src/rebar3_reltree_report.erl`
- `src/rebar3_reltree_rev.erl` (new)
- `src/rebar3_reltree_clock.erl` (new)

The worker may fix compiler warnings introduced by task-3 in
`src/rebar3_reltree_clock.erl`, but only through semantics-preserving cleanup
of warning-causing bindings or private dead code. This does not authorize a
clock API, validation, formatting, timestamp, or broader source refactor.

`src/rebar3_reltree_cli.erl` and `src/rebar3_reltree_request.erl` are decisive
read-only interfaces for this task. Their existing config/CLI precedence,
default, error classes, profile handling, and normalized `rev` atom must not be
changed. `src/rebar3_reltree_graph.erl` and
`src/rebar3_reltree_config.erl` are also read-only: revision enrichment must
consume their existing node, declaration, edge, and relationship facts.

### Owned test paths

- `test/rebar3_reltree_cli_tests.erl`
- `test/rebar3_reltree_request_tests.erl`
- `test/rebar3_reltree_project_tests.erl`
- `test/rebar3_reltree_status_tests.erl`
- `test/rebar3_reltree_report_tests.erl`
- `test/rebar3_reltree_rev_tests.erl` (new)
- `test/rebar3_reltree_SUITE.erl`
- `test/rebar3_reltree_graph_tests.erl` (compatibility assertions only)

Ownership of `test/rebar3_reltree_graph_tests.erl` is limited to replacing the
two obsolete `pending-task-3` report assertions in
`transitive_local_closure_and_external_declaration_test/0` and
`checkout_only_and_external_declarations_do_not_create_edges_test/0` with the
task-3 final non-Git declaration expectation
`revision_state: not-applicable`. Do not change their setup, graph/node/edge or
relationship assertions, add graph behavior, refactor this test module, or
otherwise reopen task-2 graph semantics.

Tests may create unique temporary fixture projects and local bare Git
repositories outside the repository and must clean them. They must configure
no network remote and must never use a real credential or user directory. No
repository path deletion is authorized.

If implementation requires a change outside these exact paths, stop and report
the path and reason; do not silently widen ownership.

## Decisive integration approach

Keep provider and escript adapters policy-free. Their existing normalized
request reaches `rebar3_reltree_project:generate/1,2`. After task-2 builds and
enriches the complete local model, but before final status evaluation and
rendering, call one shared revision enrichment boundary with:

- normalized `rev` mode from the request;
- selected `output_path` as the only possible prior report;
- task-2 nodes, edges, and per-node `dependency_relationships`;
- injected lookup and clock dependencies from generation options.

The revision boundary returns enriched declaration records, revision warnings,
revision status reasons, and report-level `network_sync_at`. Status is then
evaluated once from the combined task-2 and revision facts. The renderer
renders only the completed model; it performs no lookup, prior-report read, or
clock call. The existing atomic writer remains the sole product write path.

## Frozen behavior and invariants

### Request, profile, and report identity

- The effective mode is already decided by
  `rebar3_reltree_request:normalize/1`: CLI `--rev` overrides `{rev, Mode}` and
  absence of both means `auto`. Provider and escript must retain parity.
- Profile selects only `_build/<profile>/reltree/project.md`. Profile is not
  rendered, is not part of declaration/cache identity, and must not alter
  report content except by selecting a distinct prior/output file.
- Report `format_version` becomes `2`. A task-2 version-1 report is recognized
  as a legacy report with no reusable revisions; first `auto` generation looks
  up every applicable external Git identity. It is not diagnosed as malformed.
- Only a prior version-2 report at the exact current `output_path` may supply
  reusable evidence. No other profile, path, file, or cache is consulted.

### Local revision semantics

- Every included local node keeps task-2's locally read `git_head`; this is the
  node's local revision regardless of `rev` mode.
- A declaration whose existing relationship fact is `local_checkout` gets
  `revision_state: local-checkout`, the target node's `git_head` as
  `resolved_revision`, and declaration `network_sync_at: not-performed`.
  It never uses prior external metadata and never invokes `ls-remote`.
- An `omitted_local_checkout` declaration remains a local relationship anomaly:
  `revision_state: local-unavailable`, no resolved revision, no external
  fallback, and no lookup. task-2's graph issue continues to select
  `insufficient-local-data`.
- The revision layer must derive local target/head from task-2's existing edge
  and node model. It must not re-read `_checkouts`, rescan projects, or create a
  second local identity/relationship implementation.

### External declaration classification

An external declaration is Git-applicable only when it contains one of these
Rebar3 source shapes, with a non-empty string/binary URL:

- `{Name, {git, Url}}`
- `{Name, {git, Url, Selector}}`
- `{Name, Vsn, {git, Url}}`
- `{Name, Vsn, {git, Url, Selector}}`

`Name` remains the atom already validated by task-2. `Vsn` is retained only in
the rendered original declaration. A missing selector normalizes to `head`.
An explicit selector must be `{branch, Value}`, `{tag, Value}`, or
`{ref, Value}`, where `Value` is a non-empty string/binary. URL and selector
values are normalized to validated UTF-8 text; no atoms are created from them.

- A package/version/bare-atom or other declaration with no Git source is
  `not-applicable`, emits no revision warning, has no resolved revision, and
  performs no lookup.
- A Git-shaped declaration with an empty/invalid URL, malformed selector, or
  unsupported Git source form is `tracking-disabled` in mode `false`. In
  `auto|true` it is `missing`, emits one deterministic
  `external-revision-invalid` warning, and contributes
  `external_revision_missing` to status without invoking Git.
- Duplicate declarations with the exact same normalized identity share one
  lookup/cache decision and render the same revision result. Declarations with
  the same dependency name but different URLs/selectors are distinct external
  identities unless task-2 classified that name as a local checkout, in which
  case all declarations for that local relationship bypass external handling.

### Exact external identity and prior-report reuse

The reusable identity is exactly:

1. owning local node canonical path;
2. normalized dependency name;
3. normalized source URL;
4. normalized selector kind and selector value.

The original declaration term, profile, output path, app version, current
working directory spelling, and report order are not additional identity
fields. A change to any of the four identity fields invalidates reuse. Prior
entries not present in the current model are ignored and disappear on successful
replacement.

`auto` reads the prior report at most once, with a hard 4 MiB maximum. It may
reuse only a complete version-2 external-declaration record whose ordered field
set, UTF-8/escaping, identity values, revision state, full hexadecimal resolved
revision, and RFC 3339 timestamps all validate. It must use a bounded,
non-executable parser: no `file:consult`, `binary_to_term`, general Erlang term
parsing, dynamic atom creation, or evaluation.

- Missing version-2 output is a normal empty cache.
- Version 1 is a normal non-reusable legacy cache.
- Oversized, unreadable, malformed, duplicate-identity, or unsupported-version
  prior data emits one deterministic `prior-revision-report-invalid` warning
  with a bounded reason and is ignored. This warning alone does not lower tree
  status if fresh lookups succeed.
- A prior `resolved` or `reused` record is valid reusable evidence. A prior
  `stale`, `missing`, `tracking-disabled`, `not-applicable`, local state, or
  malformed record is never reusable as current evidence. A valid stale record
  may retain its old revision only for the failure behavior below, never skip a
  new `auto` lookup.

### Mode matrix

- `false`: do not read the prior report and perform zero external lookups.
  Well-formed or Git-shaped external declarations are `tracking-disabled`;
  non-Git declarations are `not-applicable`. Report-level
  `network_sync_at` is `not-performed`. Disabled tracking does not lower status.
- `auto`: reuse valid exact-match prior evidence as `reused`, preserving its
  `resolved_revision`, `revision_observed_at`, and declaration
  `network_sync_at`. Look up every applicable identity that is new, changed,
  previously missing/stale/invalid, or absent from a valid cache.
- `true`: do not read or reuse prior evidence. Attempt every well-formed
  applicable external Git identity on every invocation.
- Successful lookup is `resolved`, records the exact commit and current attempt
  time, and does not lower status.
- Failed `auto` lookup with previously valid exact-match resolved evidence keeps
  that revision and its original `revision_observed_at`, marks the state
  `stale`, records the current failed-attempt time as declaration
  `network_sync_at`, emits one bounded `external-revision-stale` warning, and
  contributes `external_revision_stale` to status.
- Failed lookup without such evidence, including every failed `true` lookup,
  is `missing`, has no resolved revision or observed time, records the current
  failed-attempt time as declaration `network_sync_at`, emits one bounded
  `external-revision-missing` warning, and contributes
  `external_revision_missing` to status.
- `missing` and `stale` select `insufficient-local-data`, which retains
  precedence over task-2 `update-required`. Lookup failure does not abort report
  generation; the complete degraded report is still atomically replaceable.

The exact revision-state vocabulary is:

`local-checkout | local-unavailable | not-applicable | tracking-disabled |
resolved | reused | stale | missing`.

### Read-only lookup boundary

- Production lookup is `git ls-remote` through the fixed Git executable and
  argument-vector/port boundary already established by task-2. No shell is
  used. The command has bounded output and timeout, disables interactive
  credential prompting, and returns bounded sanitized reasons without command
  environment, credentials, or unbounded remote output.
- `head` resolves advertised `HEAD`; `branch` resolves exactly
  `refs/heads/<Value>`; `tag` resolves exactly `refs/tags/<Value>` and uses its
  peeled `^{}` commit for an annotated tag or its direct commit for a
  lightweight tag; `ref` resolves the declared advertised ref/pattern only
  when all matching rows identify one compatible commit. Zero matches,
  malformed object IDs, a tag object without a valid peel, or incompatible
  multiple commits is failure.
- The lookup result is one full hexadecimal object ID exactly as advertised.
  It never infers a commit from version text, local tags, dependency names, a
  package registry, or task-2 local checkout facts.
- No invocation performs `fetch`, `clone`, `checkout`, `pull`, `push`, remote
  mutation, tag/ref mutation, dependency installation, or network API access.
  Test lookups use only local filesystem URLs/paths and bare repositories.

### Timestamp semantics

- All rendered times are UTC RFC 3339 at second precision:
  `YYYY-MM-DDTHH:MM:SSZ`. The clock is injectable and validated; invalid clock
  output is a structured generation failure before atomic replacement.
- `revision_observed_at` is when the rendered revision was successfully
  resolved by an actual lookup. `auto` reuse and stale fallback preserve it.
- Declaration `network_sync_at` is the time of the actual lookup attempt whose
  result is represented. It equals the successful attempt for `resolved`, the
  preserved successful time for `reused`, and the latest failed attempt for
  `stale|missing`. Local, disabled, and not-applicable declarations render
  `not-performed`.
- Report-level `network_sync_at` is the greatest valid declaration
  `network_sync_at` backed by an actual current or reused lookup. Failed
  attempts count. If no represented declaration has ever performed a lookup,
  it is exactly `not-performed`.
- `local_sync_at` is captured after graph/revision enrichment and complete
  in-memory model construction for the report being written. Every successful
  atomic replacement receives the current injected time. A failed generation
  or replacement leaves the old report and its times byte-identical.
- With fixed clock/lookup inputs, report bytes are deterministic. Changing only
  `local_sync_at` changes only that field; changing one lookup attempt time
  changes only that declaration's `network_sync_at` and the report-level
  maximum when applicable.

### Version-2 report shape

- Preserve task-2's metadata order, replacing the fixed network placeholder
  with the computed value: `format_version`, `status`, `local_sync_at`,
  `network_sync_at`, current project path/name, warnings, nodes, caveats.
- Each local node still renders `git_head`. Each runtime declaration becomes a
  fixed multiline record in deterministic declaration order. It renders name,
  original declaration, relationship, and revision state. Applicable external
  records additionally render normalized source URL, selector kind/value,
  resolved revision or `none`, `revision_observed_at` or `not-performed`, and
  declaration `network_sync_at` in a fixed field order.
- Local-checkout records render their target local revision and
  `not-performed` network time. Non-applicable, disabled, unavailable, and
  missing records explicitly render `none`/`not-performed` values rather than
  omitting fields. Stale records visibly retain the stale revision and original
  observation time while showing the latest failed attempt time.
- The prior parser accepts only the exact version-2 external declaration record
  structure emitted by this renderer. Arbitrary retained declaration terms
  remain display-only and are never deserialized for cache identity.
- Remove `external_revisions_pending_task_3` from report/node caveats.
  Retain `readme_mutation_not_performed`; render a deterministic read-only or
  tracking-disabled caveat appropriate to the effective mode. Do not introduce
  task-4 or task-5 facts.
- Preserve task-2 sorting, UTF-8 escaping, in-memory rendering, unique temporary
  sibling, atomic rename, prior-report preservation, and owned-temp cleanup.

## Forbidden alternatives

- No profile field/identity, external node/edge, changed checkout precedence,
  second graph scan, local-head remote validation, or remote fallback for an
  omitted/broken checkout.
- No fetch/push/clone/checkout/pull, HTTP client, package-registry lookup,
  remote write, tag mutation, shell command, credential prompt/logging, or real
  network fixture.
- No cache beside `project.md`, cache reuse in `false|true`, cache reuse after
  identity change, silent success for malformed applicable Git declarations,
  or stale evidence represented as current.
- No report parsing through executable/general term deserialization, no atom
  creation from report bytes, no direct write before full generation, and no
  deletion of the previous report.
- No `bgate`, README mutation, installer, packaged skill, new provider/command,
  or changes to task-1/task-2 CLI, profile, graph, badge, or version policy.

## Frozen test semantics

Tests must prove observable policy and boundary behavior, not merely module
existence.

### Success and local-boundary scenarios

- Config/CLI/default mode selection remains `config < CLI` with default
  `auto`, and provider/escript produce equivalent effective requests/reports.
- A local checkout declaration renders the target node's local `git_head` in
  all three modes, performs zero external lookup for that name, and ignores a
  matching prior external cache record.
- `false` performs zero prior-report reads and zero lookups; Git declarations
  are disabled, package/bare/version declarations are not applicable, and both
  report/declaration network times are `not-performed`.
- A task-2 version-1 report causes fresh `auto` lookup without malformed-cache
  warning. First `auto` resolves applicable declarations; second identical
  `auto` reuses exact identities with zero lookups and preserved timestamps.
- `true` performs one lookup per unique applicable identity on every run and
  never reuses an old revision.
- Branch, lightweight tag, annotated tag peel, HEAD, and unambiguous ref resolve
  to exact commits in local bare repositories. Package/non-Git declarations
  never invoke Git.

### Identity, failure, and status scenarios

- Changing owner canonical path, dependency name, source URL, selector kind, or
  selector value invalidates auto reuse; changing profile alone is not report
  identity, though its distinct output path naturally has its own prior file.
- Duplicate exact identities share one lookup. Same-name declarations with
  different source/selector identities do not share evidence.
- Missing report, malformed/oversized/unsupported version-2 report, duplicate
  prior identity, malformed fields, invalid UTF-8, invalid object ID, and
  invalid timestamp are safely rejected without atoms or evaluation. Fresh
  success remains eligible for `up-to-date`; relevant cache warnings are
  deterministic and bounded.
- Zero/multiple-incompatible lookup matches, timeout, unavailable executable,
  invalid Git shape, and nonzero exit yield `missing` without prior evidence.
  In `auto`, a valid exact prior revision becomes visibly `stale` after failed
  refresh. Both outcomes select `insufficient-local-data` while generation
  succeeds and unrelated declarations continue.
- `insufficient-local-data` from revision evidence outranks an existing
  task-2 `update-required`; disabled/not-applicable/resolved/reused evidence
  does not independently lower status.

### Time, determinism, and mutation scenarios

- Injected clocks prove resolved, reused, stale, missing, report maximum, and
  local replacement times exactly. Repeated fixed inputs are byte-identical;
  normalized comparisons isolate only intentionally changed time/revision
  fields.
- Lookup arguments/counts prove fixed executable/argv use and no forbidden Git
  command. Local fixtures have no network remote and no credential prompt.
- Render or clock failure and injected write/close/rename failures preserve the
  previous report byte-for-byte, including prior timestamps, and leave no
  invocation-owned temporary sibling.
- No README, workflow, config, checkout, Git ref, task-4, task-5, or path outside
  the selected report is modified.

## Ordered implementation steps

1. Add the injected clock boundary and move `local_sync_at` into the completed
   model so the renderer is pure with respect to time.
2. Implement pure external declaration/source/selector normalization and exact
   identity keys, consuming task-2 relationship facts for local precedence.
3. Extend the bounded Git argv runner with injected local-only `ls-remote`
   lookup and exact HEAD/branch/tag/ref result resolution.
4. Define/render report format 2 and implement its bounded external-record
   parser, including version-1 migration and exact identity reuse.
5. Implement the `false|auto|true` matrix, failure/stale behavior, warnings,
   per-declaration/report timestamps, caveats, and status integration.
6. Add focused EUnit and Common Test coverage for all frozen scenarios using
   temporary local bare repositories and injected lookup/clock failures. In
   the task-2 graph compatibility tests, update only the two expressly owned
   obsolete report assertions to the final `not-applicable` state.
7. Run every Coding Self-Test, inspect exact changed paths, clean generated
   artifacts, and return the complete worker-authored evidence packet without
   staging or committing.

## Coding Self-Tests — coding worker

Run from `/home/slepher/project/rebar3_reltree` after implementation and after
every rework:

1. `rebar3 compile` — expect exit 0.
2. `rebar3 eunit` — expect exit 0 and record the complete count.
3. `rebar3 ct` — expect exit 0 and record suite/case counts.
4. `rebar3 escriptize` — expect exit 0.
5. Exercise isolated provider and built-escript fixtures for `false`, first and
   second `auto`, identity-changed `auto`, failed-refresh stale `auto`, repeated
   `true`, local-checkout precedence, malformed Git source, package/non-Git
   declaration, version-1 prior report, and malformed version-2 prior report.
6. Exercise local bare-repository HEAD, branch, lightweight/annotated tag, ref,
   zero-match, incompatible-multiple-match, nonzero, timeout, and executable
   unavailable outcomes. Record exact sanitized argv and lookup counts and
   prove every fixture has no network remote.
7. Assert all revision states, status precedence, observation/declaration/
   report/local timestamps, exact identity invalidation/reuse, deterministic
   warning/order/output, and profile absence from report identity.
8. Snapshot reports and fixture files around clock/render/write/close/rename
   failures and prove old-report preservation, temporary cleanup, and absence
   of README/config/checkout/ref or external writes.
9. Record `git status --short` and `git diff --check`; remove all generated
   artifacts and classify only declared owned paths as task-attributable.

The coding packet must identify the worker; every command, completion state,
exit status, and test count; every fixture outcome; lookup argv/counts;
revision states and timestamps; cache reuse/invalidation; deterministic and
atomic-preservation comparisons; exact changed paths; and cleanup results.

## Independent Verification — separate `luna_runner`

Only after the coding worker's complete self-test packet exists, the dispatcher
must route the exact worktree/diff and this contract to a fresh
`luna_runner`. Sol does not execute any command in this section.

1. Repeat `rebar3 compile`, `rebar3 eunit`, `rebar3 ct`, and
   `rebar3 escriptize`.
2. Independently repeat every mode, local-precedence, identity, prior-report,
   lookup-result, status, timestamp, deterministic-output, and atomic-failure
   fixture listed under Coding Self-Tests.
3. Record raw exits/counts/output, lookup argv/counts, proof of local-only bare
   remotes, revision states, observation/network/local times, cache behavior,
   unchanged mutation snapshots, generated artifacts, and cleanup.
4. Record raw `git status --short` and `git diff --check` results.

The runner packet must identify the runner, each command, completion or
interruption state, exact exits/test counts, and raw scope/mutation evidence.
It performs no source/test semantic audit and no edits. Sol separately reviews
the real diff, parser/lookup safety, graph-interface reuse, report semantics,
and exact scope using that completed packet.

## Expected paths, commit, and completion

- Task-attributable tracked/untracked paths are exactly the six owned product
  paths and eight owned test paths listed above, subject to the narrow graph
  compatibility-test restriction. Normal ignored `_build` output
  is not task scope. Temporary reports, projects, and bare repositories must be
  outside the repository or removed before handoff.
- No deletion is authorized. No plan/status/release/completed/review/skill,
  sibling, Git metadata, task-4, or task-5 path may appear in the coder diff.
- Proposed commit subject: `feat: track external revisions in reltree`
- Complete only when local checkout revisions and every external mode/state,
  exact cache identity, safe parser, read-only lookup, timestamp/status rule,
  deterministic report, and atomic failure boundary pass both evidence layers;
  the real diff matches ownership; and Sol review returns `passed`.

## Stop conditions

Stop and report exact evidence without widening scope if:

- a supported Rebar3 Git declaration or selector cannot be mapped to one exact
  commit through bounded read-only `ls-remote` under the frozen rules;
- credential acquisition, interactive prompting, a non-Git protocol policy,
  fetch/clone, or any remote/local write would be required;
- prior report fields cannot be parsed and identity-matched without general
  term deserialization, atom creation, ambiguous escaping, or unbounded input;
- local checkout precedence or target revision cannot be obtained from
  task-2's existing nodes/edges/relationship facts without rescanning;
- required behavior would add profile to report identity, alter task-2 graph,
  implement task-4/task-5, or change a path outside exact ownership;
- another worker/user overlaps an owned path, generated artifacts cannot be
  cleaned, or a self-test/verification command attempts forbidden network,
  dependency mutation, staging, or commit.

Do not resolve such a condition by inventing a fallback, treating stale data as
current, converting an external declaration into a local relationship, or
editing workflow documents/status.

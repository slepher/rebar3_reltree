---
name: local-workflow
description: Execute or resume repository initiatives through versioned plan-N.md files plus durable status.md and commit.md artifacts, with Sol planning and reviewing small tasks, Luna implementing and self-testing, optional risk-triggered independent verification, and the dispatcher owning recovery, status, staging, and commits. Use for multi-task project work, interruption recovery, one-task-at-a-time implementation, review correction commits, design-plan revisions, and auditable code history. Use $delegate for all worker routing.
---

# Local Workflow

Run one small, independently implementable, testable, reviewable, and
committable task at a time. Use `$delegate` for role selection, worker identity,
permissions, and result verification.

## Route the requested goal

Treat the user's explicit Goal as authoritative. Resolve it only to the matching
repository initiative, normally `docs/plan/<Goal>/`. Before reading workflow
artifacts:

1. Select only the requested Goal's initiative.
2. Read `status.md` first. Follow its exact `Active plan: plan-N.md | none` and
   optional `Draft plan: plan-N.md | none` references, then read the applicable
   plan, `commit.md` when present, the current task, and current reviews. Never
   select a plan by recency or content guess.
3. Read specifications named by the user, referenced by the task, or required
   by repository instructions. Do not infer an OpenSpec path from the Goal.
4. If the directory is absent, create the initiative. If its contents describe
   another Goal, start a matching initiative instead of repurposing it.

Repeat the exact Goal and normative inputs in delegated contracts. Explicitly
exclude unrelated plans and specifications.

## Isolate historical plans from current authority

Treat the active normative specifications and the user's current decisions as
the only sources of required product behavior. A superseded plan, prior task,
review, retrospective, sibling implementation, or partial diff is historical
evidence, not product authority. Its existence never carries an interface,
command, architecture, edge case, test matrix, or acceptance strength into a
new plan.

When a specification changed after an earlier plan was written:

1. derive the replacement plan from the current normative inputs before
   consulting historical design detail;
2. have the dispatcher or `luna_runner`, never Sol, extract only lineage, the
   last actually selected task, completed commit boundaries, attributable
   paths, and recoverable partial work;
3. give Sol only that bounded historical-facts packet, never the old plan body
   or its path as readable planning input;
4. classify every proposed public surface, invariant, failure case, and
   acceptance gate as `normative`, `necessary implementation constraint`, or
   `historical only`;
5. omit `historical only` items. Keep a necessary implementation constraint
   only when current repository or platform evidence proves it is required to
   implement a normative behavior; implementation convenience is not proof;
6. record in the replacement plan a short `Historical isolation` summary that
   names rejected old surfaces or requirements which could otherwise be
   mistaken for current scope.

Sol must not open, read, search, or receive a superseded plan, including legacy
`plan.md`, while planning, revising a plan, defining a task, selecting
continuity, or reviewing code. The dispatcher must explicitly list those paths
as forbidden reads in every Sol contract. Do not send superseded plans or
sibling defect lists to a coding worker either. Quote only the exact historical
fact needed for the current decision and label it `historical evidence,
non-normative`. Preserve attributable partial work physically during recovery,
but reassess every hunk against the current accepted plan; preserved code does
not preserve its old requirement.

## Assign authority

### Sol

Sol owns substantive decisions:

- requirement reconciliation and architecture;
- versioned `plan-N.md` files, task selection, and, after plan approval,
  detailed task contracts;
- file ownership, reuse decisions, data shapes, pseudocode, and stop conditions;
- code review verdicts and coder-facing corrections;
- deciding whether an unfinished task is too broad and revising the plan;
- deciding whether independent verification is warranted;
- selecting continuity to the next task.

Sol is read-only for product source and tests unless a user-approved contract
explicitly grants exact source paths. Sol never edits `status.md` or
`commit.md`, stages, commits, delegates, or spawns children.

Sol's workflow artifacts are written to the shared repository workspace, not
only returned in the child conversation or an isolated private checkout. The
dispatcher must give Sol the exact artifact path and write permission in the
task contract, then verify that path and its `Plan status` on return. A prose
summary without the required file is an incomplete planning result; the
dispatcher must recover or re-route Sol and must not create the plan itself or
ask the user to authorize dispatcher authorship.

Sol does not run Git, build, test, lint, or other mechanical inspection
commands while planning or reviewing. The dispatcher or `luna_runner` gathers
those facts first and sends Sol a bounded evidence packet. Sol reasons from
that packet and inspects only decisive files when needed; it must not turn a
planning contract into a repository-wide audit.

#### Read-access contract

Read access is separate from mechanical inspection. Every Sol contract must
explicitly name all four of these fields:

- `Allowed read paths`: exact normative, task, source, test, and evidence paths
  Sol may open. A path listed here grants read access in the shared workspace;
  the contract must not simultaneously say that all shell/file commands are
  forbidden.
- `Forbidden read paths`: every superseded plan, unrelated task contract, and
  sibling artifact that must not be opened or searched. Use exact paths and
  explicit `task-M.md` globs where applicable.
- `Allowed read-only commands`: normally `sed`, `awk`, `rg`, and bounded file
  existence/listing checks restricted to `Allowed read paths`. These commands
  may inspect text and metadata but must not write, generate, or mutate files.
- `Forbidden mechanical commands`: Git, build, test, lint, formatting, network,
  or other commands reserved for the dispatcher or `luna_runner`.

The same four fields are required in every Luna coding-worker and Luna runner
contract, with the worker's exact task contract and owned source/test paths
listed explicitly. A coding worker may read its current task contract and
decisive repository files; a runner may read the bounded evidence paths needed
for its specified commands. Neither receives broad initiative-directory read
permission.

The dispatcher must resolve permission contradictions before spawning a worker.
In particular, `Allowed read paths` plus `Forbidden shell commands` is invalid
when the worker has no non-shell file reader: permit bounded read-only commands
instead. If a worker reports it cannot read a path that the contract already
allows, reissue the contract with explicit read-only command permission before
replanning, changing product scope, or marking the task blocked. If the needed
path is outside the contract, the dispatcher or `luna_runner` must extract only
the required fact and pass it as labeled evidence; the worker must not widen
its own read scope.

### Luna coding worker

`luna_coding_worker` owns only the current task's exact product/test paths. It
implements Sol's frozen behavior and blueprint, writes the required tests, runs
every Coding Self-Test, fixes failures within scope, and returns the real diff
and command evidence. It stops on an undecided behavior, unowned path, or
contract conflict instead of making a product decision.

### Luna runner

`luna_runner` collects mechanical evidence or performs explicitly requested
independent verification. It may inspect HEAD, status, paths, diffs, logs, and
command results. During independent verification it runs specified commands
without editing code or judging architecture and assertion semantics.

### Dispatcher

The dispatcher owns routing, worker identity and permission checks,
`status.md`, `commit.md`, recovery coordination, scope checks, staging, and all
Git commits. It forwards Sol decisions without technical reinterpretation and
does not replace worker-authored evidence with its own technical conclusion.

## Persist only useful history

Keep these initiative artifacts:

- `plan-N.md`: one numbered, reviewable design generation containing Goal,
  lineage, normative inputs, constraints, dependencies, ordered task
  boundaries, acceptance summaries, and `Plan status: draft | accepted`;
- `status.md`: current repository snapshot, task, phase, evidence, blocker,
  exact `Active plan`, optional `Draft plan`, and one exact next action;
- `commit.md`: append-only index of code commits by task and review correction;
- `task-M.md`: complete implementation contract for task M, where M is a root
  integer such as `6` or a flat split identifier such as `6.1`;
- `task-M-code-review-N.md`: immutable Sol review decision;
- `task-M-code-review-N-retrospective.md`: create only for a systemic,
  repeated, contract, evidence-gate, recovery, or workflow failure.

The dispatcher writes `status.md` and `commit.md`; Sol writes plans, tasks, and
reviews. Never overwrite or renumber an existing task or review artifact.
Renumbering during a split applies only to future plan entries that have not
been materialized as artifacts or repository history.

Write every `plan-N.md` in the primary language used by the user for the Goal,
or in an explicitly requested language. Keep code identifiers, commands, paths,
and quoted specification terms exact. Do not translate historical artifacts
merely for consistency during recovery.

Keep plan and task detail at separate levels. A plan is the design decision and
task map; it must not duplicate function pseudocode, full test matrices,
Coding Self-Tests, or commit instructions. Put those details only in the
current `task-M.md`, created after the plan is accepted. A plan task entry is
limited to its number/title, one-sentence objective, prerequisites,
owned-area summary, key behavior boundary, dependency/order, and short
acceptance summary.

Number plans monotonically from `plan-1.md`. Keep earlier accepted plans as
historical design records. `status.md` is the sole authority for the active
plan; never maintain two active plans. For a legacy initiative containing only
`plan.md`, the dispatcher may mechanically rename it to `plan-1.md` without
changing its content, update status, and commit that migration before creating
another design plan.

`commit.md` exists for recovery and code-history inspection, not task
execution. Do not send it to coding workers. Record only commits that change
product source, tests, or implementation fixtures:

```markdown
## plan-N / task-M

- Initial implementation: <hash> <subject>
- Review 1 correction: <hash> <subject>
- Review 2 correction: <hash> <subject>
- Final verdict: passed at review N
```

Do not index workflow-only commits in `commit.md`. A commit cannot record its
own hash. After a code commit, append its real hash and include that ledger
update in the following review commit. The final passed-review commit includes
the last code mapping; do not create a separate final-ledger commit.

For an existing initiative without `commit.md`, create it during recovery and
reconstruct only code mappings supported by Git and immutable artifacts. Do not
rewrite completed task history merely to normalize old records.

## Maintain resumable status

Use one phase:

```text
planning | plan_review | task_planning | coding | coding_self_test | review |
rework | optional_verification | committing | handoff | blocked | complete
```

Update status immediately after every durable boundary and before dispatching
another worker: plan revision, task selection, coding return, self-test return,
code commit, review decision commit, correction commit, optional verification,
handoff, blocker, or completion. Record exact commands, exits, changed paths,
commit hashes, and one executable next action. Child IDs are hints only.

## Recover before continuing

On every continuation, and whenever status conflicts with the worktree, enter
recovery before dispatch:

1. Read status, its exact active or draft `plan-N.md` for the recorded phase,
   the commit ledger, current task, and reviews.
2. Inspect HEAD, `git status --short`, real diffs, untracked files, and expected
   task paths. Git and immutable artifacts override stale status prose.
3. Ask `luna_runner` for missing mechanical facts only when needed.
4. Give Sol the current authoritative inputs and the sanitized historical-facts
   packet. Explicitly forbid every superseded plan path; do not give Sol the raw
   historical artifacts. Sol returns:

```text
Recovered Task:
Recovered Phase:
Attributable Paths:
Completed Work:
Valid Evidence:
Invalidated Evidence:
Remaining Work:
Next Worker:
Exact Next Action:
```

5. The dispatcher reconciles `status.md` from that decision, then continues.

Do not redispatch an apparently unstarted task when attributable implementation
already exists. Do not discard partial work, rerun completed gates without an
invalidation reason, or modify completed tasks to repair checkpoint prose.

## Require user approval for each design plan

Before creating a formal design plan, have Sol write the next `plan-N.md` as
`Plan status: draft` in the user's language. When an earlier plan exists, state
`Supersedes: plan-K.md` and `Previous task: task-M`. Task M is the last task
actually selected under the prior plan, whether it passed, remains in progress,
is in rework, or is blocked. Begin the new plan at task M+1; never calculate the
number from the last completed or passed task. Ignore future task proposals that
were never selected under the old plan. Preserve task M and its artifacts as
history, and assign any usable attributable partial work to the first new task.
If no task was ever selected, begin at task 1. The dispatcher then:

1. prepares a bounded planning packet from `status.md`, the current required
   specifications, the historical-facts packet defined above, and (only when
   needed) `luna_runner` mechanical evidence;
2. sends Sol the packet, the exact plan path, and the concise plan-level
   fields defined above. Do not ask Sol to run Git/tests/builds or to write
   task contracts at this stage;
3. verifies that Sol's exact `plan-N.md` exists in the shared workspace, has
   `Plan status: draft`, names the required lineage and normative inputs, has
   the required `Historical isolation` summary, and has no out-of-scope product
   changes. Trace every proposed interface, behavior, invariant, and acceptance
   gate to a current normative input, an explicit user decision, or a proved
   necessary implementation constraint. Remove anything supported only by a
   superseded artifact or sibling implementation before presenting the draft;
4. sets `Draft plan: plan-N.md`, enters `plan_review`, and sets no current
   implementation task; retain the prior `Active plan` until approval;
5. presents the actually written draft and its task boundaries to the user;
6. stops without writing or rewriting the plan, writing a task contract,
   dispatching coding, or treating the plan as accepted. User approval is for
   the content of the visible draft, never permission for the dispatcher to
   author it.

If Sol returns without the artifact, or the artifact is not visible in the
shared workspace, record the incomplete planning result and re-route/recover
Sol with the same exact path. Do not substitute dispatcher-authored content
and do not ask the user whether the dispatcher may create the draft. Only
after a visible draft exists may the dispatcher request user review.

Proceed only after the user explicitly approves the draft. If the user requests
changes, return them to Sol, revise the draft, and repeat the review pause. On
approval, have Sol change only that plan's status and approved corrections to
`accepted`; then set `Active plan: plan-N.md`, clear `Draft plan`, and let the
dispatcher enter `task_planning`.

Create `plan-(N+1).md` only for a material product-design or requirement change:
changed scope, public behavior, interface, acceptance semantics, or normative
authority. Pause again for user review before activating it. Recovery-only
status reconciliation, coder-facing review corrections, and behavior-preserving
task decomposition do not create a new plan.

## Isolate task contracts

When an agent plans, writes, implements, reworks, verifies, or reviews
`task-N`, it must not open, read, search, or receive any `task-M.md` where
`M != N`. This prohibition includes parent, sibling, predecessor, successor,
completed, superseded, and future task contracts.

- While creating `task-N.md`, allow only `task-N.md` if it already exists for
  an authorized revision; otherwise forbid every existing `task-*.md`.
- While implementing, reworking, verifying, or reviewing `task-N`, allow only
  the exact `task-N.md`. Current-task review artifacts may be supplied when the
  phase requires them; unrelated task contracts remain forbidden.
- Put the exact allowed task path and an explicit `task-M.md (M != N)` forbidden
  glob in every Sol, Luna coding-worker, and Luna runner contract. Do not give a
  broad initiative-directory read scope that defeats this boundary.
- If another task contains a needed recovery fact, have the dispatcher or
  `luna_runner` extract only that fact before the task agent starts. Supply it
  as `historical evidence, non-normative`, without the source task path or body.
- If the task agent cannot proceed without reading another task contract, it
  must stop with `Clarification required`; it must not inspect the file to
  resolve the gap itself.

## Plan small tasks

In the draft plan, Sol maps the work into vertical behavior slices. Each entry
has one primary responsibility and only the concise plan-level fields defined
above. Do not put a complete implementation contract in `plan-N.md`.

After the user accepts the plan, Sol writes the selected `task-M.md`. That
artifact is the complete coder contract and must include objective and
normative behavior, prerequisites and exact owned paths, `Must change`,
bounded `May change`, and `Read only` paths, reuse and rejected alternatives,
input/output shapes, invariants, error and write boundaries, concise
function-level pseudocode, success/failure/boundary tests, Coding Self-Tests,
expected diff, stop conditions, and commit subject.

Derive that contract only from the current specifications and accepted plan.
For a replacement task, supply historical-task facts solely as a labeled
path/diff recovery extract, never by exposing another task contract. Do not copy
old command surfaces, architecture, edge-case catalogs, or test matrices unless
the accepted plan independently requires them. Require each test group to prove
one current acceptance boundary; worker context limits and prior test existence
are not reasons to preserve a gate.

Pseudocode decides architecture and data flow without prescribing every local
expression. Luna may choose ordinary local Erlang structure when it preserves
the contract.

Do not use tests, runner repetition, or internal stages to compensate for a
broad task. A task is too broad when it has multiple independently acceptable
behaviors, needs an intermediate review before later work is safe, combines
several complex responsibilities, needs separate test matrices, or cannot fit
in one coding worker's coherent context. When this occurs before coding, split
it directly in the active `plan-N.md` before dispatch. If the split preserves
accepted behavior and scope, it is task refinement, not a new design plan.

### Split an unfinished broad task

Completed, passed tasks are immutable. Sol may directly replace a not-started
broad task in the active plan with smaller tasks without creating another plan,
provided accepted behavior and scope remain unchanged. Keep the parent entry
as superseded history rather than deleting it.

Apply these identifier rules to every split:

1. Number replacements within the original root task family. Splitting
   `task-B` creates `task-B.1`, `task-B.2`, and so on; do not consume unrelated
   root integers. Keep split identifiers flat: never create `task-B.2.1`.
2. When splitting an existing child `task-B.i` into K replacements, keep
   `task-B.i` as the superseded historical parent, reserve
   `task-B.(i+1)` through `task-B.(i+K)` for its replacements, and shift every
   later unmaterialized sibling `task-B.j` upward by K before inserting them.
   Rename those future plan entries from highest to lowest to avoid collisions.
   Example: if `task-6.2` and planned `task-6.3` exist, splitting `task-6.2`
   into two produces replacement tasks `task-6.3` and `task-6.4`, and renames
   the former planned `task-6.3` to `task-6.5`.
3. A task is materialized once it has a task artifact, is current in status,
   has a code commit, or has a review. Never rename or reuse a materialized
   identifier. If a required shift would cross a materialized later sibling,
   stop and request a plan revision instead of inventing another numbering
   scheme or rewriting history.

If coding has started but the task remains unfinished:

1. Stop further implementation and recover the current diff.
2. Have Sol identify the smallest complete behavior represented by existing
   work and the remaining independent behaviors.
3. Revise the active `plan-N.md` in place to mark the old task `superseded
   before completion`, state the reason and replacement task numbers, and assign
   existing work to the first replacement task. Keep `Active plan` unchanged.
4. Preserve the old `task-M.md`; do not overwrite it or discard its diff.
5. Implement, self-test, commit, and review each replacement independently.

Ordered coding steps may exist inside one task, but they are not workflow
stages, review gates, or separate acceptance units. If a step needs its own
review, make it a task.

## Implement and self-test

Send the current `task-M.md`, applicable repository instructions, decisive
source paths, and current attributable diff to one `luna_coding_worker`. Do not
require it to read the overall plan, status, commit ledger, workflow skill, or
retrospectives, or any other `task-*.md`; promote every coder-relevant decision
into the current task contract or latest current-task coder-facing review.

The worker implements the task and directly runs every Coding Self-Test. Tests
prove the small task's frozen behavior; they do not compensate for unresolved
design or excessive scope. A failed self-test remains coding responsibility
until fixed or genuinely blocked.

After self-tests pass, the dispatcher:

1. verifies worker identity and complete command evidence;
2. compares status/diff paths with exact task scope;
3. confirms every deletion was authorized;
4. stages explicit code/test/fixture paths only;
5. runs `git diff --cached --check`;
6. verifies the staged name set exactly;
7. commits the task implementation immediately with the accepted subject;
8. appends the real hash to `commit.md` and records it in status.

Do not wait for task review to create the implementation commit. Do not amend,
squash, or rewrite it to hide later review corrections.

## Review the committed code

Sol formally reviews the fixed implementation commit, not a moving uncommitted
diff. Give Sol the active plan identity, task contract, reviewed commit and
diff, decisive source and test paths, coding self-test packet, and prior reviews
for the same task only. Sol performs semantic,
architecture, assertion-meaning, scope, and capability-reuse review and writes
exactly one verdict:

- `changes_required`: ordered findings, exact evidence, and the smallest
  coder-facing correction blueprint;
- `passed`: no material finding remains and the reviewed code commit satisfies
  the task contract.

The dispatcher commits every review artifact immediately as a workflow-only
review commit. Include current `status.md`, the ledger mapping for the reviewed
code commit, and a retrospective only when its systemic trigger applies.

For `changes_required`, send only the review decision, task contract, current
code, and permitted paths to Luna. After correction self-tests pass, the
dispatcher creates a new code commit named for `task-M review-N correction`,
appends it to `commit.md`, and requests review N+1. Never amend the reviewed
commit. Continue until passed or blocked.

For `passed`, the review commit also records the final verdict in `commit.md`
and finalizes status. This is the task's single finalization/ledger commit; do
not create another final-ledger commit.

## Verify independently only when warranted

Do not start `luna_runner` automatically after coding self-tests. Coding-worker
evidence is trusted unless concrete risk or inconsistency requires an
independent run. Sol or the user may require verification when:

- the coding worker was interrupted or returned incomplete evidence;
- reported results conflict with the diff, tests, or repository state;
- a failure needs independent reproduction;
- the task explicitly marks a high-risk transaction, concurrency, security, or
  destructive boundary;
- final initiative or release acceptance requires an independent full run;
- the user explicitly asks for it.

Run only the focused acceptance checks needed for that risk plus the appropriate
full suite. Do not mechanically duplicate every coding fixture by default. The
runner returns raw commands, exits, counts, status, diff, interruption state,
and generated artifacts. It does not edit or provide a code-review verdict.

If optional verification fails, Sol decides the correction, Luna implements and
self-tests it, the dispatcher commits a new review correction, and Sol reviews
that commit.

## Continue and complete

After a passed review commit, Sol selects the next eligible task and chooses
`reuse`, `fresh`, or `none`. Reuse Sol when architecture and constraints are
materially shared; use fresh context when the owned domain changes or retained
context would add noise. Before a fresh Sol, collect only the mechanical facts
it needs.

The dispatcher executes the continuity decision after the passed review commit.
Stop for missing authority, real specification conflict, unsafe scope, or
repository facts that invalidate the plan. Mark the initiative complete only
when every non-superseded task has a passed review, all code commits are indexed,
status names no blocker, and the final worktree contains no unexpected task
artifact.

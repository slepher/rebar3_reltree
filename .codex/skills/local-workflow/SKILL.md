---
name: local-workflow
description: Govern explicitly requested repository initiatives through versioned plan-N.md files plus durable status.md and commit.md artifacts, with Sol planning and review, Luna implementation and self-test, optional risk-triggered verification, and dispatcher-owned recovery, staging, and commits. Use only when the user explicitly invokes $local-workflow, explicitly requests this durable planned/reviewed/committed workflow, or asks to resume an unfinished initiative already governed by it. Do not use for ordinary localized edits, questions, diagnostics, or tests merely because workflow artifacts or uncommitted changes exist. Referring to, inspecting, or editing this skill does not invoke its repository workflow. Use $delegate for all worker routing after activation.
---

# Local Workflow

## Activation gate

Before reading any initiative artifact, confirm that the user explicitly invoked
`$local-workflow`, explicitly requested this governed workflow, or asked to
resume an unfinished initiative already governed by it. If none applies, stop
using this skill and handle the request through the normal task workflow; do not
create, reopen, or recover an initiative.

Do not activate merely because the repository contains `docs/plan/`,
`status.md`, prior workflow artifacts, or uncommitted changes, or because a
localized change touches an area covered by a completed initiative. Questions
about, inspections of, and edits to this skill are not requests to execute it
unless the user separately asks to run the governed repository workflow.

Run one independently implementable, testable, reviewable, committable task at
a time. Use `$delegate` for worker routing, permissions, and result verification.

## Route the requested goal

Treat the user's explicit Goal as authoritative. Resolve it only to the matching
initiative, normally `docs/plan/<Goal>/`. Before reading workflow artifacts:

1. Select only the requested Goal's initiative.
2. Read `status.md` first. Follow its exact `Active plan: plan-N.md | none` and
   optional `Draft plan: plan-N.md | none` references, then read the applicable
   plan, current task, and current reviews. Never select a plan by recency or
   content guess. Do not read `commit.md` during task execution or recovery.
3. Read specifications named by the user, referenced by the task, or required
   by repository instructions. Do not infer an OpenSpec path from the Goal.
4. If the directory is absent, create the initiative. If its contents describe
   another Goal, start a matching initiative instead of repurposing it.

Name the exact Goal and normative input paths in contracts. Restate only the
task-specific decisions a worker needs; exclude unrelated material.

## Isolate historical plans from current authority

Only active normative specifications and current user decisions define required
product behavior. Prior artifacts, sibling code, and partial diffs are
historical evidence, not product authority.

Before replacement planning or changed-specification recovery, read
[references/historical-isolation.md](references/historical-isolation.md)
completely. Forbid superseded plans and unrelated tasks; pass only exact facts
labeled `historical evidence, non-normative`.

## Assign authority

### Sol

Sol owns substantive decisions:

- requirement reconciliation and architecture;
- versioned `plan-N.md` files and, after plan approval, task contracts;
- file ownership, reuse decisions, data shapes, pseudocode, and stop conditions;
- code review verdicts and coder-facing corrections;
- deciding whether an unfinished task is too broad and revising the plan;
- identifying semantic risks that may warrant independent verification.

Sol reads only granted product/test paths and writes only its exact workflow
artifact. It never edits `status.md` or `commit.md`, stages, commits, delegates,
or spawns children.

Sol writes workflow artifacts to the shared repository workspace, not only its
conversation or a private checkout. Give it the exact path and write permission,
then verify the artifact and `Plan status`. A prose-only result is incomplete;
recover or re-route Sol rather than authoring the plan in the dispatcher.

Sol does not run Git, build, test, lint, or mechanical verification while planning
or reviewing. The dispatcher or runner sends it a bounded evidence packet. Sol
inspects only decisive files; it must not expand into a repository-wide audit.

#### Role access contract

Every Sol, Luna coding-worker, and Luna runner contract must name:

- `Allowed read paths` and `Forbidden read paths`;
- `Allowed write paths` and `Forbidden write paths`;
- `Allowed commands` and `Forbidden commands`.

Use exact paths and commands. Forbid superseded plans, unrelated tasks, and
`task-M.md (M != N)`. Never grant broad initiative-directory access.

Apply these role capabilities:

- Sol may use bounded text readers such as `sed`, `awk`, and `rg` on allowed
  paths and write only the exact plan, task, or review artifact assigned to it.
  Forbid Git, build, test, lint, formatting, network, product/test writes,
  `status.md`, and `commit.md`.
- A coding worker may write only task-owned product, test, fixture, config,
  package, and documentation paths. Allow the exact build, test, lint, and
  formatting commands named as Coding Self-Tests. Forbid workflow-artifact
  writes, staging, commits, unrelated commands, and network unless separately
  authorized.
- A runner is read-only for repository content. Allow its exact inspection or
  verification commands and only the generated/build or unique temporary paths
  those commands require. Forbid source, test, workflow-artifact, staging, and
  commit writes.

Resolve contradictions before spawning. If an allowed path is unreadable
because no reader was permitted, reissue the contract with a bounded reader.
If a needed path is outside the contract, the dispatcher or runner extracts
only the required fact; the worker never widens its own scope.

### Luna coding worker

`luna_coding_worker` owns only the current task's exact implementation, test,
fixture, config, package, and related documentation paths. It implements Sol's
frozen behavior and blueprint, writes required tests, runs every Coding
Self-Test, fixes failures within scope, and returns real diff and command
evidence. It stops on an undecided behavior, unowned path, or contract conflict.

### Luna runner

`luna_runner` collects mechanical evidence or performs explicitly requested
independent verification. It may inspect HEAD, status, paths, diffs, logs, and
command results. During independent verification it runs specified commands
without editing code or judging architecture and assertion semantics.

### Dispatcher

The dispatcher owns routing and permission checks, `status.md`, `commit.md`,
recovery, scope checks, staging, and Git commits. It forwards Sol decisions and
does not replace worker evidence with its own technical conclusion.

## Use only the permission the operation requires

Follow `$delegate` and the current runtime's sandbox and approval rules. Run
allowed operations directly, request approval for known restricted operations,
and retry an unexpectedly blocked necessary operation only through the
runtime's approval mechanism. Permission is an execution constraint, never an
acceptance gate.

Before dispatching self-tests or verification, the dispatcher reads
[references/execution-safety.md](references/execution-safety.md) and includes
only its applicable constraints in the worker contract.

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
- `task-M-code-review-N-retrospective.md`: create only for a systemic or
  repeated contract, evidence-gate, recovery, or workflow failure.

The dispatcher writes `status.md` and `commit.md`; Sol writes plans, tasks, and
reviews. Review artifacts are immutable. A task contract may be revised only
before its first coding dispatch; afterward preserve or supersede it, never
overwrite it. Renumbering during a split applies only to future plan entries
that have not been materialized as artifacts or repository history.

Create `status.md` from [assets/status-template.md](assets/status-template.md).
If an existing status uses a legacy schema, mechanically migrate only its
current snapshot to this template before validation; do not copy completed-task
history or consult `commit.md`.
After each durable boundary and before dispatch, review, or commit, run
`python3 scripts/validate_workflow.py <initiative-directory>`. Treat validation
failure as a checkpoint defect: repair dispatcher-owned status mechanically or
return substantive artifact defects to Sol before continuing. This checks
checkpoint structure and references, not code or completion evidence.

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

`commit.md` is append-only, post-hoc audit evidence. The dispatcher updates it
but never reads or sends it during planning, execution, review, or recovery.
Record implementation commits that change code, tests, fixtures, config,
package assets, or task-required documentation:

```markdown
## plan-N / task-M

- Initial implementation: <hash> <subject>
- Verification 1 correction: <hash> <subject>
- Review 1 correction: <hash> <subject>
- Review 2 correction: <hash> <subject>
- Final verdict: passed at review N
```

Do not index workflow-only commits in `commit.md`. A commit cannot record its
own hash. After a code commit, append its real hash and include that ledger
update in the following review commit. The final passed-review commit includes
the last code mapping; do not create a separate final-ledger commit.

Changed task behavior and proportionate checks are the acceptance focus; related
artifacts never substitute for verification. Finish `task-M.md` before
dispatching Luna, and do not create or materially revise it after coding begins.
The unchanged contract and other task-owned artifacts may join the governed
implementation commit; do not create a separate checkpoint merely to record them.
A workflow-only checkpoint remains permitted for recovery; do not index it.

For an existing initiative without `commit.md`, reconstruct post-hoc mappings
only for an explicit audit; never make ledger reconstruction a task gate.

## Maintain resumable status

Use one phase:

```text
planning | plan_review | task_planning | coding | coding_self_test | review |
rework | optional_verification | committing | blocked | complete
```

Use these normal transitions:

```text
planning -> plan_review -> task_planning -> coding -> coding_self_test
coding_self_test -> committing -> optional_verification | review
optional_verification -> review | rework
review -> rework | task_planning | complete
rework -> coding_self_test
```

Any phase may enter `blocked`. Resume it only through recovery. `complete`
requires `Current task: none`, `Draft plan: none`, `Blocker: none`, and
`Next action: none`. The only exceptional backward transition is an unfinished
task split performed through [references/task-splitting.md](references/task-splitting.md).

Keep status as a concise current snapshot. Update it at each durable boundary
with the current task, phase, unresolved evidence, relevant commit, blocker, and
one executable next action. Keep exact command evidence only while the current
task needs it; after passed review retain references, not completed-task history.

## Recover before continuing

On every continuation, and whenever status conflicts with the worktree, enter
recovery before dispatch:

1. Read status, its exact active or draft `plan-N.md` for the recorded phase,
   current task, and current reviews. Do not read `commit.md`.
2. Inspect HEAD, `git status --short`, real diffs, untracked files, and expected
   task paths. Git and immutable artifacts override stale status prose.
3. Ask `luna_runner` for missing mechanical facts only when needed.
4. When attribution, evidence validity, remaining behavior, or next-worker
   selection requires substantive judgment, give Sol the current authoritative
   inputs and sanitized historical-facts packet. Explicitly forbid every
   superseded plan path; do not give Sol raw historical artifacts. Sol returns:

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

5. The dispatcher mechanically reconciles `status.md` from repository facts or
   that Sol decision, validates it, then continues.

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
3. verifies that Sol's exact `plan-N.md` exists with `Plan status: draft`, names
   required lineage and normative inputs, conditionally summarizes historical
   isolation, and has no out-of-scope product changes. Trace proposed behavior
   and gates to a normative input, explicit user decision, or proved necessary
   implementation constraint. If anything is supported only by a
   superseded artifact or sibling implementation, reject the draft and return
   the exact issue to Sol; the dispatcher must not edit the plan;
4. sets `Draft plan: plan-N.md`, enters `plan_review`, and sets no current
   implementation task; retain the prior `Active plan` until approval;
5. presents the actually written draft and its task boundaries to the user;
6. stops without writing or rewriting the plan, writing a task contract,
   dispatching coding, or treating the plan as accepted. User approval is for
   the content of the visible draft, never permission for the dispatcher to
   author it.

If the plan artifact is absent, record the incomplete result and re-route Sol
to the same exact path. Do not substitute dispatcher-authored content. Request
user review only after the artifact is visible.

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

- While creating `task-N.md`, allow an existing `task-N.md` only for an
  authorized pre-coding revision; otherwise forbid every existing `task-*.md`.
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

After plan acceptance, Sol writes the complete `task-M.md` coder contract. Always
include objective, normative behavior, exact owned paths, acceptance checks,
expected diff, stop conditions, and commit subject. Include other design details
only when material. Do not repeat plan background, global role restrictions,
unchanged behavior, or established test matrices.

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

Before splitting any planned or unfinished task, read and follow
[references/task-splitting.md](references/task-splitting.md) completely. Never
rename a materialized identifier or discard attributable partial work. Ordered
steps that require separate acceptance or review must become separate tasks.

## Implement and self-test

Confirm that Sol finished `task-M.md` in the shared workspace, then send it,
applicable instructions, decisive source paths, and the attributable diff to one
`luna_coding_worker`. Do not require the worker to read the plan, status, ledger,
workflow skill, retrospectives, or another `task-*.md`; promote every coder
decision into the contract or latest coder-facing review.

The worker implements the task and directly runs every Coding Self-Test. Tests
prove the small task's frozen behavior; they do not compensate for unresolved
design or excessive scope. A failed self-test remains coding responsibility
until fixed or genuinely blocked.

If coding rarely proves the contract's normative behavior or scope materially
wrong, stop and return the defect to Sol for the smallest plan/task correction;
do not reinterpret or rewrite the contract during implementation.

After self-tests pass, the dispatcher:

1. verifies worker identity and complete command evidence;
2. compares status/diff paths with exact task scope;
3. confirms every deletion was authorized;
4. stages only explicit task-owned code, test, fixture, config, package,
   documentation, and accepted plan/task checkpoint paths;
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

Keep a passed review concise: record the commit, verdict, and decisive evidence
without restating prior material. Before dispatching Sol,
recover missing mechanical evidence without creating a review to report its absence.

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

Do not start `luna_runner` automatically after coding self-tests. Sol identifies
foreseeable semantic risks; the dispatcher decides whether they warrant a
runner. Incomplete coding evidence returns to `coding_self_test`, never to
independent verification. Run it after the applicable implementation or
correction commit and before Sol review, only when:

- reported results conflict with the diff, tests, or repository state;
- a failure needs independent reproduction;
- the task explicitly marks a high-risk transaction, concurrency, security, or
  destructive boundary;
- final initiative or release acceptance requires an independent full run;
- the user explicitly asks for it.

Treat independent verification as exceptional. Documentation-only, metadata-only,
and small localized changes use self-tests plus Sol review unless a condition above
applies. Do not retest untouched behavior or duplicate worker checks. Run only what
the risk needs; add a full suite only for broader invalidation or final acceptance.
The runner returns raw evidence without editing or judging the code.

If optional verification fails, Sol decides the correction, Luna implements and
self-tests it, and the dispatcher creates a `task-M verification-K correction`
implementation commit and indexes it in `commit.md`. Repeat the same warranted
verification against that commit. Proceed to Sol review only after it passes;
another failure returns to rework with K incremented.

If it passes, record its exact evidence in status, validate the checkpoint, and
continue directly to review. Do not create a verification-only commit unless
the evidence itself must be preserved for recovery before review.

## Continue and complete

After a passed review commit, the dispatcher directly selects the next eligible
task from the accepted plan and enters `task_planning`; if it lacks a contract,
dispatch Sol to write it. If no task remains, enter `complete`. Ask Sol about
eligibility only when dependencies or repository facts require substantive
judgment. Do not create a continuity-only turn or artifact.

Stop for missing authority, real specification conflict, unsafe scope, or
repository facts that invalidate the plan. Mark the initiative complete only
when every non-superseded task has a passed review, status names no blocker,
every governing workflow artifact is tracked, structural validation passes,
required review and verification evidence is present, and the final worktree
contains no unexpected task or workflow change. Preserve unrelated user changes
without treating them as task scope.

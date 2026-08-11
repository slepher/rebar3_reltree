# task-2 — Local graph and deterministic project.md

## Goal

migrate-reltree-gates

## Objective

Replace task-1's tree_engine_unavailable dispatch with a bounded, two-phase
local relationship scan and deterministic project.md generator. The command
must describe the current project and only relationships that are provable
from local runtime declarations, explicit checkout entries, and the configured
scan catalog. It must write only the selected Rebar3 profile's report after a
complete successful generation.

Task-2 does not implement remote revision lookup, prior-report revision reuse,
network timestamps, or any task-3 rev behavior. External runtime declarations
remain declarations with revision state pending-task-3.

## Contract authority and scope

- Normative behavior is frozen by this contract, the current user contract,
  release.md sections 1, 2, 4, and 6 (especially release.md:166-256), and the
  task-2 section of the initiative plan.
- task-1 is committed at 54b1cce and supplies the shared normalized request,
  provider/escript adapters, profile-specific build context, CLI/config
  precedence, and no-write failure boundary.
- Root status.md is historical handoff context. The accepted task-2 rules in
  this contract and the initiative plan supersede its older statements about
  explicit missing nodes and checkout-only edges.
- Execution path is the normal luna_coding_worker path. The coding worker owns
  implementation and every Coding Self-Test. A separate luna_runner owns all
  Independent Verification.
- This contract is implementation-only. The worker must not edit plan.md,
  status.md, release.md, completed.md, review artifacts, Git metadata, sibling
  files, skills, or any documentation.

## Decisive approach

Keep provider and escript policy-free. They continue to parse and normalize
through rebar3_reltree_request, then call the one shared
rebar3_reltree:dispatch_tree/1 boundary. rebar3_reltree:dispatch_tree/1
becomes the task-2 orchestration entry point; graph, scan, project, status,
version, report, filesystem, and Git policy is not copied into either adapter.

The engine has two phases:

1. Build an invocation-local candidate/cache catalog and resolve the bounded
   local relationship closure without writing a cache file or report.
2. Enrich the included nodes, compute status and warnings, render the complete
   UTF-8 Markdown document, and atomically replace the profile-specific report.

The internal cache representation is implementation-private, but each
canonical project entry must retain its canonical path, discovery sources,
parsed runtime declarations, plugin/tool declarations, and relevant explicit
checkout entries. A project is read and parsed once per invocation after
canonical deduplication; later discoveries merge source and relationship facts
into that entry.

## Exact ownership

### Owned product paths

- src/rebar3_reltree.erl
- src/rebar3_reltree_cli.erl
- src/rebar3_reltree_prv_tree.erl
- src/rebar3_reltree_request.erl
- src/rebar3_reltree_config.erl
- src/rebar3_reltree_scan.erl
- src/rebar3_reltree_graph.erl
- src/rebar3_reltree_project.erl
- src/rebar3_reltree_git.erl
- src/rebar3_reltree_version.erl
- src/rebar3_reltree_status.erl
- src/rebar3_reltree_report.erl
- src/rebar3_reltree_fs.erl

Existing task-1 files may be extended only to preserve the frozen request
boundary and route valid requests through the shared engine. No task-1 CLI
option, config precedence, profile rule, error class, or provider/escript
normalization rule may be changed.

### Owned test paths

- test/rebar3_reltree_cli_tests.erl
- test/rebar3_reltree_provider_tests.erl
- test/rebar3_reltree_request_tests.erl
- test/rebar3_reltree_config_tests.erl
- test/rebar3_reltree_scan_tests.erl
- test/rebar3_reltree_graph_tests.erl
- test/rebar3_reltree_project_tests.erl
- test/rebar3_reltree_version_tests.erl
- test/rebar3_reltree_status_tests.erl
- test/rebar3_reltree_report_tests.erl
- test/rebar3_reltree_fixtures.erl
- test/rebar3_reltree_SUITE.erl

Tests may create unique fixture projects, Git repositories, symlinks, and
temporary output paths outside the repository, but must remove them. No
deletion of a repository path is authorized.

## Frozen behavior and invariants

### Request and dispatch

- task-1's normalized request remains the source of project_root,
  build_base_dir, profile, output_path, scan_roots, and rev. Provider and
  escript call the same dispatch function and the same engine modules.
- scan_roots is already an ordered list of absolute path/mode pairs. Absent
  configuration remains one shallow root ".."; an explicit empty configured
  list remains empty; a deep root is the only recursive mode.
- The current project_root is always the first required candidate, independent
  of scan_roots. It must directly contain rebar.config. A failure to read or
  complete current-project facts is fatal before replacement and preserves the
  old report.
- The engine performs no dependency fetch, network operation, remote Git
  lookup, Git mutation, tag mutation, README/config/checkout mutation, or
  shell command. Local Git uses an executable plus an argument vector and
  captures bounded local command results without a shell.
- Task-2 report generation uses local_sync_at from an injected UTC clock at the
  report boundary. Production adapters use the current UTC clock; renderer
  and writer APIs expose injection for deterministic tests. network_sync_at is
  exactly not-performed and no remote revision is attempted.

### Candidate catalog and filesystem boundaries

- A directory is a scan candidate only when it directly contains
  rebar.config. The explicit scan root itself is examined before its
  children. Shallow scans examine only that root and its immediate directory
  children. Deep scans recurse beneath the root.
- Every scan mode skips entries named .git, _build, _checkouts, and
  node_modules. The scanner never traverses a symlink. An explicit scan root
  that is a symlink, missing, not a directory, or unreadable produces one
  deterministic warning and is skipped.
- The scanner tracks filesystem identity, at minimum device/inode where the
  platform supplies it, to avoid revisiting a directory through an alias or
  hardlink-like identity. Canonical absolute paths are the cache key; repeated
  discoveries merge source facts and do not rescan the project.
- _checkouts is never recursively scanned. For a declared dependency name
  only, the matching project/_checkouts/<name> entry is an explicit
  relationship entry. A regular directory entry may be used directly; a
  symlink entry is resolved through its link chain with broken-link and
  loop detection to one canonical target. No unrelated link or child beneath
  the target is followed during scanning.
- An explicit checkout target is allowed as a relationship candidate even
  when it is outside scan_roots; discovering it does not authorize a
  whole-filesystem scan. Downstream candidates come from the scan catalog or
  such explicit relationship targets only.

### Configuration and relationship rules

- Each candidate's local rebar.config is consulted as Erlang terms. The
  selected top-level reltree options remain task-1 request policy; the graph
  reader extracts only task-2 project facts from the candidate config.
- Top-level deps, project_plugins, and plugins lists are retained as facts.
  A missing list is empty. A present malformed list or malformed dependency
  declaration makes that non-current candidate anomalous; the current
  project then fails generation. A runtime dependency is a bare atom or a
  tuple whose first element is an atom; the complete original declaration is
  retained for rendering. Unknown top-level config keys are ignored.
  Duplicate declarations are retained in source order, but one canonical
  relationship edge is emitted per dependency name.
- For every included node N and runtime dependency foo, foo is a local
  upstream only when N declares foo and N/_checkouts/foo exists and resolves
  to a valid project with canonical path foo. A declaration without the
  matching checkout is a normal external declaration: it remains on N, emits
  no warning, creates no node, and creates no edge. A checkout entry without
  the matching runtime declaration creates no edge.
- If a matching checkout entry exists for a declared dependency but is broken,
  looping, unreadable, not a directory, or lacks a valid project config, the
  node is anomalous. The node and every incident relationship are omitted;
  unrelated candidates continue. This is distinct from an absent checkout,
  which is normal external-dependency behavior.
- A scanned candidate C is a downstream of node N only when C's own runtime
  declarations contain N's dependency name and C/_checkouts/<that name>
  resolves to N's canonical path. A checkout basename alone never creates an
  edge; the declaration and matching checkout are both mandatory.
- Closure starts at current project_root and repeatedly applies the same
  declaration-plus-checkout rule to every newly valid local node until no new
  canonical node or edge is found. It is a fixed point bounded by the scan
  catalog and explicit matching checkout entries, not a fixed sibling
  topology. External declarations never enter the closure.

### Local project facts and anomaly handling

Every included node is enriched after closure with:

- canonical absolute path and basename project name;
- Git HEAD, reachable formal tags, highest numeric formal version, and local
  version-line facts;
- exactly one unambiguous direct src/*.app.src application identity and its
  app.vsn;
- runtime declarations, local upstream edges, local downstream edges,
  project_plugins, plugins, and other retained tool declarations;
- README.md/README.zh.md presence, .github/workflows/ci.yml presence, and
  read-only badge state.

For app identity, exactly one regular direct src/*.app.src file is required.
It must consult to one {application, App, Properties} term with an atom App and
non-empty string vsn property. Zero files, multiple files, malformed terms,
ambiguous application identity, or missing required facts are anomalies.

Candidate permission errors, malformed config, unreadable required files,
broken or looping relevant checkout links, invalid app identity, and
incomplete Git/app facts emit deterministic warnings and omit the affected
non-current candidate plus every incident edge. The warning identifies the
canonical path and stable reason/value summary. Unrelated candidates continue.
An anomaly in a relationship incident to the current or included local graph
marks the result insufficient-local-data. A wholly unrelated omitted candidate
does not create a graph node or edge and does not by itself change current
status. Current-project anomaly is fatal and leaves the prior report intact.

Warnings are accumulated in memory, deduplicated by canonical path/reason/
detail, and sorted before rendering. No anomaly or missing project is
serialized as a graph node.

### Local Git and version facts

- Git commands are local read-only calls with argument vectors. At minimum,
  read HEAD and reachable tags equivalent to git rev-parse HEAD and git tag
  --merged HEAD. Nonzero exit, unreadable repository state, or unavailable
  executable is an anomaly for the affected node.
- A formal tag is exactly X.Y.Z or vX.Y.Z with three numeric components.
  check-* and all prerelease tags are excluded from the highest formal-version
  calculation. Numeric equality treats an optional v prefix as equivalent;
  actual tag spellings remain sorted and rendered.
- The highest reachable formal version is the numeric maximum. If no formal
  tag exists, the node reports no-formal-tag and a valid app version is not
  rejected for that fact. A prerelease tag, when present, must have base
  version equal to app.vsn; a mismatch is a locally provable version error.
- A current app version equal to the highest formal version, or exactly the
  next patch or next breaking version, is a valid continuous line. A version
  that skips the highest line is update-required. A generation change whose
  intent cannot be selected from local facts is insufficient-local-data. A
  merely newer upstream does not change a downstream status.
- The version evaluator exposes stable reasons such as no-formal-tag,
  version-line-valid, version-line-mismatch, prerelease-base-mismatch, and
  generation-selection-needed. It never infers compatibility or generation
  intent from a diff.

### Status and badge facts

The only status values are, in precedence order:

1. insufficient-local-data;
2. update-required;
3. up-to-date.

insufficient-local-data is selected for missing required current/local-node
facts, an anomaly that omitted a relationship required by an included node, or
an unresolved generation-selection decision. update-required is selected for
a locally provable version/tag-line mismatch or applicable badge mismatch.
up-to-date is selected when required local facts are complete and no such
mismatch exists. A newer upstream alone never selects update-required.

Badge inspection is read-only and bounded:

- Without a regular .github/workflows/ci.yml, badge state is skipped-no-ci and
  does not affect status.
- With that workflow, README.md must contain exactly one master CI badge for
  that workflow and branch master. If a highest formal tag exists, it must
  also contain exactly one release CI badge for the actual highest tag. If no
  formal tag exists, no release badge is required. An existing README.zh.md
  must contain the same required CI badge set. Other badges and README prose
  are ignored.
- Missing required README files, duplicate/mismatched required badges, or an
  unavailable local origin needed to validate the fixed badge URLs produce
  badge-mismatch state and update-required. No README is ever written in
  task-2. Badge state and reasons are rendered as facts for task-4's bgate
  implementation to reuse.

### Deterministic report and atomic replacement

The report is UTF-8 Markdown with a fixed structure and always includes these
metadata fields in this order:

1. format_version;
2. status;
3. local_sync_at;
4. network_sync_at: not-performed;
5. current project path/name;
6. warnings;
7. nodes;
8. local-only caveats.

Warnings, nodes, declarations, edges, reasons, and tags are sorted by stable
canonical keys. Nodes sort by canonical path. Declarations sort by dependency
name and deterministic rendered declaration term; edges sort by source/target
canonical path and dependency name; tags sort by numeric version and actual
tag spelling. Empty sections render an explicit none marker rather than being
omitted. Paths and arbitrary retained terms are rendered as escaped,
single-line values so a config term or path cannot change Markdown structure.

Each node includes the facts listed above, external declarations with
revision_state pending-task-3, and local-only caveats. External declarations
are never rendered under nodes as graph nodes of their own. The report does
not include a remote revision, network timestamp, fetched ref, or inferred
external project.

Generation fully renders in memory first. The writer creates only the output
parent and one uniquely named invocation-owned temporary sibling in the same
directory, writes the complete bytes, closes and validates the write, then
renames the temporary sibling over output_path. A generation, write, or rename
failure preserves the prior complete project.md and removes only the current
invocation's temporary sibling. No partial report is visible as success.

## Forbidden alternatives

- No explicit missing or external graph nodes, external warning for a normal
  declaration without checkout, checkout-only edge, guessed dependency,
  fixed sibling topology, or use of Rebar3's _build dependency cache as graph
  proof.
- No one-pass enrich-as-scan traversal, persistent relationship cache,
  whole-filesystem scan, scan-link traversal, hardlink/alias revisit,
  recursive _checkouts traversal, or following unrelated symlinks.
- No remote Git lookup, dependency fetch, shell Git, network access, tag
  mutation, README/config/checkout mutation, or opaque executable-term
  deserialization.
- No report write before complete generation, no direct write to project.md
  before atomic replacement, no deletion of the prior report, and no cleanup
  of a temporary path not owned by the invocation.
- No policy duplicated in provider/escript adapters and no task-3 rev behavior,
  task-4 bgate mutation, or task-5 skill installer.
- No change to task-1 command names, options, last-value-wins config behavior,
  root error classes, active/default profile behavior, or normalized request
  semantics.

## Frozen test semantics

Tests must prove behavior, not module existence or test-helper structure.

### Success scenarios

- Provider and escript both dispatch through the task-1 normalized request and
  produce a report at the active/default profile-specific output path.
- Default scan roots are shallow [".."]; configured empty roots scan no
  additional candidates while still including the current project; configured
  {Path, deep} recursively finds descendants; root itself is considered.
- A current project with foo in deps and _checkouts/foo produces one local
  upstream. A candidate downstream must have both its own foo declaration and
  matching _checkouts/foo target. A checkout-only candidate and a declaration
  without checkout produce no edge; the latter is rendered as external
  pending-task-3.
- A three-project chain is discovered to a fixed point; discovery through
  multiple roots, aliases, or relation paths yields one canonical node and
  stable merged facts.
- Repeated generation with the same injected clock is byte-identical.
  Repeated generation with different clocks differs only in local_sync_at.
- A valid report contains the fixed metadata, all required local node facts,
  deterministic ordering, warnings/caveats, and network_sync_at
  not-performed.

### Failure and anomaly scenarios

- .git, _build, _checkouts, and node_modules are skipped; general scan
  symlinks are not followed; an explicit symlink scan root warns and is
  skipped; repeated filesystem identity is not traversed twice.
- One explicit _checkouts/foo symlink resolves successfully and creates the
  qualified edge. Broken and looping matching checkout links warn and omit
  the affected node/incident edge. Unrelated checkout entries do not create
  edges.
- Malformed/unreadable candidate config, ambiguous app identity, missing Git
  facts, and incomplete candidate facts warn and omit only the affected
  non-current candidate. Unrelated candidates still appear.
- Current-project config/app/Git failure returns a structured failure, leaves
  the previous project.md byte-identical, and leaves no temporary sibling.
- Version-line mismatch and applicable badge mismatch produce
  update-required; missing required facts or an unresolved generation choice
  produce insufficient-local-data; a newer upstream alone does neither.

### Atomic-write and boundary scenarios

- The report parent is created only under the selected
  _build/<profile>/reltree path. No report or directory is written for an
  invalid request or failed current-project generation.
- An injected final write/close/rename failure preserves an existing report
  byte-for-byte and removes only the invocation-owned temporary sibling.
- Provider active profile and escript default profile produce identical
  graph/report content apart from their intentionally different output path
  and injected clock context.
- No task-3 remote revision field is queried or serialized; every external
  declaration has revision_state pending-task-3 and network_sync_at remains
  not-performed.

## Ordered implementation steps

1. Extend the shared dispatch boundary and request plumbing only as needed to
   route the task-1 normalized request into the task-2 engine; preserve all
   task-1 public parsing and adapter semantics.
2. Implement filesystem/config readers for safe term consultation, candidate
   discovery, canonical paths, filesystem identity, skipped directories,
   explicit checkout resolution, and invocation-owned atomic writing.
3. Implement local Git and version readers using executable/argument vectors,
   formal tag filtering, highest-version selection, and version-line reasons.
4. Build the two-phase candidate cache and shallow/deep catalog, then resolve
   declaration-plus-checkout upstream/downstream edges to a fixed-point
   transitive closure with canonical deduplication.
5. Enrich included nodes with app, Git, declaration, plugin/tool, README/CI,
   badge, and relationship facts; implement deterministic anomaly warnings,
   omission, current-project fatal handling, and status precedence.
6. Implement the fixed Markdown renderer and atomic report replacement with
   injected clock and failure seams; return structured errors through the
   existing provider/escript adapters.
7. Add isolated EUnit/Common Test fixtures for every frozen relationship,
   scanning, anomaly, status, deterministic-output, and atomic-preservation
   scenario. Keep fixture repositories and generated reports outside tracked
   scope and clean them.
8. Run every Coding Self-Test, inspect exact changed paths, and return the
   complete coding-worker evidence packet without staging or committing.

## Coding Self-Tests — coding worker

Run from /home/slepher/project/rebar3_reltree after implementation and after
every rework:

1. rebar3 compile — expect exit 0.
2. rebar3 eunit — expect exit 0 and record the complete count.
3. rebar3 ct — expect exit 0 and record suite/case counts.
4. rebar3 escriptize — expect exit 0.
5. Exercise isolated provider and built-escript fixtures for default shallow
   scanning, explicit deep scanning, root-as-project, qualified upstream and
   downstream, external declarations, transitive closure, canonical aliases,
   skipped directories, scan symlink, one checkout symlink, broken/looping
   checkout, malformed candidate, and current-project failure.
6. Exercise version/status/badge facts and verify the exact three status values
   and precedence, including no-formal-tag, valid continuous version lines,
   mismatch, generation-selection-needed, no-CI skip, and badge mismatch.
7. Compare repeated report bytes with the same injected clock and with only
   local_sync_at changed. Inject generation/write/close/rename failures and
   prove the old report remains byte-identical with no owned temporary sibling.
8. Confirm provider and escript use profile-specific output paths, external
   declarations remain pending-task-3, network_sync_at is not-performed, and
   no README/config/checkout/Git mutation occurs.
9. Record git status --short and git diff --check; classify only the declared
   task paths as task-attributable and remove all generated artifacts.

The coding packet must identify the worker, every command and exit status,
EUnit/CT counts, fixture outcomes, warnings, discovered nodes/edges, generated
paths, deterministic comparison, atomic-preservation evidence,
timeout/interruption state, exact changed paths, and cleaned artifacts.

## Independent Verification — separate luna_runner

Only after the coding packet is complete, run against the exact same
worktree/diff:

1. rebar3 compile
2. rebar3 eunit
3. rebar3 ct
4. rebar3 escriptize
5. Repeat every fixture and acceptance scenario listed under Coding Self-Tests.
6. Record raw exits/counts, provider/escript output paths, discovered
   nodes/edges, warning reasons, status values, deterministic comparison,
   prior-report preservation, temporary cleanup, and mutation absence.
7. Record git status --short and git diff --check.

The runner packet must identify the runner, each command, completion or
interruption state, exact exit status and test counts, raw outputs and status/
diff results, generated artifacts, and cleanup. It must perform no source/test
semantic audit and no edits. Sol review separately audits graph semantics,
provider/escript reuse, report correctness, and exact scope.

## Expected paths, commit, and completion

- Task-attributable paths are exactly the thirteen owned product paths and
  twelve owned test paths listed above.
- Permitted task-attributable untracked paths before staging are only those
  owned product/test paths. Normal _build output is ignored. Fixture projects,
  reports, and temporary repositories must be outside the repository or
  removed before handoff. No deletion is authorized.
- No plan, status, release, completed, review, skill, sibling, or Git metadata
  path may appear in the coder diff.
- Commit subject: feat: generate local reltree reports
- Complete only when both surfaces generate the bounded deterministic local
  report, all frozen anomaly/status/atomic invariants are proven, both
  evidence layers pass, the real diff is exact, and Sol review returns passed.

## Stop conditions

Stop and report the exact evidence without widening scope if:

- a required Rebar3 or OTP API cannot preserve task-1's normalized request,
  active profile, or shared dispatch boundary;
- dependency/configuration forms needed by the accepted release behavior
  cannot be classified without inventing policy;
- a platform cannot provide safe filesystem identity, explicit checkout link
  resolution, or atomic replacement that preserves the old report;
- current-project failure cannot be distinguished from an unrelated candidate
  anomaly, or warning/edge omission cannot be made deterministic;
- implementing report status requires task-3 remote revision lookup, task-4
  README mutation, or any unowned path;
- an actual change is required outside exact ownership, another worker/user
  overlaps an owned path, or generated artifacts cannot be cleaned; or
- any command attempts network/dependency mutation, remote Git operation,
  shell execution, README/config/checkout mutation, staging, or commit.

Report the exact evidence and blocked conclusion to the dispatcher. Do not edit
status, stage, commit, delegate, spawn a child, or implement task-3/4/5 as a
workaround.

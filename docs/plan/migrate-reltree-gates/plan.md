# migrate-reltree-gates

## Goal

`migrate-reltree-gates`

Build the standalone `rebar3_reltree` OTP/Rebar3 application, `reltree`
escript, local project-tree generator, revision metadata support, README badge
gate, and packaged `reltree` Codex skill installer. Implement the accepted
behavior in this repository from first principles; migrate only narrow,
verified installer ideas from the sibling repository.

This is the durable local-workflow plan for the remaining work under
`docs/plan/migrate-reltree-gates/`.

## Authority and evidence

### Normative inputs

1. The current user contract and `release.md`, especially `release.md:166-274`,
   are authoritative for command names, scan behavior, relationship rules,
   external declarations, report replacement, and `bgate` behavior.
2. Root `status.md` remains normative where it does not conflict with the
   current user contract or `release.md`: project identity and output path at
   `status.md:5-9,28-38`, report facts at `status.md:40-41`, revision modes and
   timestamps at `status.md:52-66`, and the three status values at
   `status.md:68-78`.
3. If an older root-status statement conflicts with the accepted design, the
   current user contract and `release.md` win. This plan records each known
   reconciliation below; coding workers must not reopen it.

### Repository and sibling evidence

- The target repository currently contains documentation and workflow files
  only; no product source, tests, or Rebar3 configuration exists
  (`status.md:14-22`; initiative `status.md:18-27`).
- `completed.md:3-12,28-62` classifies the sibling work as partial,
  uncommitted, post-review unverified, and unacceptable. It proves there is no
  reltree graph/revision/timestamp implementation and no badge-gate
  implementation (`completed.md:30-38,64-78`).
- The sibling package and installer are evidence only. Potentially useful
  ideas are packaged-source lookup through `code:priv_dir/1`, destination
  precedence, staged replacement, rollback, and no-follow recursive file
  handling. They must be reimplemented under `rebar3_reltree` names and this
  plan's invariants, not copied wholesale.
- The sibling review found concrete defects that this plan forbids:
  unowned staging collisions could be deleted; overlap checks could miss
  symlink aliases; not every required package leaf was validated as regular;
  target conflict was checked before a complete stage; semantic tests and the
  post-review coding self-test packet were incomplete
  (`completed.md:40-51`; sibling
  `task-1-code-review-1.md:17-80`).
- The sibling's old `release-version-gates` package, `docker_ci` providers,
  plans, and partial worktree are out of scope. They are not a source of
  product files, command names, module names, package shape, or acceptance
  evidence.

### Facts, implementation choices, and unresolved cases

Facts fixed by the normative inputs are labeled **Frozen behavior** in each
task. The following are bounded implementation choices needed to make the
contracts executable:

- Minimum runtime is OTP 25 with Rebar3 3.x. The application has no
  supervision tree and no runtime dependency beyond `kernel` and `stdlib`.
- Rebar3 surfaces are namespaced providers: `rebar3 reltree tree`,
  `rebar3 reltree bgate --check|--write`, and, because the user explicitly
  requires a packaged-skill installer, `rebar3 reltree skill --install`
  with optional `--dest DIR` and `--force`. The escript mirrors these as
  `reltree tree`, `reltree bgate --check|--write`, and
  `reltree skill --install`.
- There is no `check_badges`, `install_skill`, `install_release_skill`,
  `--project`, `--profile`, or `--root` compatibility alias. Tree options are
  exactly repeatable `--scan-roots PATH[:deep]` and
  `--rev false|auto|true`. The inspected project is the invocation working
  directory. The provider takes its profile from Rebar3 state; the standalone
  escript uses `default` because it has no active Rebar3 profile.
- `rebar3 reltree skill --install` is an implementation-level command choice,
  not a compatibility promise inherited from the sibling. If the actual
  supported Rebar3 cannot register `tree`, `bgate`, and `skill` under the
  `reltree` namespace, stop rather than silently changing the accepted tree or
  badge commands.
- External Git revision metadata is attached to the owning local node's
  dependency declaration. It never creates an external graph node. A normal
  non-Git/package declaration has revision state `not-applicable`; it is not
  a scan anomaly and does not lower tree status.
- UTC timestamps use RFC 3339 second precision (`YYYY-MM-DDTHH:MM:SSZ`) from
  an injected clock. Collections and non-clock report bytes are deterministic.

One release-policy edge remains a runtime stop condition, not a planning
blocker: if both `X.Y.Z` and `vX.Y.Z` are equally highest reachable formal
tags, `bgate --write` cannot choose the required real `TAG` from
`release.md:124-129` without an explicit preference. The command must stop
before README writes and report both tags. Do not invent a preference.

## Explicit reconciliation of older statements

- Root `status.md:45-50` described unresolved local dependencies as explicit
  missing projects. The accepted rule at `release.md:210-238` supersedes it:
  a runtime declaration becomes a local upstream only through the matching
  `_checkouts/<name>` entry. Without that entry it is a normal external
  declaration, with no graph node, warning, or missing node.
- The sibling reltree plan described checkout-only reverse edges. The accepted
  rule at `release.md:220-226` requires both the downstream candidate's runtime
  declaration and its `_checkouts/<dependency-name>` link to the current node.
  Either fact alone creates no edge.
- Older plan options `--project`, `--profile`, `--root`, configured
  `project_roots`, and additive root merging are removed. The only root config
  is `{scan_roots, Roots}`; CLI `--scan-roots` replaces, not extends, config
  (`release.md:184-206`).
- Older plan commands `rebar3 reltree`, `rebar3 reltree check_badges`, and
  `rebar3 reltree install_skill` are removed. Generation is
  `rebar3 reltree tree`; badge behavior is `bgate --check|--write`.
- Root `status.md:76-78` forbade README mutation. The current accepted design
  narrows that rule: `tree` and `bgate --check` never write README files, while
  the explicitly selected `bgate --write` mode performs the ordered README
  update defined at `release.md:258-274`.
- The old plan's explicit missing graph nodes, external graph nodes,
  `pending-gate` implementation slice, and `rev_engine_unavailable` report
  behavior are removed. Invalid/anomalous projects and edges are warned and
  omitted; external declarations remain declaration records.

## Initiative-wide invariants

- Product implementation writes stay in this repository. Runtime `tree`
  writes only `<project>/_build/<active-profile>/reltree/project.md` and an
  invocation-owned temporary sibling; successful generation atomically
  replaces the final file, and failure preserves the prior complete file.
- Runtime `bgate --write` may write only `<project>/README.md` and an existing
  `<project>/README.zh.md`, in that order. It does not promise cross-file
  atomicity and must identify the exact failed path and reason.
- Runtime skill installation may write only the resolved skills parent,
  target `reltree`, and invocation-owned staging/backup siblings. Tests and
  independent verification use unique temporary destinations and never a real
  user skill directory.
- No mode fetches dependencies, fetches Git refs, pushes, mutates tags,
  publishes, reads GitHub Actions environment variables, modifies config or
  `_checkouts`, or infers remote state. Only `rev=auto|true` may perform a
  read-only revision metadata query.
- Provider and escript adapters normalize into the same request structures
  and call shared graph, report, revision, badge, and installer logic.
- Paths are handled as argument vectors and filesystem APIs, never shell
  command strings. Errors include the relevant path/declaration and reason
  without dumping credentials or environment maps.
- Current-project failure is fatal and preserves the old report. Non-current
  scan anomalies produce one deterministic warning, omit the affected project
  and every incident edge, and allow unrelated candidates to continue.
- No task owns root `release.md`, root `status.md`, root `completed.md`,
  initiative `status.md`, workflow review artifacts, `.codex/`, sibling paths,
  Git metadata, staging, or commits. Coder contracts are implementation-only.
- Each coding worker must return its own complete Coding Self-Test packet.
  Independent Verification is separately executed and authored by a fresh
  `luna_runner`; neither evidence layer substitutes for the other. Sol runs no
  test/build/lint/acceptance command during planning or review.

## Execution baseline

The prior Git metadata blocker is resolved. The dispatcher initialized a valid,
writable repository on branch `master`; it has no HEAD commit yet, and the
attested baseline contains only the pre-existing documentation and initiative
files (`docs/plan/migrate-reltree-gates/status.md:18-27,42-44`). Git repair is
not a product task and no implementation worker owns Git metadata.

The dispatcher must preserve that attested documentation-only baseline when
checking task scope. task-1 is eligible for coding; its attributable product
diff remains limited to its declared product/test paths even while the known
baseline documents are not yet represented by a HEAD commit.

## Ordered task contracts

Tasks execute strictly in order. Each uses the normal coding-worker path; none
is eligible for staged Sol source implementation. Every task is independently
verified, reviewed as passed, and committed before the next begins.

### task-1 — Minimal OTP/Rebar3/escript skeleton

**Prerequisite**

Satisfied: the dispatcher initialized writable Git metadata and recorded the
documentation-only, no-HEAD baseline.

**Objective**

Create the smallest buildable application/plugin/escript and one shared
request boundary for `tree`. Parse the accepted config and command options,
but return a specific no-write `tree_engine_unavailable` error until task-2.

**Owned product paths**

- `.gitignore`
- `rebar.config`
- `src/rebar3_reltree.app.src`
- `src/rebar3_reltree.erl`
- `src/rebar3_reltree_cli.erl`
- `src/rebar3_reltree_prv_tree.erl`
- `src/rebar3_reltree_request.erl`

**Owned test paths**

- `test/rebar3_reltree_cli_tests.erl`
- `test/rebar3_reltree_provider_tests.erl`
- `test/rebar3_reltree_request_tests.erl`

**Frozen behavior and invariants**

- Application identity is `rebar3_reltree`; escript name is `reltree`.
  `rebar3_reltree:init/1` registers only provider `{reltree, tree}` in this
  slice. No supervision tree or third-party runtime library is added.
- Provider and escript accept `tree`, repeatable
  `--scan-roots PATH[:deep]`, and `--rev false|auto|true`. The provider reads
  the already evaluated `reltree` value from Rebar3 state, takes the active
  profile from that state, and uses cwd as project root. The escript reads the
  inspected project's `rebar.config` from cwd and uses profile `default`.
  Duplicate top-level `{reltree, Options}` terms are not an error: both
  surfaces use Rebar3 last-value-wins semantics. The provider consumes the
  value already selected by Rebar3 without recovering raw config terms; the
  escript selects the last top-level `reltree` value itself and ignores every
  earlier one.
- CLI scan roots replace configured roots when at least one is present.
  Otherwise configured `{scan_roots, Roots}` applies; otherwise the default is
  `['..']` represented internally as shallow. Plain paths are shallow;
  `PATH:deep` and config tuple `{Path, deep}` are deep. Invalid/empty modes,
  paths, duplicate contradictory root modes, extra positional arguments, and
  unknown options fail before any product write. A malformed or empty path
  originating in configured `scan_roots` is `invalid_config`; the equivalent
  CLI-originated invalid path is `invalid_option`.
- Config and argument parsing are pure/testable; `main/1` and provider `do/1`
  only adapt output and exit/provider results. Both surfaces produce the same
  normalized request for equivalent inputs.
- Help and invalid input never create `project.md`. Valid execution before
  task-2 returns `tree_engine_unavailable` and also writes nothing.

**Forbidden alternatives**

- No default-namespace `rebar3 reltree`, `--project`, `--profile`, `--root`,
  `project_roots`, badge/skill placeholder provider, copied `docker_ci`
  namespace, report stub, CLI dependency, JSON dependency, or command run from
  module load/provider initialization.

**Ordered implementation steps**

1. Add minimal Rebar3 application and escript configuration and app metadata.
2. Implement pure config/CLI parsing and normalized request construction.
3. Register the namespaced `tree` provider and thin escript adapter.
4. Cover metadata, defaults, override precedence, shallow/deep syntax,
   invalid inputs, adapter parity, help, and no-write unavailable behavior.
   Regression coverage must prove duplicate top-level `reltree` terms select
   the last value on both surfaces without raw provider config access, and
   that malformed/empty configured roots remain `invalid_config` while CLI
   invalid roots remain `invalid_option`.

**Coding Self-Tests — coding worker**

- `rebar3 compile`
- `rebar3 eunit`
- `rebar3 escriptize`
- Invoke provider and built escript help, default tree request, repeated scan
  roots, and invalid rev/root cases in temporary fixture projects; record raw
  exits/output and prove no `project.md` is created.
- EUnit assertions must include provider/escript last-value-wins regression
  cases and distinct configured-root/CLI-root error-class regression cases.

**Independent Verification — separate `luna_runner`**

- Repeat every Coding Self-Test against the exact diff.
- Record command completion, exits/test counts, provider metadata/help,
  generated-path absence, `git status --short`, and `git diff --check`.
  Sol review accepts semantic parity only after inspecting that the exercised
  assertions implement last-value-wins without provider raw-config recovery
  and preserve the two root-error classes.

**Expected paths, commit, and completion**

- Tracked/untracked task diff: exactly the owned product and test paths above;
  generated `_build/` remains ignored. No deletion is authorized.
- Commit subject: `feat: scaffold reltree commands`
- Complete when both command surfaces build, parse the exact frozen request,
  apply the frozen last-value-wins and origin-specific error rules, fail safely
  before the engine exists, both evidence layers pass, and Sol reviews the
  exact scope as passed.

**Stop conditions**

Stop if this Rebar3 cannot register the namespaced command, active profile is
not available through Rebar3 state, one application cannot serve as plugin and
escript without another dependency, or any unowned path is required.

### task-2 — Local graph and deterministic `project.md`

**Prerequisite**

task-1 is committed.

**Objective**

Implement the two-phase, in-memory local relationship scan and transitive
closure, enrich valid local nodes, compute the three-state local result, and
atomically render deterministic Markdown at the active profile path.

**Owned product paths**

- `src/rebar3_reltree.erl`
- `src/rebar3_reltree_cli.erl`
- `src/rebar3_reltree_prv_tree.erl`
- `src/rebar3_reltree_request.erl`
- `src/rebar3_reltree_config.erl`
- `src/rebar3_reltree_scan.erl`
- `src/rebar3_reltree_graph.erl`
- `src/rebar3_reltree_project.erl`
- `src/rebar3_reltree_git.erl`
- `src/rebar3_reltree_version.erl`
- `src/rebar3_reltree_status.erl`
- `src/rebar3_reltree_report.erl`
- `src/rebar3_reltree_fs.erl`

**Owned test paths**

- `test/rebar3_reltree_cli_tests.erl`
- `test/rebar3_reltree_provider_tests.erl`
- `test/rebar3_reltree_request_tests.erl`
- `test/rebar3_reltree_config_tests.erl`
- `test/rebar3_reltree_scan_tests.erl`
- `test/rebar3_reltree_graph_tests.erl`
- `test/rebar3_reltree_project_tests.erl`
- `test/rebar3_reltree_version_tests.erl`
- `test/rebar3_reltree_status_tests.erl`
- `test/rebar3_reltree_report_tests.erl`
- `test/rebar3_reltree_fixtures.erl`
- `test/rebar3_reltree_SUITE.erl`

**Frozen behavior and invariants**

- Phase one builds an invocation-local cache keyed by canonical project path.
  It records discovery source, runtime dependency declarations, plugin/tool
  declarations, and explicit checkout relationships. It scans each canonical
  project once, merges duplicate discovery paths, and writes no cache file.
- A shallow root examines the root itself and its immediate children only. A
  deep root recursively descends. A directory is a project candidate only
  when it directly contains `rebar.config`. Every mode skips entries named
  `.git`, `_build`, `_checkouts`, and `node_modules`.
- General scanning never follows a symlink. It tracks filesystem identity to
  prevent alias/revisit traversal and does not traverse a hardlink-like repeat
  identity. An explicit scan root that is a symlink is warned and skipped.
  The sole link-following exception is one explicit
  `<project>/_checkouts/<dependency-name>` entry; resolve that entry to its
  canonical target with loop/broken-link detection, but do not recursively
  follow unrelated links below it.
- For every local node, runtime dependency `foo` becomes a local upstream only
  if that node's own `rebar.config` declares `foo` and its own
  `_checkouts/foo` resolves to a valid project. A checkout without the matching
  declaration creates no edge. A declaration without the checkout remains an
  external declaration and creates no node, edge, warning, or missing node.
- A scanned candidate is a downstream of node `N` only when its config
  declares `N` as a runtime dependency and its matching checkout resolves to
  `N`'s canonical path. Name matching is against the dependency declaration,
  not an arbitrary checkout basename.
- Relationship expansion continues from every newly valid local node using
  the same upstream and downstream rules until a fixed point, bounded by the
  configured scan catalog and explicit checkout entries. This is the
  transitive closure; it is not a fixed sibling topology.
- After relationship closure, phase two enriches included nodes with project
  path/name, Git HEAD, reachable formal tags/highest numeric version,
  `app.src` path/app/vsn, runtime declarations, local upstream/downstream
  edges, plugin/project-plugin/tool declarations, README presence, CI workflow
  presence, and read-only badge state. Local Git uses executable plus argument
  vectors.
- Candidate permission errors, malformed config, unreadable files, broken or
  looping checkout links, ambiguous app identity, and incomplete node facts
  emit deterministic warnings and omit the affected non-current project plus
  every incident edge. They are not serialized as anomaly or missing nodes.
  Unrelated candidates continue. If the current project cannot be completed,
  generation fails and preserves the old report.
- Status is exactly `insufficient-local-data`, `update-required`, or
  `up-to-date`, in that precedence. Required current/local-node Git/app facts
  or an omitted relationship caused by anomaly are insufficient. A locally
  provable app/tag/version-line or applicable badge mismatch is update
  required. A merely newer upstream never requests a downstream update.
- Version/tag rules follow `release.md:24-62`: numeric `X.Y.Z` and `vX.Y.Z`
  are equivalent; reachable highest formal version controls continuous equal,
  patch-next, breaking-next, or explicitly selected generation-next lines;
  prerelease base must equal app version; `check-*` is ignored. The tool never
  guesses compatibility or generation intent from a diff; where that owner
  decision is needed, the report records insufficient data.
- Output is UTF-8 Markdown with stable section, node, declaration, edge,
  warning-reason, and tag ordering. It includes every field required by
  `release.md:240-250`, a format version, and local-only caveats. Task-2 writes
  `local_sync_at` from the injected clock and `network_sync_at: not-performed`.
  External declarations are rendered with revision state `pending-task-3`,
  but never as nodes.
- Render to a uniquely owned temporary sibling and rename only after the full
  document is complete. A generation/write/rename failure preserves the prior
  `project.md` and cleans only this invocation's owned temporary path.

**Forbidden alternatives**

- No explicit missing/external graph nodes, checkout-only edges, Rebar3
  `_build` dependency cache as relationship proof, one-pass enrich-as-you-scan
  traversal, persistent relationship cache, whole-filesystem scan, scan-link
  traversal, dependency fetch, remote lookup, README/config/checkout mutation,
  shell Git, or opaque executable term deserialization.

**Ordered implementation steps**

1. Implement safe config, app, filesystem, and local-Git readers.
2. Build the shallow/deep candidate catalog and canonical in-memory cache.
3. Resolve declaration-plus-checkout edges and fixed-point transitive closure.
4. Enrich valid nodes and omit/warn anomalies under the frozen precedence.
5. Implement version/status analysis and deterministic Markdown rendering.
6. Atomically replace the profile-specific report and wire both command paths.
7. Add isolated multi-project fixtures for all relationship and scan modes.

**Coding Self-Tests — coding worker**

- `rebar3 compile`
- `rebar3 eunit`
- `rebar3 ct`
- `rebar3 escriptize`
- Exercise provider and escript fixtures for default shallow scanning, explicit
  deep scanning, root-as-project, declared checkout upstream, qualified
  downstream, checkout-only/non-checkout declarations, transitive closure,
  duplicate aliases, skipped directories, scan symlink, one checkout symlink,
  broken link, malformed candidate, and current-project failure.
- Compare repeated output after normalizing only injected timestamps; inject a
  final-write failure and prove the prior report remains byte-identical and no
  invocation-owned temporary sibling remains.

**Independent Verification — separate `luna_runner`**

- Repeat every Coding Self-Test and acceptance fixture against the exact diff.
- Record raw exits/test counts, warnings, discovered nodes/edges, generated
  paths, deterministic comparison, preservation/cleanup evidence,
  `git status --short`, and `git diff --check`.

**Expected paths, commit, and completion**

- Tracked/untracked task diff: exactly the owned paths above. Fixture reports
  and repositories remain temporary/ignored. No deletion is authorized.
- Commit subject: `feat: generate local reltree reports`
- Complete when both surfaces generate the same bounded transitive local graph
  and deterministic profile report, anomaly omission/warnings and atomic
  preservation are proven, both evidence layers pass, and review passes.

**Stop conditions**

Stop if a required dependency form cannot be classified without policy, a
requested relationship requires scanning outside frozen roots/checkout
entries, a platform cannot provide the identity needed to prevent link/alias
traversal, multiple current app identities need a selection rule, or safe
replacement cannot preserve the prior report.

### task-3 — External `rev` modes and timestamps

**Prerequisite**

task-2 is committed.

**Objective**

Replace `pending-task-3` declaration metadata with complete
`false|auto|true` revision behavior, safe prior-report reuse, read-only lookup,
and exact local/network timestamp semantics without creating external nodes.

**Owned product paths**

- `src/rebar3_reltree_cli.erl`
- `src/rebar3_reltree_request.erl`
- `src/rebar3_reltree_project.erl`
- `src/rebar3_reltree_git.erl`
- `src/rebar3_reltree_status.erl`
- `src/rebar3_reltree_report.erl`
- `src/rebar3_reltree_rev.erl`
- `src/rebar3_reltree_clock.erl`

**Owned test paths**

- `test/rebar3_reltree_cli_tests.erl`
- `test/rebar3_reltree_request_tests.erl`
- `test/rebar3_reltree_project_tests.erl`
- `test/rebar3_reltree_status_tests.erl`
- `test/rebar3_reltree_report_tests.erl`
- `test/rebar3_reltree_rev_tests.erl`
- `test/rebar3_reltree_SUITE.erl`

**Frozen behavior and invariants**

- Config `{rev, false|auto|true}` applies unless CLI `--rev` overrides it;
  default is `auto`. A declaration resolved as a local checkout always bypasses
  external lookup and prior external metadata.
- `false` performs zero lookups, does not reuse prior revisions, records each
  external declaration and either `tracking-disabled` or `not-applicable`, and
  writes report-level `network_sync_at: not-performed`.
- `auto` safely parses the previous tool-versioned report and reuses revision
  plus per-declaration network sync time only for an exact identity match:
  owning local canonical path, normalized dependency name, source URL, and
  declared selector. It looks up only new, changed, previously missing, or
  invalid prior entries.
- `true` attempts every applicable external Git declaration on every run and
  never treats cached data as current.
- Applicable lookup is `git ls-remote` through a fixed executable and argument
  list. It resolves the declared commit/ref/tag/branch to one exact commit;
  zero or incompatible multiple matches are explicit failures. No fetch,
  checkout, credential output, repository mutation, or shell is allowed.
- A package/non-Git declaration is retained verbatim with `not-applicable` and
  no warning. A failed applicable lookup records missing or stale revision
  state and its attempt time; under `auto`, prior valid evidence may be kept
  only as explicitly stale. Such failure drives
  `insufficient-local-data`, but generation still completes atomically.
- `local_sync_at` is the current injected time for each successful report
  replacement. Per-declaration network time is the reused or current attempt
  time. Report-level `network_sync_at` is the greatest represented actual
  lookup time, or `not-performed` if no actual lookup has ever contributed to
  this report.
- Prior-report parsing accepts only this tool's versioned external-declaration
  table, bounded fields, and validated values. It creates no atoms from input
  and uses no executable/general term deserialization. Malformed/mismatched
  entries are diagnosed and not reused.

**Forbidden alternatives**

- No external graph node, dependency fetch, HTTP test fixture, real network in
  tests, cache outside `project.md`, shell command, credential logging,
  silent `true` fallback to cache, reuse after identity changes, or overwrite
  of local checkout facts.

**Ordered implementation steps**

1. Add injected clock and lookup boundaries and normalize source selectors.
2. Add strict prior-report parsing and exact declaration identity matching.
3. Implement the complete mode/reuse/failure matrix.
4. Extend report/status fields without changing local graph semantics.
5. Add pure adapter tests and local bare-repository lookup fixtures.

**Coding Self-Tests — coding worker**

- `rebar3 compile`
- `rebar3 eunit`
- `rebar3 ct`
- `rebar3 escriptize`
- Run isolated `false`, two-pass `auto`, changed-identity `auto`, repeated
  `true`, local-checkout precedence, non-Git declaration, malformed prior
  report, and lookup-failure/stale fixtures using only local path/bare Git
  repositories. Prove lookup counts and deterministic non-clock bytes.

**Independent Verification — separate `luna_runner`**

- Repeat every Coding Self-Test and mode fixture.
- Record raw exits/test counts, lookup arguments/counts, revision states,
  local/network timestamps, cache invalidation/reuse, proof no network remote
  is configured, `git status --short`, and `git diff --check`.

**Expected paths, commit, and completion**

- Tracked/untracked task diff: exactly the owned paths above. Temporary bare
  repositories/reports are not tracked. No deletion is authorized.
- Commit subject: `feat: track external revisions in reltree`
- Complete when all modes, identity reuse, local precedence, failure/stale
  representation, and timestamps pass both evidence layers and review.

**Stop conditions**

Stop if a declaration requires credentials or a non-Git protocol policy, an
exact revision cannot be resolved through read-only metadata, prior format is
ambiguous, or a proposed fallback would convert an external fact into a local
relationship.

### task-4 — `bgate` check/write behavior

**Prerequisite**

task-3 is committed.

**Objective**

Implement one shared README badge analyzer/rewriter used by
`rebar3 reltree bgate --check|--write`, the mirrored escript command, and
read-only badge state in `tree` reports.

**Owned product paths**

- `src/rebar3_reltree.erl`
- `src/rebar3_reltree_cli.erl`
- `src/rebar3_reltree_prv_bgate.erl`
- `src/rebar3_reltree_project.erl`
- `src/rebar3_reltree_status.erl`
- `src/rebar3_reltree_report.erl`
- `src/rebar3_reltree_badge.erl`

**Owned test paths**

- `test/rebar3_reltree_cli_tests.erl`
- `test/rebar3_reltree_provider_tests.erl`
- `test/rebar3_reltree_project_tests.erl`
- `test/rebar3_reltree_status_tests.erl`
- `test/rebar3_reltree_report_tests.erl`
- `test/rebar3_reltree_badge_tests.erl`
- `test/rebar3_reltree_SUITE.erl`

**Frozen behavior and invariants**

- Register provider `{reltree, bgate}` with exactly one required mutually
  exclusive mode: `--check` or `--write`. The escript accepts the same modes.
  There is no `--ref`, `check_badges`, `check-badges`, or version-gate alias.
- This gate manages only the exact `master CI` and `<VERSION> release CI`
  GitHub Actions badge forms at `release.md:109-130`. `OWNER/REPO` is derived
  from one unambiguous local GitHub `origin`; no network or environment lookup
  occurs. Other badges and README prose are preserved.
- Without `.github/workflows/ci.yml`, either mode emits one warning and exits
  successfully without adding or changing a badge. With a workflow and no
  reachable formal tag, the desired block contains exactly the master badge.
  With formal tags, it also contains exactly one release badge for the
  numerically highest reachable formal version, displays VERSION without an
  optional `v`, and uses the real tag in both URLs. It never adds rc/ci badges.
- `--check` is read-only and fails on missing, duplicate, stale, malformed, or
  English/Chinese-mismatched managed badges. Existing `README.zh.md` must match
  `README.md`; absence of `README.zh.md` is allowed.
- `--write` computes both desired files before writing, removes all managed
  badge lines, and places one canonical managed block at the first former
  managed-block location; if none existed, it places the block at the start
  of the file followed by one blank line before existing content. It writes
  `README.md` first and existing `README.zh.md` second. It does not promise
  cross-file atomicity; failure names the exact file/reason and leaves any
  earlier successful file write visible.
- If both `X.Y.Z` and `vX.Y.Z` are equally highest real tags, `--write` stops
  before either README write and reports the ambiguity. `--check` accepts only
  when both README files consistently use one of those real highest tags; it
  reports the equivalent-tag ambiguity as a warning, not a fabricated
  preference.
- `bgate` never generates/modifies `project.md`, workflow, Git refs, config, or
  source. `tree` calls the same analyzer read-only per local node, marks no-CI
  as skipped, incorporates failures into its frozen status precedence, and
  never invokes the write path.

**Forbidden alternatives**

- No default README mutation, hidden fix during `tree`, cross-file transaction
  requirement, workflow creation, network, GitHub Actions variables, tag
  mutation, release action, separate provider policy, broad regex that owns
  unrelated badges, or old `docker_ci` command.

**Ordered implementation steps**

1. Implement pure desired-badge calculation from local origin/workflow/tags.
2. Implement exact managed-line parsing, validation, and canonical rewriting.
3. Register provider/escript adapters with strict mutually exclusive modes.
4. Integrate the read-only analyzer into local node/report status.
5. Cover write ordering, partial failure reporting, preservation, and all
   check/write skip/success/failure boundaries.

**Coding Self-Tests — coding worker**

- `rebar3 compile`
- `rebar3 eunit`
- `rebar3 ct`
- `rebar3 escriptize`
- In isolated Git fixtures, run both command surfaces for no workflow, no tag,
  bare/v-tag, valid/missing/stale/duplicate/malformed badges, unrelated badges,
  absent/present/mismatched Chinese README, equivalent highest tags, and an
  injected second-file write failure. Snapshot README bytes, refs, workflow,
  and `project.md` before/after as applicable.

**Independent Verification — separate `luna_runner`**

- Repeat every Coding Self-Test and badge fixture against the exact diff.
- Record raw exits/test counts/help, warning/error output, resulting README
  bytes, ordered partial-failure evidence, unchanged refs/workflow/report,
  `git status --short`, and `git diff --check`.

**Expected paths, commit, and completion**

- Tracked/untracked task diff: exactly the owned paths above. Fixture
  repositories and generated README/report data remain temporary. No deletion
  is authorized.
- Commit subject: `feat: add reltree badge gate`
- Complete when check/write and report analysis share one policy, all frozen
  README outcomes and mutation boundaries pass both evidence layers, and
  review passes.

**Stop conditions**

Stop if local origin cannot determine one GitHub repository, managed badge
lines cannot be distinguished without consuming unrelated content, actual
encoding/newline handling would require broad README normalization, or a new
tag-selection/write policy is required beyond the equivalent-tag rule above.

### task-5 — Package and install the `reltree` skill

**Prerequisite**

task-4 is committed, so packaged guidance references only implemented command
surfaces. The dispatcher must explicitly preserve the product-asset scope
below when routing; these are shipped application assets, not the repository
workflow skill under `.codex/`.

**Objective**

Create the minimal generic packaged `reltree` Codex skill and implement a safe
local installer exposed only as `rebar3 reltree skill --install` and the
mirrored escript command.

**Owned product paths**

- `src/rebar3_reltree.erl`
- `src/rebar3_reltree_cli.erl`
- `src/rebar3_reltree_prv_skill.erl`
- `src/rebar3_reltree_skill_install.erl`
- `src/rebar3_reltree_fs.erl`
- `priv/skills/reltree/SKILL.md`
- `priv/skills/reltree/agents/openai.yaml`

**Owned test paths**

- `test/rebar3_reltree_cli_tests.erl`
- `test/rebar3_reltree_provider_tests.erl`
- `test/rebar3_reltree_skill_install_tests.erl`
- `test/rebar3_reltree_fs_tests.erl`
- `test/rebar3_reltree_SUITE.erl`

**Frozen behavior and invariants**

- Packaged frontmatter name is exactly `reltree`; agent metadata/default
  prompt names `$reltree`. Guidance is repository-independent: run
  `rebar3 reltree tree`, use the generated active-profile `project.md` as a
  local factual reference, treat external declarations as non-node metadata,
  use `bgate --check`, use `bgate --write` only with explicit README-write
  authority, and never infer missing relationships or remote authorization.
  It contains no sibling project list/topology/version, `docker_ci` command,
  stale aliases, bundled generated report, or extra README/reference copy.
- Provider source discovery uses only
  `code:priv_dir(rebar3_reltree)/skills/reltree`; it never installs from cwd.
  Validate the complete source recursively before destination mutation:
  package root and `agents/` are real directories; `SKILL.md` and
  `agents/openai.yaml` are regular files; every traversed entry is regular or
  directory; symlinks and special objects are rejected. Validate the staged
  copy again before activation.
- Destination precedence is explicit `--dest` skills parent, then non-empty
  `CODEX_HOME/skills`, then non-empty `HOME/.codex/skills`; append `reltree`
  exactly once and report the absolute target. Empty/non-string destination or
  absence of all destinations is actionable failure.
- Reject canonical source/parent/target overlap, including symlinked existing
  ancestors, before creating a parent or stage. Preserve the ability to
  replace a final target symlink as a link under force; never follow it.
- Create a uniquely and atomically reserved staging sibling. A pre-existing or
  raced candidate is unowned: retry without deleting or changing it. Complete
  and validate staging before checking target conflict, so source/copy failure
  takes precedence while the target remains unchanged.
- Existing target without `--force` fails after successful staging validation
  and then removes only owned staging. With `--force`, move target to a uniquely
  reserved backup, atomically activate staging, and remove backup. On
  activation failure restore the old target; if rollback fails, retain and
  report the intact backup path. Clean only paths proven owned by this
  invocation; preserve unrelated siblings, regular-file targets under
  no-force, and all collision sentinels.
- Copy/delete uses Erlang/OTP filesystem APIs, does not follow source or target
  links, preserves regular bytes/directory structure, and invokes no Git,
  network, graph, gate, or shell operation. Tests inject environment, unique
  names/rename failures, and unique temporary `--dest`; they never resolve or
  mutate the real user destination.

**Known sibling defects specifically prevented**

- Collision candidates are explicitly unowned until atomically reserved and
  are never cleaned (`completed.md:44`; sibling review finding 1).
- Overlap uses canonical filesystem identity through existing ancestors,
  preventing symlink-alias writes into packaged source (`completed.md:45`;
  sibling review finding 2).
- Every required package leaf and every recursive entry is type-checked, not
  just `SKILL.md` (`completed.md:46`; sibling review finding 3).
- Full staging and validation occur before target conflict handling
  (`completed.md:47`; sibling review finding 4).
- Semantic regressions cover collision ownership, canonical overlap, every
  required leaf, target object types, unrelated siblings, ordered transaction
  failures, exact formatted errors, and separate coding/runner packets
  (`completed.md:48-49`; sibling review finding 5).

**Forbidden alternatives**

- No wholesale copy, `release-version-gates` name, package README/reference
  copy, hard-coded sibling topology, exact-three-entry sibling validator,
  shell `cp`/`rm`, source/target symlink following, predictable-unreserved
  temp path, in-place force overwrite, install-on-build, real-user-directory
  test, `install_skill`, or `install_release_skill` command.

**Ordered implementation steps**

1. Create the minimal packaged skill and metadata with frozen generic content.
2. Implement no-follow recursive validation/copy/delete and owned temp-path
   reservation using OTP 25 capabilities.
3. Implement destination resolution, canonical overlap rejection, stage-first
   transaction, activation, rollback, cleanup, and precise errors.
4. Register the `skill --install` provider/escript adapters and packaged-priv
   lookup.
5. Cover clean install, collision, force, target types, symlinks, overlap,
   every transaction failure, cleanup ownership, and exact installed bytes.

**Coding Self-Tests — coding worker**

- `rebar3 compile`
- `rebar3 eunit`
- `rebar3 ct`
- `rebar3 escriptize`
- Install through both surfaces into unique temporary skills parents; compare
  installed bytes with packaged source; exercise no-force and force for
  directory, regular-file, and symlink targets; inject staging collision,
  copy, backup rename, activation, rollback, and cleanup failures; prove
  sentinels/unrelated siblings survive and owned temporary paths are cleaned or
  explicitly retained/reported as required.

**Independent Verification — separate `luna_runner`**

- Repeat every Coding Self-Test and temporary installation scenario.
- Record raw exits/test counts, exact resolved/installed paths, byte-for-byte
  package comparison, collision/rollback artifacts, proof real `CODEX_HOME`
  and `HOME` targets were untouched, `git status --short`, and
  `git diff --check`.

**Expected paths, commit, and completion**

- Tracked/untracked task diff: exactly the owned product and test paths above.
  Temporary installation roots are outside tracked scope. No deletion is
  authorized.
- Commit subject: `feat: package and install the reltree skill`
- Complete when the shipped generic package and both install surfaces satisfy
  all transaction/link/ownership invariants, both evidence packets are
  complete and passing, and Sol review has no material finding.

**Stop conditions**

Stop if packaged `priv` cannot be located reliably, package validation would
require following a link, a unique stage/backup cannot be reserved safely,
force failure cannot preserve either the original target or an explicitly
reported intact backup, any test would touch a real user directory, or skill
guidance needs a project-specific release decision.

## Initiative completion criteria

- Tasks 1-5 are implemented in order, each has a distinct coding-worker
  self-test packet and independent-runner packet, each Sol review passes, and
  each accepted scope is committed with its frozen subject.
- `rebar3 reltree tree` and `reltree tree` share one deterministic two-phase
  local graph/report engine and write only the selected active/default profile
  `project.md`.
- The graph contains only valid local projects proven through declaration plus
  checkout rules, reaches the bounded transitive closure, stores external
  dependencies only as declarations, and omits/warns anomalies.
- Revision modes, prior-report reuse, timestamps, version/status behavior,
  badge check/write semantics, and packaged-skill install transactions have
  isolated success, failure, and boundary evidence.
- No sibling file, config, checkout, workflow, Git ref, remote service, or real
  user skills directory is mutated. README mutation occurs only in explicit
  `bgate --write` fixtures/runtime use.
- Final status/diff contains no unexpected tracked/untracked path and no
  abandoned invocation-owned temporary artifact.

## Initiative-wide stop conditions

Return `Clarification required` rather than inventing behavior if later
evidence conflicts with the current user contract or `release.md`, if a new
dependency/source protocol or project identity rule is needed, if a requested
relationship exceeds bounded roots/checkout entries, if a badge rewrite would
consume unrelated content, if scope expands to publishing/remote mutation,
or if an implementation requires an unowned product/document/sibling path.

task-1 is eligible. Preserve the dispatcher-attested documentation-only
baseline during scope checks; do not create a product task to alter Git.

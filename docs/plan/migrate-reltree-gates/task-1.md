# task-1 — Minimal OTP/Rebar3/escript skeleton

## Goal

`migrate-reltree-gates`

## Objective

Create the smallest buildable `rebar3_reltree` OTP application that can be
loaded as a Rebar3 plugin and built as the `reltree` escript. Register and
parse the accepted `tree` command through one shared request boundary, while
deliberately generating no `project.md` until task-2 supplies the tree engine.

## Contract authority and scope

- Normative behavior is frozen in this contract from the current user design
  and `release.md:166-256`. The coding worker does not choose alternate command
  names, option names, scan defaults, profile behavior, or revision defaults.
- The initiative plan and status, root documentation, sibling repository, Git
  metadata, staging, commits, and later graph/badge/installer behavior are out
  of scope. They may be supplied as context but are not coder-owned paths.
- Execution path: normal `luna_coding_worker`. This task is not eligible for
  staged Sol source implementation because it establishes new build, provider,
  escript, parsing, and test boundaries together.
- The coding worker owns implementation and every Coding Self-Test. A separate
  `luna_runner` owns all Independent Verification after coding self-tests pass.

## Decisive evidence and chosen approach

- The repository has no product source, test, or Rebar3 configuration. Git is
  valid on branch `master` with no HEAD commit; the dispatcher has attested the
  existing documentation/initiative files as the pre-task baseline.
- Application/repository identity is `rebar3_reltree`; user-facing executable
  and namespace are `reltree`; generation is `rebar3 reltree tree`
  (`release.md:168-181`).
- Configuration keys and defaults are `{scan_roots, Roots}` with default
  `[".."]`, shallow plain strings and explicit `{Path, deep}`, plus `{rev,
  false|auto|true}` defaulting to `auto` (`release.md:184-206`).
- Implement four purposeful boundaries only:
  `rebar3_reltree` registers providers and exposes the temporary tree dispatch;
  `rebar3_reltree_prv_tree` adapts Rebar3 state/options;
  `rebar3_reltree_cli` adapts escript arguments/output/exit;
  `rebar3_reltree_request` purely validates and normalizes shared requests.
- Provider profile/output context comes from Rebar3's active base directory,
  not a user option. The standalone escript has no Rebar3 state and therefore
  uses profile `default`. Both adapters pass an already selected base/output
  context into the same request normalizer.

## Exact ownership

### Owned product paths

- `.gitignore`
- `rebar.config`
- `src/rebar3_reltree.app.src`
- `src/rebar3_reltree.erl`
- `src/rebar3_reltree_cli.erl`
- `src/rebar3_reltree_prv_tree.erl`
- `src/rebar3_reltree_request.erl`

### Owned test paths

- `test/rebar3_reltree_cli_tests.erl`
- `test/rebar3_reltree_provider_tests.erl`
- `test/rebar3_reltree_request_tests.erl`

No other tracked or untracked path is owned. Tests may create unique temporary
fixture directories outside tracked scope and must remove them. No deletion is
authorized.

## Frozen end state

### Build and application skeleton

- `rebar.config` contains only the settings needed to compile the OTP
  application, run EUnit, and build an escript named `reltree`. Do not add a
  production dependency, release configuration, supervision tree, generated
  source, Common Test suite, formatter/linter dependency, or packaging hook.
- Minimum supported runtime is OTP 25 and current Rebar3 3.x. Source must not
  rely on OTP 29-only APIs when an OTP 25 standard-library API satisfies the
  same requirement.
- `src/rebar3_reltree.app.src` declares application
  `rebar3_reltree`, initial version `0.1.0`, applications `kernel` and
  `stdlib`, and no application callback/module or registered process.
- `rebar3_reltree:init/1` registers exactly one provider in this task:
  provider name `tree`, namespace `reltree`. Provider help/example advertises
  `rebar3 reltree tree [--scan-roots PATH[:deep]]... [--rev false|auto|true]`.
- The escript has one implemented subcommand, `tree`. Top-level help lists it;
  `reltree tree --help` describes the same options and defaults as provider
  metadata. There is no implicit generation command.
- `.gitignore` ignores `_build/` and `erl_crash.dump`. It must not ignore
  source, tests, `priv/`, documentation, or workflow artifacts.

### Shared request model

For equivalent project/config/options, provider and escript normalize to the
same map shape and values:

```erlang
#{command => tree,
  project_root => AbsoluteProjectRoot,
  profile => ProfileName,
  build_base_dir => AbsoluteBuildBaseDir,
  output_path => AbsoluteProjectMdPath,
  scan_roots => [{AbsoluteRoot, shallow | deep}],
  rev => false | auto | true}.
```

- `project_root` is the invocation working directory converted to an absolute,
  lexically normalized path. There is no project-selection option.
- For the provider, `build_base_dir` is the absolute active base directory
  obtained from Rebar3 state (the supported Rebar3 base-dir API is
  authoritative); `profile` is the corresponding active profile label, and
  `output_path` is `<build_base_dir>/reltree/project.md`. Do not reconstruct
  an assumed `_build/default` when Rebar3 selected another profile.
- For the standalone escript, `profile` is `default`, `build_base_dir` is
  `<project_root>/_build/default`, and `output_path` is
  `<project_root>/_build/default/reltree/project.md`. There is no `--profile`.
- The provider reads the already evaluated `reltree` configuration from
  Rebar3 state. The escript reads local `rebar.config` terms from cwd and
  selects the last top-level `{reltree, Options}` entry. Missing configuration
  is equivalent to an empty option list. Read/config failure is actionable and
  occurs before tree dispatch.
- Duplicate top-level `reltree` entries are ignored except for the last one:
  this is Rebar3 last-value-wins behavior, not an error or blocker. The
  provider must consume Rebar3's already selected evaluated value and must not
  read or reconstruct raw `rebar.config` terms. The escript must select the
  last top-level value itself so equivalent effective configuration normalizes
  identically on both surfaces. Earlier top-level `reltree` values, including
  their contents, do not participate in validation.
- Relevant keys inside the selected option list are `scan_roots` and `rev`.
  A duplicate relevant key within that selected list, malformed relevant
  value, or malformed selected option container is an error. Unrelated
  top-level Rebar3 configuration and unknown keys inside the selected
  `reltree` option list are ignored in task-1; they do not alter the request.

### Scan-root parsing and precedence

- With one or more CLI `--scan-roots` occurrences, those occurrences replace
  the entire configured root list. With none, use configured `scan_roots`.
  With neither, use exactly one shallow root `".."`.
- A configured root is either a non-empty string path, meaning shallow, or
  `{Path, deep}` with a non-empty string path. No `shallow` tuple, arbitrary
  atom, binary, nested options, or other tuple shape is accepted.
- A CLI root is `PATH` for shallow or `PATH:deep` for deep. Strip only one
  terminal `:deep`; an empty resulting path is invalid. Do not support the
  stale `--root` spelling.
- A malformed or empty configured root path returns
  `{invalid_config, scan_roots, Value}`. A malformed or empty CLI root path
  returns `{invalid_option, scan_roots, Value}`. Root normalization must retain
  origin long enough to preserve this distinction.
- Resolve relative roots against `project_root` and lexically normalize them
  to absolute paths without accessing or creating the filesystem. Preserve
  first occurrence order. Exact duplicates with the same mode collapse to the
  first; the same normalized path requested as both shallow and deep is an
  actionable conflict rather than an implicit precedence choice.
- An explicitly configured empty root list is valid and means scan no
  candidate roots; it does not fall back to `[".."]`. Only absence of the
  setting selects the default.

### Revision parsing and precedence

- CLI `--rev` may occur at most once and accepts exactly the strings `false`,
  `auto`, or `true`. It overrides configured `rev`.
- Configured `rev` accepts exactly the atoms `false`, `auto`, or `true`.
  With no CLI or config value, normalized `rev` is `auto`.
- Do not create atoms from arbitrary CLI/config input. Unknown, repeated, or
  malformed values fail before tree dispatch.

### Dispatch, errors, and no-write boundary

- `rebar3_reltree_request` is pure with injected cwd/config/profile/build-base
  inputs. It performs no Git, network, filesystem write, VM halt, Rebar3 state
  mutation, or report generation.
- Provider and escript use the same temporary shared tree dispatch function.
  A valid normalized request returns the structured error
  `tree_engine_unavailable`; this is replaced by task-2, not hidden behind a
  placeholder success.
- Provider `do/1` returns the conventional Rebar3 provider error containing
  its module and structured reason. `format_error/1` produces concise,
  actionable text. It does not halt the VM.
- `rebar3_reltree_cli:main/1` is a thin process adapter around a testable
  non-halting function. Help exits `0`; argument/config validation exits `2`;
  valid task-1 tree dispatch exits `1` with the unavailable-engine message.
- Help, validation failure, config failure, and valid unavailable dispatch
  create no directory or file at any `reltree/project.md` output path. Building
  may create normal Rebar3 `_build` artifacts only.
- Errors identify the option/config field and offending value or path where
  safe. They never print complete environment maps, credentials, stack traces
  for expected validation failures, or sibling terminology.

## Forbidden alternatives

- No `docker_ci`, `release-version-gates`, `check_badges`, `install_skill`,
  `install_release_skill`, default-namespace `rebar3 reltree`, implicit
  `reltree` generation, `--project`, `--profile`, `--root`, or configured
  `project_roots` compatibility surface.
- No task-2 graph scan, Git query, revision lookup, timestamp, Markdown/report
  renderer, atomic report writer, badge provider, skill provider, README
  mutation, remote access, dependency fetch, or placeholder `project.md`.
- No third-party CLI/config library, JSON/YAML dependency, supervision
  boilerplate, application process, wrapper-only module, copied sibling source,
  shell command, or Rebar3 command execution during module load/provider init.
- Do not modify documentation, workflow artifacts, Git metadata, sibling
  files, user directories, or any path outside exact ownership.

## Frozen test semantics

Tests must prove behavior, not merely module existence.

### Success scenarios

- Application metadata, escript name, and provider metadata expose only
  `rebar3_reltree`, `reltree`, and `{reltree, tree}` as frozen.
- Missing config plus no CLI options yields `rev=auto`, one shallow absolute
  `..` scan root, cwd project root, and the correct provider-active or escript
  default output context.
- Configured plain/deep roots and `rev=false|true|auto` normalize correctly.
- Two or more top-level `reltree` entries use only the last value in the
  escript, matching the effective value supplied by Rebar3 to the provider;
  earlier values do not trigger validation. Provider coverage proves this
  without provider access to raw `rebar.config` terms.
- Repeated CLI roots preserve order, collapse same-mode duplicates, replace
  config roots, and CLI rev overrides config.
- Equivalent provider/escript inputs produce the same request except for the
  intentionally injected active/default profile and build-base context.
- Top-level and tree help are successful and perform no dispatch/write.

### Failure scenarios

- Unknown command/option, extra positional argument, repeated `--rev`, invalid
  rev, empty root, `:deep`, malformed deep/config tuple, duplicate relevant
  config key within the selected option list, unreadable/malformed config, and
  contradictory root modes return the frozen validation class and no report
  write. An empty or malformed configured root is specifically
  `invalid_config`; the equivalent CLI root failure is `invalid_option`.
- Provider errors remain returned values and format with actionable context;
  expected CLI errors map to the frozen exit classes without an Erlang crash.

### Boundary scenarios

- Configured `scan_roots=[]` stays empty; absent `scan_roots` becomes
  `[".."]` shallow.
- A relative root is resolved against project cwd without requiring it to
  exist. Root validation performs no scan and follows no link.
- A provider request using a non-default active Rebar3 base directory retains
  that exact directory in `build_base_dir/output_path`; the escript remains
  default-profile.
- Valid provider and escript tree requests reach `tree_engine_unavailable`,
  return their frozen failure form/status, and create no report or reltree
  output directory.

## Ordered implementation steps

1. Add minimal `.gitignore`, `rebar.config`, and application metadata for an
   OTP library/plugin plus `reltree` escript.
2. Implement pure config/CLI root and rev validation, precedence, path
   normalization, selected-config last-value-wins behavior, origin-specific
   root errors, and shared request-map construction. Keep provider config
   access on Rebar3's evaluated selected value; do not add raw-config access.
3. Implement `rebar3_reltree` provider registration and temporary shared
   no-write tree dispatch.
4. Implement the namespaced tree provider using current Rebar3 state/profile
   and structured provider errors.
5. Implement escript command/help parsing and the thin non-halting/testable
   adapter plus final exit mapping.
6. Add the three exact EUnit modules covering every frozen success, failure,
   and boundary scenario, including duplicate top-level last-value-wins on
   both surfaces, provider operation without raw-config recovery, configured
   empty/malformed root `invalid_config`, and CLI invalid root
   `invalid_option` regressions.
7. Run all Coding Self-Tests, inspect exact changed paths, and return the
   coding-worker-authored evidence packet without staging or committing.

## Coding Self-Tests — run by coding worker

Run from `/home/slepher/project/rebar3_reltree` after implementation and after
every rework:

1. `rebar3 compile`
2. `rebar3 eunit`
3. `rebar3 escriptize`
4. `_build/default/bin/reltree --help` — expect exit `0`.
5. `_build/default/bin/reltree tree --help` — expect exit `0`.
6. `_build/default/bin/reltree tree --rev false` — expect exit `1` and
   `tree_engine_unavailable` rendering.
7. `_build/default/bin/reltree tree --rev invalid` — expect exit `2` and an
   invalid-rev message.
8. Confirm `_build/default/reltree/project.md` and any
   `_build/default/reltree/` directory do not exist after steps 4-7.
9. Record `git status --short` and `git diff --check`; classify the pre-existing
   documentation/initiative files as dispatcher-attested baseline and prove
   every task-attributable path is within exact ownership.

The coding packet must identify the worker, every command and exit status,
EUnit test count, acceptance outputs, report-path absence, exact changed paths,
timeout/interruption state, and any temporary fixtures/artifacts cleaned. Its
EUnit evidence must identify the focused last-value-wins and root-origin error
regressions as executed; passing only the pre-revision test set is insufficient.

## Independent Verification — later separate `luna_runner`

Only after the coding packet is complete, run against the same worktree/diff:

1. `rebar3 compile`
2. `rebar3 eunit`
3. `rebar3 escriptize`
4. `_build/default/bin/reltree --help`
5. `_build/default/bin/reltree tree --help`
6. `_build/default/bin/reltree tree --rev false`
7. `_build/default/bin/reltree tree --rev invalid`
8. `test ! -e _build/default/reltree/project.md`
9. `test ! -d _build/default/reltree`
10. `git status --short`
11. `git diff --check`

The runner packet must identify the runner; report raw command output, exact
exit status and EUnit count for each applicable command; explicitly recognize
the expected exits `0,0,1,2` for steps 4-7 rather than treating expected
nonzero exits as interruption; report report-path absence and exact status;
and perform no source/test semantic audit or edit. Sol review separately
inspects the implementation and focused assertions, and accepts only if both
surfaces use the effective last top-level value without provider raw-config
access and configured/CLI invalid roots retain `invalid_config`/
`invalid_option` respectively.

## Expected diff and commit

- Expected task-attributable tracked paths: exactly the seven owned product
  paths and three owned test paths listed above.
- Permitted task-attributable untracked paths before dispatcher staging:
  exactly those same new paths. Normal `_build/` output is ignored. No other
  generated or temporary path may remain.
- Authorized deletions: none.
- Pre-existing documentation/initiative files remain the dispatcher-attested
  no-HEAD baseline; they are not coder-owned and must not be modified.
- Proposed commit subject: `feat: scaffold reltree commands`

## Completion criteria

- The minimal project compiles, EUnit passes, and the escript is built.
- Provider metadata and escript help expose only the frozen tree command and
  options.
- Provider and escript build the frozen normalized request with correct config
  precedence, top-level last-value-wins behavior, origin-specific root error
  classes, and active/default profile behavior.
- Every invalid/help/unavailable path is structured, deterministic, and
  write-free; no report placeholder exists.
- Coding-worker and independent-runner packets are separately complete and
  passing, the real diff is within scope, Sol review returns `passed`, and the
  dispatcher commits the accepted paths with the frozen subject.

## Stop conditions

Stop without widening scope or choosing new policy if:

- current Rebar3 3.x cannot register `{namespace, reltree}, {name, tree}` or
  cannot provide its active build base/profile through a supported API;
- one OTP application cannot be both plugin and escript without adding a
  production dependency or an unowned path;
- a required edit falls outside exact ownership, a pre-existing path has
  unexpected content, or another worker/user change overlaps an owned path;
- any command attempts report generation, Git/network mutation, README change,
  dependency installation, or sibling/user-directory access; or
- a frozen behavior conflicts with current `release.md` or requires a user
  decision not present in this contract.

Report the exact evidence and blocked conclusion to the dispatcher. Do not
edit status, stage, commit, delegate, spawn a child, or implement task-2 as a
workaround.

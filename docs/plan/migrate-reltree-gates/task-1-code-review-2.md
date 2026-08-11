# task-1 code review 2

## Verdict

`passed`

## Findings

No material findings remain.

## Contract and implementation review

- Exact task-attributable scope matches `task-1.md:49-69`: `.gitignore`,
  `rebar.config`, the five declared `src/` files, and the three declared EUnit
  files are present; no task-owned deletion or generated artifact remains.
  The modified initiative documents and immutable round-1 artifacts are
  workflow-owned context, not product implementation scope.
- Provider/escript normalization conforms to the revised last-value-wins rule
  at `task-1.md:94-135`. The provider consumes only Rebar3's evaluated selected
  value through `rebar_state:get/3` and passes it to the shared normalizer
  (`src/rebar3_reltree_prv_tree.erl:42-60`); it does not recover raw config
  terms. The escript consults local `rebar.config` and `extract_config/1`
  selects the last top-level `reltree` term while ignoring earlier values
  (`src/rebar3_reltree_cli.erl:70-81`;
  `src/rebar3_reltree_request.erl:17-31`). This is the current user-selected
  Rebar3 last-value-wins behavior; duplicate top-level terms are not a finding.
- The round-1 configured-root defect is corrected. Config roots are validated
  before common path normalization and malformed or empty configured paths now
  return `{invalid_config, scan_roots, Path}`
  (`src/rebar3_reltree_request.erl:226-255`), while CLI parsing retains
  `{invalid_option, scan_roots, Value}`
  (`src/rebar3_reltree_request.erl:73-87,257-266`). The focused assertions cover
  empty and malformed configured paths plus the CLI-origin class
  (`test/rebar3_reltree_request_tests.erl:54-86`), and provider/escript
  last-value-wins behavior is exercised at
  `test/rebar3_reltree_provider_tests.erl:48-57` and
  `test/rebar3_reltree_cli_tests.erl:66-75`.
- The normalized request shape, active/default profile split, config/CLI
  precedence, and shared temporary dispatch match `task-1.md:94-184`
  (`src/rebar3_reltree_request.erl:33-58,132-172,298-313`;
  `src/rebar3_reltree_prv_tree.erl:42-78`;
  `src/rebar3_reltree_cli.erl:20-54`). Valid requests reach the shared
  `tree_engine_unavailable` result (`src/rebar3_reltree.erl:18-20`).
- The no-write invariant is preserved. Product source performs only cwd/config
  reads in the escript adapter (`src/rebar3_reltree_cli.erl:11-18,70-82`);
  request normalization and tree dispatch contain no filesystem write, report
  renderer, Git/network operation, or task-2 behavior.

## Evidence gates

The supplied coding-worker packet reports compile exit `0`, EUnit `40/0`,
escriptize exit `0`, help exit `0`, expected tree exits `1` and `2`, report
absence, passing status/diff checks, and generated-artifact cleanup. The
separate independent-runner packet reports the same completed results against
the reworked diff, with no interruption, no runner edit, and cleanup limited to
runner-generated `_build/`, `rebar.lock`, and `erl_crash.dump`. Together with
the source and focused assertion review above, these satisfy the two evidence
layers and completion criteria at `task-1.md:275-351`.

## Continuity recommendation

Next Task: `task-2`

Next Sol: `reuse`

Reason: task-2 directly replaces task-1's temporary dispatch and depends on
the normalized request, output-path, scan-root, profile, and no-write
boundaries reviewed here; retaining this context materially helps.

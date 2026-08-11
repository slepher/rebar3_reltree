# task-12 code review 1

## Verdict

`passed`

No material findings remain for implementation commit `a885f8d00a4f96178fc6da821a12e8642c576954`.

## Findings

None.

## Evidence

- Scope is exact and bounded: `a885f8d^..a885f8d` changes only `src/rebar3_reltree_scan.erl`, `test/rebar3_reltree_SUITE.erl`, and `test/rebar3_reltree_project_tests.erl`. No installer, escript, packaged-skill, `checkvsn`, `bgate`, README, workflow, configuration, or task-13/task-14 path changed. `git diff --check a885f8d^ a885f8d` is clean.
- Active-profile-only output is exercised through the real provider at `test/rebar3_reltree_SUITE.erl:46`: profiles `[default, test]` produce `_build/test/reltree/project.md` and leave `_build/default/reltree/project.md` absent (`test/rebar3_reltree_SUITE.erl:53-61`). This agrees with provider normalization at `src/rebar3_reltree_prv_tree.erl:43-60` and the release output rule at `release.md:157-161`.
- Scan boundaries remain simple and non-following. Reserved names are fixed at `src/rebar3_reltree_scan.erl:5`; root/self, shallow/deep, visited identity, and candidate identity handling remain at `src/rebar3_reltree_scan.erl:28-79` and `src/rebar3_reltree_scan.erl:125-152`. The only product correction reports a skipped symlink child without traversing it (`src/rebar3_reltree_scan.erl:89-123`), directly asserted at `test/rebar3_reltree_SUITE.erl:63-75`. Existing direct assertions cover root-self/shallow/deep, all four reserved directories, explicit symlink roots, repeated roots, and physical aliases (`test/rebar3_reltree_scan_tests.erl:5-198`).
- Declaration-plus-checkout closure is preserved by `src/rebar3_reltree_graph.erl:76-152`: a missing checkout remains an ordinary external declaration, and only a safely resolved checkout for a declared dependency creates an edge. Closure and connected-component filtering are bounded and cycle-safe (`src/rebar3_reltree_graph.erl:229-326`; `src/rebar3_reltree_fs.erl:68-102`). The release-derived vertical fixture proves current, upstream, downstream, transitive, exact three-edge closure, and external omission from nodes/warnings (`test/rebar3_reltree_project_tests.erl:37-77`). Existing graph tests separately prove checkout-only and declaration-only omission and matching downstream evidence (`test/rebar3_reltree_graph_tests.erl:31-105`).
- Failure classification matches the contract: unrelated incomplete candidates warn/omit/continue without lowering a complete graph (`test/rebar3_reltree_project_tests.erl:143-164`), connected missing facts yield `insufficient-local-data` and omit the node (`test/rebar3_reltree_project_tests.erl:242-262`), and malformed current configuration is fatal while preserving prior bytes and leaving no temp file (`test/rebar3_reltree_project_tests.erl:222-240`).
- Required report facts and deterministic ordering are covered at `test/rebar3_reltree_project_tests.erl:5-35` and `test/rebar3_reltree_project_tests.erl:79-99`; rendering includes format/status, both synchronization timestamps, current identity, warnings, nodes, declarations, edges, plugins, README/CI facts, and caveats at `src/rebar3_reltree_report.erl:9-238`.
- Revision behavior remains read-only and identity-cached. The vertical test proves `false` performs zero lookup, `true` performs one lookup for two identical declarations, `auto` reuses the valid prior record with zero lookup, timestamps/revision states are rendered, and local config/app/README/checkout/Git facts are unchanged (`test/rebar3_reltree_project_tests.erl:282-324`, `test/rebar3_reltree_project_tests.erl:364-380`). Existing revision tests cover malformed/oversized prior reports, stale/missing results, strict prior identity/state validation, fixed `ls-remote -- URL` argv, bounded output, selector behavior, and duplicate identity reuse (`test/rebar3_reltree_rev_tests.erl:97-384`).
- Atomic replacement remains one linear implementation: render fully in memory, then call the adjacent-file writer (`src/rebar3_reltree_project.erl:10-37`); write/close/validation complete before rename, and errors delete the temporary file (`src/rebar3_reltree_fs.erl:104-180`). Vertical generation failures preserve exact prior bytes and clean temporary files (`test/rebar3_reltree_project_tests.erl:198-220`), while current-project fatal failure has the same preservation proof (`test/rebar3_reltree_project_tests.erl:222-240`). Regeneration removes stale nodes and declarations (`test/rebar3_reltree_project_tests.erl:166-196`).
- The dispatcher-supplied independent runner evidence completed the task-12 acceptance checks with one stated caveat: no explicit hardlink-specific fixture. That caveat is not material. General scanning classifies entries with non-following `read_link_info/1` (`src/rebar3_reltree_fs.erl:17-58`), traverses directories only (`src/rebar3_reltree_scan.erl:89-123`), and deduplicates directory candidates by device/inode (`src/rebar3_reltree_fs.erl:43-58`; `src/rebar3_reltree_scan.erl:58-79`, `src/rebar3_reltree_scan.erl:125-152`). A regular-file hardlink cannot create an alternate directory traversal, and ordinary POSIX filesystems do not permit a user-created directory hardlink fixture. Existing physical-alias coverage therefore exercises the relevant identity invariant (`test/rebar3_reltree_scan_tests.erl:107-130`).

## Diff quality and simplicity

The product change is eight added lines in the existing scanner branch, introduces no abstraction or alternate dispatch path, and pairs the behavior with a provider-level boundary assertion. The remaining additions are focused release-derived tests in the two contract-required vertical test files. No brittle fixed repository topology or public-network dependency was introduced.

## Retrospective

No workflow gap was exposed. The independent runner correctly surfaced the absent hardlink-specific fixture as a review risk rather than treating fixture count as a substitute for scanner semantics.

## Continuity recommendation

Use a fresh Sol reviewer for task-13 because its version/badge policy is a distinct domain; retained task-12 graph/report context is not needed.

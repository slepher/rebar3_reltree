# task-11 code review 1

## Reviewed commit and scope

- Commit: `f843f42` (`refactor: remove historical reltree overdesign`).
- Contract: accepted `plan-2.md` task-11 boundary and exact `task-11.md`.
- Reviewed product/test scope: `src/rebar3_reltree.erl`, `src/rebar3_reltree_cli.erl`, `src/rebar3_reltree_prv_bgate.erl`, `src/rebar3_reltree_prv_tree.erl`, `src/rebar3_reltree_rev.erl`, `src/rebar3_reltree_skill_install.erl` and their four task-owned provider/CLI/rev/installer test modules. `rebar.config` and the packaged resource paths were inspected only to confirm the exact two leaves.
- Supplied changed-path evidence confirms this exact scope. The accidental `rebar.lock` deletion was restored byte-for-byte to tracked `[].` and has no diff.

## Findings

No material findings remain.

## Classification and direct evidence

| Cleanup item | Classification | Review evidence |
| --- | --- | --- |
| Root `dispatch_tree/1` and `dispatch_bgate/1` wrappers | `historical only`; removed | Root exports are only `init/1, main/1` (`src/rebar3_reltree.erl:3`); providers call the unchanged cores directly (`src/rebar3_reltree_prv_tree.erl:21`, `src/rebar3_reltree_prv_bgate.erl:21`); negative export assertions remain (`test/rebar3_reltree_provider_tests.erl:17-20`). |
| Exported CLI `run/1` and `help/1` | `historical only` as public surface; privatized/removed | CLI exports only production `main/1` and the fixture-safe `run/2` seam (`src/rebar3_reltree_cli.erl:3`); behavior is asserted through `run/2` (`test/rebar3_reltree_cli_tests.erl:6-25`). |
| Parse result `command => skill_install` | `historical only`; removed | Successful parsing now returns only `force` and optional `dest` (`src/rebar3_reltree_cli.erl:30-66`); retired skill/project commands remain usage errors without writes (`test/rebar3_reltree_cli_tests.erl:27-39,101-132`). |
| `USERPROFILE`, proplist destination options, generic invalid/map adapters and user-home shortcut | `historical only`; removed | Destination accepts a map and environment function, with explicit dest, `CODEX_HOME`, then `HOME` only (`src/rebar3_reltree_skill_install.erl:13-39`); precedence and no-environment-read behavior are directly asserted (`test/rebar3_reltree_skill_install_tests.erl:68-93`, `test/rebar3_reltree_cli_tests.erl:76-87`). Bounded static evidence found no `USERPROFILE` branch. |
| Private installer one-hop wrappers | `historical only` where semantically empty; merged | Stage creation/copy and owned cleanup now call their substantive functions directly (`src/rebar3_reltree_skill_install.erl:117-165,297-360`); deterministic copy and replace-failure tests retain cleanup/rollback boundaries (`test/rebar3_reltree_skill_install_tests.erl:137-190`). |
| Duplicate stage/backup allocation limits | duplicate policy; merged into one necessary constraint | Both allocation paths use the single `MAX_NAME_ATTEMPTS` constant (`src/rebar3_reltree_skill_install.erl:9,139-150,274-295`). |
| Previous report format-v1 `{ok, legacy}` branch | `historical only`; removed | Prior parsing accepts only format v2 and returns `unsupported_version` otherwise (`src/rebar3_reltree_rev.erl:59-70,108-119`); v1 rejection is direct (`test/rebar3_reltree_rev_tests.erl:246-255`), while exact v2 reuse and strict bounded records remain covered (`test/rebar3_reltree_rev_tests.erl:113-193,257-290`). |
| Plugin commands, bare installer options and exact two-file package | `normative`; retained | Plugin registration remains exactly tree/bgate/checkvsn (`src/rebar3_reltree.erl:5-36`); CLI usage remains bare `reltree [--dest DIR] [--force]` (`src/rebar3_reltree_cli.erl:22-66`); `rebar.config:4-7` and the resource listing contain only `SKILL.md` and `agents/openai.yaml`. |
| Archive reads, exact validation, stage/backup/atomic replace/rollback, path/symlink checks and process-local failure injection | `necessary implementation constraint` for normative safe installation; retained | Archive-capable loader wrappers remain (`src/rebar3_reltree_skill_install.erl:559-575`), as do exact source/stage validation (`:191-216,362-414`), activation/rollback/owned cleanup (`:218-360`) and bounded overlap checks (`:439-518`). Installer tests preserve exact bytes/tree, conflict immutability, full force replacement, source/target symlink safety, rollback and no-residue boundaries (`test/rebar3_reltree_skill_install_tests.erl:6-190`). |
| Generic transaction/package/multi-skill surface, fixed topology and remote release automation | normative absence; retained | Supplied public-surface/call-graph/forbidden-source/resource checks passed. Inspection found no new abstraction, option, resource or escript project-command route in the owned implementation. Existing rev lookup behavior was not expanded. |

The public surface and call graph are smaller for contract-backed reasons, while provider request/error adapters, report-v2 behavior, installer atomicity and plugin/escript separation remain intact. The changed tests continue to assert semantic boundaries rather than implementation-only shape. No task-12 tree work, task-13 gate work, task-14 skill-guidance work, dependency change, package expansion or unrelated path is present according to the supplied final changed-path and static evidence.

## Verification evidence consumed

- Compile exit `0`.
- Targeted EUnit: `47` passed, `0` failed; full EUnit: `135` passed, `0` failed.
- Common Test: `5` passed, `0` failed; escriptize exit `0`.
- Archive contains exactly the two normative leaves and installed bytes compare exactly.
- Isolated acceptance passed for bare install, environment precedence, explicit destination, option ordering, unchanged conflict, force replacement, help, retired commands, invalid options/environment and no residue.
- Precise export, call-graph, forbidden-source, resource-tree and changed-path checks passed; diff validity check exit `0`.

## Correction blueprint

None.

## Continuity recommendation

Use a fresh Sol worker for task-12 with only the accepted plan, the new task-12 contract and a sanitized current-state/evidence packet. Task-12 moves from cleanup review into tree/report behavior; retaining task-11 deletion inventory would add historical bias and weaken task isolation.

Verdict: passed

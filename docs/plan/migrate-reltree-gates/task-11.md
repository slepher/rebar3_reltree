# task-11 — 清理历史局部工作的过度设计

## Objective and normative behavior

在 task-10 已固定的产品边界内，对当前 reltree source/test/package/config 做一次小型、可复核的规范溯源与删减：只删除已证明为历史兼容、未来便利、重复转发或重复策略的内容；保留所有规范行为、必要的平台约束和有意义测试。

规范优先级与本任务固定事实：

- `docs/plan/migrate-reltree-gates/plan-2.md:53-67` 是 task-11 的 accepted contract source；`release.md` 是产品行为规范。
- 不重开 task-10：escript 的正常入口是裸 `reltree`，仅有可选 `--dest DIR` 和 `--force`；只安装 `SKILL.md` 与 `agents/openai.yaml`；目标优先级为显式 `--dest`、`CODEX_HOME`、用户 home；默认冲突失败，force 安全替换，失败不留新旧混合状态；全程 local-only。
- plugin 与 escript 必须继续分离：plugin 只提供 `tree`、`checkvsn`、`bgate`，escript 不提供这些项目命令或其他项目管理命令（`plan-2.md:22-24,113-117`; `release.md:109-142`）。
- task-11 只做行为等价的删减/合并，不实现 task-12 的 tree 行为、task-13 的 gates 行为，也不添加 task-14 的 packaged-skill 发布指导。

## Prerequisites

- Dispatcher 已确认 task-10 final implementation commit `b272304` 与 correction `49f5632` 均通过 review 2；task-10 合同和实现历史不得读取或重新解释。
- 开始编码前，dispatcher 必须确认当前工作区中所有拟修改产品文件都可归属于 task-11；若存在无法归属的并行改动，停止。
- 实现者必须先以本合同的 Inventory and classification 逐行核对当前文件。事实变化可把候选从 `historical only` 改为 `necessary implementation constraint`，但必须给出当前 repository/platform 的直接证据；不得以未来扩展或实现方便作为理由。

## Exact owned paths

仅允许修改以下文件，且只限所列 area：

- `src/rebar3_reltree.erl`：`dispatch_tree/1`、`dispatch_bgate/1` 与 `main/1` 的公开/转发面；provider 注册语义不得变化。
- `src/rebar3_reltree_prv_tree.erl`：仅 tree provider 到既有 project generator 的一跳调用边。
- `src/rebar3_reltree_prv_bgate.erl`：仅 bgate provider 到既有 badge core 的一跳调用边。
- `src/rebar3_reltree_cli.erl`：escript export、parse result、environment/destination adapter、错误/帮助文本中的冗余面；不得改变 accepted CLI 行为。
- `src/rebar3_reltree_skill_install.erl`：destination compatibility、固定两文件 stage/replace/rollback/cleanup 实现中的一跳 wrapper 与重复 policy；不得抽取通用 installer/transaction/package 层。
- `src/rebar3_reltree_rev.erl`：仅 previous-report `format_version: 1` legacy acceptance branch、对应 return type 与 direct callers；不得改变 v2 parsing、revision lookup 或 tree/report semantics。
- `test/rebar3_reltree_provider_tests.erl`：只调整 provider direct-call/public-surface assertions。
- `test/rebar3_reltree_cli_tests.erl`：只调整收窄后的 escript surface、destination compatibility 和 retained behavior snapshots。
- `test/rebar3_reltree_skill_install_tests.erl`：只调整 destination shape、删减项断言及保留的安全安装回归。
- `test/rebar3_reltree_rev_tests.erl`：只把 v1 legacy acceptance 改为 unsupported/malformed rejection，并保留 v2 与 bounded-input coverage。

不得创建任何产品、测试、fixture、inventory 或报告新文件。不得删除整个 owned file。

## Must change

1. 删除 `rebar3_reltree:dispatch_tree/1` 和 `dispatch_bgate/1` 这两个只有一个 caller、只做一跳转发的公开 wrapper；分别让 tree/bgate provider 直接调用现有 `rebar3_reltree_project:generate/1` 与 `rebar3_reltree_badge:run/1`。不得合并 provider 与 core，也不得改变 request、result、error wrapping 或 output。
2. 收窄 escript 的测试便利公开面：`main/1` 必须保留为 `escript_main_app` 入口；`run/2` 可保留为无真实用户目录写入的测试 seam；仅被模块自身或测试替代路径消费的 `run/1`、`help/1` 不得继续无理由 export。provider/CLI separation 测试应通过 `run(["--help"], Context)` 观察公开行为，而非依赖额外 export。
3. 删除 parse result 中未被 installer 消费的 `command => skill_install` 字段及其隐含的未来多命令扩展点。parse result 仅携带 `force` 和可选 `dest`。
4. 删除超出 accepted precedence 的 destination compatibility：`USERPROFILE` fallback、`resolve_destination/2` 的 proplist input、以及没有 caller/测试必要性的 map-or-invalid environment adapter/user-home shortcut。保留明确的 map request、显式 `--dest` 不读取环境、`CODEX_HOME` 后 `HOME` 的顺序及空/非法值错误。
5. 合并 installer 中纯一跳、无额外语义或 policy 的 private wrappers；至少核对 `create_stage/1 -> create_owned_directory/3`、`cleanup_owned/1 -> remove_owned/1`、`copy_stage/4 -> copy_stage_files/4`、`option_name/1` 和 `first_environment_value/2`。只在合并后控制流更直接且错误阶段/路径完全等价时修改；不得把安全阶段本身删掉。
6. 统一 stage/backup name allocation 的 attempt limit，删除 literal `128` 与 `MAX_NAME_ATTEMPTS` 的重复 policy。只保留一个命名常量和同一失败语义。
7. 删除 `rebar3_reltree_rev` 对 previous `project.md` `format_version: 1` 返回 `{ok, legacy}` 的兼容面；v1 必须像其他 unsupported versions 一样不复用历史数据，并走既有 bounded warning/error 路径。保留 format v2 的严格 parser、大小/UTF-8/duplicate-identity 防护和 `auto` 的既有 v2 reuse。
8. 更新直接测试，使每项删除都有反向 assertion 或静态 call-graph 证据，并保留 representative success/failure/boundary regression set。不得通过删除有意义测试来获得较小实现。

## Bounded May change

- `rebar.config`：只在静态资源树检查证明当前 `escript_incl_extra` 存在重复、额外或不可达 package entry 时，才可删除/合并该 entry；当前已见配置恰为两个规范资源，因此预期不改。若要改，必须先报告新证据并确认仍只打包 exact two leaves。
- owned source/tests 中可做与上述删除直接配套的函数 spec、注释、fixture helper 和错误 assertion 调整。
- 若某个列明的一跳 wrapper 经直接 evidence 证明对 escript archive、Rebar3 provider behavior、原子替换或 deterministic failure testing 必不可少，则保留并在实现交付的 classification 中写明证据；不得用此条增加新 wrapper。

## Read only

- `docs/plan/migrate-reltree-gates/plan-2.md`, `release.md`, root `status.md`, initiative `status.md`。
- `priv/skills/reltree/SKILL.md`, `priv/skills/reltree/agents/openai.yaml`：只验证 exact resource tree；内容属于 task-14 边界，本任务不得编辑。
- `src/rebar3_reltree_request.erl`, `src/rebar3_reltree_project.erl`, `src/rebar3_reltree_report.erl`, `src/rebar3_reltree_badge.erl`, `src/rebar3_reltree_prv_checkvsn.erl` 及其直接 source/test：只用于确认 plugin semantics、call graph、report v2 与 gate boundary。
- 其余当前 reltree source/test/rebar.config/priv 路径只可做 bounded call-graph/public-surface/resource-tree 检查；发现 cleanup 需要修改它们时停止，不得扩大 ownership。
- 所有 task/review/retrospective、plan-1、plan.md 和 sibling artifacts 均禁止读取。

## Inventory and classification

实现交付必须逐行给出最终分类（保留/删除、证据 path:symbol/line、最小 correction）。当前盘点基线如下：

| Item | Current evidence | Baseline classification / required disposition |
| --- | --- | --- |
| plugin commands `tree/checkvsn/bgate` | `rebar3_reltree:init/1`; plan-2:22 | `normative`; preserve exactly |
| escript `main/1` forwarding to installer CLI | `rebar.config` `escript_main_app`; `rebar3_reltree:main/1` | `necessary implementation constraint`; preserve |
| root `dispatch_tree/1`, `dispatch_bgate/1` | only callers are the matching providers; each forwards unchanged | `historical only`; remove and connect provider directly |
| CLI bare invocation, `--dest`, `--force`, help and usage errors | `rebar3_reltree_cli:parse/1`; plan-2:22,47 | `normative`; preserve |
| CLI project commands and retired `skill --install` | absent from parser; negative tests cover them | absence is `normative`; retain negative coverage, add no aliases |
| parse `command => skill_install` | produced but not consumed by `run_install/2` | `historical only`; remove |
| CLI `run/2`, `priv_dir` and env function context | direct fixture/snapshot tests avoid real install target | `necessary implementation constraint`; retain the smallest test seam |
| exported `run/1`, `help/1` | `run/1` only supports `main/1`; `help/1` has a test caller | `historical only` as public surface; make private/use behavioral test unless a non-test caller is proved |
| `USERPROFILE`, proplist options, generic env map/invalid fallback, `user_home` shortcut | installer/CLI compatibility branches; accepted precedence names only dest/CODEX_HOME/home | `historical only`; remove unless direct current platform evidence proves necessity |
| exact resource paths `SKILL.md`, `agents/openai.yaml` | `release.md:115-123`; config and installer validation | `normative`; preserve exact names/tree and reject extras/symlinks |
| `erl_prim_loader` read wrappers | packaged files may be inside escript archive; current package boundary uses `escript_incl_extra` | `necessary implementation constraint`; preserve archive-capable reads and exact validation |
| stage directory, exact byte copy/validation, target backup, atomic rename, rollback, owned cleanup | installer activation/error paths; `release.md:131-139` | `normative` behavior implemented by necessary local constraints; preserve failure atomicity and no mixed state |
| canonical path/symlink overlap checks and hop bound | task-10 fixed unsafe path/symlink boundary; source/target tests | `necessary implementation constraint`; preserve unless equivalent simpler proof covers all cases |
| process-local failure injection | directly drives deterministic copy/rename rollback tests; no production option/API | `necessary implementation constraint` for meaningful failure tests; do not generalize |
| one-hop private wrappers listed in Must change 5 | no policy beyond callee in current source | `historical only` when equivalence is exact; merge selectively, no broad rewrite |
| duplicated allocation limit literal and macro | stage uses literal 128; backup uses `MAX_NAME_ATTEMPTS` | duplicate policy; merge to one constant |
| generic transaction/package-manager/multi-skill layer | no such public type/option/module found; installer is fixed to reltree and two leaves | normative absence; prove by static surface/resource checks, do not rename fixed safety steps into a framework |
| fixed project topology / remote automation | no such item found in owned area; plan-2:19-24 forbids it | normative absence; prove statically; if found outside ownership, stop |
| previous report format v1 `{ok, legacy}` | `rebar3_reltree_rev:parse_prior_lines/1`, `prior_context/2`; direct legacy test | `historical only`; reject as unsupported and remove legacy return branches |
| format v2 strict parser and local prior reuse | current report/rev contract and v2 tests | `normative` retained tree behavior; do not alter |
| provider request normalization/help/error adapters | provider modules and request module | `necessary implementation constraint`; except the two proven root dispatch wrappers, preserve behavior and separation |

No item may remain unclassified. A new item discovered inside owned area must be added to the handoff classification before code change. Uncertain classification is a stop condition, not reviewer discretion.

## Reuse and rejected alternatives

Reuse:

- Keep the existing fixed installer state sequence and existing exact-resource validators; simplify only redundant plumbing around them.
- Keep existing project, badge, request, report-v2 and provider error behavior; direct-call existing core functions after removing root dispatch wrappers.
- Reuse existing EUnit fixtures and snapshots; add only assertions needed to prove deletion and retained equivalence.

Rejected:

- A generic transaction, package manager, install strategy behaviour, resource registry or multi-skill abstraction.
- A shared plugin/escript command parser or reintroducing escript `tree`, `checkvsn`, `bgate`, `skill`, `install` commands.
- Rewriting installer control flow, filesystem utilities, request architecture, report parser or providers beyond the listed one-hop reductions.
- Fixed project lists/topology, Git/network helpers, tag/push/publish automation, task-12 tree changes, task-13 gate changes, or task-14 skill guidance.
- Keeping a compatibility branch solely because a historical test exists.

## Input and output shapes

Escript input:

```erlang
[] | ["--dest", Dir] | ["--force"] | ["--dest", Dir, "--force"]
```

`--dest` and `--force` remain order-independent and each may appear at most once. Every command/subcommand or extra argument is usage error exit 2. Runtime install failure is exit 1; success is exit 0 and reports the absolute target.

Internal install request after cleanup:

```erlang
#{force := boolean(), dest => nonempty_string()} % dest optional
```

Destination resolution accepts that map plus an environment lookup function. It resolves parent directory as explicit `dest`, else `$CODEX_HOME/skills`, else `$HOME/.codex/skills`; target is always `Parent/reltree`.

Installer output remains:

```erlang
{ok, AbsoluteTarget} |
{error, {install, Stage, Path, Reason}}
```

Previous report parser accepts only the current bounded UTF-8 format v2 shape for reuse. Format v1 and unknown versions are unsupported input; under `auto`, existing warning/fresh-local-data behavior applies and no v1 revision data is reused.

## Invariants

- Public product commands remain exactly plugin `tree/checkvsn/bgate` plus installer-only escript `reltree [--dest DIR] [--force]`.
- Installed resource tree is exactly `reltree/SKILL.md` and `reltree/agents/openai.yaml`; no README, policy copy, manifest, dynamic skill list or additional resource.
- Default conflict never mutates target. Force either installs the complete new two-file tree or restores the complete old target; no stage/backup sibling remains after successful/handled-failure paths.
- Source/target symlinks and overlapping unsafe paths are not followed into unintended writes.
- Explicit destination performs no environment lookup. Default resolution reads only `CODEX_HOME`, then `HOME`.
- Installer performs local filesystem reads/writes only; cleanup introduces no Git/network/tag/push/publish operation.
- Tree, bgate and checkvsn request shapes, output, errors, writes and semantics remain unchanged.
- Report v2 parse/reuse behavior remains unchanged except that v1 is no longer accepted as a special compatibility result.
- No meaningful test is deleted unless its asserted behavior is itself classified `historical only`; retained behavior gets representative regression/snapshot evidence.

## Error and write boundaries

- Only installer execution may write, and only below the resolved skills parent through its owned stage/backup/target paths.
- Usage errors must perform no destination/source writes. Missing/invalid environment and source failures must occur before target activation.
- Cleanup may recursively remove only installer-created stage/backup paths or the explicitly replaced `Parent/reltree` target according to force semantics; never follow target symlinks.
- Provider direct-call cleanup must not add writes. Existing tree report and bgate write behavior is not exercised or changed by implementation logic outside their existing providers/core.
- No network, remote Git, tag mutation, README edit, user release choice or external state change is authorized.

## Concise pseudocode

```text
inventory owned symbols/branches/options/resources/callers
for each item:
  attach release/plan evidence, or direct repository/platform constraint
  classify normative | necessary implementation constraint | historical only
  if uncertain: stop with Clarification required

replace provider -> root dispatch -> core with provider -> same core
keep root main -> installer CLI

parse bare installer options into {force, optional dest}
resolve parent from dest | CODEX_HOME | HOME
validate exact packaged two-leaf source and safe paths
stage exact bytes
if no target: atomic activate
if target and not force: fail unchanged
if target and force: backup, activate, cleanup; rollback on activation failure

parse prior report:
  if bounded valid format v2: strict existing parse/reuse
  otherwise: existing unsupported/invalid path; never special-case v1

prove static command surface, call graph, resource tree, no-network boundary
run retained representative tests and compare snapshots
```

## Success, failure, and boundary tests

Success:

- Bare invocation installs exact packaged bytes through `CODEX_HOME`, and HOME fallback works when `CODEX_HOME` is absent.
- Explicit `--dest` succeeds without any environment read; options work in either order.
- First install and force replacement leave exact two-file tree and no owned stage/backup siblings.
- Tree and bgate provider success paths still reach the same core and preserve result/output behavior after dispatch-wrapper removal.
- Current format-v2 prior report still parses and `auto` reuses its exact revision evidence.

Failure:

- Existing target without force, source shape/content/symlink failure, invalid parent, stage copy failure and replace failure preserve the required old/absent target snapshot and cleanup state.
- `tree`, `checkvsn`, `bgate`, `skill --install`, unknown commands, duplicate options, missing destination, and extra arguments remain usage errors with no writes.
- Missing/empty/invalid `CODEX_HOME`/HOME returns the existing bounded install error; no USERPROFILE fallback occurs.
- Format v1, unknown format, malformed v2, invalid UTF-8 and oversized prior reports do not yield reusable entries; bounded warning/error semantics remain.

Boundary/static:

- Export/call-graph snapshot proves root exports only provider init and required escript entry, with no `dispatch_tree/1` or `dispatch_bgate/1`; providers have one direct core call each.
- CLI export snapshot contains only justified production entry and the minimum explicit test seam; no test-only help export or latent project command parser.
- Resource-tree/package snapshot proves exactly the two normative leaves in source and escript archive.
- Search proves no `USERPROFILE`, `{ok, legacy}`, `format_version: 1` acceptance, generic transaction/package/multi-skill API, fixed topology, remote automation, fetch/push/tag/publish call, or escript project command dispatch in the owned diff.
- Diff inspection proves no task-12 tree, task-13 gates, task-14 skill guidance, README/workflow, status, plan or unrelated source change.

## Coding Self-Tests

The coding worker owns these checks after implementation and after any rework. Record command, exit status and salient counts/snapshots; do not delegate them.

1. Compile the project.
2. Run targeted EUnit modules: provider, CLI, skill installer and revision tests.
3. Run the complete EUnit suite to catch cross-module public-surface regressions.
4. Run the existing Common Test suite as a representative plugin integration regression.
5. Build the escript and inspect its packaged resource listing/bytes, proving exactly the two normative leaves.
6. Execute isolated `/tmp` escript acceptance snapshots for help, bare install, explicit destination, conflict, force, invalid/retired commands and no unexpected writes. Never target a real user home.
7. Perform bounded static call-graph, export/public-surface, resource-tree, forbidden-string/no-network and changed-path checks described above.
8. Run a whitespace/diff validity check. Do not stage or commit.

Independent Verification is performed later only by a separate `luna_runner`. Its evidence packet must independently repeat the targeted/full regressions, escript package and isolated acceptance snapshots, plus static call-graph/public-surface/resource-tree/diff checks against the final worktree; implementation-worker summaries are not substitutes.

## Expected diff

Expected tracked modifications:

- `src/rebar3_reltree.erl`
- `src/rebar3_reltree_prv_tree.erl`
- `src/rebar3_reltree_prv_bgate.erl`
- `src/rebar3_reltree_cli.erl`
- `src/rebar3_reltree_skill_install.erl`
- `src/rebar3_reltree_rev.erl`
- `test/rebar3_reltree_provider_tests.erl`
- `test/rebar3_reltree_cli_tests.erl`
- `test/rebar3_reltree_skill_install_tests.erl`
- `test/rebar3_reltree_rev_tests.erl`

`rebar.config` is expected unchanged; it may appear only under the bounded condition above. No other tracked path, no untracked product/test artifact, and no authorized deletion. Generated `_build`, lock, crash, package or temporary fixture artifacts must not remain in the handoff.

Expected shape is a net reduction in public exports, branches and helper lines, with small direct test adjustments. A broad module rewrite, mass rename, formatting-only churn, dependency change or new abstraction fails scope even if tests pass.

## Completion criteria

- Every inventoried item has one of the three required classifications with direct evidence, and every `historical only` item in owned scope is removed/merged.
- All mandatory reductions are present; no normative/necessary item was removed or behaviorally weakened.
- Representative retained-behavior tests and static snapshots pass in coding self-tests and later independent verification.
- Final changed-path set matches Expected diff (plus evidence-approved `rebar.config` only), with no unrelated/generated files.
- Reviewer can trace each deletion to a classification row and each retained complexity to release/repository/platform evidence.

## Stop conditions

Stop immediately and return exactly `Clarification required` with the uncertain item, current evidence, exact question and blocked conclusion if:

- classification is uncertain or a claimed necessary constraint lacks direct repository/platform evidence;
- behavior equivalence before/after a deletion cannot be proved by targeted tests and static call graph;
- any removal changes bare installer, destination precedence, exact package, safety/rollback, provider semantics, tree/report-v2, bgate or checkvsn normative behavior;
- required modification extends beyond Exact owned paths or conflicts with unattributable work;
- cleanup would require a broad rewrite, new dependency, new abstraction, new resource, remote/network access or real user-directory write;
- work would implement task-12 tree behavior, task-13 gate behavior or task-14 skill guidance;
- current source contradicts the dispatcher-fixed task-10 boundary or decisive evidence is missing.

## Commit subject

`refactor: remove historical reltree overdesign`

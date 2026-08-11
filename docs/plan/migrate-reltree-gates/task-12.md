# task-12 — 完成本地 tree 与 project.md 事实报告

## Objective

完成并收敛现有 Rebar3 plugin `tree` 纵向链路，使 `rebar3 reltree tree` 只依据当前本地项目、显式扫描范围、runtime dependency 声明和 `_checkouts` 关系证据，在当前 profile 的 `_build/<profile>/reltree/project.md` 生成可重复、可降级、成功后才替换的联合发布事实报告。

本任务以 `release.md` §3、§6 和 accepted `plan-2.md` 的 task-12 为规范，不重开已经通过的 task-10 installer 或 task-11 cleanup，不实现 task-13 `checkvsn`/`bgate`，也不编写 task-14 packaged skill 指导。

## Decisive evidence

- `docs/plan/migrate-reltree-gates/plan-2.md` 的 task-12 要求依次固定扫描/根识别、节点/边分类与异常降级、报告事实与 revision metadata，并把 `release.md` 作为唯一发布规范。
- `release.md` §6.1–§6.3 定义 profile 输出路径、`scan_roots`/`rev` 输入、项目根和跳过目录、声明加 checkout 的关系证明、传递闭包、内存去重、报告字段、只读 revision metadata 及成功写入边界。
- 当前实现已有应复用的线性链路：`rebar3_reltree_prv_tree:request_from_state/1` → `rebar3_reltree_request:normalize/1` → `rebar3_reltree_project:generate/2` → graph/enrich/revision/status/render → `rebar3_reltree_fs:atomic_write/3`（`src/rebar3_reltree_prv_tree.erl:28`、`src/rebar3_reltree_project.erl:10`）。
- 当前扫描器已把 `.git`、`_build`、`_checkouts`、`node_modules` 列为跳过目录，并以内存中的 filesystem identity/canonical path 合并候选（`src/rebar3_reltree_scan.erl:5`、`src/rebar3_reltree_scan.erl:12`、`src/rebar3_reltree_scan.erl:127`）。
- 当前 graph 以 dependency name 查找 `_checkouts/<name>`，并只把有效 declaration-plus-checkout 关系纳入与当前节点连接的闭包（`src/rebar3_reltree_graph.erl:84`、`src/rebar3_reltree_graph.erl:233`）。
- 当前报告由 model 内存事实渲染，按 path/edge/declaration 排序；写入器在目标旁创建临时文件并仅以最终 rename 替换（`src/rebar3_reltree_report.erl:10`、`src/rebar3_reltree_fs.erl:107`）。
- 现有直接测试覆盖了很多局部行为，但 task-12 的验收必须重新以当前 `release.md` 边界组织成功、失败和边界证明，不得复制历史 task 的矩阵或把既有测试名称当作规范。

## Prerequisites

- `plan-2.md` 已 accepted。
- task-10 installer 和 task-11 cleanup 已通过；其公开 plugin/escript 分工及简化后的调用图是不可回退边界。
- 当前 tree/report 源码和直接测试可明确归属于本任务；若发现无法归属的并行改动，停止并交回 dispatcher。
- 实现者开始前只依据本合同、`release.md`、当前源码和当前直接测试判断，不读取或恢复历史 task 合同、review 或 retrospective。

## Exact owned paths

### Must change

以下两个纵向验收测试必须被补充或重组，以形成由当前 `release.md` 边界驱动的 task-12 证明；不得只保留历史局部断言并宣称完成：

- `test/rebar3_reltree_SUITE.erl`
- `test/rebar3_reltree_project_tests.erl`

测试必须至少形成一条真实 provider 到 profile-specific report 的成功路径、一条当前项目失败保留旧报告的失败路径，以及覆盖扫描/关系/revision/write 边界的针对性 fixture 证明。

### May change, bounded by failing task-12 evidence

仅当上述 release-derived 测试暴露真实不符合时，允许对下列现有模块作最小修正；不得为了统一风格、未来扩展或重命名而改动：

- `src/rebar3_reltree_prv_tree.erl`
- `src/rebar3_reltree_request.erl`
- `src/rebar3_reltree_scan.erl`
- `src/rebar3_reltree_graph.erl`
- `src/rebar3_reltree_config.erl`
- `src/rebar3_reltree_project.erl`
- `src/rebar3_reltree_rev.erl`
- `src/rebar3_reltree_report.erl`
- `src/rebar3_reltree_status.erl`
- `src/rebar3_reltree_fs.erl`
- `src/rebar3_reltree_git.erl`
- `src/rebar3_reltree_clock.erl`
- `test/rebar3_reltree_config_tests.erl`
- `test/rebar3_reltree_request_tests.erl`
- `test/rebar3_reltree_scan_tests.erl`
- `test/rebar3_reltree_graph_tests.erl`
- `test/rebar3_reltree_report_tests.erl`
- `test/rebar3_reltree_rev_tests.erl`
- `test/rebar3_reltree_provider_tests.erl`
- `test/rebar3_reltree_status_tests.erl`
- `test/rebar3_reltree_fixtures.erl`

不得新增通用 scanner、cache、transaction、report framework 或第二套 dispatch 层。只有在现有测试文件无法清晰承载一个 release-derived assertion 时，才可新增一个直接、task-12-only 测试文件；新增前必须先向 dispatcher 说明必要性。

### Read only

- `docs/plan/migrate-reltree-gates/plan-2.md`
- `release.md`
- root `status.md`
- `docs/plan/migrate-reltree-gates/status.md`
- `rebar.config`
- `src/rebar3_reltree.erl`（provider 注册面已由 task-11 固定）
- `src/rebar3_reltree_version.erl`（只消费其本地版本事实，不改变 task-13 policy）
- `src/rebar3_reltree_badge.erl`、`src/rebar3_reltree_prv_bgate.erl`、`src/rebar3_reltree_prv_checkvsn.erl` 及其测试
- installer、CLI、packaged skill、agent metadata、README、workflow、status、plan、review、commit 和所有其他路径

## Reuse and rejected alternatives

### Reuse

- 保留 task-11 后的单一路径和既有模块职责；优先在现有 request/scan/graph/project/rev/report/fs 函数内作局部修正。
- 复用 `rebar3_reltree_fs` 的 non-following filesystem inspection、identity 去重、显式 checkout resolution 和 atomic write。
- 复用 `rebar3_reltree_config` 的 consulted-term 读取及原始 dependency declaration 保留。
- 复用 `rebar3_reltree_git` 的本地 HEAD/tag/origin 读取和受限 `ls-remote` revision metadata lookup；测试使用本地 bare repository 或注入 lookup，不依赖公网。
- 复用可注入 clock，使除同步时间外的报告字节可确定比较。

### Rejected alternatives

- 不固定项目名称、目录布局、依赖矩阵或 `release.md` §12 示例拓扑。
- 不把普通 external runtime dependency 变成 graph node、missing-node warning 或本地 checkout 猜测。
- 不扫描整个文件系统，不跟随普通扫描 symlink/hardlink alias，不建立磁盘 cache/index。
- 不 fetch、push、clone、checkout、创建/移动/删除 tag、发布或修改 README；`rev` lookup 只读取 revision metadata，不产生网络或仓库状态副作用。
- 不把 tree 拆成新框架，也不恢复 task-11 已删除的 wrapper、provider/CLI 转发或未来扩展点。
- 不复制历史测试矩阵；每个新增断言必须直接指向本合同中的当前 `release.md` 行为。

## Inputs and outputs

### Normalized input shape

`rebar3_reltree_request:normalize/1` 的成功结果保持为一个内存 request map，至少包含：

```erlang
#{command => tree,
  project_root => AbsoluteCurrentProject,
  profile => Profile,
  build_base_dir => ActiveProfileBuildBase,
  output_path => ActiveProfileBuildBase ++ "/reltree/project.md",
  scan_roots => [{AbsolutePath, shallow | deep}],
  rev => false | auto | true}.
```

- 未配置 `scan_roots` 时使用 `[{"..", shallow}]`（相对于 current project 规范化）。
- 配置接受普通 `Path`（shallow）和 `{Path, deep}`；CLI 接受可重复 `--scan-roots PATH[:deep]`，一旦出现即整体覆盖配置。
- CLI `--rev false|auto|true` 覆盖配置；均未指定时为 `auto`。
- 同一 canonical/physical root 的重复发现合并；同一路径出现冲突 mode 属配置/请求错误，不猜优先级。

### Graph/model shape

- catalog 仅含 current project 及扫描范围内有 `rebar.config` 的候选；checkout 明确指向的有效 local upstream 可在关系解析时按规范加入。
- node 至少含 canonical path/name、Git HEAD、可达正式 tag/version、`app.src`/`app.vsn`、原始 runtime declarations、`project_plugins`、普通 plugins/工具声明、README/README.zh/CI workflow/badge facts、local-only caveats。
- edge 仅表示被 declaration 和匹配 checkout 同时证明的 runtime dependency，方向为 downstream/source → upstream/target。
- external dependency 只留在所属 node 的 declaration/revision facts 中，不进入 nodes/edges；正常的 checkout 缺失不 warning。

### Report output

- 唯一产品写入为 `_build/<profile>/reltree/project.md`，UTF-8 Markdown。
- metadata 至少含 format version、`up-to-date | update-required | insufficient-local-data`、current project path/name、`local_sync_at`、`network_sync_at`。
- 节点、边、声明、warnings 除同步时间外稳定排序；相同时钟和相同本地事实生成相同字节。
- `network_sync_at`/每个 declaration 的 revision state 必须准确区分未执行、复用、成功解析、stale 和 missing；`local_sync_at` 使用有效 UTC `YYYY-MM-DDTHH:MM:SSZ`。

## Normative behavior and invariants

1. 当前 Rebar3 profile 决定唯一输出路径；不得写项目根 `project.md` 或其他 profile。
2. 每个显式 root 本身先作为候选检查；shallow 只检查 root 与直接子目录，deep 才递归。
3. 递归只把含 `rebar.config` 的目录视为项目根，并在任何深度跳过 `.git`、`_build`、`_checkouts`、`node_modules`。
4. 普通扫描不跟随 symlink；physical identity/canonical identity 在本次调用内去重，多个 root、alias、checkout name 或传递路径只 enrich 一次。不得持久化 cache。
5. 唯一特殊链接规则是显式 `_checkouts/<dependency-name>` 关系入口；其解析必须 bounded、cycle-safe，最终目标必须是可读取的 project directory。
6. local upstream 必须同时有 owner 的 runtime declaration 和匹配 `_checkouts/<name>`；downstream 必须由扫描到的项目自身声明 current/local node，并由其匹配 checkout 指回该节点。
7. checkout-only 不建边；declaration-only 且无 checkout 是正常 external dependency，不建 node/edge、不 warning。
8. 每发现一个合法 local node，按同一规则继续寻找其上下游，得到受 scan roots 与显式 checkout 入口约束的传递闭包。
9. 候选读取、配置、权限、app identity、Git 或 checkout 异常应 warning、omit、continue；与 current project 无关的坏候选不得降低 current graph status。影响已连接关系的缺失事实必须使报告可解释地成为 `insufficient-local-data`。
10. current project 自身缺少生成所需事实是命令失败，不生成猜测报告；失败必须保留旧报告字节。
11. `rev=false` 不读取旧报告、不 lookup external revision；`auto` 只复用 identity 完全匹配的有效旧记录，并对尚无有效记录的可追踪 external declaration 做一次只读 metadata lookup；`true` 对每个可追踪 external identity 做一次 lookup。重复 identity 在内存中共享结果。
12. revision lookup 只能执行固定参数、bounded output/timeout 的只读 metadata 查询；不得 fetch/push/tag mutation，也不得覆盖 local checkout HEAD。失败记录 bounded stale/missing 事实并继续，不泄漏任意命令输出或凭空创建 graph node。
13. tree 只报告 README/CI badge facts，不写 README；它可消费现有本地版本/badge 结果来计算 tree status，但不得实现或改变 task-13 的 `checkvsn`/`bgate` policy。
14. report 完整 render、UTF-8 encode、临时写入、close 和内容校验全部成功后，才以同目录 rename 替换旧文件；任一步失败都清理本次 temp 并保留旧报告。
15. 不产生固定拓扑、远端发布动作或其他外部状态副作用。

## Error and write boundaries

- 请求/config/CLI 值非法：返回结构化错误，不创建 output directory/report。
- current project `rebar.config`、唯一 `app.src`、Git HEAD 或 render 所需事实不可用：整个命令失败，旧 report 保持逐字节不变。
- 非 current 候选或关系入口异常：输出一条去重、稳定排序、detail bounded 的 warning；遗漏无充分证据的节点/边，继续处理其他候选。
- external revision lookup 异常：不使扫描崩溃；按是否有有效 prior 记录为 stale 或 missing，令 status/reasons 表达数据不足。
- prior report malformed/oversized/unreadable：不得执行其中内容或据其建图；warning 后按无可复用 prior 继续。
- 唯一授权产品写入是 normalized `output_path`；测试 fixture 只能写其临时目录。不得修改任何被扫描项目的 config、Git refs、README 或 checkout。
- atomic write 的 open/write/close/validate/rename 失败均返回具体 stage，清理 temp，保留 prior bytes。

## Concise pseudocode

```text
request = normalize(provider cwd, active profile/build base, reltree config, CLI)
catalog = {current} + scan_each_root(root itself, shallow/deep, skip reserved, no symlink follow)
catalog = deduplicate_in_memory(canonical path + filesystem identity)

for candidate in catalog:
    read runtime/plugin/tool declarations
    current failure => abort; unrelated failure => warning + omit

queue = valid candidates
for project in queue:
    for runtime declaration name:
        if _checkouts/name absent: record external declaration only
        else resolve explicit checkout safely
             valid target + matching declaration => add local edge and enqueue target
             anomaly => warning + omit unsupported relation

included = declaration+checkout connected closure around current
enrich included nodes from local Git/app/README/CI facts; omit incomplete non-current nodes
apply rev false|auto|true to external declarations with in-memory identity cache
evaluate exact tree status and timestamps
render stable UTF-8 Markdown entirely in memory
atomic_write(active-profile project.md); on any failure retain prior report
```

## Tests derived from current release.md

### Success tests

- Provider with default profile and a non-default active profile writes only the matching `_build/<profile>/reltree/project.md`; no root-level or other-profile report appears.
- Default `..` shallow, configured mixed shallow/deep roots, repeatable CLI roots, root-self candidate, and CLI-over-config behavior are asserted through normalized request plus actual discovery results.
- A fixture with current, local upstream, local downstream, transitive local node, and ordinary external declaration proves exact nodes/edges/directions and proves the external declaration has no node or warning.
- Report assertions cover all required local facts: canonical path/name, Git HEAD, formal tag/version, `app.src`/`app.vsn`, runtime declarations, upstream/downstream, project plugins/plugins/tool facts, README/CI badge facts, exact status vocabulary, both sync timestamps and caveats.
- Duplicate roots/physical aliases/transitive paths and duplicate external revision identities prove one canonical node scan/one edge identity/one lookup while retaining all declaration facts.
- Injected fixed clock proves byte determinism; a changed clock may change only synchronization time fields.
- `rev=false|auto|true` each have focused tests proving lookup count, valid prior reuse, fresh lookup, per-identity cache and accurate `network_sync_at`; local bare repositories or injected lookup are used, never the public network.

### Failure tests

- Invalid CLI/config values fail before report creation.
- Malformed current config, missing/ambiguous app identity, unavailable current Git fact, invalid clock/report encoding, and each atomic write stage preserve exact prior bytes and leave no task temp file.
- Malformed/oversized/unreadable prior report is never evaluated; warning is bounded and generation continues from current facts.
- External lookup timeout/failure with valid prior becomes stale; without prior becomes missing; both continue and produce `insufficient-local-data` with explicit bounded reason.

### Boundary tests

- `.git`、`_build`、`_checkouts`、`node_modules` are skipped under deep roots; explicit symlink scan roots and symlink children are warned/skipped without traversal; filesystem aliases do not duplicate nodes.
- Explicit `_checkouts/<name>` allows only the special bounded relationship resolution, including cycle/broken-target handling; it does not authorize general symlink traversal.
- declaration-only external dependency and checkout-only directory/link produce no local edge; downstream requires both its declaration and checkout back to the candidate.
- Unrelated malformed/unreadable candidates warn/omit/continue without changing a complete current graph to insufficient; anomaly on a required connected relation omits that relation and yields `insufficient-local-data`.
- Regeneration after a local relationship/declaration is removed atomically replaces the report and removes stale node/edge/declaration facts.
- Static/runtime probes prove only read-only local Git commands and optional `ls-remote -- URL` metadata lookup occur; no fetch/push/tag/checkout/clone or README/config mutation is invoked.

## Ordered implementation steps

1. Translate the success/failure/boundary list above into focused assertions against current fixtures. Reuse existing tests where they already prove the exact current release boundary; rename/restructure only when needed for clarity.
2. Run the focused tests to identify actual gaps. Do not change source merely because historical structure differs from a preferred design.
3. Correct request/profile/scan behavior minimally, preserving current adapter boundary and CLI-over-config semantics.
4. Correct graph/project enrichment minimally so only declaration-plus-checkout local relationships form the canonical connected closure and anomalies degrade exactly as specified.
5. Correct revision/report/status/write behavior minimally, retaining memory-only cache, deterministic rendering and atomic prior-report preservation.
6. Complete the provider-to-report CT path and negative/no-side-effect assertions, then run all Coding Self-Tests.
7. Compare changed paths with this contract. Remove generated artifacts; report any needed owned-area expansion instead of editing it.

## Coding Self-Tests

The coding worker owns and must execute these after implementation and after every rework:

```text
rebar3 compile
rebar3 eunit
rebar3 ct
rebar3 escriptize
```

In addition, the worker must report focused evidence mapping the release-derived success/failure/boundary tests above to exact test names, plus:

- output paths and exit statuses for default and non-default profile provider fixtures;
- exact prior-report bytes before/after injected generation failures;
- revision lookup call counts/argv and a before/after snapshot proving no Git refs, checkout, config, README or unrelated file mutation;
- generated artifact cleanup (`_build`, `rebar.lock`, crash dumps or fixture leftovers) before handoff.

Failure of any self-test remains coding responsibility; it is not deferred to independent verification.

## Independent Verification

A fresh `luna_runner`, not the coding worker, must independently execute the same four commands against the final diff, rerun the task-12 CT/EUnit acceptance paths, and inspect the actual report/no-side-effect evidence. The runner must specifically confirm:

- active-profile-only output and successful provider-to-report behavior;
- exact local graph proof and ordinary external dependency omission from nodes/warnings;
- all three revision modes and no mutating Git/network command;
- anomaly continuation versus current-project fatal failure;
- prior report preservation and temp cleanup for generation/write failure;
- changed-path scope and absence of task-13/task-14/installer behavior.

The runner may add a bounded risk-based check, but may not edit source/tests or substitute coding-worker summaries for execution evidence.

## Expected diff

- Required: focused modifications to the two Must change vertical test paths so the final evidence is explicitly derived from current `release.md`.
- Conditional: the smallest necessary subset of May change source/support-test paths, each paired with a failing release-derived assertion and a regression test.
- Expected product shape remains the current linear module chain; no new production module is expected.
- No deletion is authorized. No untracked product file is expected. A new direct test file requires dispatcher approval under the bounded rule above.
- No changes to `rebar.config`, provider registration, version/bgate policy, installer/escript CLI, packaged skill, README/workflows, plan/status/review/commit documents or any other path.

## Completion criteria

- `rebar3 reltree tree` produces the exact active-profile report from local and explicitly allowed read-only metadata evidence, with no fixed topology or mutating side effect.
- All scan, identity, relationship, external declaration, anomaly, status, revision-mode, report-field and atomic replacement invariants above have direct current-release tests.
- Current failures preserve prior report; non-current anomalies warn/omit/continue; successful regeneration removes stale facts and atomically replaces the report.
- Coding Self-Tests pass, then independent runner verification passes against the same final diff.
- Review finds no material contract mismatch, scope leak or task-11 simplification regression.

## Stop conditions

Stop and return to dispatcher without broadening scope if any of the following occurs:

- task-12 requires changing `rebar.config`, `src/rebar3_reltree.erl`, installer/escript/package/skill files, README/workflow, task-13 providers/policy, task-14 guidance, or any unowned path;
- a requested behavior would require a fixed project topology, whole-filesystem scan, persistent cache, fetch/push/tag mutation/publish, README mutation or other external state change;
- current work cannot be distinguished from unrelated user changes or task-11's accepted simplification cannot be preserved;
- `release.md` cannot decide whether a candidate/revision/status should be included, omitted, warning-only or fatal;
- preserving a prior report would require a broader transaction framework or non-local write;
- a new production abstraction/module or test hierarchy appears necessary rather than a local correction;
- self-test or independent evidence is missing, contradictory or depends on historical task matrices instead of current release behavior.

## Commit subject

```text
feat: complete local reltree project reports
```

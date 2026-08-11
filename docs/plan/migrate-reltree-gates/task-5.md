# task-5 — 补齐纯本地版本门禁

## Objective and normative behavior

在已接受的 `plan-1.md` 下新增 plugin-only `rebar3 reltree checkvsn`：复用当前
`rebar3_reltree_version`、`rebar3_reltree_git` 与 `rebar3_reltree_config:app_identity/1` 的本地事实，
按根目录 `release.md` §2 与 §7 校验当前项目的 `app.src` 版本、当前 tag 一致性及相对最高可达
formal tag 的版本连续性。

规范行为如下：

- 应用版本唯一来自当前项目唯一的 `src/*.app.src` 中唯一字符串 `vsn`，格式必须是 `X.Y.Z`。
- formal tag 只识别 `[v]X.Y.Z`；prerelease 只识别 `[v]X.Y.Z-rc.N` 与
  `[v]X.Y.Z-ci.N`；`check-*` 完全忽略，其他 tag 不参与门禁。
- formal 版本按三段非负整数比较，`X.Y.Z` 与 `vX.Y.Z` 数值等价；最高 formal 按数值确定，
  不因 tag 字符串排序改变结论。
- 没有 formal tag 时，任意格式合法的 `X.Y.Z` 可作为初始应用版本。
- 存在最高 formal `X.Y.Z` 时，应用版本只允许为该版本本身、`X.Y.(Z+1)`、
  `X.(Y+1).0` 或 `(X+1).0.0`；更低版本、跳 patch、跳 minor、minor 后非零 patch、跳世代或
  新世代后非 `0.0` 均失败。
- `(X+1).0.0` 仅验证结构上是连续下一世代；是否选择新世代由发布者在命令外明确决定。
  provider 不新增确认 option，也不从 diff 自动判断兼容性或发布意图。
- 当前 tag 与 `app.src` 的一致性、reachable prerelease 的适用范围必须遵守下述 stop condition；
  不得用未写入 `release.md` 的“active prerelease”规则补足歧义。
- 命令成功只报告门禁通过并返回原 Rebar3 state；失败返回有界、可诊断的 provider error。
  命令不修改文件、Git refs 或 Rebar3 配置。

## Prerequisites and exact owned paths

### Prerequisites

- `docs/plan/migrate-reltree-gates/plan-1.md` 已为 `Plan status: accepted`。
- task-1..task-4 的产品实现已在 HEAD `e0c98bf`；现有 `tree`、`bgate` 和 escript 行为是本任务的
  回归基线，不在 task-5 重构。
- 编码前必须确认本合同的 reachable prerelease stop condition 未被实际目标场景触发，或已由
  用户作出明确解释并由 Sol 更新合同。

### Must change

- `src/rebar3_reltree.erl`
- `src/rebar3_reltree_prv_checkvsn.erl`（新增）
- `src/rebar3_reltree_version.erl`
- `src/rebar3_reltree_git.erl`
- `test/rebar3_reltree_provider_tests.erl`
- `test/rebar3_reltree_version_tests.erl`
- `test/rebar3_reltree_checkvsn_tests.erl`（新增）

### Bounded May change

- `test/rebar3_reltree_fixtures.erl`：仅可增加构造本地 version-gate fixture 所需的窄 helper，
  例如创建 annotated/lightweight tag 或读取 refs；不得加入网络或真实仓库操作。
- `test/rebar3_reltree_config_tests.erl`：仅当新增 checkvsn 回归暴露现有
  `app_identity/1` 的规范错误分类缺口时补充断言；不得改变 config domain 行为。

### Read only

- `src/rebar3_reltree_cli.erl`
- `src/rebar3_reltree_request.erl`
- `src/rebar3_reltree_prv_tree.erl`
- `src/rebar3_reltree_prv_bgate.erl`
- `src/rebar3_reltree_project.erl`
- `src/rebar3_reltree_badge.erl`
- `src/rebar3_reltree_rev.erl`
- `src/rebar3_reltree_report.erl`
- `src/rebar3_reltree_config.erl`
- `priv/skills/reltree/**`
- 除上述 Must/May 测试外的全部测试路径。
- `release.md`、`docs/plan/migrate-reltree-gates/plan-1.md`、`status.md`、`commit.md`、历史 task/review
  artifact、`.codex/**`、Git metadata 与工作区中用户已有修改。

## Reuse and rejected alternatives

### Reuse

- 复用 `rebar3_reltree_config:app_identity/1` 对唯一 `app.src`、唯一 `vsn` 和读取错误的现有分类。
- 复用 `rebar3_reltree_git:read/1` 的 argv-based、bounded、纯本地 HEAD/reachable-tag 读取；只增加
  checkvsn 确实需要且现有 map 缺少的 current-HEAD tag fact，不建立第二套 Git runner。
- 复用 `rebar3_reltree_version:parse_version/1`、`parse_tag/1`、数值排序与最高 formal facts；将
  连续性判定收敛为同模块内可供 tree facts 与 checkvsn gate 使用的单一核心分类，不复制 parser。
- provider 直接读取 app/Git facts 并调用 version gate；注册层只注册 provider，不新增 dispatch
  或 strategy wrapper。

### Rejected alternatives

- 不在 escript、`rebar3_reltree_cli` 或通用 request parser 中加入 `checkvsn`；该命令面属于 task-6
  之外的 plugin-only 行为。
- 不新增 `dispatch_checkvsn/1`、通用 gate registry、发布状态机或第二套 version policy。
- 不引入 SemVer 依赖、远端 tag 查询、fetch、push、tag mutation、文件写入或 GitHub Actions env。
- 不根据 diff、分支名、commit message 或 API 扫描自动判断兼容性、发布意图或新世代授权。
- 不为 `(X+1).0.0` 新增 `--major`、`--generation`、`--confirm` 等规范外 option。
- 不顺带修改 task-6 installer/escript、task-7 badge/legacy 裁剪或 task-8 skill 工作流。

## Input and output shapes

### Version policy

- 输入：`AppVsn :: string()` 与 Git version facts map，至少包含
  `reachable_tags :: [string()]`；若 current-tag 一致性采用 HEAD 精确事实，则另含
  `head_tags :: [string()]`。
- 输出成功：`{ok, Facts}`，其中至少保留 parsed app version、按数值排序/去重后的 formal versions、
  所有真实 tag spelling、最高 formal 及连续性分类；不得为等价 `X.Y.Z`/`vX.Y.Z` 强选一个
  “首选 tag”。
- 输出失败：`{error, Reason}`，Reason 为稳定结构化 atom/tuple，能区分非法 app version、当前 tag
  base 不一致和 formal 版本不连续；不包含整份环境或无界 Git 输出。

### Provider

- 输入：Rebar3 `State`；project root 为 `rebar_state:dir(State)`。命令没有产品 option 或位置参数，
  只允许 Rebar3 正常传入的空参数形态及 provider help 路径。
- 输出成功：`{ok, State}`，可输出一行简短通过信息但不得输出易漂移的完整 report。
- 输出失败：`{error, {rebar3_reltree_prv_checkvsn, Reason}}`；`format_error/1` 将结构化原因转换为
  有界文本。

## Invariants

- `src/*.app.src` 的 `vsn` 是应用版本唯一事实来源；缺失、多个、malformed、重复/非法 `vsn`
  均不得猜测或回退到 app metadata、Git tag、release 文件或环境变量。
- 最高 formal 仅由 HEAD 可达的合法 formal tags 按数值计算；prerelease 与 `check-*` 不参与最高
  formal 或连续性增量计算。
- formal 数值去重不丢失真实 spelling；等价裸/v tag 不造成版本 gap，也不触发任意 tag 选择。
- 允许集合必须精确为 highest/same、next patch、next minor with patch zero、next major with
  minor/patch zero；不允许 `>=` 或“看起来更新”之类宽松判定。
- `tree` 现有 `evaluate/2` facts、`tree` provider、`bgate` provider 和 escript 命令面不得因本任务
  倒退或扩张。
- 所有 Git 调用继续使用 executable + argv，不拼 shell command；仅查询当前本地 repository。

## Error and write boundaries

- 使用现有 app identity 错误作为原因链：`no_app_src`、`multiple_app_src`、读取/term/vsn 错误必须
  保留可诊断性；不得吞并为普通 version mismatch。
- Git executable、HEAD、reachable tags 或必要 HEAD-tag facts 读取失败是命令失败；不得降级为
  “无 tag”或访问远端补齐。
- 非法 `app.src` 版本、当前相关 tag base 不一致、低于最高 formal 或任何版本跳跃分别返回明确
  gate error；不自动修改 `app.src` 或 tag。
- provider 参数错误在读取 app/Git facts 前失败；help 不执行门禁。
- 运行时写边界为空：不得创建/修改 `project.md`、README、`app.src`、config、cache、临时文件或
  Git refs。测试只在 invocation-owned 唯一临时 fixture 中写入，并在结束时清理。

## Concise function-level pseudocode

```text
rebar3_reltree:init(State):
  register existing tree and bgate providers unchanged
  register {namespace = reltree, name = checkvsn, opts = []}

checkvsn_provider:do(State):
  validate no product arguments
  Root := rebar_state:dir(State)
  App := config:app_identity(Root)
  GitFacts := git:read(Root) plus the minimal local HEAD-tag fact required by the gate
  version:check(App.app_vsn, GitFacts)
  ok -> {ok, State}
  error -> structured provider error

version:check(AppVsn, GitFacts):
  parse AppVsn as exactly X.Y.Z
  classify reachable tags with existing parser; ignore check-* and unsupported forms
  group formal tags by numeric version while retaining every spelling
  Highest := numeric maximum formal, or none
  validate current relevant tag bases only after prerelease scope is normatively resolved
  validate App against {initial | Highest | next_patch | next_minor | next_major}
  return normalized facts or exact gate error
```

## Tests

### Success cases

- 无 formal tag 时，多个合法初始版本（含非零 major/minor/patch）通过。
- app 等于最高 formal、严格 next patch、严格 next minor `.0`、严格 next major `.0.0` 分别通过。
- 裸 formal、`v` formal、相同数值的裸/v 双 tag 和多位数字段按数值处理。
- 合法 `[v]X.Y.Z-rc.N`/`-ci.N` 能被识别；`check-*` 和 unsupported tag 不参与最高 formal。
- provider 从唯一 app.src 与纯本地 Git facts 成功返回原 State；现有 tree/bgate 注册仍存在。

### Failure cases

- app version 不是精确三段数字，或 app.src 缺失、多个、malformed、vsn 缺失/重复/非字符串。
- app 低于最高 formal；跳 patch；跳 minor；next minor 的 patch 非零；跳 major；next major 的
  minor 或 patch 非零。
- 指向当前门禁对象的合法 formal/prerelease tag base 与 app version 不一致（仅在 prerelease
  stop condition 已解决后冻结断言）。
- 非 Git 目录、无有效 HEAD、Git executable/tag 查询失败；未知参数在任何事实读取前失败。

### Boundary cases

- `0.0.0`、段值大于 9、前导 `v`、相同数值不同 spelling、重复 tag facts 和无关 tag。
- `rc`/`ci` 之外的后缀、缺失/非数字/额外 prerelease 段均不作为规范 prerelease。
- `check-*` 即使包含看似更高版本也不影响结果。
- provider help/metadata、失败前后 filesystem 与 refs snapshot、现有 escript 对 `checkvsn` 仍为未知命令。
- tree 的既有 version facts/status 回归保持，避免 gate error API 意外改写 `project.md` 行为。

## Coding Self-Tests

编码 worker 必须直接运行并返回原始命令、exit code、测试数与关键输出；不得把后续独立 runner
证据当作自身 self-test：

1. `rebar3 compile`
2. `rebar3 eunit --module=rebar3_reltree_version_tests`
3. `rebar3 eunit --module=rebar3_reltree_checkvsn_tests`
4. `rebar3 eunit --module=rebar3_reltree_provider_tests`
5. `rebar3 eunit`
6. `rebar3 ct`
7. `rebar3 escriptize`
8. 在唯一临时本地 fixture 中通过 provider API 覆盖成功、gap、app/tag mismatch、无 HEAD 与 unknown
   argument，并比较运行前后文件/refs snapshot；不得把本仓库未安装 plugin 导致的
   `Command reltree not found` 当作产品失败。
9. 确认构建后的 escript 未新增 `checkvsn` 命令面，且现有 tree/bgate 的 task-5 回归未改变。
10. `git diff --check`，并确认实际修改路径严格落在 Must/May change 集合内，无生成物残留。

独立验证如有需要由 dispatcher 另行交给 `luna_runner`；Sol 不运行上述命令。

## Expected diff

- `rebar3_reltree.erl` 增加一个 `checkvsn` provider registration，既有 provider registration 保持。
- 新增一个薄 `rebar3_reltree_prv_checkvsn.erl`，直接编排 app/Git facts 与 version gate，不新增
  dispatch wrapper。
- `rebar3_reltree_version.erl` 增加共享 gate/classification API，并复用现有 parser/sort；不复制
  tree policy。
- `rebar3_reltree_git.erl` 仅增加校验当前 tag 一致性所需的最小本地 fact，保持 argv/no-network
  边界。
- provider/version/checkvsn 测试覆盖注册、纯 policy、真实本地 fixture、错误和零写入；fixture helper
  仅在必要时小幅扩展。
- 不出现 CLI/request/escript、installer、badge/project/rev/report、skill 或 workflow artifact diff。

## Stop conditions

- **Reachable prerelease 歧义：** `release.md` 未唯一说明“历史上可达、但不指向当前 HEAD，或已被
  后续 formal 覆盖的 rc/ci tag”是否仍必须以其 base 匹配当前 `app.src`。若目标仓库或测试必须
  决定该行为，立即停止并询问用户：门禁应只校验当前 HEAD 上的 prerelease tag，还是校验全部
  reachable prerelease tag？在答复前不得实现 `active prerelease`、`latest prerelease` 或
  “formal 已覆盖即忽略”等自定义规则。
- **等价裸/v tag：** 数值连续性可直接去重且保留全部 spelling；若实现、输出或 current-tag 校验
  被迫在等价最高 `X.Y.Z` 与 `vX.Y.Z` 中选择唯一真实 tag，停止并询问用户，不按字典序或前缀偏好。
- 若 Rebar3 无法注册精确的 namespaced no-option 命令 `rebar3 reltree checkvsn`，停止，不新增 alias
  或默认 namespace 命令。
- 若完成门禁必须读取网络/CI env、修改文件/refs、自动判断兼容性/发布意图、新增新世代 option，
  或修改 task-6..8/只读路径，停止并报告合同冲突。
- 若共享 version core 无法在不改变现有 tree 外部事实/状态的情况下复用，停止并由 Sol 决定是否
  需要修订 task ownership；不得复制第二套 parser/policy 规避冲突。
- 若发现未归属的用户修改与 Must/May 路径重叠，停止并交由 dispatcher recovery。

## Commit subject

`feat: add local reltree version gate`

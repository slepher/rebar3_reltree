# task-6 — 交付专用 skill installer 并收窄 escript

## Objective and normative behavior

在已接受的 `plan-1.md` 下落实根目录 `release.md` §5：把本仓库维护的两文件
`reltree` Codex skill 打包进 escript，提供唯一安装命令
`reltree skill --install [--dest DIR] [--force]`，并删除 escript/CLI 现有 `tree`、`bgate`
项目管理命令面及其 compatibility path。

规范行为如下：

- escript 只负责安装 skill；`tree`、`checkvsn`、`bgate` 继续且只由 Rebar3 plugin 提供。
  plugin 独立运行，不依赖用户已经安装 skill，也不新增 Rebar3 installer provider。
- 可打包 source 必须且仅为 `priv/skills/reltree/SKILL.md` 与
  `priv/skills/reltree/agents/openai.yaml`；不得增加 README、`release.md` 副本、manifest 副本或
  其他 package leaf。
- `--dest DIR` 把 DIR 作为 skills parent，并在其下追加 `reltree`；无 `--dest` 时，若
  `CODEX_HOME` 已设置且非空，则 parent 为 `$CODEX_HOME/skills`；否则 parent 为用户 home 下的
  `.codex/skills`。最终 target 始终为 `<parent>/reltree`，成功时报告其准确绝对路径。
- target 不存在时执行首次安装；target 已存在时默认冲突失败且不修改。只有显式 `--force` 才能
  全量替换。
- 首次安装和 force 替换都必须先在 target 同一 parent 内完成 invocation-owned stage，并验证
  stage 完整；force 随后把旧 target 原子移到 invocation-owned backup，再把完整 stage 原子移到
  target。第二次 rename 失败时必须尝试 rollback；不得逐文件覆盖 target，也不得留下新旧文件混合
  的 target。
- installer 只做本地文件操作，不调用 Git、不访问网络、不读取 CI 环境、不创建/移动 tag、不
  push/publish。除解析安装位置所需的 `CODEX_HOME` 与 user home 外，不读取无关环境变量。
- usage error 返回 exit 2；安装/路径/打包 runtime error 返回 exit 1；成功返回 exit 0。错误必须包含
  具体 path 与 stage，且不得泄露整个环境或无界文件内容。

## Prerequisites and exact owned paths

### Prerequisites

- `docs/plan/migrate-reltree-gates/plan-1.md` 为 `Plan status: accepted`。
- task-5 已在 review 2 判定 passed，最终 checkpoint commit 为 `febdc0a`。
- 当前 package source 已存在且只有 `priv/skills/reltree/SKILL.md` 与
  `priv/skills/reltree/agents/openai.yaml`；二者内容在 task-6 只读，task-8 才负责发布工作流文档补充。
- 当前 `tree`/`bgate` provider help 依赖 `rebar3_reltree_cli:help/1`；本任务必须先在 provider adapter
  内保留等价 help，再从 CLI 删除项目管理 help，避免 plugin 行为倒退。

### Must change

- `rebar.config`
- `src/rebar3_reltree_cli.erl`
- `src/rebar3_reltree_skill_install.erl`（新增）
- `src/rebar3_reltree_prv_tree.erl`
- `src/rebar3_reltree_prv_bgate.erl`
- `test/rebar3_reltree_cli_tests.erl`
- `test/rebar3_reltree_skill_install_tests.erl`（新增）
- `test/rebar3_reltree_badge_tests.erl`
- `test/rebar3_reltree_SUITE.erl`

### Bounded May change

- `src/rebar3_reltree_fs.erl`：仅增加 installer 所需、可复用且保持 no-follow 的窄 filesystem
  primitive；installer-specific orchestration、ownership tracking 和 rollback 不下沉为通用事务层。
- `test/rebar3_reltree_provider_tests.erl`：仅补充 tree/bgate provider help 与 escript 解耦后的回归
  断言；不改变 provider domain semantics。
- `test/rebar3_reltree_report_tests.erl` 或现有 filesystem 直接测试：仅当
  `rebar3_reltree_fs.erl` 新增 primitive 时添加其 no-follow/error-boundary 聚焦断言。

### Read only

- `priv/skills/reltree/SKILL.md`
- `priv/skills/reltree/agents/openai.yaml`
- `src/rebar3_reltree.erl`
- `src/rebar3_reltree_request.erl`
- `src/rebar3_reltree_prv_checkvsn.erl`
- `src/rebar3_reltree_project.erl`
- `src/rebar3_reltree_badge.erl`
- `src/rebar3_reltree_version.erl`
- `src/rebar3_reltree_git.erl`
- `src/rebar3_reltree_rev.erl`
- `src/rebar3_reltree_report.erl`
- `src/rebar3_reltree.app.src`
- 除上述 Must/May 测试外的全部测试路径。
- `release.md`、`docs/plan/migrate-reltree-gates/plan-1.md`、task-5/review artifact、`status.md`、
  `commit.md`、`.codex/**`、Git metadata 与工作区中用户已有修改。

## Reuse and rejected alternatives

### Reuse

- 运行中的 escript 通过 `code:priv_dir(rebar3_reltree)` 定位 packaged app priv，再固定追加
  `skills/reltree`；不得从 cwd、源码仓库相对路径或网络寻找 source。
- 复用 `rebar3_reltree_fs:absolute/1`、`regular/1`、`read_file/1` 等现有窄能力；缺少的 rename、
  no-follow inspect、exclusive stage、bounded cleanup 可以作为 installer 私有函数，只有确实跨模块
  复用时才加入 `rebar3_reltree_fs`。
- 复用 `rebar3_reltree_cli:run/2` 作为窄 test seam，但其 production default 必须使用真实
  `code:priv_dir/1`、`CODEX_HOME` 和 user home；测试注入只允许 source/home/env/filesystem failure
  所需的局部函数或值，不传入整份环境 map。
- `rebar3_reltree_request` 的 tree/bgate parser 继续只供 Rebar3 providers 使用。它在 escript CLI
  不再可达，因此不为“清理命名”重写 provider parser。

### Rejected alternatives

- 不保留 `reltree tree`、`reltree bgate`、`reltree checkvsn`、旧 help 或任何 compatibility alias；
  不新增其他项目管理命令。
- 不新增 Rebar3 `skill` provider，不把 plugin providers 迁移或镜像到 escript，也不要求 plugin
  调用 installer。
- 不创建通用包管理器、多 skill registry/抽象、plugin/escript command registry、安装 manifest、
  发布状态机或通用 filesystem transaction framework。
- 不把 package source 复制到第三处，不生成 README 或规范副本，不动态选择任意 skill 名称。
- 不逐文件原地覆盖 target，不使用跨 filesystem stage，不删除未由本 invocation 创建或接管的
  stage/backup，不跟随 source/target symlink 递归删除。
- 不访问 Git/网络、fetch/push/tag/publish，不读取 GitHub Actions env 或扫描无关环境变量。

## Input and output shapes

### CLI request

- 允许输入：top help；`skill --help`；精确的 `skill --install`，后接可选且各最多一次的
  `--dest DIR`、`--force`。两个 option 可按普通 CLI 顺序出现，但 `--dest` 必须有独立非空值，
  `--force` 不接受值。
- 规范化输出：`#{command => skill_install, parent => AbsoluteParent, force => boolean()}`；source 不由
  用户指定，adapter 从 packaged priv 固定解析。
- 未知 command/option、重复 option、缺少 `--install`、缺失/空 `--dest` value、额外位置参数和
  `--force=...` 均为 usage error，不读取 source、不创建 parent、不调用 installer。

### Installer domain

- 输入：`SourceRoot :: absolute path`、`Parent :: absolute path`、`Force :: boolean()`，以及仅测试用的
  bounded failure-injection options。
- 成功输出：`{ok, AbsoluteTarget}`，其中 `AbsoluteTarget = <Parent>/reltree`。
- 失败输出：`{error, {install, Stage, Path, Reason}}` 或同等稳定结构；Stage 至少能区分
  source validation、parent、target conflict、stage create/copy/validate、backup、replace、rollback
  和 cleanup。

### Packaged source shape

```text
priv/skills/reltree/
├── SKILL.md
└── agents/
    └── openai.yaml
```

source root 与 `agents` 必须为 no-follow ordinary directory；两个 leaf 必须为 no-follow regular file。
目录 entry set 必须精确相等，缺失或多余 entry、symlink、special file 或不可读 leaf 均失败。

## Invariants

- parent precedence 精确为 `--dest` > `CODEX_HOME/skills` > `<user-home>/.codex/skills`；最终只追加
  一次 `reltree`。显式 `--dest` 不读取 `CODEX_HOME`，有效 `CODEX_HOME` 不读取 user home。
- 所有报告和 error path 使用解析后的准确绝对路径；路径含空格或非 ASCII 时不经过 shell。
- stage 与 backup 位于 target 同一 parent，以 exclusive、不可预测的 invocation-owned 名称创建；
  名称碰撞时选择新名称或失败，绝不接管/删除预存同名 entry。
- 在首次 target rename 或 force backup rename 前，stage 已含且仅含两个完整 regular leaf，并完成
  bytes re-read validation；任何 earlier failure 保持原 target 完全不变。
- target 已存在且 `force=false` 时，在接管 target 前失败；target 的 file/directory/symlink 类型不得
  通过 follow 后静默覆盖。
- force 流程只允许 old target、complete stage、owned backup 三种完整对象状态转换；replace 失败
  必须优先恢复 backup。rollback 失败时保留可恢复的 owned backup 并报告其准确路径，绝不删除
  唯一旧副本或把其内容混入 target。
- cleanup 只接触本 invocation 记录为 created/taken-over 的 stage/backup；递归 cleanup 对 symlink
  只删除 link 本身，不跟随目标。
- 成功 target 只包含 package 的两个文件，bytes 与 packaged source 一致；force 是全量替换，不保留
  target 中旧的多余文件。
- plugin 的 `tree`、`checkvsn`、`bgate` 注册、命令行为和 domain 写边界不变；只有 escript command
  surface 被收窄。

## Error and write boundaries

- `code:priv_dir/1` 返回 error、source shape/type/read failure、home 缺失、parent 无法创建/不是普通
  directory、source/target overlap、target conflict及每个 stage/rename/rollback/cleanup failure 均返回
  bounded structured error，包含具体 path 和 stage。
- 空或无效 `CODEX_HOME` 不解释为 cwd；若变量已设置但不可作为路径，报告配置错误，不静默回退。
  user home 无法可靠取得时失败，不使用 cwd 或 `/tmp` 作为 production fallback。
- Runtime 可写路径只限 resolved parent、`<parent>/reltree` 及本 invocation-owned 同级 stage/backup；
  为创建 parent 所需的缺失目录只能位于解析后的 parent path。不得写仓库、README、`project.md`、
  config、Git refs 或其他 skill target。
- 测试一律使用 invocation-owned 唯一临时 parent/source；不得省略 `--dest` 后写入真实
  `$CODEX_HOME`、真实 user home 或已安装 skills 目录。环境 precedence 使用注入 seam 或进程级临时
  override，并在测试结束恢复。
- replace 成功后 cleanup 失败时不得回滚已经完整可见的新 target；返回 cleanup error并保留准确
  owned backup 路径供恢复。此状态不是半安装或 target 内新旧混合。

## Concise function-level pseudocode

```text
cli:run(Args, Context):
  parse only help | skill --install [--dest DIR] [--force]
  usage error -> {2, bounded_error}
  Parent := explicit dest
            else nonempty CODEX_HOME + "/skills"
            else user_home + "/.codex/skills"
  Source := code:priv_dir(rebar3_reltree) + "/skills/reltree"
  skill_install:install(Source, Parent, Force, narrow_test_options)
  ok(Target) -> {0, exact_target_line(Target)}
  error(Reason) -> {1, path_and_stage_error(Reason)}

skill_install:install(Source, Parent, Force, Options):
  absolute + overlap checks
  validate exact no-follow source tree and read two source bytes
  ensure and validate ordinary parent
  allocate exclusive owned stage beside Target
  create exact stage tree; write, close, reread, and validate both leaves
  if Target absent:
    rename Stage -> Target atomically
  else if not Force:
    cleanup owned Stage; return target_conflict
  else:
    rename Target -> owned Backup
    rename Stage -> Target
    on replace failure: rename Backup -> Target; preserve/report Backup if rollback fails
    on success: cleanup owned Backup without following links
  cleanup only tracked leftovers; return absolute Target

tree/bgate providers:
  retain provider-local equivalent help and existing request/domain calls
  never route through installer-only escript CLI
```

## Tests

### Success cases

- explicit `--dest` 首次安装产生 `<dest>/reltree`，只含两个规定 leaf，bytes 与 source 相同，输出为
  准确绝对 target，且无 stage/backup 残留。
- `--force` 在完整 stage 后全量替换旧 target，删除旧 target 内多余文件并保留准确新 bytes。
- `--dest`、`CODEX_HOME`、user home 三种 parent 来源分别成功，并证明 precedence 与只追加一次
  `reltree`。
- top/skill help 成功且零写入；option 两种顺序均可；含空格/非 ASCII parent 正确处理。
- `rebar3 escriptize` 产物通过自身 packaged priv 完成首次安装与 force，不依赖源码 cwd。
- Rebar3 plugin 的 tree/checkvsn/bgate provider metadata/help 与既有聚焦行为继续成功，无 skill 安装
  前置条件。

### Failure cases

- target 已存在且无 `--force`，原 target bytes/tree 不变；unknown/duplicate/missing/extra CLI 输入
  exit 2 且未读取 source/创建 parent。
- priv/source 缺失、多余 entry、directory/leaf symlink、非 regular leaf、不可读 leaf、source/target
  overlap 和 invalid parent 均在 target 接管前失败。
- stage create、first/second copy、close、re-read validation、backup rename、replace rename、rollback、
  backup cleanup 各失败路径返回具体 stage/path；每项证明 target 为完整旧版或完整新版，绝无混合。
- invocation-owned stage/backup 清理失败可诊断；同名预存非 owned entry 保持不变。
- user home 缺失、无效/空 `CODEX_HOME`、`code:priv_dir/1` failure 均不回退到 cwd 或真实用户目录。

### Boundary cases

- existing target 为 ordinary directory、file 或 symlink 的 default conflict；force 对 target entry 本身
  操作且不跟随 symlink target。
- source、parent、target 的 lexical/identity overlap；stage/backup 名称碰撞；partial pre-existing
  similarly named entry；缺失 parent 的受限创建。
- installed target entry set 精确；package/escript 不含额外 skill README 或 `release.md` 副本。
- built escript 对 `tree`、`bgate`、`checkvsn` 和未知 alias 均返回 usage exit 2 且零产品写入；help
  不列出这些项目管理命令。
- provider tests 不通过 escript CLI 获取 tree/bgate help；`rebar3_reltree_request` parser 仍只服务
  providers，未形成可达 escript compatibility path。

## Coding Self-Tests

编码 worker 必须直接运行并返回原始命令、exit code、测试数与关键输出；后续独立 runner 证据不能
替代 coding self-test：

1. `rebar3 compile`
2. `rebar3 eunit --module=rebar3_reltree_skill_install_tests`
3. `rebar3 eunit --module=rebar3_reltree_cli_tests`
4. 若修改 provider 或 fs 直接测试，运行对应 focused EUnit modules。
5. `rebar3 eunit`
6. `rebar3 ct`
7. `rebar3 escriptize`
8. 对构建后的 escript 使用唯一临时 `--dest` 执行首次安装、default conflict、`--force` 替换，记录
   exit/output，核对准确 target、两文件 bytes、精确 entry set 与无 stage/backup 残留。
9. 通过注入的临时 `CODEX_HOME` 与 user-home seam 验证 precedence；不得让命令写入真实用户目录。
10. 对构建后的 escript 调用 `tree`、`bgate`、`checkvsn`、未知 alias 与 help，证明 installer-only
    command surface、usage exit 和零产品写入。
11. 使用 OTP/escript archive 能力或等价只读检查确认 packaged skill 资源精确为
    `SKILL.md` 与 `agents/openai.yaml`，无额外 README/规范副本；不得安装新依赖完成检查。
12. 对 plugin providers 执行聚焦 metadata/help/代表性 command regression，证明不依赖 skill target。
13. `git diff --check`，确认实际修改路径严格属于 Must/May change 且无生成物残留。

独立验证若由风险或最终验收触发，只能由 dispatcher 指派 `luna_runner`；Sol 不运行上述命令。

## Expected diff

- `rebar.config` 增加 escript 打包两文件 skill source 所需的最小配置；不增加 dependency 或第三个
  package resource。
- 新增单用途 `rebar3_reltree_skill_install.erl`，包含 exact source validation、stage/replace/rollback
  orchestration 和 bounded error formatting；不演变为通用 installer framework。
- `rebar3_reltree_cli.erl` 删除 tree/bgate config、help、dispatch 与 request compatibility path，缩小为
  skill-install parser/adapter；不增加 checkvsn 或 alias。
- tree/bgate provider adapters 只把原先从 CLI 取得的 help 收回本地，其他解析与 domain dispatch
  保持；`rebar3_reltree_request.erl` 不变。
- installer/CLI tests 覆盖 package、路径 precedence、首次/force、安全失败与准确输出；现有 CLI/CT/
  badge tests 移除 escript tree/bgate parity 假设，改为证明 provider-only 与 installer-only 边界。
- product/test diff 只出现在 Must/实际需要的 May paths；不修改 package 内容、task-7 badge/legacy
  实现或 task-8 skill 文档。

## Stop conditions

- 若当前 Rebar3/escript 打包机制无法让运行中的 escript 通过 `code:priv_dir(rebar3_reltree)` 读取精确
  两文件 package，停止并报告证据；不得改用 cwd、网络、源码绝对路径或复制第三份 source。
- 若安全替换无法把 stage 与 target 放在同一 parent/filesystem，或不能在 replace failure 后保留
  完整旧 target/可恢复 backup，停止；不得降级为逐文件覆盖或删除后重建。
- 若实现必须跟随 source/target symlink、清理非 invocation-owned path、写真实用户目录、读取无关
  env、访问 Git/网络或引入通用事务/包管理抽象，停止并报告合同冲突。
- 若保持 plugin tree/bgate help 必须改变其公开命令语义、迁移 provider 到 escript 或修改 task-7
  domain 实现，停止；不得保留 escript compatibility path 规避解耦。
- 若 `CODEX_HOME` 或 user home 的可移植取得方式无法在支持的 OTP/OS 上可靠决定，停止并请求用户
  明确平台边界，不回退 cwd 或 `/tmp`。
- 若 coding 前或途中证明 installer 安全事务、packaging 与 CLI 收窄无法由一个 worker 在一次独立
  review 中完整验证，则停止 coding，由 Sol 在已接受 `plan-1` 范围内 refinement task-6 为更小的
  顺序任务；不创建新 plan，不自行扩 scope。
- 若发现必须修改 Read only 路径或与未归属用户修改重叠，停止并交由 dispatcher recovery。

## Commit subject

`feat: add packaged reltree skill installer`

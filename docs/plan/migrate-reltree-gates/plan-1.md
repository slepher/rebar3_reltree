# migrate-reltree-gates — `release.md` 对齐修正计划

Plan status: accepted

## Goal

以根目录 `release.md` 全文（§1–§12）为唯一产品规范，在保留当前已满足要求的 `tree` 与
`bgate` 行为的基础上，补齐纯本地 `checkvsn`、installer-only escript、可打包 `reltree`
skill 及发布工作流，并只裁剪有调用图与测试证据支持的冗余，不为形成 diff 重写正确实现。

## Lineage

- `Supersedes: plan.md`
- `Previous task: task-4`
- 历史 `plan.md` 及 task-1..4、review、`status.md`、`commit.md` artifact 保留不改；虽然
  initiative `status.md` 仍停在 task-4 planning checkpoint，task-4 已在 HEAD `e0c98bf` 完成。
- 本计划从 task-5 开始，仅替代旧计划的未完成部分；获批前不创建 task-5+ artifact，也不进入
  coding lifecycle。

## Normative inputs

- 唯一产品规范：根目录 `release.md` 全文，重点包括 §2 版本/tag、§4 badge、§5 skill/installer、
  §6 tree/bgate、§7 checkvsn 与 §8–§11 发布流程；本计划不复制其正文。
- 当前用户合同决定本 draft 的路径、lineage、任务编号、只读边界与审核暂停点。
- HEAD `e0c98bf` 的源码、测试和 runner 证据仅用于确认已满足行为与真实缺口，不能增加
  `release.md` 未要求的产品能力。

## Constraints

- 已满足的 `tree` 主体与 `bgate` 不重复实现。保留扫描调用内 canonical cache、`tree` 成功后
  原子替换且失败保旧、`bgate` 按 `README.md` 后 `README.zh.md` 顺序写且不承诺跨文件事务。
- installer 必须保留 staging、原子替换与失败回滚边界；默认不覆盖，仅 `--force` 可替换，且
  失败后不得出现半安装或新旧混合。
- `checkvsn`、tree facts 与 installer 默认只使用本地只读 Git/文件事实；不得 fetch、push、
  修改 tag、发布制品、读取 GitHub Actions 环境或推断代码兼容性。
- escript 最终只提供 `reltree skill --install [--dest DIR] [--force]`；`tree`、`checkvsn`、
  `bgate` 只属于 Rebar3 plugin，且 plugin 不依赖 skill 已安装。
- 不新增命令别名、通用依赖数据库、磁盘关系 cache、发布状态机、跨仓库事务、远端 cache/网络
  操作、README 全文格式化、规范副本或额外 skill README。
- task-9/task-10 只是 task-6 在已批准 `release.md` §5 范围内的 task refinement；仍只实现专用
  两文件 installer 与 installer-only escript，不新增通用 transaction、package manager、multi-skill
  abstraction 或新的产品行为。现有 task-6 partial diff 按路径归属两个 replacement task，必须保留，
  不删除、不重写或借 refinement 扩 scope。
- task-7 明确移除产品代码中已有规范与调用图证据支持的过度设计：`project.erl`/`badge.erl`
  重复 badge facts/template/判定、`rebar3_reltree.erl` 的单次转发 wrapper、`badge.erl` 中返回
  相同结果的 `tag_policy` 分支，以及 `rev.erl`/`report.erl` 中无当前规范依据且不再需要的
  `format_version=1` legacy 分支。每项实施删除前仍须由测试与调用图证明行为等价；不得借裁剪
  改变 `tree`/`bgate` 外部行为、revision 模式或当前 report 语义。
- 若 `release.md` 无法唯一决定 reachable prerelease 的门禁范围、等价最高 `X.Y.Z`/`vX.Y.Z`
  的真实 tag 选择，或任何修正会改变未规定的 report/revision 语义，则停止当前任务并请求用户
  澄清，不新增选项或偏好。

## Dependencies and order

task-6 已 superseded before completion。剩余严格按 task-9 → task-10 → task-7 → task-8 执行；
每项只有在其独立 task contract 完成并通过实现、证据与审查后，下一项才可开始。task-7 与
task-8 在 task-10 passed review 前均不可开始；任务边界需要实质扩张时停止并修订计划。

## Ordered tasks

### task-5 — 补齐纯本地版本门禁

- **一句话目标：** 复用现有版本/tag parser 和本地 Git/app facts，新增 plugin-only
  `rebar3 reltree checkvsn`，落实 `release.md` §2 与 §7 的一致性和连续性门禁。
- **前置条件：** task-4 已完成；本 draft 已获用户批准。
- **Owned-area summary：** provider 注册与新的 checkvsn provider、版本 policy 及其直接
  provider/version 测试；Git/config 读取层仅允许最小复用调整。
- **关键行为边界：** 无网络、无 CI env、无文件或 Git 写入；忽略 `check-*`，识别规范允许的
  formal/rc/ci tag；不自动判断兼容性或发明“新世代确认”命令选项，规范歧义触发 stop condition。
- **依赖顺序：** 第一项；其共享版本事实可供后续 badge 裁剪复用。
- **验收摘要：** plugin 精确暴露 `checkvsn`，对合法连续版本成功、对不一致或跳版本给出可诊断
  失败，且 escript 不暴露该命令、运行前后本地状态不变。

### task-6 — 交付专用 skill installer 并收窄 escript — superseded before completion

- **状态：** `superseded before completion`；两个 coding worker 均在 installer + packaging + CLI +
  full acceptance 的单 worker 边界重复中断，现有 `task-6.md` 与 partial diff 保留为历史和恢复输入，
  replacement 为 task-9、task-10。

- **一句话目标：** 打包 `priv/skills/reltree/SKILL.md` 与 `agents/openai.yaml`，实现安全的本地
  installer，并把 escript 收窄为唯一安装命令面。
- **前置条件：** task-5 通过审查；两文件 skill package 仍是规范要求的唯一资源树。
- **Owned-area summary：** escript/CLI adapter、专用 installer、必要的 package 配置与窄文件系统
  原语，以及 installer/CLI/package 直接测试；明确删除 escript 中现有 `tree`/`bgate` 项目管理
  命令面，不改三个 plugin domain 的规范行为。
- **关键行为边界：** 目标优先级为 `--dest`、`CODEX_HOME`、用户 home；目标存在默认失败，
  `--force` 使用完整 stage 后的原子替换/回滚；只写解析后的 skills parent 内 invocation-owned
  target/stage/backup，不访问 Git、网络或真实测试用户目录；escript 不保留 `tree`/`bgate`
  compatibility path 或新增其他项目管理命令。
- **依赖顺序：** 第二项；完成后 plugin 与 escript 的职责边界固定。
- **验收摘要：** 生成的 escript 含且仅安装规定的两文件 skill，准确报告目标路径，失败不留混合
  状态，并拒绝 `tree`、`checkvsn`、`bgate` 等项目管理命令而无副作用。

### task-9 — 完成 installer/resource domain

- **一句话目标：** 从保留的 task-6 partial work 完成专用 installer domain 与两文件 escript
  resource packaging，使安全安装事务可通过直接 domain API 独立验收。
- **前置条件：** task-6 已 superseded before completion；其 partial diff 原样保留并完成路径归属，
  task-9 contract 获得独立 coding/review 边界。
- **Owned-area summary：** `rebar.config`、`src/rebar3_reltree_skill_install.erl`、installer 直接测试，
  以及 `priv/skills/reltree/SKILL.md` 与 `agents/openai.yaml` 的精确两文件资源完整性；资源内容不改。
- **关键行为边界：** exact regular/no-follow source 校验、默认 target conflict、完整 stage 后的原子
  replace/rollback 和 invocation-owned cleanup；只做本地文件操作，不包含 CLI/provider 迁移、通用
  transaction、package manager 或 multi-skill abstraction。
- **依赖顺序：** task-6 的第一 replacement；task-9 passed review 后才可开始 task-10。
- **验收摘要：** installer domain 能从精确 packaged source 完成首次安装与安全 force 替换，失败不留
  半安装或混合 target，且资源集严格只有两个规定 leaf。

### task-10 — 完成 installer-only escript/CLI 与最终 packaging acceptance

- **一句话目标：** 在 task-9 installer domain 上完成 installer-only escript adapter、plugin help
  解耦和最终 packaged command boundary/full acceptance。
- **前置条件：** task-9 passed review；task-6 中归属 CLI/provider/test 的现有 partial hunks 继续保留
  并由 task-10 接管，不删除或重写已完成的可用工作。
- **Owned-area summary：** `src/rebar3_reltree_cli.erl`、tree/bgate provider help adapter、CLI/provider/
  badge/CT 相关测试；覆盖 escript command surface、destination precedence 与最终 packaged boundary。
- **关键行为边界：** escript 只接受 `reltree skill --install [--dest DIR] [--force]`，删除 tree/bgate
  compatibility path且不新增 checkvsn/alias；plugin 三 provider 保持 plugin-only并不依赖 skill 安装。
- **依赖顺序：** task-9 的第二 replacement；task-10 passed review 后才可开始 task-7，随后 task-8。
- **验收摘要：** 最终 packaged escript 正确处理 `--dest`、`CODEX_HOME`、user home、conflict/force/
  failure/no-write，并拒绝所有项目管理命令；plugin provider 与完整回归边界通过。

### task-7 — 统一 badge policy 并删除已证实冗余

- **一句话目标：** 让 `tree` 与 `bgate` 复用一个符合 `release.md` §4/§6.4 的只读 badge
  facts/policy，并删除 runner 调用图与规范证据已确认的重复 policy、无效分支、单次转发层和
  `format_version=1` legacy 路径。
- **前置条件：** task-10 passed review；installer-only escript 边界已完成，当前 `tree`/`bgate`
  plugin 行为基线保持可对照。
- **Owned-area summary：** `rebar3_reltree_badge.erl` 与 `rebar3_reltree_project.erl` 收敛为一个
  共享只读 badge facts/template/判定来源并删除另一套重复实现；`rebar3_reltree.erl` 删除
  `dispatch_tree/1`、`dispatch_bgate/1` 单次转发；`rebar3_reltree_badge.erl` 删除 `tag_policy`
  中返回相同错误的冗余分支；`rebar3_reltree_rev.erl`、`rebar3_reltree_report.erl` 删除不再需要的
  `format_version=1` legacy 分支，并同步最小直接测试。
- **关键行为边界：** 上述每项在测试与调用图证明等价后删除；保留真实 tag spelling、固定 badge
  模板、其他 badge/README 正文、双 README 顺序写和 `project.md` 的只读 badge facts。不得改变
  `tree`/`bgate` 外部行为、tree 图、revision 模式、当前 report 格式或原子/写入边界；若任何删除
  无法证明等价则停止 task-7 并请求修订，而不是保留已明确列入范围的冗余后宣告完成。
- **依赖顺序：** task-10 后执行；依赖 task-5 的统一版本事实，不依赖或重开 task-1..4 的正确实现。
- **验收摘要：** `tree` 与 `bgate` 对相同本地事实使用唯一共享只读 badge policy；重复 badge
  实现、两个 dispatch wrapper、`tag_policy` 同结果分支及 `format_version=1` legacy 分支均在
  等价证据成立后移除，规范要求的所有外部行为保持不变。

### task-8 — 完成 packaged `reltree` skill 发布工作流

- **一句话目标：** 在不复制规范的前提下，使安装后的 skill 能按 `release.md` §1、§3、§8–§11
  引导单项目及最小必要联合发布，并正确停在人工决策与授权边界。
- **前置条件：** task-7 通过审查；plugin 三命令与 installer-only escript 的最终职责已稳定。
- **Owned-area summary：** `priv/skills/reltree/SKILL.md`，必要时仅同步
  `priv/skills/reltree/agents/openai.yaml` metadata 及现有 package 静态断言；不得增加第三个文件。
- **关键行为边界：** 使用当前 profile 的 `project.md`，不硬编码拓扑；下游只按用户明确范围更新，
  兼容性/新世代/远端操作由用户决定；本地 annotated tag、门禁、完整项目检查及上游到下游顺序
  必须清楚，但 skill 不默认执行网络、push、覆盖远端 tag 或发布。只补缺失的发布流程指导，
  不复制 `release.md` 全文，不加入固定拓扑、额外 README、发布状态机或其他计划层设计。
- **依赖顺序：** task-7 后最后执行；文档只描述已经存在的最终命令面与安全边界。
- **验收摘要：** 两文件 package 能覆盖单项目发布、联合发布、badge/release commit 约束、失败与
  覆盖处理及发布后核对，同时不含规范副本、固定项目名、额外 README 或自动决策。

## Acceptance summary

- Rebar3 plugin 只提供并独立运行 `tree`、`checkvsn`、`bgate`；escript 只负责安全安装两文件
  `reltree` skill。
- runner 已证明满足的 `tree`/`bgate` 行为保持不倒退，规范要求的原子性、顺序写和本地只读边界
  均保留。
- `release.md` §1–§12 的可执行职责分别落在现有 tree/bgate、task-5 版本门禁、task-9 installer/
  resource domain、task-10 installer-only escript 最终边界和 task-8 skill 工作流中；task-7 删除已由
  证据确认的产品冗余，不扩大产品设计。
- task-6 作为 `superseded before completion` 历史保留；task-9/task-10 只拆分原批准的 §5 scope，
  不增加通用 transaction、package manager、multi-skill abstraction。task-7/task-8 必须等待
  task-10 passed review。
- 旧 `plan.md` 作为历史 workflow artifact 原样保留，不表示保留其中或产品代码中的过度设计；
  产品代码中的重复 badge policy、单次 dispatch wrapper、同结果分支和无依据 legacy 分支由
  task-7 按等价证据删除。
- 不改写其他历史 workflow artifact，不新增规范外命令、持久 cache、网络副作用或事务层。

# task-14 — 完成 packaged skill 的最小发布指导

Status: accepted

## Objective

仅更新 packaged `reltree` skill 的工作流说明与必要的最小 agent metadata，使安装后的 skill 能以简明、可执行、非重复的方式引用 `release.md` §1–§12，指导单项目和基于当前 `project.md` 的多项目人工发布；同时准确说明裸 `reltree` 安装入口、两文件包边界、plugin/escript 分工、可选安装参数和历史过度设计清理方法。不得修改或重设计任何运行时行为。

## Normative authority and reconciliation

- 产品规范唯一来源为 `release.md` §1–§12；`plan-2.md` 的 task-14 边界和本合同只负责把该规范收敛成实现范围与验收方式。
- 用户当前明确纠正优先于 `release.md` §5 中仍残留的历史命令示例：正常安装入口必须是无参数 `reltree`，不得要求 `skill` 子命令或 `--install` 参数。
- `--dest DIR` 与 `--force` 仅是可选修饰：前者显式选择 skills 父目录并在其下追加 `reltree`，后者仅在用户明确要求替换已有目标时使用。裸调用仍按 `CODEX_HOME` 后 user home 的现有目标优先级完成首次安装。
- 事实：当前 package 资源树为 `priv/skills/reltree/SKILL.md` 和 `priv/skills/reltree/agents/openai.yaml`；`rebar.config` 仅声明这两个 escript extra resource；当前 CLI 已实现裸安装并拒绝历史 `skill --install` 命令。
- 推论：task-14 只需补全资源文档，不需要改变 installer、CLI、provider、tree、checkvsn 或 bgate 的代码与测试逻辑。

## Prerequisites

- plan-2 已 accepted。
- task-10、task-11、task-12、task-13 已完成并固定当前安装入口、两文件资源边界、`project.md` 字段以及三个 plugin provider 的职责。
- 开始编辑前确认 owned paths 不含无法归属的用户改动；若有重叠且不能无损保留，停止并交回 dispatcher。

## Exact ownership

### Must change

- `priv/skills/reltree/SKILL.md`

### May change

- `priv/skills/reltree/agents/openai.yaml`，仅当其 display metadata/default prompt 必须与补全后的 skill 职责、裸安装入口或人工发布工作流保持一致时；不得在 metadata 中复制发布政策。

### Read only

- `release.md`
- `rebar.config`
- `src/rebar3_reltree.app.src`
- `src/rebar3_reltree.erl`
- `src/rebar3_reltree_cli.erl`
- `src/rebar3_reltree_skill_install.erl`
- `test/rebar3_reltree_cli_tests.erl`
- `test/rebar3_reltree_skill_install_tests.erl`
- `docs/plan/migrate-reltree-gates/plan-2.md`

除 `Must change` 与有条件的 `May change` 两个资源文件外，所有产品源、测试、配置、规范、workflow 状态和 Git 元数据均只读。

## Required skill content

### 1. 安装与包边界

- 开头直接说明首次安装运行 `reltree`，不带参数；不得展示或保留 `reltree skill --install`、`install` 子命令、位置参数或其他 alias。
- 简明说明 `--dest DIR` 和 `--force` 的可选语义，不得把任一选项写成正常安装前提。
- 说明默认目标解析为：设置 `CODEX_HOME` 时使用 `$CODEX_HOME/skills/reltree`，否则使用用户 home 下 `.codex/skills/reltree`；显式 `--dest DIR` 使用 `DIR/reltree`。
- 说明目标存在时默认失败；仅显式 `--force` 可安全替换；失败不得留下半安装或新旧混合状态。只描述既有语义，不扩展 recovery API、transaction API 或 package-manager 概念。
- 明确源码和安装结果都只有 `SKILL.md` 与 `agents/openai.yaml` 两个资源文件，保持相对位置；不打包 `release.md` 副本、README、模板、脚本或其他政策文件。
- 明确 escript 只安装 packaged skill；plugin 独立提供 `rebar3 reltree tree`、`rebar3 reltree checkvsn`、`rebar3 reltree bgate --check|--write`。不得把 provider 命令写成 escript 子命令，也不得说 plugin 依赖 skill 已安装。
- 明确安装器只做本地文件操作，无网络、Git、tag、push 或发布副作用。

### 2. 规范引用方式

- 指示执行者在发布工作开始时读取目标仓库当前 `release.md`，并按 §1–§12 执行；skill 只保留必要步骤、决策点、停止条件和命令引用，不逐段改写或嵌入规范全文。
- `src/*.app.src` 的 `vsn` 是应用版本唯一事实来源；版本等级和是否发布由用户明确决定，工具不得从 diff 自动猜测。
- 正式版本只概括为当前最高正式版本、严格下一 patch、严格下一 minor `.0`，或用户明确要求的新世代；不得跳版。预发布仅在用户明确要求时使用，基础版本必须等于 `app.src`，序号只依据本地同类 tag 递增。
- README/CI badge 交给 `bgate`：准备阶段可按需执行 `--write`，验收执行 `--check`；无 `ci.yml` 不伪造 badge，两个 README 保持一致，其他 badge 不受影响。
- `checkvsn` 仅验证本地 tag、`app.src` 和版本连续性，不承担 README/badge、网络或发布职责。

### 3. 单项目人工发布流程

以短步骤覆盖：获取必要 tag 事实并确认工作区；由用户确认是否发布及兼容性等级；按规范更新 `app.src`、固定 runtime dependency、README/迁移说明；运行 `bgate --write`（需要时）；创建 release commit 和本地 annotated tag；运行 `checkvsn`、`bgate --check` 与项目完整测试；核对 tag、版本、README 和制品一致性。所有 tag 创建/移动、远端 push 和制品发布动作必须在执行前再次取得用户明确授权。

badge release commit 不得作为缺少对应 tag 的普通 `master` 提交提前推送。尚未推送的本地 tag 可按用户要求移动或重建；远程 tag 默认不可覆盖，已公开 release/制品不得通过移动同名 tag 替换。

### 4. 多项目人工发布流程

- 先运行 `rebar3 reltree tree`，只使用当前 profile 的 `_build/<profile>/reltree/project.md` 作为当前本地项目集合、runtime dependency、upstream 和 downstream 的事实来源。
- 若报告为 `insufficient-local-data`、缺少决定发布顺序或依赖更新所需事实，立即停止并向用户说明缺失信息；不得依据目录名、历史项目列表或 §12 示例补猜。
- 只有用户明确列入范围的下游才更新；直接依赖可直接更新，间接依赖只沿当前报告证明的路径更新最小必要中间项目。普通 plugin、`project_plugins` 和 CI 工具不触发应用版本级联。
- 本地准备顺序为 upstream tag 后更新直接 downstream，再逐层继续；每层只能引用已准备的上游 tag。远端 tag/push/发布必须由用户逐项授权并按 upstream-to-downstream 拓扑顺序执行。
- 上游破坏性升级不得自动决定下游版本等级；每个项目的兼容性和目标版本都由用户分别决定。

### 5. 历史过度设计清理指导

在发布前加入一个短小的 cleanup gate，不创建新的自动状态机：

1. 检查当前 help/公开命令面、资源树、相关 diff 与文档引用，列出 wrapper、alias、重复入口、重复政策文本和额外 package resource。
2. 将每项分类为 `normative`、`necessary implementation constraint` 或 `historical only`；`necessary implementation constraint` 必须能直接证明为实现当前规范不可避免，未来扩展或实现方便不算证明。
3. 删除或合并 `historical only` 项：尤其是 `reltree skill --install`/其他安装 wrapper 或 alias、escript 版 provider 命令、通用 transaction/package-manager/multi-skill 层、额外资源文件，以及 skill 内重复的 `release.md` 政策。
4. cleanup 只移除无依据表面，不得借机改变 installer 安全语义、provider 行为、版本规则、报告格式或发布授权边界。若删除需要跨出用户当前授权范围，先报告候选项和证据并停止等待授权。

## Rejected alternatives and exclusions

- 不保留历史 `reltree skill --install` 作为兼容 alias，也不新增任何 wrapper。
- 不把 `release.md` 复制进 package，不新增 README、checklist 文件、模板、脚本或第三个 resource。
- 不新增通用发布 orchestrator、状态机、transaction/package manager、多 skill 框架、固定项目拓扑或远端自动化。
- 不修改 `release.md`；其历史命令示例由本合同中的用户纠正解决。若实现者发现除该已解决示例外的阻断性歧义，停止并建议 dispatcher 另立小型文档澄清任务。
- 不修改 CLI、installer、provider、tree/report、checkvsn、bgate、README、workflow、应用版本、依赖或测试代码。
- 不创建、移动或删除 tag，不 fetch、push、publish，不访问网络，不写真实用户 skills 目录，不安装依赖，不 stage/commit。
- `release.md` §12 仅为展示格式的非规范示例，绝不固化为真实拓扑。

## Implementation outline

1. 在 `SKILL.md` 中保留最小 frontmatter，重写正文结构：安装/职责边界 → 规范来源与 cleanup gate → 单项目流程 → 多项目流程 → 授权与停止条件 → 发布后核对。
2. 每个流程只引用执行所需命令和决策，不复制规范表格、badge URL 模板或完整条款。
3. 逐项对照 §1–§12 建立临时覆盖核对；最终文件不需要保留逐节复述，但必须能从正文定位每节的必要行为。
4. 仅在 metadata 仍错误地把 skill 描述为纯安装器或出现历史命令时，最小更新 `openai.yaml`；metadata 不承载第二份发布政策。
5. 完成静态资源边界、文本语义、安装回归和 escript archive 检查；不得因文档验收修改运行时代码或测试。

## Focused validation

### Coding self-tests（由实现 Luna 执行）

- 静态检查 `SKILL.md` 与可选 metadata：裸 `reltree`、可选 `--dest`/`--force`、默认目标优先级、两文件路径、provider/escript 分工、单/多项目流程、`insufficient-local-data`、用户授权边界和 cleanup 分类均存在。
- 负向静态检查：资源中不存在 `reltree skill --install`、escript provider 子命令、固定 §12 拓扑、自动 push/publish/remote overwrite 指令、发布规范全文副本或第三个 package resource。
- 运行 focused EUnit：`rebar3_reltree_cli_tests` 与 `rebar3_reltree_skill_install_tests`，证明裸调用、可选参数、历史命令拒绝、目标优先级、精确两文件安装、冲突/force/rollback 和 no-mixed-state 语义未回退。
- 执行 `rebar3 escriptize`，检查生成 escript archive 的 packaged resource subtree 恰好包含并保持：
  - `rebar3_reltree/priv/skills/reltree/SKILL.md`
  - `rebar3_reltree/priv/skills/reltree/agents/openai.yaml`
  且不包含该 subtree 下的第三个文件、`release.md` 或 README；从 archive 提取的两文件 bytes 必须与源码资源一致。
- 在临时目标运行生成的 escript：裸调用完成首次安装；另以 `--dest` 验证显式父目录，以已有目标验证默认冲突失败和 `--force` 完整替换。所有目标限定在测试临时目录；不得使用真实 `CODEX_HOME` 或 user home。
- 运行只读 diff whitespace/scope 检查，确认产品改动名集只含本合同实际使用的一个或两个 resource owned paths。

### Independent verification（仅由独立 `luna_runner` 执行）

在实现者自测完成后独立重复：focused CLI/installer EUnit、escriptize、archive 两文件路径与 byte-for-byte 检查、临时目录裸安装/冲突/force 检查，以及正负向 skill 文本/范围审计。runner 返回原始命令、exit、测试计数、archive entry 清单、安装目标 snapshot、写入路径和生成物清理结果；runner 不修改资源、源码或测试。该证据完成后才进入 Sol review。

## Expected diff

- 必须修改：`priv/skills/reltree/SKILL.md`。
- 可选且应保持极小：`priv/skills/reltree/agents/openai.yaml`。
- 无其他 source、test、config、README、release、workflow 或 package 文件变化。

## Completion criteria

- packaged skill 对 `release.md` §1–§12 的必要发布行为有最小、可执行、可定位的覆盖，且没有复制规范正文。
- 首次安装明确且只要求裸 `reltree`；`--dest`/`--force` 只作为可选语义；默认目标、两文件 placement、安全替换与 local-only 边界准确。
- plugin/escript 分工清楚，无 wrapper、alias、重复政策或额外 resource 被指导保留。
- 单项目和多项目流程都把版本等级、下游范围、tag、push、远端覆盖和发布动作停在用户明确授权边界；`insufficient-local-data` 必须停止，§12 示例不成为事实。
- focused self-tests 与独立 runner evidence 全部通过，archive 与安装结果都证明精确两文件边界，实际 diff 仅含 owned resource paths。

## Stop conditions

- 需要改变 CLI、installer、provider、报告、gate、测试、配置或 `release.md` 才能完成指导。
- 当前 runtime 行为与本合同所述裸安装、两文件 package 或 provider/escript 分工冲突。
- 除已由用户纠正的历史安装命令外，`release.md` 存在影响发布决定的阻断性歧义。
- 无法证明某个 wrapper、alias、重复政策或额外资源属于 `historical only`，或 cleanup 需要扩大用户授权范围。
- 发现 owned resource 中有无法归属或无法无损保留的并发用户改动。
- 验证需要网络、真实用户目录、依赖安装、远端 Git 操作或任何未授权写路径。

遇到任一条件，返回 `Clarification required`，列出准确路径/文本、规范证据、需要用户回答的问题和被阻断的结论，不自行扩大范围。

## Commit subject

`docs: complete packaged reltree release guidance`

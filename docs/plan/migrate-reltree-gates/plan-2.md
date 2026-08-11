# migrate-reltree-gates replacement plan

Goal

以 `release.md` 为唯一发布规范，在保留现有合规局部工作的前提下，完成 reltree 的本地树、版本门禁、README badge 门禁、安全技能安装和 packaged skill 发布指导；删除没有规范依据的抽象与自动化，并确保所有远端或发布动作始终由用户明确授权和执行。

Supersedes: plan-1.md

Previous task: task-9

Normative inputs

- 唯一规范输入是 dispatcher 提供并已验证的 `release.md` §1–§12 边界事实包。
- `release.md` §12 仅是示例，不得当作当前项目拓扑事实。
- 当前 `rebar3 reltree tree` 生成的 `project.md` 是联合发布关系的唯一来源；数据不足时必须报告 `insufficient-local-data`，不得猜测。

Constraints

- 工具默认仅操作本地：不查询远端、不 fetch、不 push、不发布；版本事实来自 `app.src`。
- 版本选择只允许当前正式版、严格下一 patch、下一 minor.0，或用户明确要求的新世代；不得跳版。预发布必须由用户明确要求，且基础版本与 `app.src` 相同。
- 未推送的本地 tag 可移动；远程 tag 默认不可覆盖。任何 tag、push、发布、远端覆盖、下游更新或版本等级决定均不得由工具或技能代替用户执行。
- plugin 仅提供 `tree`、`checkvsn`、`bgate`；escript 的正常安装入口仅为不带参数的 `reltree`。不得要求子命令或 install 参数，也不得增加 escript 版 tree/bgate/checkvsn 或项目管理命令。
- 保留规范要求的两文件 installer、默认冲突失败、`--force` 安全替换、失败不留混合状态、目标优先级和 local-only 边界。
- 不引入通用 transaction/package manager/multi-skill 抽象、固定拓扑、远端发布自动化、额外 release 状态机，也不把 `release.md` 整篇复制进 packaged skill。
- 不把历史实现、旧 task 合同、已有局部代码或测试结果自动升级为规范要求；本计划不声明任何测试已经通过。

Historical isolation

- 历史状态仅用于定位恢复起点：plan-1 曾 active，task-6 已在完成前 superseded，最后实际选中的旧任务是 task-9，task-9/task-10 的局部工作涉及 installer、resource、CLI 和 package。
- 未提交产品路径及其测试文件属于待审查的历史局部工作，不构成已完成、已验证或必须保留的设计。
- 新任务只能依据本计划和 `release.md` 判断保留、修正或移除；不得复制历史 task 合同，也不得由历史编号推断完成状态。

Partial-work recovery

开始 task-10 时先按 owned area 逐项核对现有未提交改动：合乎 `release.md` 且属于当前任务边界的部分可继续使用；无规范依据、跨越 plugin/escript 职责或引入过度抽象的部分必须收缩或移除。恢复不得覆盖用户无关改动；若无法区分归属、发现规范冲突或需要扩大 owned area，立即停止并交回 dispatcher 澄清。每项任务只以其独立实现、自测证据及后续独立验证证据判定完成。

Ordered follow-up tasks

## task-10 — 收敛 skill installer 与打包边界

单句目标：恢复现有 installer/resource/CLI/package 局部工作，将其收敛为只安全安装 packaged skill 两个文件的 local-only escript 能力。

前置条件：plan-2 获 dispatcher 接受；task-9 不再继续；相关未提交改动的归属可明确辨认。

Owned-area summary：`rebar.config` 中相关打包配置、skill-only escript CLI、installer、`priv/skills/reltree/SKILL.md`、`priv/skills/reltree/agents/openai.yaml` 及直接对应测试。

关键行为边界：不带参数直接执行 `reltree` 即可完成首次安装；目标始终按可选显式 `--dest`、`CODEX_HOME`、home 的优先级解析，因此裸运行在未给 `--dest` 时依次使用 `CODEX_HOME`、home。`--dest` 与 `--force` 只作为可选的显式目标覆盖/异常冲突替换选项，不得成为正常安装所需参数；只安装两个规范文件；默认冲突失败，`--force` 安全替换，任何失败不得留下混合状态；防止不安全 path/symlink 目标；不得扩展成通用事务、包管理器、多技能框架或项目管理 CLI。

顺序：先界定并收缩 CLI/package surface，再完成两文件 stage/replace/rollback/cleanup 行为，最后补齐对应局部测试与证据。

短验收摘要：escript 以裸 `reltree` 作为正常入口且可完成首次安装；可选 `--dest`/`--force`、两文件安装、目标优先级、冲突、force、失败原子性和 local-only 边界均有直接证据。

## task-11 — 清理历史局部工作的过度设计

单句目标：在继续功能任务前，对当前 partial source/test/package/config 变更执行一次独立、可审查的规范溯源与删减，使实现面只保留 `release.md` 明确要求的最小能力。

前置条件：task-10 完成并固定 installer 的公开入口、两文件资源边界和安全替换语义；当前局部变更的归属可明确辨认。

Owned-area summary：当前与本计划相关的 partial source/test/package/config 变更；只允许在已归属的现有区域内删减或合并，不得借 cleanup 扩大 owned area。

盘点与分类：逐项列出每个 abstraction、wrapper、branch、option、resource path，并依据 `release.md` 将每项分类为 `normative`、`necessary implementation constraint` 或 `historical only`；`necessary implementation constraint` 必须记录其不可避免性及与规范行为的直接关系，不能把未来扩展或实现方便当作必要性。

清理边界：删除或合并所有 `historical only`，以及仅为未来扩展或方便实现存在的内容，特别是额外 escript 项目命令、通用 transaction/package manager/multi-skill 层、固定拓扑/远端发布自动化、重复 provider/CLI 转发与无效兼容面。只保留 `release.md` 明确需要的两文件 installer、安全替换、plugin/escript 分工和 local-only 边界。

停止条件：若无法证明删减前后规范行为等价、需要扩大 owned area，或某项行为找不到规范来源，立即停止并交回 dispatcher 澄清，不得以 cleanup 名义猜测或重构相邻设计。

短验收摘要：公开命令面、调用图、资源树及 source/test diff 均无冗余；每个删除项均有针对性测试或静态证据，保留行为不倒退，且盘点分类可由 reviewer 逐项复核。

## task-12 — 完成本地 tree 与 project.md 事实报告

单句目标：使 plugin 的 `tree` 在当前 profile 内可靠生成完全基于本地证据的联合发布关系报告。

前置条件：task-11 完成，plugin/escript 边界稳定且过度设计清理已有可审查证据。

Owned-area summary：tree provider、扫描与关系判定逻辑、`_build/<profile>/reltree/project.md` 报告生成及直接对应测试。

关键行为边界：`scan_roots` 默认 `..` shallow，重复 `PATH[:deep]` 且 CLI 覆盖配置；仅识别 `rebar.config` 项目根，跳过规定目录，不跟随扫描 symlink/hardlink；local upstream 和 downstream 必须满足各自 declaration/checkout 条件，外部依赖仅声明；异常 warning 后继续；canonical 内存去重；仅报告成功后替换旧文件；revision metadata 严守 rev false/auto/true 且无网络或 tag mutation。

顺序：先固定扫描和根识别，再实现节点/边分类及异常降级，最后生成包含规定状态、版本/tag/app.vsn、plugin/tool、README/CI badge 和同步时间字段的报告。

短验收摘要：当前 profile 的唯一输出能表达完整本地证据和 `insufficient-local-data`，不猜拓扑、不触网，失败时保留旧报告。

## task-13 — 收敛 checkvsn 与 bgate 独立门禁

单句目标：完成 plugin 内彼此独立的版本连续性门禁和 README badge 检查/写入门禁。

前置条件：task-12 完成并可提供本地版本、tag、README/CI badge 事实。

Owned-area summary：checkvsn provider、bgate provider、README.md、README.zh.md 的门禁行为及直接对应测试。

关键行为边界：checkvsn 仅检查本地 tag、`app.src` 版本及允许的连续版本，不读 Actions 环境变量且不联网；bgate 不承担版本门禁，`--check` 只检查，`--write` 严格按 README.md 后 README.zh.md 写入；存在 `ci.yml` 时仅保留唯一 master CI badge 和唯一最高正式 tag release CI badge，不存在时不得伪造 badge。

顺序：先完成 checkvsn 的本地版本集合与连续性规则，再完成 bgate 的纯检查，最后加入受限的双 README 顺序写入。

短验收摘要：版本等级、预发布基础版本、跳版拒绝和两个 README 的 CI badge 规则分别由对应 provider 独立证明，且全程无网络和远端副作用。

## task-14 — 完成 packaged skill 的最小发布指导

单句目标：以引用和简明步骤覆盖 `release.md` §1–§12 所需的单项目与多项目人工发布指导，而不复制规范或增加自动发布能力。

前置条件：task-10 至 task-13 全部完成，其最终 CLI、报告字段和门禁行为可供技能准确引用。

Owned-area summary：`priv/skills/reltree/SKILL.md` 与必要的最小 agent metadata；若发现 `release.md` 自身存在阻断性歧义，只另立一个小型文档澄清任务，不在本任务重写规范。

关键行为边界：指导须以 `app.src` 和当前 `project.md` 为事实来源，覆盖允许版本、预发布、README/bgate、checkvsn、tag 可移动性、下游显式选择、`insufficient-local-data` 停止条件，以及按拓扑顺序由用户显式 push/发布；不得把 §12 示例固化为拓扑，不得自动创建 tag、push、发布、覆盖远端或替用户选择版本等级，也不得把 `release.md` 全文嵌入技能。

顺序：先建立 §1–§12 最小覆盖清单，再写单项目流程和基于当前 project.md 的多项目流程，最后逐条核对授权边界与停止条件。

短验收摘要：packaged skill 对 §1–§12 均有最小、可执行且不重复规范的指导覆盖，所有远端、下游和发布动作明确停在用户授权与执行边界。

Acceptance summary

- plugin 的公开职责严格限制为 `tree`、`checkvsn`、`bgate`，escript 严格限制为两文件 skill installer。
- tree 只生成当前 profile 的本地事实报告；关系来自声明与 checkout 证据，信息不足不猜测，报告替换具备成功门槛。
- checkvsn 和 bgate 职责独立，分别覆盖本地版本连续性与双 README badge 规则，均无网络或远端副作用。
- installer 以裸 `reltree` 完成首次安装；`--dest`/`--force` 仅为可选覆盖选项，并满足目标优先级、两文件范围、冲突/force、安全替换与失败无混合状态，且不演化为通用框架。
- 历史局部工作须经逐项规范分类与独立 cleanup 审查；公开命令面、调用图、资源树和 source/test diff 不保留无规范依据或仅面向未来扩展的冗余。
- packaged skill 以最小指导覆盖 `release.md` §1–§12，包括单项目、多项目拓扑流程和人工授权边界；§12 示例不被当作事实。
- 所有任务都需有实现者自测证据，并由独立 runner 提供验证证据后再进入 review；本 draft 不预断言现有实现或测试通过。
- 若任何任务需要固定未知拓扑、访问远端、扩大 owned area、替用户决定发布动作，或无法从本地证据得出结论，必须停止并请求 dispatcher 澄清。

Plan status: accepted

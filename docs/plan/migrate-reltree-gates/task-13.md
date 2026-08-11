# task-13 — 收敛 checkvsn 与 bgate 独立门禁

Status: accepted

Plan: `plan-2.md`

## Goal

在 Rebar3 plugin 内收敛两个互不代替的纯本地门禁：`checkvsn` 只判断
`app.src` 与本地可达 tag 的版本一致性和连续性；`bgate --check|--write` 只判断或
维护两个 README 的 CI badge。保留当前合规实现，删除或修正本任务 owned area 内任何
超出 `release.md` 的行为，不重写已经存在且足够简单的共享能力。

## Normative basis and current evidence

- 唯一产品规范是 `release.md`。版本事实、允许的连续版本和 tag 形式见
  `release.md:13-16,18-56`；README badge 模板与一致性见
  `release.md:76-107`；`bgate` 命令边界见 `release.md:237-253`；
  `checkvsn` 命令边界见 `release.md:255-272`。
- `plan-2.md:83-95` 将本任务限制为独立的 checkvsn/bgate 门禁，并要求先版本规则、
  再纯检查、最后 README 顺序写入。task-12 已在 commit ledger 中记录为通过 review。
- 当前 `rebar3_reltree_version:check/2` 已消费 `app_vsn`、`reachable_tags` 和
  `head_tags`，并已有数值分组与连续性分类（`src/rebar3_reltree_version.erl:30-69,154-185`）。
  当前 checkvsn provider 已直接复用本地 app/Git facts
  （`src/rebar3_reltree_prv_checkvsn.erl:32-65`）。
- 当前 badge 模块已经以 workflow 是否存在为第一道边界，使用本地 origin 和 merged tags，
  读取 `README.md` 后读取可选 `README.zh.md`，并按该顺序逐文件写入
  （`src/rebar3_reltree_badge.erl:11-23,59-112,134-172,285-327,519-532`）。
  这些事实只说明可复用起点，不预断言本任务已经通过。

## Preconditions

- `plan-2.md` 保持 accepted，task-12 的产品提交与 review 结论可用。
- 开始实现前确认工作树中不存在无法归属到本任务 owned paths 的重叠修改；若存在，停止并
  交回 dispatcher，不覆盖或吸收它们。
- 不读取历史 task 合同或 review 来补充产品语义；实现判断只来自本合同、`release.md` 与
  当前代码。

## Owned paths

实现者只可修改以下路径，并应优先形成测试补强或最小局部修正，而不是重写：

- `src/rebar3_reltree_version.erl`
- `src/rebar3_reltree_prv_checkvsn.erl`
- `src/rebar3_reltree_badge.erl`
- `src/rebar3_reltree_prv_bgate.erl`
- `test/rebar3_reltree_version_tests.erl`
- `test/rebar3_reltree_checkvsn_tests.erl`
- `test/rebar3_reltree_badge_tests.erl`
- `test/rebar3_reltree_provider_tests.erl`
- `test/rebar3_reltree_SUITE.erl`

不要求每个 owned path 都发生变化。没有由下面验收行为证明必要的生产代码变化不得制造。

## Read-only boundaries

除上述 owned paths 外，所有项目路径均只读。特别包括：

- `release.md`、根 `status.md`、`docs/plan/migrate-reltree-gates/plan-2.md`、
  initiative `status.md` 与 `commit.md`；
- `src/rebar3_reltree_git.erl`、`src/rebar3_reltree_config.erl`、
  `src/rebar3_reltree_request.erl`、`src/rebar3_reltree_fs.erl` 和 provider 注册模块；
- tree scanner/provider/model/report、`project.md` 生成逻辑及其测试；
- 根 `README.md`、根 `README.zh.md`、`.github/workflows/ci.yml` 和 Git refs；
- fixture helper、build/package config、escript CLI/resources 及其他测试。

测试只能在隔离 fixture 中创建或修改 README、workflow 和 Git refs；不得以本仓库真实 README、
workflow、tag 或 `_build/<profile>/reltree/project.md` 作为写入目标。若共享只读模块存在阻断性
缺陷，停止并请求拆分后续任务，不扩大 ownership。

## Inputs and outputs

### `rebar3 reltree checkvsn`

- 输入：当前项目根；唯一 `src/*.app.src` 的三段数字 `vsn`；本地 Git HEAD；当前 HEAD
  可达的本地 tags；直接指向当前 HEAD 的本地 tags。
- 成功输出：provider 成功并给出简短 passed 信息；不产生文件、缓存或 report。
- 失败输出：provider 返回有界、可诊断的 app/Git/tag/连续性错误；失败同样无写入。
- 参数面：不接受业务参数或选项；help 不读取项目事实，未知参数在事实读取前失败。

### `rebar3 reltree bgate --check|--write`

- 输入：当前项目根、互斥且恰好一个 mode、本地 `.github/workflows/ci.yml` 存在性、
  本地 Git HEAD、单一可解析 GitHub origin、HEAD 可达的本地正式 tags、`README.md` 和
  存在时的 `README.zh.md`。
- `--check` 成功输出：两个 README 的 managed CI badge 均符合规则；文件和 refs 不变。
- `--write` 成功输出：只对需要变化的 README 做逐文件安全替换；其他内容保持不变。
- 失败输出：具体 workflow/Git/origin/tag/README 路径与阶段，或具体 badge mismatch；不得用
  原始无界 Git 输出污染错误。

## Normative behavior

### A. checkvsn version gate

1. `app.src` 是应用版本唯一事实来源，且必须严格解析为非负整数三段 `X.Y.Z`。无文件、
   多文件、缺失/重复/非法 `vsn` 都失败。
2. 只识别正式 tag `X.Y.Z`、`vX.Y.Z` 与预发布 tag `X.Y.Z-rc.N`、
   `X.Y.Z-ci.N` 及其可选 `v` 前缀；其他形式和全部 `check-*` 不参与门禁。
3. `X.Y.Z` 与 `vX.Y.Z` 按同一个数值版本分组；最高正式版本按三段数值而不是字符串或 tag
   spelling 选择。历史预发布 tag 不算正式版本，不阻止同基础正式版。
4. 没有可达正式 tag 时，任何合法三段 `app.src` 版本是允许的初始版本。
5. 有最高可达正式版本 `{X,Y,Z}` 时，`app.src` 只允许：相同版本；
   `{X,Y,Z+1}`；`{X,Y+1,0}`；或 `{X+1,0,0}`。后一项表示发布者已通过修改
   `app.src` 明确选择新世代；工具不得依据 diff 猜测版本等级。任何回退、patch 跳跃、
   minor 跳跃、非零 next-minor patch、major 跳跃或非零 next-major minor/patch 都失败。
6. 直接指向当前 HEAD 的每个已识别正式/预发布 tag，其数值版本或预发布基础版本必须等于
   `app.src`。旧提交上的历史 tag 可参与最高正式版本计算，但不得被错误要求等于当前
   `app.src`。
7. 该门禁不读取 README、workflow、`project.md`、Actions/GitHub 环境变量或远端事实；不执行
   network Git 命令，不创建、移动或删除 tag，不修改任何文件。

### B. bgate badge gate

1. 两种 mode 必须显式且互斥。`bgate` 不解析或判断 `app.src` 版本连续性，也不调用
   checkvsn；它只处理 badge。
2. 若 `.github/workflows/ci.yml` 不存在，两种 mode 都只输出一行 warning 后成功；不得读取
   origin/tags/README，不得创建 workflow、README 或 badge，也不得写任何路径。
3. workflow 存在时，从本地 origin 推导 `OWNER/REPO`，并只使用 HEAD 可达的本地 tags；
   不访问网络。正式 tag 的识别和数值排序复用版本模块规则；忽略预发布与 `check-*`。
4. 每个受管 README 必须包含且只包含一个固定模板的 `master CI` badge，指向 `master`。
   没有正式 tag 时不得有受管 release badge；有正式 tag 时还必须恰有一个固定模板的
   `VERSION release CI` badge，`VERSION` 去掉可选 `v`，而 badge branch/query 中的 `TAG`
   保留仓库真实最高 tag spelling。master 在前、release 在后，中间一个空行。
5. `README.md` 必须存在且为普通可读文件；`README.zh.md` 不存在时跳过，存在时必须为普通
   可读文件并包含与英文 README 完全相同的两个 CI badge。两个文件正文可以不同。Hex、
   license、coverage 等非受管 badge、正文、换行风格和无关字节必须保留。
6. 若数值最高版本同时存在 `X.Y.Z` 与 `vX.Y.Z`：`--check` 可接受任一真实 spelling，但两个
   README 必须选择同一个 spelling，并输出明确 warning；`--write` 在任何 README 写入前失败，
   因为 `release.md` 没有授权工具替用户选择二者。不得增加配置、偏好或任意 tie-breaker。
7. `--check` 在成功和 mismatch/error 时均严格只读。它检查缺失、重复、陈旧、错误模板、
   错序、分隔错误和双 README 不一致，并返回可诊断失败。
8. `--write` 先读取并验证全部输入，再形成两个转换结果；随后严格按 `README.md`、
   `README.zh.md` 顺序，仅写有变化的文件。每个文件使用现有安全替换原语；不承诺跨文件
   transaction。第二文件失败时允许第一文件已更新，但错误必须指出第二文件及 replace 阶段，
   未成功写入的文件保持原内容。
9. `bgate` 不生成或修改任何 `project.md`，不修改 workflow、Git config/refs/tags、`app.src`
   或其他文件，不 fetch、不 push、不发布。

## Rejected alternatives

- 不合并 checkvsn 与 bgate，不让任一 provider 调用另一 provider，也不引入通用 release gate
  orchestrator。
- 不以 tree model、历史 `project.md`、Actions 环境变量或远端状态替代各命令的直接本地输入。
- 不让工具根据 diff 猜 patch/minor/new-generation，也不创建预发布编号或 tag。
- 不自动创建 `ci.yml`，不重写整个 README，不删除非受管 badge，不为两个 README 增加跨文件
  transaction。
- 不为等价最高 tag spelling 发明配置或自动优先级；数据不能唯一决定写入目标时停止。
- 不抽取通用 badge/package/transaction 框架，不为未来命令增加 wrapper、callback 层或新公开
  option；优先复用现有 version、Git command、atomic-write 和 request 边界。

## Ordered implementation steps

1. 在 `rebar3_reltree_version` 及其直接测试中逐项锁定 tag 分类、数值分组、HEAD tag 基础版本
   一致性、初始版本和四种允许连续线；只对缺失行为做最小修正。
2. 在 checkvsn provider 测试中证明参数先验验证、合法/非法项目结果、错误可诊断以及成功/失败
   均不改变文件和 refs；不得添加新的输入通道。
3. 在 badge policy 测试中先证明 `--check` 的 workflow skip、origin/tag 选择、唯一模板、双
   README parity、等价 tag 和全路径只读行为；只修正这些断言暴露的局部缺陷。
4. 最后证明 `--write` 的无 tag/有 tag 转换、内容保留、幂等性、固定双文件写序、逐文件失败
   边界和 project/workflow/ref 无副作用。保持 provider/request surface 不变。
5. 审查最终 diff：删除无规范来源的新增 abstraction/branch，确认无 task-14 或相邻域改动，
   再交付 coding self-test evidence。

## Focused tests required

- Version unit matrix：无正式 tag；same；next patch；next minor `.0`；next generation `.0.0`；
  app 低于最高；patch/minor/major 跳跃；两个非零归零字段；裸/v 等价分组；rc/ci 基础；
  `check-*` 和非法 prerelease 忽略；HEAD 正式和预发布 mismatch。
- checkvsn fixture tests：成功、gap、HEAD mismatch、无 HEAD、非法/multiple app source、help、
  未知参数；每个业务路径都比较执行前后文件与 refs snapshot，并以注入/静态证据证明不读取
  Actions 环境或网络。
- bgate unit/fixture tests：无 workflow 的单 warning/零额外读取；无正式 tag master-only；
  数值最高真实 tag 与 `v` display；预发布/check tag 忽略；check 成功和各种 mismatch 零写入；
  英中 parity；其他 badge/正文/CRLF 保留；幂等 write；等价最高 tag check/write 分岔；
  workflow/origin/tag/README 失败；英文后中文写序及第二文件失败；`project.md` sentinel、workflow、
  refs 均不变。
- Provider/CT regression：plugin 仍仅注册 tree/checkvsn/bgate；checkvsn 无 options；bgate 恰为
  `--check|--write`；tree report 行为不倒退。

## Coding self-tests

实现 worker 返回以下结果与退出状态，不在 initiative 文档中写临时日志：

- compile；
- version、checkvsn、badge、provider 的 focused EUnit suites；
- 全量 EUnit；
- 现有 Common Test suite；
- owned-path diff name check、diff whitespace check，以及真实根 README/workflow/refs/project report
  未变化的 status/snapshot 证据。

若任何 self-test 需要网络、真实 README 写入、tag mutation 或扩大 owned paths，停止，不执行该
动作，并交回 dispatcher。

## Independent verification

独立 `luna_runner` 在 implementation commit 上重复 compile、四个 focused EUnit suites、全量
EUnit、现有 CT、diff name/whitespace 检查，并单独提供以下证据包：

- version matrix 的每个允许/拒绝分支都有独立断言；
- checkvsn 在 success、continuity failure、HEAD tag mismatch、argument failure 下无文件/ref 写入，
  且没有 Actions 环境或 network Git 依赖；
- bgate no-workflow 路径只产生一条 warning 且不继续读写；check 全路径零写入；write 只按英文后
  中文顺序写 fixture README；第二文件失败边界与等价-tag stop 行为符合合同；
- committed diff 仅包含 owned paths，且根 README、workflow、refs、tree/report、installer/skill
  均无变化。

runner 只报告命令、退出状态、测试计数和快照/静态证据，不修复代码；其证据完成前不得进入
Sol code review。

## Completion criteria

- 上述 A/B 每条规范行为均由直接测试或明确静态证据覆盖，两个 provider 可独立运行。
- 所有 coding self-tests 与独立验证通过；没有网络、远端或非 owned-path 副作用。
- 最终实现复用现有模块，没有新增无规范依据的 abstraction、option 或公开命令。
- 根 README、workflow、Git refs、tree/report、installer/package/skill 均未改变。
- Sol review 无 material finding 后，本任务才可标记 passed。

## Stop conditions

- `release.md` 无法唯一决定 consequential 写入（除本合同已规定的等价 tag fail-before-write
  边界）、需要远端事实或需要替用户选择版本等级；
- 需要修改任一 read-only path、扩大公开 CLI、改变 tree/report 或相邻打包行为；
- 发现 owned path 中有无法归属的用户改动，或验证证据涉及真实仓库 mutation；
- 无法以最小局部修正保持 checkvsn/bgate 独立。

发生任一条件时停止并返回 `Clarification required`，说明具体路径、规范冲突和被阻断结论。

## Explicit exclusions

本任务不包含 task-14 packaged skill guidance，不修改 skill metadata/resources；不包含 escript
安装能力或打包配置；不修改 tree scanner、关系、revision、status 或 `project.md` 报告；不恢复
历史 release automation、兼容命令、固定拓扑或其他过度设计。

## Commit

单一实现提交，subject：

`refactor: converge reltree local gates`

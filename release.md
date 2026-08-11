# Erlang 项目版本发布规范

本文档定义 Erlang 项目的版本、依赖、tag、README badge 与发布顺序。项目集合及其依赖
关系不在本文档中硬编码，由 `rebar3 reltree tree` 根据当前本地项目生成。

目标是让各项目独立发布，同时在确实需要联合发布时依据当前项目树保持依赖关系、版本线和
发布制品一致。

## 1. 基本原则

- 每个项目独立决定是否发布以及发布版本；上游发布不会自动触发下游发布。
- 只有用户明确要求更新下游依赖时，才修改和发布下游。
- `src/*.app.src` 中的 `vsn` 是应用版本的唯一事实来源。
- 发布工具默认只操作本地状态，不查询远端、不 push、不发布制品。
- 尚未推送的本地 tag 默认允许移动或重建；远程 tag 默认不可覆盖。只有用户明确要求时，才能进入远程覆盖流程。
- 仅 README、CI、badge、文档或工具链变化时，用户没有明确要求发布则不创建 tag、不提升应用版本。

## 2. 版本号规则

版本采用三段数字 `X.Y.Z`。第一位表示人工决定的版本世代，第二位表示破坏性版本，第三位表示兼容版本。

设当前提交历史中数值最高的可达正式 tag 为 `X.Y.Z`，则 `app.src` 只允许为：

| 允许版本 | 含义 |
| --- | --- |
| `X.Y.Z` | 尚未开始下一版本，或当前正式版本已发布 |
| `X.Y.(Z+1)` | 下一次非破坏性发布 |
| `X.(Y+1).0` | 下一次破坏性发布 |
| `(X+1).0.0` | 用户明确决定进入新的版本世代 |

不得跳版本。例如从 `0.4.0` 不能直接变成 `0.4.2` 或 `0.5.1`。没有任何正式 tag 的项目可以自行设定初始 `app.src` 版本。

### 2.1 选择本次正式 tag

- 如果当前 `app.src` 对应的正式 tag 不存在，直接使用当前版本。
- 如果当前版本的正式 tag 已存在，必须先按本次代码兼容性提升 `app.src`：
  - 破坏性变更：第二位加一，第三位归零；
  - 非破坏性变更：第三位加一。
- 第一位只在用户明确决定进入新版本世代时加一，第二、三位归零。
- 兼容性由发布者明确判断，工具不得根据 diff 自动猜测。
- `X.Y.Z` 与历史形式 `vX.Y.Z` 表示同一版本；新 tag 推荐统一使用不带 `v` 的裸版本号。

### 2.2 预发布 tag

预发布不是默认流程，仅在用户明确要求时创建：

- `X.Y.Z-rc.N`
- `X.Y.Z-ci.N`
- 兼容历史的 `vX.Y.Z-rc.N`、`vX.Y.Z-ci.N`

预发布规则：

- 基础版本 `X.Y.Z` 必须等于 `app.src`；后缀不写入 `app.src`。
- 预发布 tag 不算正式版本已发布，因此不阻止后续创建同一基础版本的正式 tag。
- 只有用户要求预发布时，才从本地同类 tag 的最大序号自动选择下一个 `N`；没有时从 `1` 开始。
- `check-*` 不属于发布 tag，版本与 badge 门禁均忽略它。

## 3. 依赖关系与联合发布

执行联合发布前，运行 `rebar3 reltree tree`，并以当前 profile 生成的 `project.md` 作为本次
本地项目集合、runtime dependency、upstream 和 downstream 关系的事实来源。不得根据本文档
中的项目名称、历史拓扑或固定目录位置推断关系。`project.md` 为
`insufficient-local-data` 时，不得补猜缺失关系。

联合发布遵循以下规则：

- 用户没有要求更新下游时，不更新下游。
- 目标项目直接依赖某个新上游 tag 时，可以直接更新该依赖，不要求发布中间项目。
- 目标项目仅间接依赖该上游时，必须沿依赖链更新并发布最小必要的中间项目。
- 本地上游 tag 存在后，即可准备下游依赖修改和本地 tag。
- 远端 tag 必须按照上游到下游的拓扑顺序显式推送；工具不得自动 push。
- 上游的破坏性升级不自动决定下游的版本等级。下游保持公共 API 与行为兼容时只提升第三位；下游也向用户暴露破坏性变化时才提升第二位。
- 仅更新固定运行时依赖并发布新的依赖组合，且下游兼容性未破坏时，下游第三位加一。
- `project_plugins`、构建插件和 CI 工具不属于运行时依赖，不触发应用版本级联升级。

## 4. README 更新与 badge 策略

每次正式发布都要核对并同步更新：

- `README.md` 与现有的 `README.zh.md`；
- 当前项目版本及安装示例；
- 本次明确变化的固定依赖版本；
- 与本次发布相关的用法、兼容性和破坏性迁移说明。

如果仓库存在 `.github/workflows/ci.yml`，README 必须长期保留以下 badge：

1. 唯一的 `master CI` badge，始终指向 `master`；
2. 存在正式 tag 后，唯一的 `release CI` badge，指向数值最高的可达正式 tag。

固定模板为：

```markdown
[![master CI](https://github.com/OWNER/REPO/actions/workflows/ci.yml/badge.svg?branch=master&event=push)](https://github.com/OWNER/REPO/actions/workflows/ci.yml?query=branch%3Amaster)

[![VERSION release CI](https://github.com/OWNER/REPO/actions/workflows/ci.yml/badge.svg?branch=TAG&event=push)](https://github.com/OWNER/REPO/actions/workflows/ci.yml?query=branch%3ATAG)
```

其中：

- `VERSION` 是去掉可选 `v` 前缀后的应用版本；
- `TAG` 是仓库中真实存在的 tag 名；
- 仓库地址从本地 `origin` 推导；
- `README.md` 与现有的 `README.zh.md` 必须包含相同的 CI badge；
- 不添加 `rc/ci` badge；
- 不累计历史 release badges，只保留最高正式版本；
- Hex、许可证、覆盖率等其他 badge 不受影响；
- 没有 `ci.yml` 的仓库不添加虚假的 CI badge。

## 5. `reltree` skill 与用户级安装

`rebar3_reltree` 同时发布 Rebar3 plugin 和安装 escript。Rebar3 plugin 提供项目树、
版本门禁和 badge 门禁命令；escript 只用于把本仓库维护的 `reltree` Codex skill 安装到
用户级 skills 目录，不提供 `tree`、`checkvsn`、`bgate` 或其他项目管理命令。

skill 的可打包源码位于：

```text
priv/skills/reltree/
├── SKILL.md
└── agents/openai.yaml
```

skill 只包含自身工作流和 agent metadata，不打包发布规范副本，也不得创建额外 README。

通过本项目生成的安装 escript 安装到用户级 Codex skills 目录：

```bash
reltree skill --install
```

安装规则：

- `CODEX_HOME` 已设置时，默认安装到 `$CODEX_HOME/skills/reltree`；
- 否则安装到用户主目录下的 `.codex/skills/reltree`；
- `--dest DIR` 用于显式指定 skills 父目录，命令在其下追加 `reltree`；
- 目标已存在时默认失败，不静默覆盖；只有显式传入 `--force` 才允许替换；
- 强制替换必须使用临时目录加原子重命名、回滚或同等安全方式，失败后不得留下半安装或新旧文件混合状态；
- 安装完成后报告准确目标路径；
- 安装器只进行本地文件操作，不访问 Git 或网络，不创建、移动或推送 tag，不发布任何制品。

安装后的 skill 使用 Rebar3 plugin 提供的本地事实管理当前项目。plugin 命令独立运行，
不以用户已经安装该 skill 为前提。

## 6. reltree `project.md` 项目树参考

`rebar3_reltree` Rebar3 plugin 提供一个供 `reltree` skill 使用的本地项目树参考对象。
它只描述当前项目及其
可证明的本地上下游关系，不是通用依赖数据库，也不把正常的外部 runtime dependency 当作
项目树节点。

生成命令为：

```bash
rebar3 reltree tree
```

当前 Rebar3 profile 决定输出位置：

```text
_build/<profile>/reltree/project.md
```

### 6.1 配置与扫描范围

项目配置可以指定扫描根和外部 revision 追踪策略：

```erlang
{reltree, [
    {scan_roots, ["..", {"../workspace", deep}]},
    {rev, auto}
]}.
```

规则如下：

- `scan_roots` 中的普通字符串默认 shallow，只检查 root 自身和直接子目录；
- `{Path, deep}` 才递归检查 Path 的子目录；
- 未配置时默认 `{scan_roots, [".."]}`，其中 `..` 为 shallow；
- 命令行 `--scan-roots PATH[:deep]` 可重复指定扫描根，并覆盖配置文件中的扫描根；
- 命令行 `--rev false|auto|true` 覆盖配置文件中的 `rev`；未指定时默认 `auto`；
- root 自身包含 `rebar.config` 时也作为候选项目；
- 递归扫描只把包含 `rebar.config` 的目录视为项目根；
- 跳过 `.git`、`_build`、`_checkouts` 和 `node_modules`；不跟随扫描中的 symlink 或 hardlink；
- 显式的 `_checkouts/foo` 可以解析一次 symlink，这是 Rebar3 local checkout 的关系入口；
- 显式扫描 root 如果本身是 symlink，则 warning 并跳过。

### 6.2 项目关系

当前项目的 runtime dependency `foo` 只通过以下固定规则解析：

```text
rebar.config 声明 foo
→ 查找 _checkouts/foo
```

两者都满足时，`foo` 才是 local upstream。runtime dependency 不在 `_checkouts` 中是正常的
外部依赖：保留其配置声明，但不生成项目树节点、warning 或 missing node。

扫描到的其他项目只有在其自身同时满足以下条件时，才是当前项目的 downstream：

1. 自身 `rebar.config` 声明当前项目为 runtime dependency；
2. 自身 `_checkouts/<dependency-name>` 解析后指向当前项目。

只有 `_checkouts` 链接而没有 runtime dependency 声明时，任何方向都不建立项目树边。发现
一个合法节点后，继续按同一规则递归发现它的上下游，形成受 `scan_roots` 限制的传递闭包。

项目关系扫描分为两阶段：

1. 在内存缓存中记录 canonical project path、runtime dependency 声明、checkout 关系和发现来源；
2. 扫描完成后补充 Git HEAD/tag、`app.src`/版本、插件工具和 README/CI badge 状态，再生成节点。

缓存只存在于当前命令调用中，不写入独立缓存文件。同一个项目通过多个扫描根、checkout 名称
或传递路径发现时，以 canonical path 去重并合并关系，只扫描一次。最终无法补齐必要事实的
项目及其边不写入 `project.md`，仅输出 warning。

扫描异常（权限错误、损坏配置、不可读文件、链接入口无效等）只输出 warning，并继续扫描
其他候选；异常本身不写入 `project.md`。

### 6.3 project.md 内容与更新

生成文件是 UTF-8 Markdown，除同步时间外保持稳定排序。至少包含：

- tree status：`up-to-date`、`update-required` 或 `insufficient-local-data`；
- 当前项目和已解析 local 节点的路径/name；
- Git HEAD、可达正式 tag/version 和 `app.src`/`app.vsn`；
- runtime dependency、upstream、downstream 边；
- `project_plugins`、普通插件和 CI/tool 声明；
- README 与 CI badge 状态；
- `network_sync_at`、`local_sync_at` 和 local-only caveats。

外部依赖只作为当前节点的配置声明记录；`--rev` 只在 `false|auto|true` 规则允许时补充其
revision 信息，不创建外部项目节点。远程操作仅限只读 revision metadata lookup，禁止 fetch、
push、tag mutation、发布或覆盖本地 checkout 事实。

`project.md` 生成成功后才替换旧文件；生成失败保留旧文件，并清理本次临时文件。

### 6.4 bgate 命令

badge 门禁独立于 `project.md` 生成：

```bash
rebar3 reltree bgate --check
rebar3 reltree bgate --write
```

- `--check` 只检查 README badge；
- `--write` 更新 `README.md` 和存在时的 `README.zh.md`；
- 无 `.github/workflows/ci.yml` 时输出一行 warning 后成功结束，不新增 badge；
- 无正式 tag 时只维护唯一的 `master CI` badge；
- 保留其他 badge 和 README 正文；
- 从本地 `origin` 推导 `OWNER/REPO`，不访问网络；
- 两个 README 按固定顺序写入；不要求跨文件原子更新；失败时返回具体文件和原因；
- `bgate` 不生成或修改 `project.md`。

## 7. `checkvsn` 本地版本门禁

`rebar3_reltree` Rebar3 plugin 提供纯本地版本门禁：

```bash
rebar3 reltree checkvsn
```

该命令不得读取 GitHub Actions 环境变量，不得访问网络，只读取本地 Git 和文件系统。

门禁只负责：

- 校验 tag 与 `app.src` 版本一致；正式 tag 使用 `X.Y.Z` 或 `vX.Y.Z`，`rc/ci` tag
  使用其基础版本，`check-*` 不参与校验；
- 校验版本连续；`app.src` 必须等于最高可达正式版本，或是严格连续的下一兼容、
  下一破坏性或用户明确选择的新世代版本，不得跳版本。

README badge 不属于 `checkvsn` 的职责，由第 6.4 节的 `bgate --check|--write` 负责。

## 8. 单项目正式发布流程

1. 获取 tags，确认工作区状态并运行当前发布门禁。
2. 确认本次确实需要发布；判断代码变化属于破坏性还是非破坏性。
3. 按第 2 节规则确定 `app.src` 和目标 tag，不得跳版本。
4. 按需更新固定运行时依赖、README、安装示例和迁移说明。
5. 永久保留 `master CI`；把 `release CI` 更新为目标正式 tag。
6. 创建 release commit。
7. 在该 commit 上创建本地 annotated tag。
8. 运行 `rebar3 reltree checkvsn`、`rebar3 reltree bgate --check` 和项目完整测试。
9. 只有用户明确要求时才执行远端操作。
10. 推送时先推 tag，再推包含同一 release commit 的 `master`；也可以在一次明确的 Git 操作中同时推送两者。

发布 badge 提交不能提前作为没有对应 tag 的普通 `master` 提交推送。业务代码可以先通过 PR 合并，最终版本、release badge 和发布元数据由单独的 release commit 完成。

## 9. 多项目正式发布流程

可以在本地为所有目标项目准备提交和 tag。涉及多个项目时按依赖关系逐层发布：

```text
创建上游 tag
  → 更新直接下游依赖并创建其 tag
    → 继续下一层
```

每一层都只能引用已经按要求创建的上游 tag。只有用户明确列入本次发布范围的下游才参与发布。

## 10. 失败与覆盖处理

- 尚未推送的本地 tag 默认允许移动或重建。
- 远程 tag 默认不可覆盖；只有用户明确要求时才能进入覆盖流程。
- 无论能否查询远端，工具都不得默认 push。
- 已经公开的 Release 或制品不得通过移动同名 tag 替换。

## 11. 发布后核对

- [ ] tag 指向预期 release commit，tag 与 `app.src` 版本一致。
- [ ] 版本从最高可达正式 tag 连续升级，没有跳版本。
- [ ] 固定运行时依赖只更新了用户明确要求的项目。
- [ ] 联合发布按依赖顺序推送并验证。
- [ ] `README.md` 与现有的 `README.zh.md` 内容和 CI badge 一致。
- [ ] `master CI` 始终指向 `master`。
- [ ] `release CI` 指向最高可达正式 tag。
- [ ] 没有因为插件、CI、badge 或文档的单独变化误升应用版本。

## 12. 项目关系示例

以下内容只演示 `project.md` 可能表达的 runtime dependency 和工具声明，不是当前项目关系的
事实来源，也不参与发布判断：

```text
astranaut
├── erlando
├── lenses
└── async

erlando
├── lenses
└── async

lenses
└── async
```

```text
rebar3_erlando      普通 Rebar3 plugin；某个项目可以按需使用
rebar3_docker_ci    CI 工具；某个项目可以按需使用
```

实际关系始终由执行 `rebar3 reltree tree` 后生成的当前 `project.md` 决定。

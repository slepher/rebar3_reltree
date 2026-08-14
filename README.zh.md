[![CI](https://github.com/slepher/rebar3_reltree/actions/workflows/ci.yml/badge.svg?branch=master&event=push)](https://github.com/slepher/rebar3_reltree/actions/workflows/ci.yml?query=branch%3Amaster)

[![CI](https://github.com/slepher/rebar3_reltree/actions/workflows/release.yml/badge.svg?branch=0.2.0&event=push)](https://github.com/slepher/rebar3_reltree/actions/workflows/release.yml?query=branch%3A0.2.0)

# rebar3_reltree

[English](README.md)

`rebar3_reltree` 是一个本地优先的 Rebar3 插件，用于理解 Erlang 项目关系并准备一致的版本发布。它提供三个相互独立的命令：

- `tree` 根据本地可证明的运行时依赖关系生成 Markdown 报告。
- `checkvsn` 根据本地可达 Git tag 校验 `app.src` 版本。
- `bgate` 检查或更新项目 README 中由工具管理的 GitHub Actions badge。

仓库还提供独立的 `reltree` Codex skill 安装器。这些工具都不会 push 分支或 tag、发布制品、fetch 仓库，也不会替用户决定发布版本。

## 环境要求

- Erlang/OTP
- Rebar3
- Git，用于读取版本和仓库事实

## 安装 Rebar3 插件

在目标项目的 `rebar.config` 中加入：

```erlang
{project_plugins, [
    {rebar3_reltree, {git, "https://github.com/slepher/rebar3_reltree.git", {tag, "0.2.0"}}}
]}.
```

本地开发时也可以使用 checkout：

```text
_checkouts/rebar3_reltree -> /path/to/rebar3_reltree
```

插件与 Codex skill 相互独立：使用插件命令不要求先安装 skill。

## 0.2.0 版本

这是一个兼容性维护版本，无需迁移；除 Erlang/OTP 的 `kernel` 和 `stdlib` 应用外，
没有固定的运行时依赖。

## 项目树报告

```bash
rebar3 reltree tree
```

报告按当前 profile 写入：

```text
_build/<profile>/reltree/project.md
```

报告记录项目路径和名称、Git HEAD 与可达 tag、`app.src` 版本、运行时依赖、本地上下游、插件和工具声明、README badge 状态、同步时间，以及以下状态之一：

- `up-to-date`
- `update-required`
- `insufficient-local-data`

可在 `rebar.config` 中配置扫描：

```erlang
{reltree, [
    {scan_roots, ["..", {"../workspace", deep}]},
    {rev, auto}
]}.
```

命令行参数会覆盖配置值：

```bash
rebar3 reltree tree --scan-roots ../apps --scan-roots ../libs:deep --rev false
```

- 普通扫描根为 shallow；追加 `:deep` 才递归发现。
- 默认值为 `..` shallow 和 `rev=auto`。
- `--rev` 接受 `false`、`auto` 或 `true`。
- 扫描会跳过 `.git`、`_build`、`_checkouts` 和 `node_modules`。
- 运行时依赖必须同时声明在 `rebar.config` 中并通过 `_checkouts/<name>` 解析，才是本地上游。
- 被扫描项目必须声明当前应用为运行时依赖，且其 checkout 反向解析到当前项目，才是下游。
- 普通外部依赖只保留为声明，不成为项目树节点。

只有报告生成成功后才替换旧报告。warning 不会变成臆造的关系，`insufficient-local-data` 也不能当作完整发布拓扑。

## 版本门禁

```bash
rebar3 reltree checkvsn
```

`src/*.app.src` 是应用版本的唯一事实来源。`checkvsn` 接受与最高可达正式 tag 相同的应用版本，或以下严格连续版本之一：

- 兼容版本：`X.Y.(Z+1)`
- 破坏性版本：`X.(Y+1).0`
- 新版本世代：`(X+1).0.0`

跳版本会被拒绝。正式 tag 可以是 `X.Y.Z` 或 `vX.Y.Z`；`rc.N` 和 `ci.N` 预发布使用相同的 `app.src` 基础版本；`check-*` tag 会被忽略。该命令只读取本地文件和 Git 状态，不检查 README badge。

## README badge 门禁

```bash
rebar3 reltree bgate --write
rebar3 reltree bgate --write --tag
rebar3 reltree bgate --check
```

- `--write` 维护 `ci.yml` 中的 master badge，并移除工具管理的 release badge。
- `--write --tag` 还会把已有 `release.yml` 的顶层名称更新为 `<版本>`，并按照当前 `app.src` 版本写入 release badge。应在选择或提升版本后、创建正式 tag 前运行。
- `--check` 校验两个 workflow 名称，以及 master badge 和指向最高可达正式 tag 的 release badge。应在创建 tag 后运行。

badge 行不再添加人为可见的前置文字。GitHub 会根据 workflow 顶层 `name` 显示名称；
master workflow 使用 `master`，release workflow 使用 `<tag>`。

如果不存在 `.github/workflows/ci.yml`，命令只输出 warning，不伪造 badge。它从本地 `origin` 推导 `OWNER/REPO`，删除非受管 badge 行、保留正文，并同步维护 `README.md` 与已有的 `README.zh.md`。`--check` 遇到非受管 badge 时报错。

## 安装 Codex skill

在本仓库中直接执行 escript，无需先运行 `rebar3 escriptize`：

```bash
scripts/install_reltree.escript
```

默认目标为：

```text
$HOME/.agents/skills/reltree
```

可选参数：

```bash
scripts/install_reltree.escript --dest /path/to/skills
scripts/install_reltree.escript --force
```

`--dest DIR` 安装到 `DIR/reltree`。目标已存在时默认失败；`--force` 执行完整的安全替换。安装器只复制 `SKILL.md` 和 `agents/openai.yaml`，不执行网络、Git、tag、push 或发布操作。

## 建议的本地发布顺序

1. 检查 `git status`、本地 tag 和当前门禁。
2. 确认确实需要发布，并在不跳版本的前提下选择兼容、破坏性或新世代版本。
3. 更新 `app.src`、用户指定的固定运行时依赖和两个 README。
4. 运行 `rebar3 reltree bgate --write --tag`。
5. 创建 release commit 和本地 annotated tag。
6. 运行 `rebar3 reltree checkvsn`、`rebar3 reltree bgate --check` 和项目完整测试。
7. 只有获得单独明确授权后才 push 或发布；获得授权时，先推 tag，再推包含同一 release commit 的分支，或一次同时推送两者。

联合发布时先生成 `project.md`，只准备用户明确选择的下游，并按上游到下游的顺序处理。插件、CI 工具和纯文档变更不会触发应用版本级联。

## 开发

```bash
rebar3 compile
rebar3 eunit
rebar3 ct
```

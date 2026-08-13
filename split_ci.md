# Split CI 与 release workflow 名称管理需求

## 背景

当前 `bgate` 假定项目只存在 `.github/workflows/ci.yml`，并让 master badge
和 release badge 都指向该 workflow。GitHub 官方 badge 的左侧文字来自 workflow
顶层 `name`，因此单个 workflow 无法同时稳定显示 master 与当前 release 的不同名称。

需要将 master CI 与 release CI 拆成两个 workflow，并把每次发布前修改
`release.yml` 顶层 `name` 的动作纳入 `bgate`，避免人工修改 workflow 名称与
README release badge 时发生版本不一致。

## 目标

- master workflow 固定使用 `.github/workflows/ci.yml`，顶层名称固定为
  `name: master`。
- release workflow 使用 `.github/workflows/release.yml`，顶层名称为
  `name: release-<tag>`。
- `rebar3 reltree bgate --write --tag` 在准备发布时，根据当前应用版本确定目标
  release tag，并同步更新 `release.yml` 的 workflow 名称和 README release badge。
- master badge 与 release badge 使用 GitHub 官方按 workflow 文件路径生成的 badge，
  分别读取 master 与目标 release tag 的 CI 结果。
- 每个项目独立应用该规则。例如：
  - Erlando：`master` 与 `release-2.11.8`；
  - Astranaut：`master` 与 `release-0.13.6`。

## Workflow 合同

### Master workflow

路径固定为：

```text
.github/workflows/ci.yml
```

其顶层 workflow 名称必须为：

```yaml
name: master
```

该 workflow 负责 master 分支和 pull request 的常规集成检查。`bgate` 不根据
release tag 改写该名称。

### Release workflow

路径固定为：

```text
.github/workflows/release.yml
```

其顶层 workflow 名称必须为：

```yaml
name: release-<tag>
```

例如，准备 `2.11.8` 时名称为：

```yaml
name: release-2.11.8
```

release workflow 沿用拆分前 release CI 的运行条件：只在对应 tag 已存在并发生 tag
push 时运行，不在普通 branch push 或 pull request 上运行。tag 过滤可以继续使用既有
的通配规则，因此发布时只需更新 workflow 名称，不要求为每个版本改写触发条件。
如果项目原有 release CI 支持手工触发，手工触发也必须要求输入或选中的 ref 是一个
已经存在的 tag；不得把任意 branch ref 当作 release 运行。

`<tag>` 必须与 release badge 查询的 ref 完全相同。沿用当前
`bgate --write --tag` 的预发布规则时，目标 tag 是从 `app.src` 的 `vsn` 得到的裸
SemVer，例如 `2.11.8`。本需求不新增推断 `v2.11.8` 前缀的规则，也不创建 tag。

## `bgate` 行为

### `bgate --write`

- 继续维护唯一的 master badge，并移除工具管理的 release badge。
- master badge 必须指向 `.github/workflows/ci.yml`，并查询
  `branch=master&event=push`。
- 不修改 `release.yml` 的名称；普通 master badge 维护不应产生 release 准备副作用。
- 不创建 workflow 文件，不修改 Git refs，不访问网络。

### `bgate --write --tag`

- 继续从当前 `app.src` 读取目标版本，并按现有规则生成预期 tag。
- 要求 `.github/workflows/ci.yml` 和 `.github/workflows/release.yml` 都是可读的
  普通文件。
- 验证 master workflow 的顶层名称为 `master`。
- 将 `release.yml` 的顶层 workflow 名称更新为
  `release-<目标 tag>`。
- 只修改顶层 `name`；不得改写 job、step、trigger、注释或其他 YAML 内容。
- 同步维护 README 中的 master badge 与目标 release badge。
- 该命令发生在创建 tag 之前，只准备 release workflow 名称和 badge；它不触发
  `release.yml`。后续创建并推送目标 tag 后，GitHub 才运行 release workflow。
- 在任何输入、workflow 或 README 校验失败时，不得留下部分写入。
- 不创建 tag、commit 或 release，不执行 push，也不访问 GitHub API。

### `bgate --check`

- 继续以 HEAD 可达的最高正式 tag 作为当前 release tag；等价正式 tag 的既有拒绝
  规则保持不变。
- 验证 `ci.yml` 顶层名称严格等于 `master`。
- 当不存在正式 release tag 时，只要求 master workflow 和 master badge，不要求
  `release.yml` 已具有某个版本化名称。
- 当存在当前 release tag 时，要求 `release.yml` 存在，并验证其顶层名称严格等于
  `release-<当前 release tag>`。
- 验证 README release badge 指向 `release.yml` 并查询同一个 release tag。
- check 模式保持完全只读。

## Badge 格式

master badge 使用：

```text
https://github.com/<OWNER>/<REPO>/actions/workflows/ci.yml/badge.svg?branch=master&event=push
```

release badge 使用：

```text
https://github.com/<OWNER>/<REPO>/actions/workflows/release.yml/badge.svg?branch=<tag>&event=push
```

badge 链接也必须分别进入对应 workflow，并按同一个 master 分支或 release tag
过滤。不得使用旧式 `/workflows/<ci_name>/badge.svg` URL；workflow 名称只负责官方
badge 左侧显示，workflow 文件路径负责稳定标识 CI。

README 中工具管理的两行仍按 master 在前、release 在后排列，并保持 README.md 与
已存在的 README.zh.md 一致。无关 badge 和正文继续保留。

## 文件缺失与错误

- `.github/workflows/ci.yml` 不存在时，沿用当前行为：输出 warning、成功跳过，且不
  读取 Git/origin/tags/README/release workflow，也不产生写入。
- `ci.yml` 存在但其顶层 `name` 缺失、重复、不是标量或不等于 `master` 时，返回明确
  workflow 错误。
- release 操作需要 `release.yml` 时，该路径不存在、不是普通文件、不可读或 YAML
  顶层 `name` 无法安全定位，必须失败，不得伪造或新建 workflow。
- 错误信息必须指出 `ci.yml` 或 `release.yml` 的具体路径和失败类别。

## 写入约束

- 保留原文件换行风格和末尾换行状态。
- 对 `release.yml` 进行最小文本修改，只替换唯一的顶层 `name` 值。
- 名为 `name` 的 job 或 step 字段不得被修改。
- 若 workflow 使用当前实现无法无损处理的 YAML 形式，应明确失败，不得重新序列化
  整个文件。
- 重复执行相同命令必须幂等。

## 验收标准

- master 与 release badge 分别指向 `ci.yml` 和 `release.yml`。
- `bgate --write --tag` 能把 `name: release-2.11.7` 更新为
  `name: release-2.11.8`，并同步把 README release badge 更新到 `2.11.8`。
- 上述操作不改变 `ci.yml`，也不改变 `release.yml` 除顶层 `name` 之外的任何字节。
- `bgate --check` 能识别 workflow 名称过期、release badge tag 过期、badge 指向错误
  workflow，以及 README.md/README.zh.md 不一致。
- 缺失 `release.yml`、重复或嵌套 `name` 误判、无效 app version、等价正式 tag、任一
  目标文件不可写等失败路径均不会留下部分写入。
- 覆盖 LF、CRLF、无末尾换行、顶层 `name` 前后存在注释、job/step 中存在其他
  `name`、重复执行等回归场景。
- 现有 origin 解析、版本连续性、正式 tag 排序、无关 README 内容保留和无网络副作用
  行为不回退。

## 非目标

- 不由 `bgate` 创建 `ci.yml` 或 `release.yml`。
- 不由 `bgate` 创建 commit、tag、GitHub Release 或执行 push。
- 不让 `release.yml` 在普通 branch push 或 pull request 上运行。
- 不动态计算 GitHub Actions 的 `name` 表达式。
- 不保留所有历史 release workflow 名称；README 只展示 master 与最新 release。
- 不引入 Shields.io 或其他第三方 badge 服务。

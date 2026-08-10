# rebar3_docker_ci Implementation Completion Report

> 状态：**部分完成，不可验收**
>
> 记录时间：2026-08-10 Asia/Shanghai

## 1. 结论

当前 `rebar3_docker_ci` 工作树没有完成原 `release-version-gates` 计划，也没有完成新的
`rebar3_reltree` 项目迁移。现有代码是一次未提交、经过 review 后仍未重新验证的 partial diff。

不能将当前状态标记为 release gate 或 reltree 已实现。

## 2. 已存在的实现

旧项目工作树中已经存在以下部分：

- `priv/skills/release-version-gates/SKILL.md`
- `priv/skills/release-version-gates/agents/openai.yaml`
- `priv/skills/release-version-gates/references/release.md`
- `src/rebar3_docker_ci_prv_install_release_skill.erl`
- `src/rebar3_docker_ci_skill_install.erl`
- `rebar3_docker_ci_files:copy_tree/2`
- 安装 provider、文件复制和安装事务的部分测试

这些内容属于旧项目的 `release-version-gates` 尝试，不是 `rebar3_reltree` 的实现。

## 3. 尚未完成或不可接受的部分

### 3.1 功能缺失

- `scripts/write_project_context.escript` 不存在。
- `rebar3 docker_ci check_badges` provider 未实现/未注册。
- 没有生成 `_build/<profile>/reltree/project.md` 的 reltree 工具。
- 没有实现基于 `rebar.config`、`_checkouts` 的完整上下游项目树。
- 没有实现外部项目 `--rev false|auto|true` 模式。
- 没有实现 `network_sync_at` 和 `local_sync_at` 输出。
- 没有把实现迁移到独立项目 `rebar3_reltree`。

### 3.2 Review 未解决项

最近一次 review 返回 `changes_required`，至少包括：

- staging 名称冲突可能删除并非当前调用拥有的目录；
- symlink alias 的 source/target overlap 检测不完整；
- 只验证了 `SKILL.md`，没有验证另外两个必需 regular file；
- existing target 检查早于 staging，违反 stage-before-conflict；
- 缺少语义场景测试；
- post-review coding self-test 没有有效报告。

当前 partial diff 不得直接提交或作为独立验证通过的实现接受。

## 4. 验证证据

- 初始实现阶段曾通过 quick validation、reference 比对、compile、EUnit 和 CT；当时报告为
  EUnit 91 tests、CT 10 cases。
- review 后发生了 rework，但 coding worker 没有提供有效的最终 self-test 报告。
- review 后的 partial diff 没有完成独立验证。
- 当前工作树存在未提交的 tracked 修改和 untracked 实现/计划文件。
- 没有实现 commit，不能提供可发布 commit hash。

因此，早期测试通过不能证明当前工作树状态通过验收。

## 5. release.md 中已定义但尚未实现的 gate

最终规范 `release.md` 已定义：

- `app.src` 版本与最高可达正式 tag 的连续版本线；
- `X.Y.Z` 与 `vX.Y.Z` 等价；
- `rc/ci` 基础版本校验，忽略 `check-*`；
- 当前提交正式 tag 与 `app.src` 的一致性；
- 有 `ci.yml` 时的唯一 `master CI` badge；
- 有正式 tag 时指向最高正式 tag 的唯一 `release CI` badge；
- 中英文 README badge 一致性；
- 无 `ci.yml` 时跳过 badge 但继续执行版本/tag gate；
- 禁止默认网络、push、tag mutation 和发布动作。

这些是规范要求，不代表当前旧项目已经实现。

## 6. 下一步

下一窗口应在 `/home/slepher/project/rebar3_reltree` 中：

1. 读取本文件复制版和 `release.md`；
2. 使用项目内 `.codex/skills/local-workflow/SKILL.md` 建立正式 initiative；
3. 重新冻结 `rebar3_reltree` / `reltree` 的实现计划；
4. 以 Erlang escript 实现 local tree、checkout graph、rev modes、sync timestamps 和 badge gate；
5. 独立验证后再判断完成，不继承旧项目的未验证 partial diff。

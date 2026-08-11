# task-5 code review 1

Plan: `docs/plan/migrate-reltree-gates/plan-1.md` (`accepted`)

Task: `docs/plan/migrate-reltree-gates/task-5.md`

Reviewed commit: `85a1b8ee91476ff3bb9f3fb9c637decb78f94d7e` (`feat: add local reltree version gate`)

Verdict: changes_required

## Findings

### 1. Medium — 多个独立的版本不连续分支没有被 task-5 测试直接证明

**Evidence**

- 合同要求失败测试覆盖低于最高 formal、跳 patch、跳 minor、next minor 的 patch 非零、跳 major，
  以及 next major 的 minor/patch 非零（`docs/plan/migrate-reltree-gates/task-5.md:175-182`）。这些是
  `release.md:22-31,265-270` 的核心门禁，而不是可选强化。
- 实现分别用独立 pattern guard 决定 `next_patch`、`next_minor`、`next_major`，其他输入才落入
  `invalid`（`src/rebar3_reltree_version.erl:176-185`）；每个 guard 的维度不同，单个 patch-gap
  断言不能证明其余拒绝边界。
- `test/rebar3_reltree_version_tests.erl:74-92` 覆盖四个成功分类，但失败侧只断言
  `1.2.0 → 1.2.2` 的 patch gap、一个 HEAD prerelease mismatch 和非法 app 格式。
  `test/rebar3_reltree_checkvsn_tests.erl:16-25` 的 provider gap fixture 也只是同类 patch gap。
- 提供的 Coding Self-Test 与独立 runner 均通过，证明现有断言可重复通过；它们没有补足上述缺失
  assertion semantics。

**Smallest valid correction**

- 只在 `test/rebar3_reltree_version_tests.erl` 增加表驱动或等价聚焦断言，至少分别证明：app 低于
  highest；minor 跳级；next minor 带非零 patch；major 跳级；next major 带非零 minor 或 patch。
- 每个输入都应直接断言 `{error, {version_not_continuous, _}}`，并保留现有 same/next
  patch/minor/major 成功断言；无需增加 provider 层重复 fixture。
- 除非新增断言暴露真实实现缺陷，否则不改产品代码。由 coding worker 重跑 task-5 focused/full
  Coding Self-Tests，并由 dispatcher 提供新的 committed correction 与证据供 review 2 审查。

## Confirmed behavior and scope

- `src/rebar3_reltree.erl:25-36` 仅新增 namespaced、no-option `checkvsn` provider registration；
  `src/rebar3_reltree_prv_checkvsn.erl:14-68` 直接编排 app identity、local Git facts 与 version gate，
  没有新增 `dispatch_checkvsn` 或策略 wrapper。
- `src/rebar3_reltree_git.erl:15-46` 仅用 argv 读取本地 HEAD、reachable tags 与 HEAD tags；未引入
  remote lookup、CI env、写入或 tag mutation。
- `src/rebar3_reltree_version.erl:30-69,154-185` 按 formal 数值分组并保留裸/v spelling，允许 initial、
  same、严格 next patch/minor/major；没有自动兼容性判断或新世代 CLI option。
- reviewed scope 与合同 Must/May 集合一致：八个 supplied diff paths 均在
  `task-5.md:38-53` 内；未包含 task-6 installer/escript、task-7 badge/legacy 或 task-8 skill 范围。
- supplied evidence 完整且一致：compile 0；focused EUnit 7/0、6/0、12/0；full EUnit 126/0；
  CT 5/0；escriptize 0；fixture no-write/ref snapshot、escript command boundary 和 diff check 均通过；
  independent runner 在 reviewed commit 上复现相同结果。
- 当前仓库无 formal Git tag，合同 `task-5.md:227-233` 的 historical reachable prerelease 与等价
  裸/v 唯一真实 tag 选择 stop condition 均未触发。本 review 不决定该歧义，也不要求相关改动。

## Review boundary

本 review 未运行 Git、build、test 或 lint；结论来自已提交源码/测试的只读语义检查及用户提供的
coding/runner evidence。除 Finding 1 的最小测试补强外，无其他 material finding。

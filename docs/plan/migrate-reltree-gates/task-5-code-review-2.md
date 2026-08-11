# task-5 code review 2

Plan: `docs/plan/migrate-reltree-gates/plan-1.md` (`accepted`)

Task: `docs/plan/migrate-reltree-gates/task-5.md`

Reviewed commits: `85a1b8e` (`feat: add local reltree version gate`) + `bfd3c04`
(`fix: task-5 review 1 version continuity assertions`)

Verdict: passed

## Findings

无 material finding。

## Review 1 resolution

- Review 1 的唯一 finding 要求分别证明 app 低于 highest、minor 跳级、next minor 带非零 patch、
  major 跳级，以及 next major 带非零 minor 或 patch，并直接断言
  `{error, {version_not_continuous, _}}`
  （`docs/plan/migrate-reltree-gates/task-5-code-review-1.md:29-36`）。
- correction 在 `test/rebar3_reltree_version_tests.erl:94-105` 增加单一聚焦测试，依次使用
  `1.1.9`、`1.4.0`、`1.3.1`、`3.0.0`、`2.1.0` 对最高 formal `1.2.0` 覆盖上述五类边界，
  每项均直接断言 `version_not_continuous`。
- 原有 initial、same、next patch、next minor、next major 成功断言仍保留在
  `test/rebar3_reltree_version_tests.erl:74-79`。因此新增失败断言证明的是各独立拒绝边界，而不是
  用宽泛结果或 provider fixture 重复替代 policy semantics。
- Review 1 finding 已完整覆盖；无需进一步产品或测试修正。

## Contract, architecture, and scope confirmation

- correction 仅修改 `test/rebar3_reltree_version_tests.erl`，该路径属于 task-5 Must change
  （`docs/plan/migrate-reltree-gates/task-5.md:38-46`），没有进入 task-6 installer/escript、task-7
  badge/legacy 或 task-8 skill 范围。
- 原实现 commit `85a1b8e` 的产品逻辑未经 correction 修改；review 1 已确认 plugin-only provider、
  local argv Git facts、共享 version policy、零写入、无 CI env/网络、无自动兼容性判断、无新世代
  option，且没有新增 dispatch/strategy wrapper。
- correction 没有增加 helper、抽象层、重复 provider fixture 或产品分支；以最小表面补足 contract
  要求的 assertion semantics，符合无过度设计边界。
- supplied correction evidence 完整且一致：compile 0；version EUnit 8/0；checkvsn EUnit 6/0；
  provider EUnit 12/0；full EUnit 127/0；CT 5/0；escriptize 0；diff check 0。
- correction changed-path evidence 为唯一
  `test/rebar3_reltree_version_tests.erl`；结合原实现已通过的 fixture no-write/ref snapshot、escript
  command boundary 与 independent evidence，scope 和回归证据无 material finding。

## Stop conditions

- 当前仓库无 formal Git tag；correction 只增加 formal 连续性拒绝断言，没有引入或解释 historical
  reachable prerelease 行为。`task-5.md:227-233` 的 prerelease 与等价裸/v 唯一真实 tag 选择
  stop condition 仍未触发。

## Review boundary

本 review 未运行 Git、build、test 或 lint；结论来自 correction 后测试内容的只读语义检查及用户
提供的 committed correction/self-test evidence。

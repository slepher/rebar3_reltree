# task-10 code review 1 retrospective

## 事件

本次 review 前，Sol worker 的读取权限合同反复自相矛盾：合同要求读取本地任务、证据与工作流文件，同时禁止所有 shell/file commands。在没有其他文件读取接口的情况下，worker 无法取得 review 的决定性输入，因而多次返回 `Clarification required` 或等待至超时。

这不是产品代码问题，而是 systemic workflow/evidence-gate failure。review gate 要求 Sol 基于真实合同与证据作出语义判断，但 dispatcher 发出的权限合同阻断了这些证据的读取；重复重试同一矛盾合同不能产生有效 review，也会把基础设施失败误呈现为任务阻塞。

## 修复

Dispatcher 已通过 commit `34f108c` 更新 `.codex/skills/local-workflow/SKILL.md`，要求每个 worker 合同显式包含四个字段：

- `Allowed read paths`
- `Forbidden read paths`
- `Allowed read-only commands`
- `Forbidden mechanical commands`

skill 同时规定冲突修复规则：允许读取路径时，不得再全面禁止 worker 唯一可用的文件读取方式；应授权仅限允许路径的 `sed`、`awk`、`rg` 等只读命令。若已允许的路径仍无法读取，dispatcher 应先以明确的只读命令权限重发合同，不得先改产品范围、重新规划或将任务标记为 blocked。

该修复把“可读证据”和“禁止机械执行”拆成独立、可核验的权限维度，使 dispatcher 能在 dispatch 前发现矛盾，也使 worker 能读取决定性证据而仍不能运行 Git、build、test、lint 或其他保留给 dispatcher/runner 的命令，从合同生成和恢复路径上防止同类失败复发。

## 剩余风险

权限修复只恢复了 review gate 的可执行性，不证明 task-10 产品行为正确，也不替代缺失的独立验证。当前 review 已给出 `changes_required`，其中的产品、范围和证据问题应由后续 correction、runner evidence 与 review 2 承担；本 retrospective 不评价产品代码，也不扩展 task-10 行为。

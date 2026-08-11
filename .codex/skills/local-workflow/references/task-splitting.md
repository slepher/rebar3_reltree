# Task splitting

Completed, passed tasks are immutable. Sol may replace a not-started broad task
in the active plan with smaller tasks without a new plan only when accepted
behavior and scope remain unchanged. Keep the parent entry as superseded
history.

Apply these identifier rules:

1. Number replacements within the original root family. Splitting `task-B`
   creates `task-B.1`, `task-B.2`, and so on. Keep identifiers flat; never
   create `task-B.2.1`.
2. When splitting an existing child `task-B.i` into K replacements, keep it as
   the superseded parent, reserve `task-B.(i+1)` through `task-B.(i+K)`, and
   shift every later unmaterialized sibling upward by K before inserting the
   replacements. Rename future entries from highest to lowest.
3. For example, if `task-6.2` and planned `task-6.3` exist, splitting
   `task-6.2` into two creates replacements `task-6.3` and `task-6.4` and
   renames the former planned `task-6.3` to `task-6.5`.
4. A task is materialized once it has a task artifact, is current in status,
   has an implementation commit, or has a review. Never rename or reuse a
   materialized identifier. If a shift would cross a materialized later
   sibling, stop and request a plan revision.

If coding started but the task remains unfinished:

1. Stop implementation and recover the current diff.
2. Have Sol identify the smallest complete behavior in existing work and the
   remaining independent behaviors.
3. Revise the active plan in place to mark the old task `superseded before
   completion`, state the reason and replacement numbers, and assign existing
   work to the first replacement. Keep `Active plan` unchanged.
4. Before creating a replacement contract, have the dispatcher clear
   `Current task`, set `Phase: task_planning`, and set the exact next action to
   create the first replacement task. Validate this exceptional
   `coding | rework -> task_planning` checkpoint.
5. Preserve the old task artifact and diff. After Sol writes the first
   replacement contract, select that replacement as `Current task` and resume
   the normal `task_planning -> coding` flow.
6. Implement, self-test, commit, and review each replacement independently.

Ordered coding steps are not workflow stages or acceptance units. If a step
needs its own review, make it a task.

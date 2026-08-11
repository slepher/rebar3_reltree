# Historical isolation

Use this procedure only when a specification changed after an earlier plan was
written or recovery must distinguish current authority from historical work.

1. Derive the replacement plan from current normative inputs before consulting
   historical design detail.
2. Have the dispatcher or `luna_runner`, never Sol, extract only lineage, the
   last actually selected task, completed commit boundaries, attributable
   paths, and recoverable partial work.
3. Give Sol only that bounded historical-facts packet, never an old plan body or
   its path as readable planning input.
4. Classify each proposed public surface, invariant, failure case, and
   acceptance gate as `normative`, `necessary implementation constraint`, or
   `historical only`.
5. Omit `historical only` items. Keep a necessary implementation constraint
   only when current repository or platform evidence proves it is required for
   normative behavior; implementation convenience is not proof.
6. Record a short `Historical isolation` plan summary naming rejected old
   surfaces or requirements that could otherwise be mistaken for current scope.

Sol must not open, read, search, or receive a superseded plan, including legacy
`plan.md`, while planning, revising a plan, defining a task, selecting
continuity, or reviewing code. List each such path as a forbidden read in every
Sol contract. Do not send superseded plans or sibling defect lists to a coding
worker.

Quote only the exact historical fact needed for the current decision and label
it `historical evidence, non-normative`. Preserve attributable partial work
physically during recovery, but reassess every hunk against the current accepted
plan; preserved code does not preserve its old requirement.

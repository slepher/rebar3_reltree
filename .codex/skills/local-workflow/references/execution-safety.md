# Execution safety

Keep verification commands and effects bounded. Group related checks only when
their individual commands, exits, and artifacts remain visible. Do not wrap
validation in an unbounded shell command or clean a broad shared location.

When temporary files are needed, create a unique task-scoped directory with
`mktemp -d` using a project/task prefix, record the resolved path, operate only
inside it, and remove only artifacts created by that verification. Never use a
deterministic shared `/tmp` path across retries, recovery, or concurrent runs.

If required verification remains blocked after the appropriate approval path
is unavailable or the user declines it, record the exact command, paths,
restriction, and missing evidence in `status.md` and stop at `blocked`. A
bounded script for the user is a last-resort handoff, not a substitute for an
available approval request. Do not continue review or commit as though missing
evidence had passed.

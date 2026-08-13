# Execution safety

Keep verification commands and effects bounded. Group related checks only when
their individual commands, exits, and artifacts remain visible. Do not wrap
validation in an unbounded shell command or clean a broad shared location.

Give every command that can wait on a process, shim, archive, network, or child
tool an explicit timeout proportionate to its normal runtime. Run independent
acceptance scenarios separately so one hang identifies its exact scenario and
does not erase earlier evidence. Do not place a full matrix in one long shell
invocation merely to reduce tool calls.

Resolve toolchain executables before changing environment inputs for an isolated
test; use the resolved runtime or preserve its discovery environment. Inspect
prefixed or self-extracting artifacts with a bounded, format-aware tool and
distinguish container warnings from content failures. Treat a missing or stalled
shim as a harness defect, not a product result.

When temporary files are needed, create a unique task-scoped directory with
`mktemp -d` using a project/task prefix, record the resolved path, operate only
inside it, and remove only artifacts created by that verification. Never use a
deterministic shared `/tmp` path across retries, recovery, or concurrent runs.

After a timeout or interruption, confirm that no child command remains active,
record the last completed scenario, and minimise or repair the harness before
retrying. Do not send a fresh runner to repeat an unchanged timed-out matrix.
Reuse passed evidence tied to the same commit and diff; rerun only the failed or
invalidated scenario unless broader evidence was actually invalidated.

If required verification remains blocked after the appropriate approval path
is unavailable or the user declines it, have the dispatcher record the exact
command, paths, restriction, and missing evidence in `status.md` and stop. A
bounded script for the user is a last-resort handoff, not a substitute for an
available approval request. Do not continue review or commit as though missing
evidence had passed.

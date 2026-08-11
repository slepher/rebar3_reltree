#!/usr/bin/env python3
"""Validate local-workflow checkpoint structure without modifying it."""

from __future__ import annotations

import re
import sys
from pathlib import Path


PHASES = {
    "planning",
    "plan_review",
    "task_planning",
    "coding",
    "coding_self_test",
    "review",
    "rework",
    "optional_verification",
    "committing",
    "handoff",
    "blocked",
    "complete",
}
ACTIVE_REQUIRED = PHASES - {"planning", "plan_review", "blocked"}
TASK_REQUIRED = {
    "coding",
    "coding_self_test",
    "review",
    "rework",
    "optional_verification",
    "committing",
    "handoff",
}
REQUIRED = {
    "Goal",
    "Repository",
    "Phase",
    "Active plan",
    "Draft plan",
    "Current task",
    "Next action",
    "Blocker",
}
PLAN_RE = re.compile(r"plan-[1-9][0-9]*\.md\Z")
TASK_RE = re.compile(r"task-[1-9][0-9]*(?:\.[1-9][0-9]*)?\.md\Z")
FIELD_RE = re.compile(r"^- ([^:]+):\s*(.*)$")
PLAN_STATUS_RE = re.compile(r"^Plan status:\s*(draft|accepted)\s*$", re.MULTILINE)


def plain(value: str) -> str:
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] == "`":
        return value[1:-1].strip()
    return value


def fields_from(status: Path) -> tuple[dict[str, str], list[str]]:
    fields: dict[str, str] = {}
    errors: list[str] = []
    for number, line in enumerate(
        status.read_text(encoding="utf-8").splitlines(), 1
    ):
        match = FIELD_RE.match(line)
        if not match:
            continue
        key, value = match.groups()
        if key in fields:
            errors.append(f"status.md:{number}: duplicate field {key!r}")
        fields[key] = plain(value)
    return fields, errors


def check_artifact(
    initiative: Path,
    label: str,
    value: str,
    pattern: re.Pattern[str],
    expected_status: str | None,
    errors: list[str],
) -> None:
    if value == "none":
        return
    if not pattern.fullmatch(value) or Path(value).name != value:
        errors.append(f"{label} has an invalid local filename: {value!r}")
        return
    artifact = initiative / value
    if not artifact.is_file():
        errors.append(f"{label} does not exist: {value}")
        return
    if expected_status:
        statuses = PLAN_STATUS_RE.findall(artifact.read_text(encoding="utf-8"))
        if statuses != [expected_status]:
            errors.append(
                f"{value} must contain exactly one Plan status: {expected_status}"
            )


def validate(initiative: Path) -> list[str]:
    status = initiative / "status.md"
    if not status.is_file():
        return [f"missing {status}"]

    fields, errors = fields_from(status)
    for key in sorted(REQUIRED - fields.keys()):
        errors.append(f"status.md: missing field {key!r}")
    for key in sorted(REQUIRED & fields.keys()):
        if not fields[key]:
            errors.append(f"status.md: field {key!r} must not be empty")

    phase = fields.get("Phase", "")
    if phase not in PHASES:
        allowed = ", ".join(sorted(PHASES))
        errors.append(f"invalid Phase {phase!r}; expected one of {allowed}")

    active = fields.get("Active plan", "")
    draft = fields.get("Draft plan", "")
    task = fields.get("Current task", "")
    check_artifact(initiative, "Active plan", active, PLAN_RE, "accepted", errors)
    check_artifact(initiative, "Draft plan", draft, PLAN_RE, "draft", errors)
    check_artifact(initiative, "Current task", task, TASK_RE, None, errors)

    if active != "none" and active == draft:
        errors.append("Active plan and Draft plan must differ")
    if phase == "plan_review" and draft == "none":
        errors.append("plan_review requires a Draft plan")
    if phase != "plan_review" and draft != "none":
        errors.append(f"{phase or 'current phase'} requires Draft plan: none")
    if phase in {"planning", "plan_review"} and task != "none":
        errors.append(f"{phase} requires Current task: none")
    if phase in ACTIVE_REQUIRED and active == "none":
        errors.append(f"{phase or 'current phase'} requires an Active plan")
    if phase in TASK_REQUIRED and task == "none":
        errors.append(f"{phase} requires a Current task")
    blocker = fields.get("Blocker", "")
    next_action = fields.get("Next action", "")
    if phase == "blocked" and blocker == "none":
        errors.append("blocked requires a concrete Blocker")
    if phase in PHASES - {"blocked"} and blocker != "none":
        errors.append(f"{phase} requires Blocker: none")
    if phase in PHASES - {"complete"} and next_action == "none":
        errors.append(f"{phase or 'current phase'} requires a concrete Next action")
    if phase == "complete":
        for key in ("Draft plan", "Current task", "Blocker", "Next action"):
            if fields.get(key) != "none":
                errors.append(f"complete requires {key}: none")

    return errors


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(f"usage: {Path(argv[0]).name} INITIATIVE_DIRECTORY", file=sys.stderr)
        return 2
    initiative = Path(argv[1]).resolve()
    errors = validate(initiative)
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print(f"OK: structural checkpoint {initiative}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))

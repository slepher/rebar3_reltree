---
name: reltree
description: Guide local reltree releases from current repository facts and explicit user decisions.
---

# Reltree

Use the target repository's current local facts and explicit user instructions. Do not substitute historical project lists or a fixed topology for the generated project tree.

## Install and boundaries

For a first install, run `reltree` with no arguments. `--dest DIR` is an optional explicit skills
parent; the target is `DIR/reltree`. `--force` is an optional explicit replacement of an existing
target. Without `--dest`, a set `CODEX_HOME` selects `$CODEX_HOME/skills/reltree`; otherwise the
user home fallback is `.codex/skills/reltree`. An existing target fails by default. A forced
replacement is complete or fails without a half-installed or mixed old/new target.

The packaged source and installed result contain exactly these two files, at these relative paths:

```text
SKILL.md
agents/openai.yaml
```

There is no packaged `release.md` copy, README, template, script, or other policy resource. The
escript only installs this packaged skill and performs local file operations: no network, Git,
tag, push, or artifact publication. Its bare entry point has no provider-command subcommands.
The Rebar3 plugin independently provides `rebar3 reltree tree`, `rebar3 reltree checkvsn`, and
`rebar3 reltree bgate --check|--write`; those commands are not escript commands and do not require
that this skill already be installed.

## Source of truth and cleanup gate

At the start of release work, read the target repository's current `release.md` and apply §§1–12.
This skill keeps only the executable decisions and checks below; it does not reproduce that
specification. `src/*.app.src` `vsn` is the only application-version fact. The user decides whether
to release and the compatibility level. A formal version is the current highest formal version,
the strict next patch, the strict next minor with `.0`, or a user-directed new generation; never
jump versions. Use a prerelease only when the user asks, with the `app.src` base and a locally
incremented same-kind suffix.

Before publishing, run a small cleanup gate. Inspect current help/public commands, the packaged
resource tree, the relevant diff, documentation references, and the affected call graph. List
wrappers, aliases, duplicate entry points, duplicate policy or validation, and extra package
resources. Classify each as `normative`, `necessary implementation constraint`, or `historical
only`; the middle category needs direct proof that the current specification cannot work without
it, not merely that it helps a future extension. Remove or merge historical-only items, especially
old install wrappers/aliases, duplicated policy/validation, callback or adapter chains, caches,
transaction frameworks, future-option layers, and extra resources. Preserve normative behavior,
then recheck the changed call graph, relevant existing tests, and the packaged archive/resource
boundary. If removal crosses the user's authorization or its status is unclear, stop and report
the evidence.

## Single-project release

1. Inspect local tag facts and `git status`; run the current release checks before deciding anything.
2. Ask the user to confirm that a release is wanted and whether compatibility is patch, minor, or
   a new generation. Update `app.src`, fixed runtime dependencies, README/installation examples,
   and migration notes as required by `release.md`.
3. When needed, run `rebar3 reltree bgate --write`. Keep the master badge and, when a formal tag
   exists, the release badge correct in both README files; without `ci.yml`, do not invent a badge.
4. Create the release commit and a local annotated tag. Run `rebar3 reltree checkvsn`,
   `rebar3 reltree bgate --check`, and the project's complete tests. Verify the tag, version,
   dependency, README, and artifact results agree.

`checkvsn` validates only local tags, `app.src`, and version continuity. It does not validate
badges or perform network/release work. Do not push or publish by default. Before creating,
moving, or pushing any tag, pushing a branch, or publishing an artifact, obtain the user's explicit
authorization for that action. Local unpublished tags may be moved or rebuilt only as requested;
remote tags are not overwritten by default, and a public release/artifact is never replaced by
moving its same-name tag. Do not push a badge release commit before its corresponding tag exists.

## Multi-project release

First run `rebar3 reltree tree` and use only the current profile's
`_build/<profile>/reltree/project.md` as facts for the project set, runtime dependencies, upstreams,
and downstreams. If its status is `insufficient-local-data`, or it lacks a fact needed for order or
dependency updates, stop and ask the user; do not infer from directories, history, or examples.

Include only downstreams the user explicitly names. Update a direct dependent directly; for an
indirect dependent, follow only the report-proven path and update the minimum required intermediate
projects. Plugins, `project_plugins`, and CI tools do not trigger application-version cascades.
Prepare locally upstream-to-downstream: create the upstream tag before preparing a direct
downstream, and each layer may reference only an already prepared upstream tag. The user chooses
each project's compatibility and target version independently, including after an upstream
breaking change. Remote tag, push, and publication actions require separate user authorization
and follow the same upstream-to-downstream order. The `release.md` §12 topology is illustrative,
not repository fact.

## After-release checks

Confirm the tag points to the intended release commit and matches `app.src`; versions are
continuous; only requested runtime dependencies and downstreams changed; README badge parity and
master/release badge targets are correct; and no plugin, CI, badge, or documentation-only change
caused an accidental application-version release.

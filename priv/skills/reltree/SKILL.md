---
name: reltree
description: Manage a Rebar3 project's local dependency relationships and release readiness using repository-provided reltree commands. Use when inspecting local upstream or downstream projects, preparing a single-project or coordinated release, checking tag and app versions, or checking and updating release badges.
---

# Reltree

Use the target repository's current local facts and explicit user instructions. Do not substitute historical project lists or a fixed topology for the generated project tree.

## First install

Run `reltree` with no arguments to install this packaged skill locally. The optional `--dest DIR`
and `--force` flags select a skills parent directory and intentionally replace an existing
installation. Installation uses only the two packaged skill files and does not access the network.

## Workflow

1. Run `rebar3 reltree tree` in the target repository.
2. Read the active profile's generated `project.md` for the current local project set, runtime dependencies, upstream projects, downstream projects, versions, and warnings.
3. Treat external declarations as metadata rather than project nodes. If the tree reports `insufficient-local-data`, report the missing evidence instead of inferring relationships.
4. Run `rebar3 reltree checkvsn` to check tag and `app.src` agreement and version continuity.
5. Run `rebar3 reltree bgate --check` to check README badges. Run `rebar3 reltree bgate --write` only when the user explicitly authorizes README changes.
6. Ask the user for release scope, compatibility, version-generation, or publication decisions that local evidence cannot establish.

## Guardrails

- Use `project.md` generated for the current repository and invocation; do not hard-code project names, sibling paths, or dependency topology.
- Default to local, read-only inspection until the user authorizes a mutation.
- Do not access the network, fetch, push, publish, overwrite remote tags, or broaden downstream scope without explicit authorization.
- Do not infer compatibility, release intent, missing relationships, or remote authority.
- Keep project relationship discovery, version checks, and badge checks separate, and report the exact result of each command.

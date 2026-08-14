[![CI](https://github.com/slepher/rebar3_reltree/actions/workflows/ci.yml/badge.svg?branch=master&event=push)](https://github.com/slepher/rebar3_reltree/actions/workflows/ci.yml?query=branch%3Amaster)

[![CI](https://github.com/slepher/rebar3_reltree/actions/workflows/release.yml/badge.svg?branch=0.2.1&event=push)](https://github.com/slepher/rebar3_reltree/actions/workflows/release.yml?query=branch%3A0.2.1)

# rebar3_reltree

[中文](README.zh.md)

`rebar3_reltree` is a local-first Rebar3 plugin for understanding Erlang project relationships and preparing consistent releases. It provides four independent commands:

- `tree` builds a Markdown report from locally provable runtime-dependency relationships.
- `checkvsn` validates `app.src` versions against reachable local Git tags.
- `bgate` checks or updates the managed GitHub Actions badges in project READMEs.
- `fmt` checks erlfmt style over the default set plus the files required by `~/.agents/AGENT.md`.

The repository also ships a standalone installer for the `reltree` Codex skill. None of these tools pushes branches or tags, publishes artifacts, fetches repositories, or decides a release version for you.

## Requirements

- Erlang/OTP
- Rebar3
- Git for version and repository facts

## Install the Rebar3 plugin

Add the plugin to the target project's `rebar.config`:

```erlang
{project_plugins, [
    {rebar3_reltree, {git, "https://github.com/slepher/rebar3_reltree.git", {tag, "0.2.1"}}}
]}.
```

During local development, a checkout can be used instead:

```text
_checkouts/rebar3_reltree -> /path/to/rebar3_reltree
```

The plugin and the Codex skill are independent: plugin commands do not require the skill to be installed.

## Release 0.2.1

This is a compatibility maintenance release. It has no migration requirements and no fixed
runtime dependencies beyond the Erlang/OTP `kernel` and `stdlib` applications.

## Project tree report

```bash
rebar3 reltree tree
```

The report is written for the active profile to:

```text
_build/<profile>/reltree/project.md
```

It records project paths and names, Git HEAD and reachable tags, `app.src` versions, runtime dependencies, local upstreams and downstreams, plugin/tool declarations, README badge state, synchronization timestamps, and one of these statuses:

- `up-to-date`
- `update-required`
- `insufficient-local-data`

Configure scanning in `rebar.config`:

```erlang
{reltree, [
    {scan_roots, ["..", {"../workspace", deep}]},
    {rev, auto}
]}.
```

Command-line options override the configured values:

```bash
rebar3 reltree tree --scan-roots ../apps --scan-roots ../libs:deep --rev false
```

- A plain scan root is shallow; append `:deep` for recursive discovery.
- The defaults are `..` shallow and `rev=auto`.
- `--rev` accepts `false`, `auto`, or `true`.
- `.git`, `_build`, `_checkouts`, and `node_modules` are skipped during scanning.
- A runtime dependency is a local upstream only when it is declared in `rebar.config` and resolved through `_checkouts/<name>`.
- A scanned project is a downstream only when it declares the current application as a runtime dependency and its checkout resolves back to the current project.
- Ordinary external dependencies remain declarations; they do not become project-tree nodes.

The report is replaced only after successful generation. Warnings do not become invented relationships, and `insufficient-local-data` must not be treated as a complete release topology.

## Version gate

```bash
rebar3 reltree checkvsn
```

`src/*.app.src` is the application-version source of truth. `checkvsn` accepts an application version equal to the highest reachable formal tag or one of the strict next versions:

- patch: `X.Y.(Z+1)`
- minor: `X.(Y+1).0`
- new generation: `(X+1).0.0`

It rejects skipped versions. Formal tags may be `X.Y.Z` or `vX.Y.Z`. `rc.N` and `ci.N` prereleases use the same `app.src` base version, while `check-*` tags are ignored. The command reads only local files and Git state; it does not validate README badges.

## Formatting check

```bash
rebar3 reltree fmt --check
```

This proxies `rebar3 fmt --check` over the erlfmt default set and the additional files required by `~/.agents/AGENT.md`:

- `*.escript` outside `.git`, `_build`, `_checkouts`, `deps`, and `node_modules`
- `rebar.config.script`

The command requires the erlfmt plugin (`rebar3 fmt`). It never writes files: `--write` is intentionally not supported, because formatting should be an explicit action. Format with `rebar3 fmt -w <file>` yourself.

## README badge gate

```bash
rebar3 reltree bgate --write
rebar3 reltree bgate --write --tag
rebar3 reltree bgate --check
```

- `--write` maintains the master badge in `ci.yml` and removes managed release badges.
- `--write --tag` also updates the top-level name of the existing `release.yml` to `<version>` and writes its badge for the current `app.src` version. Use it after selecting or increasing the version and before creating the formal tag.
- `--check` verifies both workflow names and the master/release badges for the highest reachable formal tag. Use it after tagging.

The badge lines contain no manually added display label. GitHub derives the visible label
from the workflow's top-level `name`; the master workflow is named `master` and the release
workflow is named `<tag>`.

When `.github/workflows/ci.yml` is absent, the command emits a warning and does not invent badges. It derives `OWNER/REPO` from the local `origin`, removes badge lines it does not manage, preserves prose, and keeps `README.md` and an existing `README.zh.md` aligned. `--check` fails when a README still contains a badge that reltree does not manage.

## Install the Codex skill

From this repository, run the executable escript directly:

```bash
scripts/install_reltree.escript
```

The default target is:

```text
$HOME/.agents/skills/reltree
```

Optional controls:

```bash
scripts/install_reltree.escript --dest /path/to/skills
scripts/install_reltree.escript --force
```

`--dest DIR` installs to `DIR/reltree`. Existing targets fail by default; `--force` performs a complete safe replacement. The installer copies exactly `SKILL.md` and `agents/openai.yaml` and performs no network, Git, tag, push, or publication operation.

## Suggested local release sequence

1. Inspect `git status`, local tags, and current gates.
2. Confirm that a release is wanted and select the compatible, breaking, or new-generation version without skipping.
3. Update `app.src`, requested fixed runtime dependencies, and both READMEs.
4. Run `rebar3 reltree bgate --write --tag`.
5. Create the release commit and a local annotated tag.
6. Run `rebar3 reltree checkvsn`, `rebar3 reltree bgate --check`, and the project's complete tests.
7. Push or publish only after separate explicit authorization; when authorized, push the tag before the branch containing the same release commit, or push both together.

For multi-project releases, generate `project.md` first and prepare only explicitly selected downstreams, from upstream to downstream. Plugins, CI tools, and documentation-only changes do not trigger application-version cascades.

## Development

```bash
rebar3 compile
rebar3 eunit
rebar3 ct
```

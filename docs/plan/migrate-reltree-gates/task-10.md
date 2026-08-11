# plan-2 / task-10 — 收敛 skill installer 与打包边界

## Objective/normative

Make bare `reltree` the zero-argument first-install command. Installation is local-files-only, installs exactly the two packaged leaf artifacts, and is atomic from the user's perspective. Keep plugin entry behavior unchanged. The escript must not expose `tree`, `checkvsn`, or `bgate`. `--dest` and `--force`, if retained, are optional overrides rather than required inputs.

Normative authority, in order, is: this task's user-frozen behavior; accepted `plan-2.md:19-25,39-51,111-120`; and the destination, two-file, safe replacement, and local-only rules in `release.md` §5. The historical `reltree skill --install` example at `release.md:125-129` is superseded by the user-frozen zero-argument entry and `plan-2.md:22,47,116`; it is not a compatibility surface. Current partial source/config/test/package work is historical evidence, non-normative, and retains no design merely because it exists.

## Prerequisites

- `plan-2.md` is accepted, initiative status selects task-10, task-9 is no longer continued, and the listed partial work is attributable to task-10.
- Confirm the packaged leaf source files exist before changing installer flow; do not read any other task contract to recover behavior.
- Preserve existing plugin invocation and provider registration contracts.
- All write-bearing tests must use test-owned temporary roots, never real `CODEX_HOME`, real home, Git, or network state.

## Exact owned paths

### Must change

- `src/rebar3_reltree_cli.erl`: route bare `reltree` to installation; reject unsupported escript commands, including `tree`, `checkvsn`, and `bgate`.
- `src/rebar3_reltree_skill_install.erl`: resolve destination, preflight sources/conflicts, stage a complete install, then safely publish or replace with rollback.
- `test/rebar3_reltree_cli_tests.erl`: cover zero-argument installation and escript command boundaries.
- `test/rebar3_reltree_skill_install_tests.erl`: cover destination priority, two-leaf scope, conflicts, atomic replacement, and failure cleanup.

### Bounded May change

- `rebar.config`: only if archive evidence requires a minimal change so `code:priv_dir(rebar3_reltree)` exposes exactly the two skill leaves below; do not alter providers, dependencies, or unrelated build configuration.
- `priv/skills/reltree/SKILL.md` and `priv/skills/reltree/agents/openai.yaml`: only if directly required for the two leaves to remain valid and loadable packaged resources. Task-14 owns complete release guidance; do not expand, rewrite, or generally clean that content here.
- Refactor private functions inside the two owned Erlang modules when required for linear preflight/stage/publish flow.
- Add test-local fixtures/helpers inside the two owned test files.
- Retain `--dest` for explicit destination selection and `--force` for intentional replacement, but neither may become required.

Do not create a third package leaf, README, release-specification copy, manifest, dependency, or new source/test module.

## Read only

- `docs/plan/migrate-reltree-gates/plan-2.md`, `release.md`, root `status.md`, and initiative `status.md`.
- All paths outside the seven exact owned paths above.
- Plugin provider modules and plugin entry wiring.
- The task-11 cleanup boundary described only in accepted `plan-2.md:53-67`, including cleanup of cross-area over-design.

Do not read any other `task-*.md`, `plan-1.md`, or legacy `plan.md`.

## Reuse/rejected

- Reuse existing argument parsing, filesystem helpers, packaged-resource lookup, and test fixture conventions where they satisfy these invariants.
- Reuse standard Erlang/OTP file and directory primitives; do not add dependencies.
- Reuse one authoritative destination resolver (preferably in the installer) rather than retaining separate CLI and installer precedence implementations.
- Reuse the current same-parent stage/backup/rename/rollback skeleton only after each branch satisfies this contract. Any deterministic file-failure seam must be private/test-only and limited to representative rollback-boundary tests; it is not a public transaction API. Production exports remain minimal: the installer entry and destination resolver only, with no exported fault map/function or unused formatter surface.
- Reject network fetches, remote archives, generated downloads, or shell-based installers.
- Reject installing parent bundles, unrelated skills, or more than the two leaf artifacts.
- Reject in-place force overwrites that can expose mixed old/new content.
- Reject broad CLI redesign, plugin-entry changes, and task-11 cleanup.
- Reject `skill --install` as an alias, recursive directory copying, generic package-manager/multi-skill/transaction frameworks, cross-device copy fallback, and any source supported only by historical tests.

## Shapes

- CLI input: `reltree [--dest PATH] [--force]`, with no positional command required. Both option orders are accepted; duplicate options, empty/missing `--dest`, `--force=...`, positionals, subcommands, and unknown options are usage errors.
- Destination priority: explicit `--dest` > `CODEX_HOME`-derived target > user-home-derived target.
- Exact targets are `abs(--dest)/reltree`, otherwise `abs(CODEX_HOME)/skills/reltree`, otherwise `abs(home)/.codex/skills/reltree`. Once a higher-priority source is selected, lower-priority sources are not read. Empty/invalid selected values fail; they do not silently fall back.
- Install set: exactly:
  - `priv/skills/reltree/SKILL.md`
  - `priv/skills/reltree/agents/openai.yaml`
- Runtime install layout preserves the relative leaf shape under the resolved reltree skill destination.
- Help input is only `--help` or `-h`; it exits `0`, is read-only, and shows `reltree [--dest DIR] [--force]` without project commands.
- Success exits `0` and reports the unique accurate absolute target. Usage errors exit `2` without package lookup or writes. Runtime/install failures exit `1`.
- Installer success is `{ok, AbsTarget}`. Every expected failure has the equivalent of `{error, {install, Phase, ExactPathOrSource, Reason}}`; avoid exceptions for expected validation failures.

## Invariants

- Bare `reltree` initiates first installation without parameters.
- Explicit `--dest` always wins; otherwise `CODEX_HOME` wins over home fallback.
- Exactly two leaf files are installed; no directory-wide copying.
- Source, stage, and successful target have the exact entry set `SKILL.md`, `agents/`, and `agents/openai.yaml`; installed bytes equal packaged bytes.
- Both source and stage leaves are regular files, never symlinks. Required directories are actual directories with exact case-sensitive names. Hardlink-count rejection is not a product requirement for this task.
- Existing destination conflicts fail by default before destination mutation.
- `--force` publishes only after the complete replacement has been staged and validated.
- Any failure leaves either the previous complete install or no install, never a mixed tree.
- The installer does not follow a target symlink. Default mode treats any target entry type as a conflict; force renames/replaces only the link entry and never mutates its referent.
- Canonical source, parent, target, stage, and backup locations/identities do not overlap as equal or ancestor/descendant paths. Stage and backup are unique direct siblings under the resolved parent and cannot escape through `..`, symlink resolution, or path overlap.
- Sources come only from locally packaged files.
- The escript does not provide `tree`, `checkvsn`, or `bgate`.
- Plugin entry behavior does not change.

## Error/write boundaries

- Validate arguments, destination value, exact source shape, regular-file/symlink safety, path confinement/overlap, and existing parent type before creating package-derived files.
- Writes are limited to missing directories on the resolved parent path, a unique stage/backup sibling under that parent, and the resolved `reltree` target. Existing parent contents are never removed.
- On non-force conflict, do not create, truncate, rename, or remove destination content.
- On force, preserve the prior destination until the staged replacement is complete; publish via bounded rename/swap steps.
- If publish fails after preserving the prior install, restore it and remove incomplete staging/replacement artifacts.
- Cleanup failure must be reported with the primary failure; it must not be presented as success.
- Cleanup and rollback use lstat/read-link-info semantics, recurse only into confirmed owned directories, and unlink symlink entries without traversing referents.
- At every return point the authoritative target is absent, the complete old install, or the complete new install. If rollback/cleanup itself fails, preserve the most complete recoverable target/backup artifact, report every relevant path and reason, and do not continue destructive cleanup or report success.
- No code path invokes Git, network, shell, tag, README mutation, or publishing APIs.
- Never follow this task into edits outside owned paths.

## Pseudocode

```text
main(args):
  opts = parse_optional_dest_and_force(args)
  reject positional commands and unknown options
  parent = explicit_dest_parent() ?? codex_home_skills_parent() ?? user_home_skills_parent()
  source = packaged_priv_dir() + "/skills/reltree"
  install(source, parent, opts.force)

install(source, parent, force):
  target = parent + "/reltree"
  validate exact source directories and two regular non-symlink leaves; read bytes
  canonicalize/lstat source, parent, target; reject unsafe links and overlap before writes
  ensure missing parent directories without following unsafe links

  stage = unique_direct_sibling(parent)
  create_stage_layout(stage)
  write exactly two exclusive regular leaves from packaged bytes
  re-read metadata, exact entries, and bytes; reject link/identity mismatch

  lstat target again
  if target absent:
    rename(stage, target) or clean stage and fail with path/reason
  else if not force:
    clean stage; return conflict without target mutation
  else:
    backup = unique_direct_sibling(parent)
    rename(target entry, backup) without following it
    try rename(stage, target)
      success -> remove backup; return success
      failure -> restore backup to target; clean stage; return replace/rollback error
    if rollback or cleanup fails, preserve complete recoverable artifacts and report paths/reasons
```

## Tests

### Success boundary

- Bare CLI invocation installs successfully with no required parameters.
- Explicit `--dest` receives exactly the two expected leaves with expected contents/layout.
- With no `--dest`, `CODEX_HOME` is selected; without it, home fallback is selected.
- Each precedence case proves lower-priority accessors are not read; paths with spaces/Unicode remain accurate.
- `--force` replaces a complete prior install with the complete staged version.
- Built-escript/archive inspection proves its packaged skill subtree has exactly the two expected leaves and that installed bytes match them.

### Failure boundary

- Existing destination without `--force` returns a conflict and leaves all prior bytes unchanged.
- Missing/unreadable packaged leaf fails before destination publication.
- Missing, extra, malformed, unreadable, or symlink packaged leaves fail before destination publication. Hardlink-count rejection is neither required nor accepted as a task-10 feature.
- Through one private/test-only deterministic seam, cover a small representative failure set: one failure while staging before publication, one replacement-publication failure after preserving the old target that exercises successful rollback, and, only if needed to prove the observable recovery boundary, one rollback or cleanup failure. Each assertion proves an absent/full-old/full-new target, never mixed bytes; any retained recoverable artifact is exact and reported. Do not enumerate every open/write/close/rename/cleanup point or expose a production fault/transaction API.
- Existing directory/file/symlink targets without force return conflict and leave prior bytes/identity unchanged.
- Unknown/duplicate/missing-value options or positional commands return usage error with reason and no package lookup or installer writes.

### Scope boundary

- Assert exactly two leaves are copied; unrelated packaged files are absent.
- Assert local packaged sources are used and no network/shell path is invoked.
- Assert escript `tree`, `checkvsn`, and `bgate` are rejected/unavailable.
- Assert `skill --install` is rejected, its rejection output does not advertise that legacy command, and help exposes only the direct installer surface. Rejections for `tree`, `checkvsn`, and `bgate` likewise must not advertise any project-command escript surface.
- Reject source/agents/leaf symlinks, non-directory components, direct/`..`/symlink-resolved source-parent-target overlap, and unsafe stage/backup escape. External symlink referent bytes/entries remain unchanged. Do not add hardlink-count policy or a generic path/transaction framework.
- Assert plugin entry implementation is unchanged; existing provider tests are read-only evidence, not task-owned tests.

## Coding Self-Tests

The coding worker runs and reports command, exit, test count, and relevant filesystem assertions; Sol does not execute them:

1. `rebar3 compile`
2. `rebar3 eunit --module=rebar3_reltree_skill_install_tests`
3. `rebar3 eunit --module=rebar3_reltree_cli_tests`
4. `rebar3 eunit`
5. `rebar3 escriptize`
6. In one test-owned temporary root, set temporary `CODEX_HOME` and `HOME`, execute `_build/default/bin/reltree` with zero argv, and assert exit `0`, exact target/layout/bytes; then prove default conflict, explicit `--force`, explicit `--dest`, and both option orders. Never invoke a path that can fall through to a real user directory.
7. Against the built escript, run `--help`, `tree`, `checkvsn`, `bgate`, and `skill --install`; assert specified exits/output and no writes outside the temporary root.
8. Inspect the built escript/archive skill subtree and prove exact entry set and bytes; repository-source inspection alone is insufficient.

Because force replacement and link/path handling are high-risk boundaries, the dispatcher should assign a separate `luna_runner` to repeat focused acceptance evidence after the implementation commit. Independent verification commands and execution belong to that runner, not Sol.

## Expected diff

- Small CLI dispatch simplification centered on zero-argument install.
- Installer rewritten or tightened around explicit preflight, exact leaf list, staging, atomic publish, and rollback.
- Packaging metadata changes only if built-archive evidence requires the smallest exact-two-leaf correction.
- Focused unit tests expand around success, failure atomicity, and scope boundaries.
- Packaged leaf content normally remains unchanged; any edit requires direct loader/metadata evidence and must not pre-implement task-14 guidance.
- No product changes outside the seven owned paths.

## Stop conditions

- Stop if satisfying the contract requires changing plugin entry code or any unowned path.
- Stop if the two packaged leaves cannot be made available through `rebar.config` alone.
- Stop if destination semantics conflict with an accepted public contract not editable in owned paths.
- Stop if safe replace/rollback cannot be tested deterministically with existing test seams without cross-area redesign.
- Stop on any requirement to add network access, dependencies, or task-11 cleanup.
- Stop if a partial hunk cannot be distinguished from unrelated user work, if normative regular-file/symlink or canonical-overlap safety cannot be proved with current OTP/filesystem capabilities, or if a secure fix requires a generic transaction/package layer or cross-device semantics.
- Stop if rollback/cleanup artifact semantics or symlink handling reveal consequential ambiguity that changes visible behavior.
- Stop when extra historical abstractions/options/resources cannot be proved or removed within normative installer/CLI/package behavior; report them for task-11 instead of expanding into general cleanup. Task-14 release guidance is also excluded.

On stop, return `Clarification required` with exact path/symbol, evidence, required decision, and blocked acceptance boundary.

## Completion criteria

- Success, failure, and security/scope groups each directly prove their named acceptance boundary.
- Built escript evidence proves zero-argument first install, optional destination/force, exact two-leaf archive/install, default conflict, complete force replacement, no mixed target across the representative failure/rollback boundary, path/link/overlap confinement, and local-only responsibility.
- The diff contains only exact owned paths; every bounded-May-change path has direct necessity evidence.
- No task-11 cleanup or task-14 release guidance is absorbed.

## Commit subject

`feat: install packaged reltree skill safely`

# task-10 code review 1

Reviewed commit: `b272304`

Reviewed scope: `priv/skills/reltree/SKILL.md`, `priv/skills/reltree/agents/openai.yaml`, `src/rebar3_reltree_cli.erl`, `src/rebar3_reltree_skill_install.erl`, `test/rebar3_reltree_cli_tests.erl`, and `test/rebar3_reltree_skill_install_tests.erl`. Dispatcher reports this was the exact changed and staged scope; plugin paths were unchanged.

Evidence: accepted `plan-2.md`, `task-10.md`, `release.md` §5, current phase/identity status, the six resulting files, and dispatcher-supplied coding evidence (focused EUnit 8/8, compile, escriptize, absolute-OTP bare-install smoke with exactly two leaves, and diff check all exit 0). The asdf-shebang smoke failure is environmental because the isolated home lacked the shim target; the absolute OTP invocation is valid evidence for the built escript payload. No independent runner-authored verification packet was supplied.

## Findings

1. **High — rejected legacy command is still advertised.** `src/rebar3_reltree_cli.erl:145-147` rejects a positional command but tells the user to use `skill --install`, although `task-10.md:7,54,158` explicitly removes that compatibility surface and requires bare `reltree`. `test/rebar3_reltree_cli_tests.erl:20-27` checks only `unknown command`, so it gives false confidence while missing the contradictory instruction. Smallest correction: replace the suffix with guidance to run bare `reltree` or `reltree --help`, and assert that rejection output contains neither `skill --install` nor any `tree`/`checkvsn`/`bgate` escript surface.

2. **High — task-14 release guidance leaked into task-10 packaged resources.** Both bounded-May-change resource paths are in the commit, yet the supplied evidence establishes packaging/installability only, not a need to change their guidance. `priv/skills/reltree/SKILL.md:16-31` already defines the tree/checkvsn/bgate release workflow and authorization guardrails, while `priv/skills/reltree/agents/openai.yaml:4` prompts release-readiness use. That is the guidance work reserved to task-14 by `plan-2.md:97-109` and excluded by `task-10.md:28,183,195,204`. Smallest correction: retain only the minimal valid/loadable resource content needed for this task (including the bare-install statement if required), restore/remove the release-workflow and release-readiness prompt changes, and defer their final wording to task-14.

3. **Medium — a test-control transaction surface is exported as production API without normative need.** `src/rebar3_reltree_skill_install.erl:5,45-64,345-371,618-634` publicly exports `install/4` and accepts arbitrary failure maps or two-/three-argument rename functions; `format_error/1` at lines 639-644 is also exported but unused by the reviewed CLI. The current normative inputs require a two-file atomic installer, not a public fault-injection/transaction API; `task-10.md:49` permits only a test-only deterministic seam. Smallest correction: keep the production API at the minimum (`install/3` and the destination resolver), expose any necessary fault seam only in test builds, and remove the unused formatter export/function unless a reviewed production caller requires it.

4. **Medium — the frozen task contract itself contains non-normative security/test expansion and should not drive more implementation.** Hardlink-count rejection and exhaustive named injection points in `task-10.md:75,148-149,159` are not required by `plan-2.md:19-25,39-51,111-120` or `release.md:109-142`; the implementation does not in fact check `#file_info.links` in `read_regular/1` (`src/rebar3_reltree_skill_install.erl:460-468`). Adding more machinery merely to satisfy those historical assertions would deepen overdesign. Smallest correction: dispatcher should narrow the task acceptance text to the normative symlink/path confinement and observable atomicity/no-mixed-state behavior, then require a small representative failure set rather than a public named-failure framework. Do not add hardlink framework code as this review correction.

5. **Medium — completion evidence is incomplete.** The supplied 8/8 focused EUnit and bare first-install smoke do not establish optional force replacement, default conflict, destination precedence, rejected built-escript surfaces, or rollback/no-mixed-state behavior; no independent `luna_runner` packet was supplied as required by `task-10.md:175,202`. Smallest correction: after findings 1-4 are resolved and the contract is narrowed, obtain independent runner evidence for the remaining normative acceptance boundaries before review 2.

## Correction blueprint

1. Remove the legacy CLI recommendation and strengthen its focused assertion.
2. Revert/defer task-14 resource guidance while preserving exactly two loadable leaves.
3. Privatize the test seam and remove unused public surface.
4. Narrow the non-normative task assertions instead of implementing additional framework behavior.
5. Obtain an independent evidence packet covering the corrected normative boundary.

Verdict: changes_required

Continuity recommendation: reuse this Sol reviewer for review 2; the decisive contract/code mappings are retained, and the correction should remain bounded to the same six paths plus dispatcher-owned contract clarification.

## Caveats

- The review used the dispatcher-supplied exact-scope statement because Git commands were forbidden.
- No test, build, lint, Git, network, or independent-verification command was run by Sol.

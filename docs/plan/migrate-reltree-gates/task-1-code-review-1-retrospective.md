# task-1 code review 1 retrospective

## Outcome

Review verdict: `changes_required`.

No reusable local-workflow skill gap was found. The frozen contract already
specified both rejected behaviors and required behavioral tests; correction
belongs in implementation and verification coverage, not in the plan,
contract, or workflow skill.

## Finding 1 — provider loses duplicate top-level configuration evidence

- Prevention that already existed: `task-1.md:119-128` requires the provider
  to read evaluated configuration and rejects duplicate top-level `reltree`
  entries; `task-1.md:210-211,216-222` requires adapter parity and the duplicate
  failure scenario.
- Why it escaped: the implementation reused the shared normalizer only after
  `rebar_state:get/3` had selected one `reltree` value
  (`src/rebar3_reltree_prv_tree.erl:42-60`). The provider tests construct state
  with one top-level entry and therefore never expose the information-loss
  boundary (`test/rebar3_reltree_provider_tests.erl:35-46`). The supplied EUnit
  and command packets confirm those tests passed, but contain no duplicate
  provider-config scenario.
- Recurrence prevention: implementation must preserve the complete evaluated
  configuration through shared extraction. Verification must include the
  provider-boundary duplicate scenario and compare its structured result with
  the escript/config extractor result.
- Correction owner: implementation first; coding self-test and independent
  verification must then exercise the corrected boundary.

## Finding 2 — configured root origin is lost before path validation

- Prevention that already existed: `task-1.md:124-128,130-148,177-179`
  distinguishes malformed configuration from invalid CLI options and requires
  actionable field/value errors; `task-1.md:214-220` requires malformed
  relevant config coverage.
- Why it escaped: root syntax is split between `configured_roots/1` and a
  shared `normalize_roots/2`, but the first stage accepts empty lists and the
  second no longer knows whether a root came from configuration or CLI
  (`src/rebar3_reltree_request.erl:234-293`). Existing request tests cover a bad
  configured tuple but not an empty configured string
  (`test/rebar3_reltree_request_tests.erl:54-62`). The broad passing EUnit gate
  therefore did not demonstrate this frozen boundary case.
- Recurrence prevention: implementation must validate configured paths before
  origin is erased. Verification must assert the structured config error for
  an empty configured path and retain the no-write outcome.
- Correction owner: implementation and focused regression verification.

## Workflow decision

The contract and local workflow already require frozen failure scenarios,
adapter parity, exact error behavior, coding self-tests, and independent
verification. The gap was implementation/test-case coverage, not a missing
workflow rule. Do not create a skill-change artifact or edit the local skill.

# task-1 code review 1

## Verdict

`changes_required`

## Findings

### 1. Medium — the provider boundary cannot reject duplicate top-level `reltree` configuration

Evidence: the frozen contract requires a duplicate top-level `reltree` entry to
be an error (`task-1.md:119-128`, especially lines 124-126). The escript keeps
the complete consulted term list and passes it to `extract_config/1`
(`src/rebar3_reltree_cli.erl:70-81`), where duplicates are detected
(`src/rebar3_reltree_request.erl:17-37`). In contrast, the provider retrieves a
single value with `rebar_state:get(State, reltree, [])` and sends only that
value to `normalize/1` (`src/rebar3_reltree_prv_tree.erl:42-60`). The complete
evaluated option container is therefore discarded before the shared validator
can determine whether more than one top-level `reltree` entry existed. This
also breaks the contract's provider/escript normalization parity for malformed
equivalent configuration (`task-1.md:94-128`).

Smallest correction: at the provider adapter, obtain the complete evaluated
configuration representation from the supported Rebar3 state API, pass all
top-level terms (or all `reltree` values without collapsing them) through
`rebar3_reltree_request:extract_config/1`, and normalize only the resulting
validated option list. Preserve ignored unrelated top-level terms. Add a
provider-boundary regression scenario with two top-level `reltree` entries and
require the same structured duplicate-config failure as the escript boundary.
If Rebar3's supported evaluated-state API has already irreversibly collapsed
duplicates, stop under `task-1.md:333-334` rather than silently weakening the
frozen behavior.

### 2. Low — invalid configured root paths are misclassified as CLI option errors

Evidence: configured roots must be non-empty string paths and malformed
relevant configuration must be reported as configuration failure
(`task-1.md:124-128,130-148,177-179`). `configured_root_term/1` accepts every
list, including the empty list (`src/rebar3_reltree_request.erl:247-252`), and
`configured_roots/1` converts it without retaining its configuration origin
(`src/rebar3_reltree_request.erl:234-245`). The later common root normalizer
returns `{invalid_option, scan_roots, Path}` for an invalid path
(`src/rebar3_reltree_request.erl:265-293`). Thus, for example,
`{scan_roots, [[]]}` is a malformed config value but is rendered as an invalid
command option. The same origin loss applies to any configured string rejected
by `valid_path/1`.

Smallest correction: validate configured path non-emptiness/string validity in
the configured-root parser and return `{invalid_config, scan_roots, Value}`
there; reserve `{invalid_option, scan_roots, Value}` for CLI-originated roots.
Add regression coverage for an empty configured path and retain the existing
exit/no-write behavior.

## Scope and supplied gate evidence

The task-attributable paths are exactly the seven product and three test paths
owned by `task-1.md:49-69`; the only other reported worktree modification is
dispatcher-owned initiative `status.md`. No deletion is present. Source review
found no product write, report placeholder, production dependency, or
out-of-scope command surface.

The supplied coding-worker and independent-runner packets report successful
compile, 35 passing EUnit tests, successful escript construction, expected
help/unavailable/invalid exits, report-path absence, and successful diff
checks. Those results satisfy the commands they report, but they do not negate
the two unexercised normalization defects above. After correction, rerun the
complete Coding Self-Test and Independent Verification layers from
`task-1.md:254-298` before the next Sol review.

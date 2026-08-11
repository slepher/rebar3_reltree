-module(rebar3_reltree).

-export([init/1, dispatch_tree/1, dispatch_bgate/1, main/1]).

-spec init(term()) -> {ok, term()}.
init(State) ->
    Provider = providers:create([
        {name, tree},
        {namespace, reltree},
        {module, rebar3_reltree_prv_tree},
        {example, "rebar3 reltree tree [--scan-roots PATH[:deep]]... [--rev false|auto|true]"},
        {short_desc, "Inspect the local project tree."},
        {desc, "Build the reltree project tree report."},
        {opts, rebar3_reltree_prv_tree:option_spec()}
    ]),
    BadgeProvider = providers:create([
        {name, bgate},
        {namespace, reltree},
        {module, rebar3_reltree_prv_bgate},
        {example, "rebar3 reltree bgate --check|--write"},
        {short_desc, "Check or update local CI badges."},
        {desc, "Check or update the local README CI badges."},
        {opts, rebar3_reltree_prv_bgate:option_spec()}
    ]),
    State1 = rebar_state:add_provider(State, Provider),
    {ok, rebar_state:add_provider(State1, BadgeProvider)}.

-spec dispatch_tree(map()) -> {ok, map()} | {error, term()}.
dispatch_tree(Request) when is_map(Request) ->
    rebar3_reltree_project:generate(Request).

-spec dispatch_bgate(map()) -> {ok, map()} | {error, term()}.
dispatch_bgate(Request) when is_map(Request) ->
    rebar3_reltree_badge:run(Request).

-spec main([string()]) -> no_return().
main(Args) ->
    rebar3_reltree_cli:main(Args).

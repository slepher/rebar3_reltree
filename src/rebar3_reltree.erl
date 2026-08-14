-module(rebar3_reltree).

-export([init/1]).

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
    State2 = rebar_state:add_provider(State1, BadgeProvider),
    CheckVsnProvider = providers:create([
        {name, checkvsn},
        {namespace, reltree},
        {module, rebar3_reltree_prv_checkvsn},
        {example, "rebar3 reltree checkvsn"},
        {short_desc, "Check local application version continuity."},
        {desc, "Check local application version and tag continuity."},
        {opts, rebar3_reltree_prv_checkvsn:option_spec()}
    ]),
    State3 = rebar_state:add_provider(State2, CheckVsnProvider),
    FmtProvider = providers:create([
        {name, fmt},
        {namespace, reltree},
        {module, rebar3_reltree_prv_fmt},
        {example, "rebar3 reltree fmt --check"},
        {short_desc, "Check erlfmt style with AGENT.md file support."},
        {desc,
            "Proxy rebar3 fmt --check over the default set plus the files required by ~/.agents/AGENT.md."},
        {opts, rebar3_reltree_prv_fmt:option_spec()}
    ]),
    State4 = rebar_state:add_provider(State3, FmtProvider),
    {ok, State4}.

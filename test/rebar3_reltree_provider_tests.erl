-module(rebar3_reltree_provider_tests).

-include_lib("eunit/include/eunit.hrl").

provider_registration_test() ->
    {ok, State} = rebar3_reltree:init(rebar_state:new([])),
    Providers = rebar_state:providers(State),
    ?assert(contains_term(Providers, tree)),
    ?assert(contains_term(Providers, reltree)),
    ?assert(contains_term(Providers, rebar3_reltree_prv_tree)).

provider_metadata_test() ->
    Spec = rebar3_reltree_prv_tree:option_spec(),
    ?assertMatch([{scan_roots, _, "scan-roots", string, _},
                  {rev, _, "rev", string, _}], Spec),
    ?assertEqual("tree_engine_unavailable",
                 lists:flatten(rebar3_reltree_prv_tree:format_error(
                                  tree_engine_unavailable))).

provider_default_context_test() ->
    Root = unique_root(),
    State0 = rebar_state:new([]),
    State1 = rebar_state:dir(State0, Root),
    State2 = rebar_state:command_args(State1, []),
    {ok, Request} = rebar3_reltree_prv_tree:request(State2),
    ?assertEqual(Root, maps:get(project_root, Request)),
    ?assertEqual(default, maps:get(profile, Request)),
    ?assertEqual(filename:join([Root, "_build", "default"]),
                 maps:get(build_base_dir, Request)),
    ?assertEqual([{filename:dirname(Root), shallow}],
                 maps:get(scan_roots, Request)),
    ?assertEqual(filename:join([Root, "_build", "default", "reltree",
                                "project.md"]), maps:get(output_path, Request)).

provider_active_profile_and_config_test() ->
    Root = unique_root(),
    State0 = rebar_state:new([{reltree, [{scan_roots, []}, {rev, false}]}]),
    State1 = rebar_state:dir(State0, Root),
    State2 = rebar_state:current_profiles(State1, [default, test]),
    State3 = rebar_state:command_args(State2, ["--rev", "true"]),
    {ok, Request} = rebar3_reltree_prv_tree:request(State3),
    ?assertEqual(test, maps:get(profile, Request)),
    ?assertEqual(filename:join([Root, "_build", "test"]),
                 maps:get(build_base_dir, Request)),
    ?assertEqual([], maps:get(scan_roots, Request)),
    ?assertEqual(true, maps:get(rev, Request)).

provider_uses_effective_last_config_value_test() ->
    Root = unique_root(),
    State0 = rebar_state:new(
               [{reltree, [{scan_roots, [{bad, root}]}]},
                {reltree, [{scan_roots, []}, {rev, true}]}]),
    State1 = rebar_state:dir(State0, Root),
    State2 = rebar_state:command_args(State1, []),
    {ok, Request} = rebar3_reltree_prv_tree:request(State2),
    ?assertEqual([], maps:get(scan_roots, Request)),
    ?assertEqual(true, maps:get(rev, Request)).

provider_returns_unavailable_error_test() ->
    Root = unique_root(),
    State0 = rebar_state:new([]),
    State1 = rebar_state:dir(State0, Root),
    State2 = rebar_state:command_args(State1, []),
    ?assertEqual({error, {rebar3_reltree_prv_tree, tree_engine_unavailable}},
                 rebar3_reltree_prv_tree:do(State2)),
    ?assertNot(filelib:is_dir(filename:join([Root, "_build", "default",
                                             "reltree"]))).

provider_validation_is_returned_test() ->
    State0 = rebar_state:new([]),
    State1 = rebar_state:command_args(State0, ["--rev", "invalid"]),
    ?assertMatch({error, {rebar3_reltree_prv_tree,
                         {invalid_option, rev, "invalid"}}},
                 rebar3_reltree_prv_tree:do(State1)).

provider_help_is_successful_test() ->
    State0 = rebar_state:new([]),
    State1 = rebar_state:command_args(State0, ["--help"]),
    ?assertMatch({ok, _}, rebar3_reltree_prv_tree:do(State1)).

unique_root() ->
    filename:join("/tmp", "reltree-task1-provider-" ++
                         integer_to_list(erlang:unique_integer([positive]))).

contains_term(Term, Wanted) when Term =:= Wanted ->
    true;
contains_term(Term, Wanted) when is_tuple(Term) ->
    contains_term(tuple_to_list(Term), Wanted);
contains_term(Term, Wanted) when is_list(Term) ->
    lists:any(fun(Item) -> contains_term(Item, Wanted) end, Term);
contains_term(Term, Wanted) when is_map(Term) ->
    contains_term(maps:to_list(Term), Wanted);
contains_term(_Term, _Wanted) ->
    false.

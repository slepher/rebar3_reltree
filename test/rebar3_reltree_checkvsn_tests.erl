-module(rebar3_reltree_checkvsn_tests).

-include_lib("eunit/include/eunit.hrl").

provider_success_is_read_only_test() ->
    Root = continuous_fixture("1.0.1"),
    try
        {State, Before} = provider_state(Root, ["checkvsn"]),
        ?assertEqual({ok, State},
                     rebar3_reltree_prv_checkvsn:do(State)),
        ?assertEqual(Before, snapshot(Root))
    after
        rebar3_reltree_fixtures:cleanup(Root)
    end.

provider_gap_is_reported_without_writes_test() ->
    Root = continuous_fixture("1.0.2"),
    try
        {State, Before} = provider_state(Root, ["checkvsn"]),
        ?assertMatch({error, {rebar3_reltree_prv_checkvsn,
                             {version_not_continuous, _}}},
                     rebar3_reltree_prv_checkvsn:do(State)),
        ?assertEqual(Before, snapshot(Root))
    after
        rebar3_reltree_fixtures:cleanup(Root)
    end.

provider_current_tag_mismatch_is_reported_without_writes_test() ->
    Root = rebar3_reltree_fixtures:new_root(),
    try
        rebar3_reltree_fixtures:write_project(Root, checkvsn_mismatch, [],
                                              "1.0.0"),
        rebar3_reltree_fixtures:git_tag(Root, "0.9.0"),
        {State, Before} = provider_state(Root, ["checkvsn"]),
        ?assertMatch({error, {rebar3_reltree_prv_checkvsn,
                             {current_tag_base_mismatch, _}}},
                     rebar3_reltree_prv_checkvsn:do(State)),
        ?assertEqual(Before, snapshot(Root))
    after
        rebar3_reltree_fixtures:cleanup(Root)
    end.

provider_no_head_is_reported_without_writes_test() ->
    Root = rebar3_reltree_fixtures:new_root(),
    try
        rebar3_reltree_fixtures:write_file(
          filename:join([Root, "src", "no_head.app.src"]),
          "{application, no_head, [{vsn, \"1.0.0\"}]} .\n"),
        {State, Before} = provider_state(Root, ["checkvsn"]),
        ?assertMatch({error, {rebar3_reltree_prv_checkvsn, {git_head, _}}},
                     rebar3_reltree_prv_checkvsn:do(State)),
        ?assertEqual(Before, snapshot(Root))
    after
        rebar3_reltree_fixtures:cleanup(Root)
    end.

provider_unknown_argument_fails_before_fact_reads_test() ->
    Root = filename:join("/tmp", "reltree-checkvsn-no-read-" ++
                          integer_to_list(erlang:unique_integer([positive]))),
    State0 = rebar_state:new([]),
    State1 = rebar_state:dir(State0, Root),
    State = rebar_state:command_args(State1, ["checkvsn", "--unknown"]),
    ?assertMatch({error, {rebar3_reltree_prv_checkvsn,
                         {invalid_arguments, checkvsn}}},
                 rebar3_reltree_prv_checkvsn:do(State)).

provider_help_does_not_read_facts_test() ->
    State = rebar_state:command_args(rebar_state:new([]),
                                     ["checkvsn", "--help"]),
    ?assertMatch({ok, _}, rebar3_reltree_prv_checkvsn:do(State)).

continuous_fixture(AppVsn) ->
    Root = rebar3_reltree_fixtures:new_root(),
    rebar3_reltree_fixtures:write_project(Root, checkvsn_fixture, [],
                                          "1.0.0"),
    rebar3_reltree_fixtures:git_tag(Root, "1.0.0"),
    AppSrc = io_lib:format(
               "{application, checkvsn_fixture, [{vsn, ~p}]} .~n",
               [AppVsn]),
    rebar3_reltree_fixtures:write_file(
      filename:join([Root, "src", "checkvsn_fixture.app.src"]), AppSrc),
    rebar3_reltree_fixtures:git_commit(Root, "advance app version"),
    Root.

provider_state(Root, Args) ->
    State0 = rebar_state:new([]),
    State1 = rebar_state:dir(State0, Root),
    State = rebar_state:command_args(State1, Args),
    {State, snapshot(Root)}.

snapshot(Root) ->
    Files = [filename:join([Root, "rebar.config"]),
             filename:join([Root, "src", "checkvsn_fixture.app.src"]),
             filename:join([Root, "src", "no_head.app.src"])],
    {file_snapshot(Files), refs_snapshot(Root)}.

file_snapshot(Paths) ->
    [{Path, file:read_file(Path)} || Path <- Paths].

refs_snapshot(Root) ->
    case rebar3_reltree_git:command(Root, ["show-ref"], #{}) of
        {ok, Output} -> {ok, Output};
        {error, {exit, 1, _}} -> no_refs;
        {error, Reason} -> {error, Reason}
    end.

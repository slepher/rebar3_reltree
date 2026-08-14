-module(rebar3_reltree_provider_tests).

-include_lib("eunit/include/eunit.hrl").

provider_registration_test() ->
    {ok, State} = rebar3_reltree:init(rebar_state:new([])),
    Providers = rebar_state:providers(State),
    ?assert(contains_term(Providers, tree)),
    ?assert(contains_term(Providers, reltree)),
    ?assert(contains_term(Providers, rebar3_reltree_prv_tree)),
    ?assert(contains_term(Providers, bgate)),
    ?assert(contains_term(Providers, rebar3_reltree_prv_bgate)),
    ?assert(contains_term(Providers, checkvsn)),
    ?assert(contains_term(Providers, rebar3_reltree_prv_checkvsn)),
    ?assert(contains_term(Providers, fmt)),
    ?assert(contains_term(Providers, rebar3_reltree_prv_fmt)),
    ?assertNot(contains_term(Providers, skill)).

provider_root_has_no_historical_dispatch_exports_test() ->
    Exports = rebar3_reltree:module_info(exports),
    ?assertNot(lists:member({dispatch_tree, 1}, Exports)),
    ?assertNot(lists:member({dispatch_bgate, 1}, Exports)).

provider_metadata_test() ->
    Spec = rebar3_reltree_prv_tree:option_spec(),
    ?assertMatch(
        [
            {scan_roots, _, "scan-roots", string, _},
            {rev, _, "rev", string, _}
        ],
        Spec
    ).

provider_checkvsn_metadata_test() ->
    ?assertEqual([], rebar3_reltree_prv_checkvsn:option_spec()).

provider_fmt_metadata_test() ->
    ?assertMatch(
        [{check, $c, "check", undefined, _}],
        rebar3_reltree_prv_fmt:option_spec()
    ).

provider_fmt_file_set_test() ->
    Root = unique_root(),
    try
        rebar3_reltree_fixtures:write_file(
            filename:join([Root, "src", "sample.erl"]),
            "-module(sample).\n"
        ),
        rebar3_reltree_fixtures:write_file(
            filename:join([Root, "scripts", "tool.escript"]),
            "#!/usr/bin/env escript\n"
        ),
        rebar3_reltree_fixtures:write_file(
            filename:join([Root, "rebar.config.script"]),
            "[]."
        ),
        rebar3_reltree_fixtures:write_file(
            filename:join([Root, "_build", "default", "bin", "built.escript"]),
            "built"
        ),
        rebar3_reltree_fixtures:write_file(
            filename:join([Root, "deps", "dep", "vendor.escript"]),
            "vendor"
        ),
        Files = rebar3_reltree_prv_fmt:file_set(Root),
        ?assertEqual(
            [
                "{src,include,test}/*.{hrl,erl,app.src}",
                "rebar.config",
                "rebar.config.script",
                "scripts/tool.escript"
            ],
            Files
        ),
        ?assertNot(lists:member("_build/default/bin/built.escript", Files)),
        ?assertNot(lists:member("deps/dep/vendor.escript", Files))
    after
        rebar3_reltree_fixtures:cleanup(Root)
    end.

provider_fmt_rejects_write_test() ->
    State0 = rebar_state:new([]),
    State1 = rebar_state:command_args(State0, ["fmt", "--write"]),
    ?assertMatch(
        {error, {rebar3_reltree_prv_fmt, write_unsupported}},
        rebar3_reltree_prv_fmt:do(State1)
    ),
    State2 = rebar_state:command_args(State0, ["fmt", "-w"]),
    ?assertMatch(
        {error, {rebar3_reltree_prv_fmt, write_unsupported}},
        rebar3_reltree_prv_fmt:do(State2)
    ).

provider_fmt_rejects_missing_mode_test() ->
    State0 = rebar_state:new([]),
    State1 = rebar_state:command_args(State0, ["fmt"]),
    ?assertMatch(
        {error, {rebar3_reltree_prv_fmt, mode_missing}},
        rebar3_reltree_prv_fmt:do(State1)
    ).

provider_fmt_rejects_other_options_test() ->
    State0 = rebar_state:new([]),
    State1 = rebar_state:command_args(
        State0,
        ["fmt", "--print-width", "100"]
    ),
    ?assertMatch(
        {error, {rebar3_reltree_prv_fmt, invalid_arguments}},
        rebar3_reltree_prv_fmt:do(State1)
    ).

provider_fmt_help_is_successful_test() ->
    State0 = rebar_state:new([]),
    State1 = rebar_state:command_args(State0, ["fmt", "--help"]),
    ?assertMatch({ok, _}, rebar3_reltree_prv_fmt:do(State1)).

provider_bgate_metadata_and_request_test() ->
    ?assertMatch(
        [
            {check, undefined, "check", boolean, _},
            {write, undefined, "write", boolean, _},
            {tag, undefined, "tag", boolean, _}
        ],
        rebar3_reltree_prv_bgate:option_spec()
    ),
    Root = unique_root(),
    State0 = rebar_state:new([]),
    State1 = rebar_state:dir(State0, Root),
    State2 = rebar_state:command_args(State1, ["bgate", "--check"]),
    ?assertEqual(
        {ok, #{
            command => bgate,
            mode => check,
            project_root => filename:absname(Root)
        }},
        rebar3_reltree_prv_bgate:request(State2)
    ),
    TagState = rebar_state:command_args(State1, ["bgate", "--write", "--tag"]),
    ?assertEqual(
        {ok, #{
            command => bgate,
            mode => write,
            tag => true,
            project_root => filename:absname(Root)
        }},
        rebar3_reltree_prv_bgate:request(TagState)
    ),
    ?assertMatch(
        {error, {rebar3_reltree_prv_bgate, {tag_requires_write, check}}},
        rebar3_reltree_prv_bgate:do(
            rebar_state:command_args(
                State1,
                ["bgate", "--check", "--tag"]
            )
        )
    ),
    ?assertMatch(
        {error, {rebar3_reltree_prv_bgate, {invalid_mode, missing}}},
        rebar3_reltree_prv_bgate:do(
            rebar_state:command_args(State1, ["bgate"])
        )
    ).

provider_no_workflow_is_successful_test() ->
    Root = rebar3_reltree_fixtures:new_root(),
    try
        State0 = rebar_state:new([]),
        State1 = rebar_state:dir(State0, Root),
        State2 = rebar_state:command_args(State1, ["bgate", "--write"]),
        ?assertMatch({ok, _}, rebar3_reltree_prv_bgate:do(State2)),
        ?assertNot(filelib:is_regular(filename:join(Root, "project.md")))
    after
        rebar3_reltree_fixtures:cleanup(Root)
    end.

provider_default_context_test() ->
    Root = unique_root(),
    State0 = rebar_state:new([]),
    State1 = rebar_state:dir(State0, Root),
    State2 = rebar_state:command_args(State1, []),
    {ok, Request} = rebar3_reltree_prv_tree:request(State2),
    ?assertEqual(Root, maps:get(project_root, Request)),
    ?assertEqual(default, maps:get(profile, Request)),
    ?assertEqual(
        filename:join([Root, "_build", "default"]),
        maps:get(build_base_dir, Request)
    ),
    ?assertEqual(
        [{filename:dirname(Root), shallow}],
        maps:get(scan_roots, Request)
    ),
    ?assertEqual(
        filename:join([
            Root,
            "_build",
            "default",
            "reltree",
            "project.md"
        ]),
        maps:get(output_path, Request)
    ).

provider_active_profile_and_config_test() ->
    Root = unique_root(),
    State0 = rebar_state:new([{reltree, [{scan_roots, []}, {rev, false}]}]),
    State1 = rebar_state:dir(State0, Root),
    State2 = rebar_state:current_profiles(State1, [default, test]),
    State3 = rebar_state:command_args(State2, ["--rev", "true"]),
    {ok, Request} = rebar3_reltree_prv_tree:request(State3),
    ?assertEqual(test, maps:get(profile, Request)),
    ?assertEqual(
        filename:join([Root, "_build", "test"]),
        maps:get(build_base_dir, Request)
    ),
    ?assertEqual([], maps:get(scan_roots, Request)),
    ?assertEqual(true, maps:get(rev, Request)).

provider_uses_effective_last_config_value_test() ->
    Root = unique_root(),
    State0 = rebar_state:new(
        [
            {reltree, [{scan_roots, [{bad, root}]}]},
            {reltree, [{scan_roots, []}, {rev, true}]}
        ]
    ),
    State1 = rebar_state:dir(State0, Root),
    State2 = rebar_state:command_args(State1, []),
    {ok, Request} = rebar3_reltree_prv_tree:request(State2),
    ?assertEqual([], maps:get(scan_roots, Request)),
    ?assertEqual(true, maps:get(rev, Request)).

provider_returns_current_failure_test() ->
    Root = unique_root(),
    State0 = rebar_state:new([]),
    State1 = rebar_state:dir(State0, Root),
    State2 = rebar_state:command_args(State1, []),
    ?assertMatch(
        {error, {rebar3_reltree_prv_tree, {current_project, _, _}}},
        rebar3_reltree_prv_tree:do(State2)
    ),
    ?assertNot(
        filelib:is_dir(
            filename:join([
                Root,
                "_build",
                "default",
                "reltree"
            ])
        )
    ).

provider_validation_is_returned_test() ->
    State0 = rebar_state:new([]),
    State1 = rebar_state:command_args(State0, ["--rev", "invalid"]),
    ?assertMatch(
        {error, {rebar3_reltree_prv_tree, {invalid_option, rev, "invalid"}}},
        rebar3_reltree_prv_tree:do(State1)
    ).

provider_help_is_successful_test() ->
    State0 = rebar_state:new([]),
    State1 = rebar_state:command_args(State0, ["--help"]),
    ?assertMatch({ok, _}, rebar3_reltree_prv_tree:do(State1)).

provider_help_is_local_to_adapters_test() ->
    TreeHelp = lists:flatten(rebar3_reltree_prv_tree:help()),
    BgateHelp = lists:flatten(rebar3_reltree_prv_bgate:help()),
    ?assert(string:str(TreeHelp, "--scan-roots") > 0),
    ?assert(string:str(BgateHelp, "--check") > 0),
    ?assertEqual(0, string:str(TreeHelp, "checkvsn")),
    ?assertEqual(0, string:str(BgateHelp, "checkvsn")).

provider_dispatches_valid_project_and_writes_report_test() ->
    Root = rebar3_reltree_fixtures:new_root(),
    try
        rebar3_reltree_fixtures:write_project(
            Root,
            provider_fixture,
            [],
            "0.1.0"
        ),
        State0 = rebar_state:new([]),
        State1 = rebar_state:dir(State0, Root),
        State2 = rebar_state:command_args(State1, ["tree"]),
        {ok, State2} = rebar3_reltree_prv_tree:do(State2),
        Output = filename:join([
            Root,
            "_build",
            "default",
            "reltree",
            "project.md"
        ]),
        {ok, Bytes} = file:read_file(Output),
        ?assert(
            string:str(
                binary_to_list(Bytes),
                "status: up-to-date"
            ) > 0
        )
    after
        rebar3_reltree_fixtures:cleanup(Root)
    end.

unique_root() ->
    filename:join(
        "/tmp",
        "reltree-task1-provider-" ++
            integer_to_list(erlang:unique_integer([positive]))
    ).

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

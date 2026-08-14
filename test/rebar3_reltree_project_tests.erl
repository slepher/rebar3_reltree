-module(rebar3_reltree_project_tests).

-include_lib("eunit/include/eunit.hrl").

complete_local_report_contains_required_facts_test() ->
    Workspace = rebar3_reltree_fixtures:new_root(),
    try
        Current = filename:join(Workspace, "current"),
        ok = file:make_dir(Current),
        rebar3_reltree_fixtures:write_project(
            Current,
            current,
            [{external, "1.0"}],
            "0.1.0"
        ),
        rebar3_reltree_fixtures:write_file(
            filename:join(Current, "rebar.config"),
            "{deps, [{external, \"1.0\"}]} .\n"
            "{project_plugins, [rebar3_format]}.\n"
            "{plugins, [rebar3_hex]}.\n"
        ),
        Request = request(Current, [], default),
        {ok, Result} = rebar3_reltree_project:generate(
            Request, #{clock => fixed_clock()}
        ),
        Text = binary_to_list(maps:get(bytes, Result)),
        ?assert(string:str(Text, "format_version: 2") > 0),
        ?assert(string:str(Text, "current_project_path: ") > 0),
        ?assert(string:str(Text, "app_src: ") > 0),
        ?assert(string:str(Text, "project_plugins") > 0),
        ?assert(string:str(Text, "plugins") > 0),
        ?assert(string:str(Text, "git_head: ") > 0),
        ?assert(string:str(Text, "highest_formal_version: none") > 0),
        ?assert(string:str(Text, "README.md: absent") > 0),
        ?assert(string:str(Text, "ci_workflow: absent") > 0),
        ?assert(string:str(Text, "revision_state: not-applicable") > 0),
        ?assert(string:str(Text, "network_sync_at: not-performed") > 0),
        ?assert(string:str(Text, "status: up-to-date") > 0)
    after
        rebar3_reltree_fixtures:cleanup(Workspace)
    end.

complete_local_relationship_report_and_external_omission_test() ->
    Workspace = rebar3_reltree_fixtures:new_root(),
    try
        Current = filename:join(Workspace, "current"),
        Upstream = filename:join(Workspace, "upstream"),
        Transitive = filename:join(Workspace, "transitive"),
        Downstream = filename:join(Workspace, "downstream"),
        lists:foreach(
            fun file:make_dir/1,
            [Current, Upstream, Transitive, Downstream]
        ),
        rebar3_reltree_fixtures:write_project(
            Current, current, [upstream, external], "0.1.0"
        ),
        rebar3_reltree_fixtures:write_project(
            Upstream, upstream, [transitive], "0.1.0"
        ),
        rebar3_reltree_fixtures:write_project(
            Transitive,
            transitive,
            [],
            "0.1.0"
        ),
        rebar3_reltree_fixtures:write_project(
            Downstream,
            downstream,
            [current],
            "0.1.0"
        ),
        rebar3_reltree_fixtures:checkout(Current, upstream, Upstream),
        rebar3_reltree_fixtures:checkout(Upstream, transitive, Transitive),
        rebar3_reltree_fixtures:checkout(Downstream, current, Current),
        Request = request(Current, [{Workspace, deep}], default),
        {ok, Result} = rebar3_reltree_project:generate(
            Request, #{clock => fixed_clock()}
        ),
        Model = maps:get(model, Result),
        ?assertEqual(4, length(maps:get(nodes, Model))),
        ?assertEqual(3, length(maps:get(edges, Model))),
        ?assertEqual(up_to_date, maps:get(status, Model)),
        Text = binary_to_list(maps:get(bytes, Result)),
        ?assertEqual(4, count(Text, "### node:")),
        ?assert(string:str(Text, "### node: upstream") > 0),
        ?assert(string:str(Text, "### node: downstream") > 0),
        ?assert(string:str(Text, "dependency: upstream") > 0),
        ?assert(string:str(Text, "dependency: current") > 0),
        ?assert(string:str(Text, "dependency: transitive") > 0),
        ?assert(
            string:str(
                Text,
                "name: external; declaration: external; relationship: external"
            ) > 0
        ),
        ?assertEqual(0, string:str(Text, "### node: external")),
        ?assertEqual(0, string:str(Text, "reason: external"))
    after
        rebar3_reltree_fixtures:cleanup(Workspace)
    end.

same_clock_is_byte_deterministic_and_only_sync_time_changes_test() ->
    Workspace = rebar3_reltree_fixtures:new_root(),
    try
        Current = filename:join(Workspace, "current"),
        ok = file:make_dir(Current),
        rebar3_reltree_fixtures:write_project(
            Current,
            current,
            [z, a],
            "0.1.0"
        ),
        Request = request(Current, [], default),
        {ok, First} = rebar3_reltree_project:generate(
            Request, #{clock => fixed_clock()}
        ),
        {ok, Second} = rebar3_reltree_project:generate(
            Request, #{clock => fixed_clock()}
        ),
        ?assertEqual(maps:get(bytes, First), maps:get(bytes, Second)),
        {ok, Third} = rebar3_reltree_project:generate(
            Request, #{clock => later_clock()}
        ),
        ?assertEqual(
            remove_time(maps:get(bytes, First)),
            remove_time(maps:get(bytes, Third))
        ),
        ?assertNotEqual(maps:get(bytes, First), maps:get(bytes, Third))
    after
        rebar3_reltree_fixtures:cleanup(Workspace)
    end.

ci_badges_are_read_only_facts_and_mismatch_changes_status_test() ->
    Workspace = rebar3_reltree_fixtures:new_root(),
    try
        Current = filename:join(Workspace, "current"),
        ok = file:make_dir(Current),
        rebar3_reltree_fixtures:write_project(Current, current, [], "1.2.1"),
        rebar3_reltree_fixtures:git_tag(Current, "v1.2.0"),
        rebar3_reltree_fixtures:add_origin(
            Current,
            "https://github.com/owner/repo.git"
        ),
        rebar3_reltree_fixtures:write_file(
            filename:join([Current, ".github", "workflows", "ci.yml"]),
            <<"name: master\n">>
        ),
        Master =
            "[![CI](https://github.com/owner/repo/actions/"
            "workflows/ci.yml/badge.svg?branch=master&event=push)]("
            "https://github.com/owner/repo/actions/workflows/ci.yml?"
            "query=branch%3Amaster)",
        Release =
            "[![CI](https://github.com/owner/repo/"
            "actions/workflows/release.yml/badge.svg?branch=v1.2.0&"
            "event=push)](https://github.com/owner/repo/actions/"
            "workflows/release.yml?query=branch%3Av1.2.0)",
        Content = list_to_binary(Master ++ "\n" ++ Release ++ "\n"),
        rebar3_reltree_fixtures:write_file(
            filename:join(Current, "README.md"), Content
        ),
        rebar3_reltree_fixtures:write_file(
            filename:join(Current, "README.zh.md"), Content
        ),
        Request = request(Current, [], default),
        {ok, Good} = rebar3_reltree_project:generate(
            Request, #{clock => fixed_clock()}
        ),
        ?assertEqual(up_to_date, maps:get(status, maps:get(model, Good))),
        Before = file_snapshot(Current),
        rebar3_reltree_fixtures:write_file(
            filename:join(Current, "README.md"),
            list_to_binary(
                Master ++ "\n" ++ Release ++ "\n" ++
                    Release ++ "\n"
            )
        ),
        {ok, Bad} = rebar3_reltree_project:generate(
            Request, #{clock => fixed_clock()}
        ),
        ?assertEqual(update_required, maps:get(status, maps:get(model, Bad))),
        ?assertNotEqual(Before, file_snapshot(Current))
    after
        rebar3_reltree_fixtures:cleanup(Workspace)
    end.

unincluded_incomplete_candidate_is_warned_without_status_impact_test() ->
    Workspace = rebar3_reltree_fixtures:new_root(),
    try
        Current = filename:join(Workspace, "current"),
        Bad = filename:join(Workspace, "bad"),
        ok = file:make_dir(Current),
        ok = file:make_dir(Bad),
        rebar3_reltree_fixtures:write_project(Current, current, [], "0.1.0"),
        rebar3_reltree_fixtures:write_project(Bad, bad, [], "0.1.0"),
        ok = file:delete(filename:join([Bad, "src", "bad.app.src"])),
        Request = request(Current, [{Workspace, deep}], default),
        {ok, Result} = rebar3_reltree_project:generate(
            Request, #{clock => fixed_clock()}
        ),
        Model = maps:get(model, Result),
        ?assertEqual(up_to_date, maps:get(status, Model)),
        ?assertEqual(1, length(maps:get(nodes, Model))),
        ?assert(
            lists:any(
                fun(W) ->
                    maps:get(path, W) =:=
                        rebar3_reltree_fs:canonical(Bad) andalso
                        maps:get(reason, W) =:= candidate_incomplete
                end,
                maps:get(warnings, Model)
            )
        )
    after
        rebar3_reltree_fixtures:cleanup(Workspace)
    end.

regeneration_removes_stale_nodes_and_old_declarations_test() ->
    Workspace = rebar3_reltree_fixtures:new_root(),
    try
        Current = filename:join(Workspace, "current"),
        Upstream = filename:join(Workspace, "upstream"),
        ok = file:make_dir(Current),
        ok = file:make_dir(Upstream),
        rebar3_reltree_fixtures:write_project(
            Current,
            current,
            [upstream],
            "0.1.0"
        ),
        rebar3_reltree_fixtures:write_project(
            Upstream,
            upstream,
            [],
            "0.1.0"
        ),
        ok = file:make_dir(filename:join(Current, "_checkouts")),
        Checkout = filename:join([Current, "_checkouts", "upstream"]),
        ok = file:make_symlink(Upstream, Checkout),
        Request = request(Current, [{Workspace, deep}], default),
        {ok, First} = rebar3_reltree_project:generate(
            Request, #{clock => fixed_clock()}
        ),
        FirstText = binary_to_list(maps:get(bytes, First)),
        ?assert(string:str(FirstText, "### node: upstream") > 0),
        ok = file:delete(Checkout),
        rebar3_reltree_fixtures:write_file(
            filename:join(Current, "rebar.config"), "{deps, []}.\n"
        ),
        {ok, Second} = rebar3_reltree_project:generate(
            Request, #{clock => fixed_clock()}
        ),
        SecondText = binary_to_list(maps:get(bytes, Second)),
        ?assertEqual(1, count(SecondText, "### node:")),
        ?assertEqual(0, string:str(SecondText, "### node: upstream")),
        ?assertEqual(
            0,
            string:str(
                SecondText,
                rebar3_reltree_fs:canonical(Upstream)
            )
        )
    after
        rebar3_reltree_fixtures:cleanup(Workspace)
    end.

generation_failure_preserves_prior_report_and_temp_boundary_test() ->
    Workspace = rebar3_reltree_fixtures:new_root(),
    try
        rebar3_reltree_fixtures:write_project(
            Workspace,
            current,
            [],
            "0.1.0"
        ),
        Request = request(Workspace, [], default),
        {ok, First} = rebar3_reltree_project:generate(
            Request, #{clock => fixed_clock()}
        ),
        Prior = maps:get(bytes, First),
        lists:foreach(
            fun(Stage) ->
                ?assertMatch(
                    {error, {atomic_write, Stage, injected}},
                    rebar3_reltree_project:generate(
                        Request, #{
                            clock => fixed_clock(),
                            fail_stage => Stage
                        }
                    )
                ),
                {ok, Current} = file:read_file(
                    maps:get(
                        output_path,
                        Request
                    )
                ),
                ?assertEqual(Prior, Current),
                ?assertEqual([], temp_files(maps:get(output_path, Request)))
            end,
            [write, close, rename]
        )
    after
        rebar3_reltree_fixtures:cleanup(Workspace)
    end.

current_project_failure_preserves_prior_report_test() ->
    Workspace = rebar3_reltree_fixtures:new_root(),
    try
        rebar3_reltree_fixtures:write_project(
            Workspace,
            current,
            [],
            "0.1.0"
        ),
        Request = request(Workspace, [], default),
        {ok, First} = rebar3_reltree_project:generate(
            Request, #{clock => fixed_clock()}
        ),
        Prior = maps:get(bytes, First),
        rebar3_reltree_fixtures:write_file(
            filename:join(Workspace, "rebar.config"), "{deps, [} .\n"
        ),
        ?assertMatch(
            {error, {current_project, _, _}},
            rebar3_reltree_project:generate(Request)
        ),
        {ok, Current} = file:read_file(maps:get(output_path, Request)),
        ?assertEqual(Prior, Current),
        ?assertEqual([], temp_files(maps:get(output_path, Request)))
    after
        rebar3_reltree_fixtures:cleanup(Workspace)
    end.

connected_candidate_missing_required_facts_is_omitted_test() ->
    Workspace = rebar3_reltree_fixtures:new_root(),
    try
        A = filename:join(Workspace, "a"),
        B = filename:join(Workspace, "b"),
        ok = file:make_dir(A),
        ok = file:make_dir(B),
        rebar3_reltree_fixtures:write_project(A, a, [b], "0.1.0"),
        rebar3_reltree_fixtures:write_project(B, b, [], "0.1.0"),
        rebar3_reltree_fixtures:checkout(A, b, B),
        ok = file:delete(filename:join([B, "src", "b.app.src"])),
        Request = request(A, [{Workspace, deep}], default),
        {ok, Result} = rebar3_reltree_project:generate(
            Request, #{clock => fixed_clock()}
        ),
        Model = maps:get(model, Result),
        ?assertEqual(insufficient_local_data, maps:get(status, Model)),
        ?assertEqual(1, length(maps:get(nodes, Model))),
        Text = binary_to_list(maps:get(bytes, Result)),
        ?assert(string:str(Text, "candidate-incomplete") > 0)
    after
        rebar3_reltree_fixtures:cleanup(Workspace)
    end.

profile_specific_reports_do_not_share_output_path_test() ->
    Workspace = rebar3_reltree_fixtures:new_root(),
    try
        rebar3_reltree_fixtures:write_project(Workspace, current, [], "0.1.0"),
        Default = request(Workspace, [], default),
        Test = request(Workspace, [], test),
        {ok, DefaultResult} = rebar3_reltree_project:generate(
            Default, #{clock => fixed_clock()}
        ),
        {ok, TestResult} = rebar3_reltree_project:generate(
            Test, #{clock => fixed_clock()}
        ),
        ?assertNotEqual(
            maps:get(output_path, Default),
            maps:get(output_path, Test)
        ),
        ?assert(filelib:is_regular(maps:get(output_path, DefaultResult))),
        ?assert(filelib:is_regular(maps:get(output_path, TestResult)))
    after
        rebar3_reltree_fixtures:cleanup(Workspace)
    end.

revision_modes_are_read_only_and_share_identity_test() ->
    Workspace = rebar3_reltree_fixtures:new_root(),
    try
        rebar3_reltree_fixtures:write_project(
            Workspace,
            current,
            [
                {external, {git, "file:///external"}},
                {external, {git, "file:///external"}}
            ],
            "0.1.0"
        ),
        Request = request(Workspace, [], default),
        Lookup = fun(_Url, _Selector) ->
            put(task12_lookup_count, lookup_count() + 1),
            {ok, "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}
        end,
        Snapshot = local_snapshot(Workspace),
        erase(task12_lookup_count),
        {ok, Disabled} = rebar3_reltree_project:generate(
            Request#{rev => false},
            #{clock => fixed_clock(), lookup => Lookup}
        ),
        ?assertEqual(0, lookup_count()),
        ?assertMatch(
            {_, _},
            binary:match(
                maps:get(bytes, Disabled),
                <<"revision_state: tracking-disabled">>
            )
        ),

        erase(task12_lookup_count),
        {ok, Resolved} = rebar3_reltree_project:generate(
            Request#{rev => true},
            #{clock => fixed_clock(), lookup => Lookup}
        ),
        ?assertEqual(1, lookup_count()),
        ?assertMatch(
            {_, _},
            binary:match(
                maps:get(bytes, Resolved),
                <<"revision_state: resolved">>
            )
        ),
        ?assertEqual(
            nomatch,
            binary:match(
                maps:get(bytes, Resolved),
                <<"network_sync_at: not-performed">>
            )
        ),
        ?assertEqual(Snapshot, local_snapshot(Workspace)),

        erase(task12_lookup_count),
        {ok, Reused} = rebar3_reltree_project:generate(
            Request#{rev => auto},
            #{clock => later_clock(), lookup => Lookup}
        ),
        ?assertEqual(0, lookup_count()),
        ?assertMatch(
            {_, _},
            binary:match(
                maps:get(bytes, Reused),
                <<"revision_state: reused">>
            )
        )
    after
        rebar3_reltree_fixtures:cleanup(Workspace)
    end.

request(Root, ScanRoots, Profile) ->
    Build = filename:join([Root, "_build", atom_to_list(Profile)]),
    #{
        command => tree,
        project_root => Root,
        profile => Profile,
        build_base_dir => Build,
        output_path => filename:join([Build, "reltree", "project.md"]),
        scan_roots => ScanRoots,
        rev => auto
    }.

fixed_clock() -> fun() -> {{2020, 1, 2}, {3, 4, 5}} end.
later_clock() -> fun() -> {{2020, 1, 2}, {3, 4, 6}} end.

remove_time(Bytes) ->
    Lines = binary:split(Bytes, <<"\n">>, [global]),
    iolist_to_binary(
        lists:join(
            <<"\n">>,
            [
                Line
             || Line <- Lines,
                binary:match(
                    Line, <<"local_sync_at:">>
                ) =:=
                    nomatch
            ]
        )
    ).

file_snapshot(Root) ->
    {ok, Readme} = file:read_file(filename:join(Root, "README.md")),
    {ok, ReadmeZh} = file:read_file(filename:join(Root, "README.zh.md")),
    {Readme, ReadmeZh}.

count(Text, Needle) ->
    count(Text, Needle, 0).

count([], _Needle, Acc) ->
    Acc;
count(Text, Needle, Acc) ->
    case lists:prefix(Needle, Text) of
        true -> count(lists:nthtail(length(Needle), Text), Needle, Acc + 1);
        false -> count(tl(Text), Needle, Acc)
    end.

temp_files(Output) ->
    {ok, Names} = file:list_dir(filename:dirname(Output)),
    [
        Name
     || Name <- Names,
        lists:prefix(".project.md.reltree-", Name)
    ].

lookup_count() ->
    case get(task12_lookup_count) of
        undefined -> 0;
        Count -> Count
    end.

local_snapshot(Root) ->
    {ok, Config} = file:read_file(filename:join(Root, "rebar.config")),
    {ok, AppSrc} = file:read_file(filename:join([Root, "src", "current.app.src"])),
    Readme = file:read_file(filename:join(Root, "README.md")),
    ReadmeZh = file:read_file(filename:join(Root, "README.zh.md")),
    Checkout =
        case file:list_dir(filename:join(Root, "_checkouts")) of
            {ok, Names} -> lists:sort(Names);
            {error, enoent} -> none
        end,
    {ok, Git} = rebar3_reltree_git:read(Root),
    {Config, AppSrc, Readme, ReadmeZh, Checkout, Git}.

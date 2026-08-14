-module(rebar3_reltree_badge_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("kernel/include/file.hrl").

no_workflow_skips_both_modes_without_other_reads_or_writes_test() ->
    Root = rebar3_reltree_fixtures:new_root(),
    try
        README = filename:join(Root, "README.md"),
        Sentinel = filename:join(Root, "project.md"),
        ok = file:write_file(README, <<"body\n">>),
        ok = file:write_file(Sentinel, <<"sentinel\n">>),
        Before = snapshot(Root, [README, Sentinel]),
        Options = counted_options(Root),
        lists:foreach(
            fun(Mode) ->
                {ok, #{
                    status := skipped_no_workflow,
                    warnings := [#{code := skip_no_workflow}]
                }} =
                    run(Root, Mode, Options)
            end,
            [check, write]
        ),
        ?assertEqual(Before, snapshot(Root, [README, Sentinel])),
        ?assertEqual([], get_counter(git)),
        ?assertEqual([], get_counter(read_file)),
        ?assertEqual([], get_counter(write))
    after
        rebar3_reltree_fixtures:cleanup(Root)
    end.

write_tag_updates_release_workflow_and_uses_path_badges_test() ->
    Root = fixture("https://github.com/acme/split.git"),
    try
        CI = workflow(Root),
        ReleaseWorkflow = release_workflow(Root),
        README = filename:join(Root, "README.md"),
        CIContent = read(CI),
        ok = file:write_file(
            ReleaseWorkflow,
            <<"name: release-0.0.9 # preserve\n", "jobs:\n  build:\n    name: nested\n">>
        ),
        ok = file:write_file(README, <<"body\n">>),
        {ok, #{status := written}} = run(Root, write, #{tag => true}),
        ?assertEqual(CIContent, read(CI)),
        ?assertEqual(
            <<"name: release-0.1.0 # preserve\n", "jobs:\n  build:\n    name: nested\n">>,
            read(ReleaseWorkflow)
        ),
        Text = read(README),
        ?assertNotEqual(
            none,
            binary:match(
                Text,
                list_to_binary(master("acme/split"))
            )
        ),
        ?assertNotEqual(
            none,
            binary:match(
                Text,
                list_to_binary(
                    release(
                        "acme/split",
                        "0.1.0"
                    )
                )
            )
        ),
        ?assertEqual(nomatch, binary:match(Text, <<"**master CI**">>)),
        ?assertEqual(nomatch, binary:match(Text, <<"release CI**">>))
    after
        rebar3_reltree_fixtures:cleanup(Root)
    end.

workflow_name_validation_rejects_duplicates_and_collections_test() ->
    Root = fixture("https://github.com/acme/workflow-name.git"),
    try
        CI = workflow(Root),
        ok = file:write_file(filename:join(Root, "README.md"), <<"body\n">>),
        ok = file:write_file(CI, <<"name: master\nname: duplicate\n">>),
        ?assertMatch(
            {error, {workflow_invalid, CI, duplicate_top_level_name}},
            run(Root, check, #{})
        ),
        ok = file:write_file(CI, <<"name: |\n  master\n">>),
        ?assertMatch(
            {error, {workflow_invalid, CI, non_scalar_top_level_name}},
            run(Root, check, #{})
        ),
        ok = file:write_file(CI, <<"name: master\njobs:\n  build:\n", "    name: nested\n">>),
        ok = file:write_file(
            filename:join(Root, "README.md"),
            list_to_binary(
                master("acme/workflow-name") ++
                    "\n"
            )
        ),
        ?assertMatch({ok, #{status := checked}}, run(Root, check, #{}))
    after
        rebar3_reltree_fixtures:cleanup(Root)
    end.

write_tag_requires_existing_release_workflow_without_readme_write_test() ->
    Root = fixture("https://github.com/acme/missing-release-workflow.git"),
    try
        ReleaseWorkflow = release_workflow(Root),
        README = filename:join(Root, "README.md"),
        ok = file:write_file(README, <<"body\n">>),
        Before = read(README),
        ok = file:delete(ReleaseWorkflow),
        ?assertMatch(
            {error, {workflow_invalid, ReleaseWorkflow, missing}},
            run(Root, write, #{tag => true})
        ),
        ?assertEqual(Before, read(README))
    after
        rebar3_reltree_fixtures:cleanup(Root)
    end.

no_formal_tag_writes_master_only_and_preserves_content_test() ->
    Root = fixture("https://github.com/acme/no-tag.git"),
    try
        English = filename:join(Root, "README.md"),
        Chinese = filename:join(Root, "README.zh.md"),
        Body = <<"# English\n\n[![Hex](https://hex.pm/badge.svg)](https://hex.pm)\ntext\n">>,
        ZhBody = <<"# 中文\n\n[![License](license)](license)\n正文\n">>,
        ok = file:write_file(English, Body),
        ok = file:write_file(Chinese, ZhBody),
        BeforeProject = snapshot_file(filename:join(Root, "project.md")),
        {ok, #{status := written}} = run(Root, write, #{}),
        EnglishAfter = read(English),
        ChineseAfter = read(Chinese),
        Master = list_to_binary(master("acme/no-tag")),
        ?assertEqual(<<Master/binary, "\n\n", Body/binary>>, EnglishAfter),
        ?assertEqual(<<Master/binary, "\n\n", ZhBody/binary>>, ChineseAfter),
        ?assertNotEqual(none, binary:match(EnglishAfter, <<"Hex">>)),
        ?assertNotEqual(none, binary:match(ChineseAfter, <<"License">>)),
        ?assertEqual(
            BeforeProject,
            snapshot_file(
                filename:join(
                    Root,
                    "project.md"
                )
            )
        ),
        {ok, #{status := checked}} = run(Root, check, #{}),
        ?assertEqual(EnglishAfter, read(English)),
        ?assertEqual(ChineseAfter, read(Chinese))
    after
        rebar3_reltree_fixtures:cleanup(Root)
    end.

write_without_tag_master_only_even_with_reachable_tags_test() ->
    Root = fixture("https://github.com/acme/master-only.git"),
    try
        rebar3_reltree_fixtures:git_tag(Root, "1.0.0"),
        README = filename:join(Root, "README.md"),
        ok = file:write_file(
            README,
            list_to_binary(
                master("acme/master-only") ++
                    "\n\n" ++
                    release(
                        "acme/master-only",
                        "1.0.0"
                    ) ++ "\n"
            )
        ),
        {ok, #{status := written}} = run(Root, write, #{}),
        Text = read(README),
        ?assertNotEqual(
            none,
            binary:match(
                Text,
                list_to_binary(
                    master(
                        "acme/master-only"
                    )
                )
            )
        ),
        ?assertEqual(nomatch, binary:match(Text, <<"release CI">>)),
        ?assertMatch(
            {error, {workflow_invalid, _, _}},
            run(Root, check, #{})
        )
    after
        rebar3_reltree_fixtures:cleanup(Root)
    end.

write_with_tag_uses_app_src_version_and_ignores_reachable_tags_test() ->
    Root = fixture("https://github.com/acme/plan-tag.git"),
    try
        rebar3_reltree_fixtures:git_tag(Root, "9.9.9"),
        README = filename:join(Root, "README.md"),
        ok = file:write_file(README, <<"content\n">>),
        {ok, #{status := written}} = run(Root, write, #{tag => true}),
        Text = read(README),
        ?assertNotEqual(
            none,
            binary:match(
                Text,
                list_to_binary(
                    master(
                        "acme/plan-tag"
                    )
                )
            )
        ),
        ?assertNotEqual(
            none,
            binary:match(
                Text,
                list_to_binary(
                    release(
                        "acme/plan-tag", "0.1.0"
                    )
                )
            )
        ),
        ?assertEqual(nomatch, binary:match(Text, <<"9.9.9 release CI">>))
    after
        rebar3_reltree_fixtures:cleanup(Root)
    end.

write_with_tag_requires_app_src_test() ->
    Root = fixture("https://github.com/acme/no-app.git"),
    try
        remove_path(filename:join([Root, "src", "bgate_fixture.app.src"])),
        README = filename:join(Root, "README.md"),
        ok = file:write_file(README, <<"content\n">>),
        ?assertMatch({error, no_app_src}, run(Root, write, #{tag => true})),
        ?assertEqual(<<"content\n">>, read(README))
    after
        rebar3_reltree_fixtures:cleanup(Root)
    end.

check_selects_numeric_highest_reachable_tag_test() ->
    Root = fixture("git@github.com:acme/tagged.git"),
    try
        lists:foreach(fun(Tag) -> rebar3_reltree_fixtures:git_tag(Root, Tag) end, [
            "1.9.9",
            "1.10.0-rc.1",
            "check-1.99.0",
            "1.10.0"
        ]),
        set_release_workflow(Root, "1.10.0"),
        README = filename:join(Root, "README.md"),
        ok = file:write_file(
            README,
            list_to_binary(
                master("acme/tagged") ++ "\n\n" ++
                    release("acme/tagged", "1.10.0") ++ "\n"
            )
        ),
        ?assertMatch({ok, #{status := checked}}, run(Root, check, #{})),
        ok = file:write_file(
            README,
            list_to_binary(
                master("acme/tagged") ++ "\n\n" ++
                    release("acme/tagged", "1.9.9") ++ "\n"
            )
        ),
        ?assertMatch({error, {badge_mismatch, _}}, run(Root, check, #{}))
    after
        rebar3_reltree_fixtures:cleanup(Root)
    end.

v_formal_tag_check_uses_display_version_and_real_branch_test() ->
    Root = fixture("https://github.com/acme/vtag.git"),
    try
        rebar3_reltree_fixtures:git_tag(Root, "v2.3.4"),
        set_release_workflow(Root, "v2.3.4"),
        README = filename:join(Root, "README.md"),
        ok = file:write_file(
            README,
            list_to_binary(
                master("acme/vtag") ++ "\n\n" ++
                    release("acme/vtag", "v2.3.4") ++ "\n"
            )
        ),
        ?assertMatch({ok, #{status := checked}}, run(Root, check, #{}))
    after
        rebar3_reltree_fixtures:cleanup(Root)
    end.

check_is_read_only_on_success_and_mismatch_test() ->
    Root = fixture("https://github.com/acme/check.git"),
    try
        rebar3_reltree_fixtures:git_tag(Root, "1.0.0"),
        set_release_workflow(Root, "1.0.0"),
        README = filename:join(Root, "README.md"),
        Content = list_to_binary(
            master("acme/check") ++ "\n\n" ++
                release("acme/check", "1.0.0") ++ "\nprose\n"
        ),
        ok = file:write_file(README, Content),
        Before = snapshot(Root, [
            README,
            workflow(Root),
            release_workflow(Root)
        ]),
        {ok, #{status := checked}} = run(Root, check, #{}),
        ?assertEqual(
            Before,
            snapshot(Root, [
                README,
                workflow(Root),
                release_workflow(Root)
            ])
        ),
        ok = file:write_file(README, <<"wrong\n">>),
        MismatchBefore = snapshot_file(README),
        ?assertMatch({error, {badge_mismatch, _}}, run(Root, check, #{})),
        ?assertEqual(MismatchBefore, snapshot_file(README))
    after
        rebar3_reltree_fixtures:cleanup(Root)
    end.

write_with_tag_replaces_managed_lines_is_idempotent_and_preserves_crlf_test() ->
    Root = fixture("https://github.com/acme/preserve.git"),
    try
        rebar3_reltree_fixtures:git_tag(Root, "3.0.0"),
        README = filename:join(Root, "README.md"),
        Chinese = filename:join(Root, "README.zh.md"),
        Master = master("acme/preserve"),
        Old = master("old/repo"),
        OldRelease = legacy_release("old/repo", "1.0.0"),
        Body = iolist_to_binary([
            "intro\r\n",
            Old,
            "\r\n\r\n",
            OldRelease,
            "\r\n\r\n",
            "[![Other](other)](other)\r\n",
            unicode:characters_to_binary("正文\r\n")
        ]),
        ok = file:write_file(README, Body),
        ok = file:write_file(Chinese, <<"中文正文\n">>),
        {ok, #{status := written}} = run(Root, write, #{tag => true}),
        First = read(README),
        ?assertNotEqual(nomatch, binary:match(First, <<"\r\n">>)),
        ?assertNotEqual(
            none,
            binary:match(
                First,
                list_to_binary(
                    release(
                        "acme/preserve",
                        "0.1.0"
                    )
                )
            )
        ),
        ?assertEqual(nomatch, binary:match(First, list_to_binary(Old))),
        ?assertNotEqual(none, binary:match(First, <<"Other">>)),
        ?assertNotEqual(none, binary:match(First, <<"正文">>)),
        {ok, #{status := written}} = run(Root, write, #{tag => true}),
        ?assertEqual(First, read(README)),
        ChineseAfter = read(Chinese),
        ?assertNotEqual(
            nomatch,
            binary:match(
                ChineseAfter,
                <<"中文正文\n">>
            )
        ),
        ?assertNotEqual(
            nomatch,
            binary:match(
                ChineseAfter,
                list_to_binary(
                    release(
                        "acme/preserve", "0.1.0"
                    )
                )
            )
        ),
        ?assertEqual(Master, Master)
    after
        rebar3_reltree_fixtures:cleanup(Root)
    end.

write_with_tag_preserves_gap_bytes_between_non_adjacent_managed_lines_test() ->
    Root = fixture("https://github.com/acme/gap.git"),
    try
        rebar3_reltree_fixtures:git_tag(Root, "2.0.0"),
        README = filename:join(Root, "README.md"),
        OldMaster = master("old/repo"),
        Other = "[![Other](other)](other)",
        OldRelease = release("old/repo", "1.0.0"),
        ok = file:write_file(
            README,
            list_to_binary(
                "before\n" ++ OldMaster ++ "\n\n" ++ Other ++
                    "\n\n" ++ OldRelease ++ "\nafter\n"
            )
        ),
        {ok, #{status := written}} = run(Root, write, #{tag => true}),
        Expected = list_to_binary(
            "before\n" ++ master("acme/gap") ++
                "\n\n" ++ release("acme/gap", "0.1.0") ++
                "\n\n" ++ Other ++ "\n\nafter\n"
        ),
        ?assertEqual(Expected, read(README))
    after
        rebar3_reltree_fixtures:cleanup(Root)
    end.

write_preserves_last_bare_cr_byte_test() ->
    Root = fixture("https://github.com/acme/bare-cr.git"),
    try
        README = filename:join(Root, "README.md"),
        Original = <<"tail", 13>>,
        ok = file:write_file(README, Original),
        {ok, #{status := written}} = run(Root, write, #{}),
        Expected =
            <<"[![CI](https://github.com/acme/bare-cr/actions/workflows/ci.yml/badge.svg?branch=master&event=push)](https://github.com/acme/bare-cr/actions/workflows/ci.yml?query=branch%3Amaster)\n\n",
                "tail", 13>>,
        ?assertEqual(Expected, read(README))
    after
        rebar3_reltree_fixtures:cleanup(Root)
    end.

write_preserves_managed_last_bare_cr_byte_test() ->
    Root = fixture("https://github.com/acme/managed-bare-cr.git"),
    try
        README = filename:join(Root, "README.md"),
        Master = master("acme/managed-bare-cr"),
        Original = list_to_binary(Master ++ [13]),
        ok = file:write_file(README, Original),
        {ok, #{status := written}} = run(Root, write, #{}),
        ?assertEqual(Original, read(README))
    after
        rebar3_reltree_fixtures:cleanup(Root)
    end.

check_reports_missing_release_badge_test() ->
    Root = fixture("https://github.com/acme/missing-release.git"),
    try
        rebar3_reltree_fixtures:git_tag(Root, "1.0.0"),
        set_release_workflow(Root, "1.0.0"),
        README = filename:join(Root, "README.md"),
        ok = file:write_file(
            README,
            list_to_binary(
                master("acme/missing-release") ++
                    "\n"
            )
        ),
        ?assertMatch(
            {error, {badge_mismatch, [{_, [missing]}]}},
            run(Root, check, #{})
        )
    after
        rebar3_reltree_fixtures:cleanup(Root)
    end.

chinese_managed_block_must_match_but_prose_may_differ_test() ->
    Root = fixture("https://github.com/acme/zh.git"),
    try
        rebar3_reltree_fixtures:git_tag(Root, "v4.5.6"),
        set_release_workflow(Root, "v4.5.6"),
        English = filename:join(Root, "README.md"),
        Chinese = filename:join(Root, "README.zh.md"),
        Block = list_to_binary(
            master("acme/zh") ++ "\n\n" ++
                release("acme/zh", "v4.5.6") ++ "\n"
        ),
        ok = file:write_file(English, <<Block/binary, "English prose\n">>),
        ok = file:write_file(Chinese, <<Block/binary, "中文内容不同\n">>),
        ?assertMatch({ok, #{status := checked}}, run(Root, check, #{})),
        ok = file:write_file(Chinese, <<
            (list_to_binary(master("acme/zh")))/binary,
            "\n\n",
            (list_to_binary(
                release(
                    "acme/zh",
                    "4.5.6"
                )
            ))/binary,
            "\n中文内容不同\n"
        >>),
        ?assertMatch({error, {badge_mismatch, _}}, run(Root, check, #{}))
    after
        rebar3_reltree_fixtures:cleanup(Root)
    end.

equivalent_tags_check_warns_and_write_ignores_tags_test() ->
    Root = fixture("https://github.com/acme/equivalent.git"),
    try
        rebar3_reltree_fixtures:git_tag(Root, "1.2.3"),
        rebar3_reltree_fixtures:git_tag(Root, "v1.2.3"),
        English = filename:join(Root, "README.md"),
        Chinese = filename:join(Root, "README.zh.md"),
        Bare = list_to_binary(
            master("acme/equivalent") ++ "\n\n" ++
                release("acme/equivalent", "1.2.3") ++ "\n"
        ),
        VTag = list_to_binary(
            master("acme/equivalent") ++ "\n\n" ++
                release("acme/equivalent", "v1.2.3") ++ "\n"
        ),
        ok = file:write_file(English, Bare),
        ok = file:write_file(Chinese, VTag),
        ?assertMatch({error, {badge_mismatch, _}}, run(Root, check, #{})),
        ok = file:write_file(Chinese, Bare),
        {ok, #{status := checked, warnings := [Warning]}} =
            run(Root, check, #{}),
        ?assertEqual(equivalent_formal_tags, maps:get(code, Warning)),
        WarningText = lists:flatten(
            rebar3_reltree_badge:format_result(
                #{warnings => [Warning]}
            )
        ),
        ?assert(string:str(WarningText, "1.2.3") > 0),
        ?assert(string:str(WarningText, "v1.2.3") > 0),
        {ok, #{status := written}} = run(Root, write, #{}),
        Plain = read(English),
        ?assertNotEqual(
            none,
            binary:match(
                Plain,
                list_to_binary(
                    master(
                        "acme/equivalent"
                    )
                )
            )
        ),
        ?assertEqual(nomatch, binary:match(Plain, <<"release CI">>)),
        {ok, #{status := written}} = run(Root, write, #{tag => true}),
        WithTag = read(English),
        ?assertNotEqual(
            none,
            binary:match(
                WithTag,
                list_to_binary(
                    release(
                        "acme/equivalent", "0.1.0"
                    )
                )
            )
        ),
        ok
    after
        rebar3_reltree_fixtures:cleanup(Root)
    end.

read_and_write_errors_are_bounded_and_path_specific_test() ->
    Root = fixture("https://github.com/acme/errors.git"),
    try
        Workflow = workflow(Root),
        README = filename:join(Root, "README.md"),
        ok = file:write_file(README, <<"body">>),
        ok = file:delete(Workflow),
        ok = file:make_dir(Workflow),
        ?assertMatch(
            {error, {workflow_invalid, Workflow, _}},
            run(Root, check, #{})
        ),
        remove_path(Workflow),
        rebar3_reltree_fixtures:write_file(Workflow, <<"name: master\n">>),
        ok = file:delete(README),
        ?assertMatch(
            {error, {readme_read, README, enoent}},
            run(Root, check, #{})
        ),
        ok = file:make_dir(README),
        ?assertMatch(
            {error, {readme_invalid, README, _}},
            run(Root, write, #{})
        )
    after
        rebar3_reltree_fixtures:cleanup(Root)
    end.

write_order_and_partial_second_file_failure_test() ->
    Root = fixture("https://github.com/acme/failure.git"),
    try
        README = filename:join(Root, "README.md"),
        Chinese = filename:join(Root, "README.zh.md"),
        ok = file:write_file(README, <<"English\n">>),
        ok = file:write_file(Chinese, <<"中文\n">>),
        BeforeZh = read(Chinese),
        erase(write_calls),
        Writer = fun(Path, Content) ->
            put(write_calls, value(write_calls, []) ++ [Path]),
            case filename:basename(Path) of
                "README.zh.md" -> {error, injected_second_file};
                _ -> rebar3_reltree_fs:atomic_write(Path, Content, #{})
            end
        end,
        ?assertMatch(
            {error, {readme_write, Chinese, replace, injected_second_file}},
            run(Root, write, #{atomic_write => Writer})
        ),
        ?assertEqual([README, Chinese, README], get(write_calls)),
        ?assertEqual(<<"English\n">>, read(README)),
        ?assertEqual(BeforeZh, read(Chinese))
    after
        rebar3_reltree_fixtures:cleanup(Root)
    end.

provider_and_escript_request_parity_test() ->
    Root = rebar3_reltree_fixtures:new_root(),
    try
        State0 = rebar_state:new([]),
        State1 = rebar_state:dir(State0, Root),
        State2 = rebar_state:command_args(State1, ["bgate", "--check"]),
        {ok, ProviderRequest} = rebar3_reltree_prv_bgate:request(State2),
        ?assertEqual(
            ProviderRequest,
            #{
                command => bgate,
                mode => check,
                project_root => filename:absname(Root)
            }
        ),
        TagState = rebar_state:command_args(State1, [
            "bgate",
            "--write",
            "--tag"
        ]),
        {ok, TagRequest} = rebar3_reltree_prv_bgate:request(TagState),
        ?assertEqual(
            TagRequest,
            #{
                command => bgate,
                mode => write,
                tag => true,
                project_root => filename:absname(Root)
            }
        ),
        ?assert(
            string:str(
                lists:flatten(rebar3_reltree_prv_bgate:help()),
                "Usage: reltree bgate"
            ) > 0
        ),
        ?assert(
            string:str(
                lists:flatten(rebar3_reltree_prv_bgate:help()),
                "--tag"
            ) > 0
        ),
        ?assertMatch({ok, _}, rebar3_reltree_prv_bgate:do(State2)),
        ?assertMatch({ok, _}, rebar3_reltree_prv_bgate:do(TagState))
    after
        rebar3_reltree_fixtures:cleanup(Root)
    end.

counted_options(Root) ->
    erase(git),
    erase(read_file),
    erase(write),
    #{
        fs => #{
            read_link_info => fun(Path) ->
                self() ! {read_link_info, Path},
                file:read_link_info(Path)
            end,
            read_file => fun(Path) ->
                put(read_file, [Path | value(read_file, [])]),
                file:read_file(Path)
            end
        },
        git_command => fun(_Path, _Args) ->
            put(git, [called | value(git, [])]),
            {error, unexpected_git_call}
        end,
        atomic_write => fun(Path, _Content) ->
            put(write, [Path | value(write, [])]),
            {error, unexpected_write}
        end,
        root => Root
    }.

get_counter(Key) ->
    lists:reverse(value(Key, [])).

value(Key, Default) ->
    case get(Key) of
        undefined -> Default;
        Value -> Value
    end.

run(Root, Mode, Options) ->
    rebar3_reltree_badge:run(
        #{project_root => Root, mode => Mode},
        maps:remove(root, Options)
    ).

fixture(Origin) ->
    Root = rebar3_reltree_fixtures:new_root(),
    rebar3_reltree_fixtures:write_project(Root, bgate_fixture, [], "0.1.0"),
    rebar3_reltree_fixtures:add_origin(Root, Origin),
    rebar3_reltree_fixtures:write_file(workflow(Root), <<"name: master\n">>),
    rebar3_reltree_fixtures:write_file(
        release_workflow(Root),
        <<"name: release-0.1.0\n">>
    ),
    Root.

workflow(Root) -> filename:join([Root, ".github", "workflows", "ci.yml"]).

release_workflow(Root) ->
    filename:join([Root, ".github", "workflows", "release.yml"]).

set_release_workflow(Root, Tag) ->
    rebar3_reltree_fixtures:write_file(
        release_workflow(Root), list_to_binary("name: release-" ++ Tag ++ "\n")
    ).

master(Repo) ->
    "[![CI](https://github.com/" ++ Repo ++
        "/actions/workflows/ci.yml/badge.svg?branch=master&event=push)](https://github.com/" ++
        Repo ++ "/actions/workflows/ci.yml?query=branch%3Amaster)".

release(Repo, Tag) ->
    "[![CI](https://github.com/" ++ Repo ++
        "/actions/workflows/release.yml/badge.svg?branch=" ++ Tag ++
        "&event=push)](https://github.com/" ++
        Repo ++ "/actions/workflows/release.yml?query=branch%3A" ++ Tag ++ ")".

legacy_release(Repo, Tag) ->
    "[![" ++ Tag ++ " release CI](https://github.com/" ++ Repo ++
        "/actions/workflows/ci.yml/badge.svg?branch=" ++ Tag ++ "&event=push)](https://github.com/" ++
        Repo ++ "/actions/workflows/ci.yml?query=branch%3A" ++ Tag ++ ")".

read(Path) ->
    {ok, Content} = file:read_file(Path),
    Content.

snapshot(Root, Paths) ->
    [{Path, snapshot_file(Path)} || Path <- Paths] ++
        [{root, Root}].

snapshot_file(Path) ->
    case file:read_file(Path) of
        {ok, Content} -> {ok, Content};
        {error, Reason} -> {error, Reason}
    end.

remove_path(Path) ->
    case file:read_link_info(Path) of
        {ok, #file_info{type = directory}} ->
            {ok, Names} = file:list_dir(Path),
            lists:foreach(fun(Name) -> remove_path(filename:join(Path, Name)) end, Names),
            file:del_dir(Path);
        {ok, _} ->
            file:delete(Path);
        {error, _} ->
            ok
    end.

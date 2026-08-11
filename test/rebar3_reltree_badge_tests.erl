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
                  {ok, #{status := skipped_no_workflow,
                         warnings := [#{code := skip_no_workflow}]}} =
                      run(Root, Mode, Options)
          end, [check, write]),
        ?assertEqual(Before, snapshot(Root, [README, Sentinel])),
        ?assertEqual([], get_counter(git)),
        ?assertEqual([], get_counter(read_file)),
        ?assertEqual([], get_counter(write))
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
        ?assertEqual(BeforeProject, snapshot_file(filename:join(Root,
                                                                 "project.md"))),
        {ok, #{status := checked}} = run(Root, check, #{}),
        ?assertEqual(EnglishAfter, read(English)),
        ?assertEqual(ChineseAfter, read(Chinese))
    after
        rebar3_reltree_fixtures:cleanup(Root)
    end.

formal_tag_policy_is_numeric_and_preserves_real_tag_test() ->
    Root = fixture("git@github.com:acme/tagged.git"),
    try
        lists:foreach(fun(Tag) -> rebar3_reltree_fixtures:git_tag(Root, Tag)
                      end, ["1.9.9", "1.10.0-rc.1", "check-1.99.0",
                            "1.10.0"]),
        README = filename:join(Root, "README.md"),
        ok = file:write_file(README, <<"content\n">>),
        {ok, #{status := written}} = run(Root, write, #{}),
        Text = read(README),
        ?assertNotEqual(none, binary:match(Text,
                                           list_to_binary(master("acme/tagged")))),
        ?assertNotEqual(none, binary:match(Text,
                                           list_to_binary(release("acme/tagged",
                                                                  "1.10.0")))),
        ?assertEqual(nomatch, binary:match(Text, <<"1.9.9 release CI">>)),
        ?assertEqual(nomatch, binary:match(Text, <<"1.10.0-rc.1 release CI">>)),
        ?assertEqual(nomatch, binary:match(Text, <<"check-1.99.0">>))
    after
        rebar3_reltree_fixtures:cleanup(Root)
    end.

v_formal_tag_uses_display_version_and_real_branch_test() ->
    Root = fixture("https://github.com/acme/vtag.git"),
    try
        rebar3_reltree_fixtures:git_tag(Root, "v2.3.4"),
        README = filename:join(Root, "README.md"),
        ok = file:write_file(README, <<"content">>),
        {ok, _} = run(Root, write, #{}),
        Text = read(README),
        ?assertNotEqual(none, binary:match(Text, <<"2.3.4 release CI">>)),
        ?assertNotEqual(none, binary:match(Text, <<"branch=v2.3.4">>)),
        ?assertNotEqual(none, binary:match(Text, <<"branch%3Av2.3.4">>))
    after
        rebar3_reltree_fixtures:cleanup(Root)
    end.

check_is_read_only_on_success_and_mismatch_test() ->
    Root = fixture("https://github.com/acme/check.git"),
    try
        rebar3_reltree_fixtures:git_tag(Root, "1.0.0"),
        README = filename:join(Root, "README.md"),
        Content = list_to_binary(master("acme/check") ++ "\n\n" ++
                                 release("acme/check", "1.0.0") ++ "\nprose\n"),
        ok = file:write_file(README, Content),
        Before = snapshot(Root, [README, workflow(Root)]),
        {ok, #{status := checked}} = run(Root, check, #{}),
        ?assertEqual(Before, snapshot(Root, [README, workflow(Root)])),
        ok = file:write_file(README, <<"wrong\n">>),
        MismatchBefore = snapshot_file(README),
        ?assertMatch({error, {badge_mismatch, _}}, run(Root, check, #{})),
        ?assertEqual(MismatchBefore, snapshot_file(README))
    after
        rebar3_reltree_fixtures:cleanup(Root)
    end.

write_replaces_managed_lines_is_idempotent_and_preserves_crlf_test() ->
    Root = fixture("https://github.com/acme/preserve.git"),
    try
        rebar3_reltree_fixtures:git_tag(Root, "3.0.0"),
        README = filename:join(Root, "README.md"),
        Chinese = filename:join(Root, "README.zh.md"),
        Master = master("acme/preserve"),
        Old = master("old/repo"),
        OldRelease = release("old/repo", "1.0.0"),
        Body = iolist_to_binary(["intro\r\n", Old, "\r\n\r\n", OldRelease,
                                 "\r\n\r\n", "[![Other](other)](other)\r\n",
                                 unicode:characters_to_binary("正文\r\n")]),
        ok = file:write_file(README, Body),
        ok = file:write_file(Chinese, <<"中文正文\n">>),
        {ok, #{status := written}} = run(Root, write, #{}),
        First = read(README),
        ?assertNotEqual(nomatch, binary:match(First, <<"\r\n">>)),
        ?assertNotEqual(none, binary:match(First,
                                           list_to_binary(release("acme/preserve",
                                                                  "3.0.0")))),
        ?assertEqual(nomatch, binary:match(First, list_to_binary(Old))),
        ?assertNotEqual(none, binary:match(First, <<"Other">>)),
        ?assertNotEqual(none, binary:match(First, <<"正文">>)),
        {ok, #{status := written}} = run(Root, write, #{}),
        ?assertEqual(First, read(README)),
        ChineseAfter = read(Chinese),
        ?assertNotEqual(nomatch, binary:match(ChineseAfter,
                                              <<"中文正文\n">>)),
        ?assertNotEqual(nomatch, binary:match(ChineseAfter,
                                              list_to_binary(release(
                                                "acme/preserve", "3.0.0")))),
        ?assertEqual(Master, Master)
    after
        rebar3_reltree_fixtures:cleanup(Root)
    end.

write_preserves_gap_bytes_between_non_adjacent_managed_lines_test() ->
    Root = fixture("https://github.com/acme/gap.git"),
    try
        rebar3_reltree_fixtures:git_tag(Root, "2.0.0"),
        README = filename:join(Root, "README.md"),
        OldMaster = master("old/repo"),
        Other = "[![Other](other)](other)",
        OldRelease = release("old/repo", "1.0.0"),
        ok = file:write_file(
               README,
               list_to_binary("before\n" ++ OldMaster ++ "\n\n" ++ Other ++
                              "\n\n" ++ OldRelease ++ "\nafter\n")),
        {ok, #{status := written}} = run(Root, write, #{}),
        Expected = list_to_binary("before\n" ++ master("acme/gap") ++
                                  "\n\n" ++ release("acme/gap", "2.0.0") ++
                                  "\n\n" ++ Other ++ "\n\nafter\n"),
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
        Expected = <<"[![master CI](https://github.com/acme/bare-cr/actions/workflows/ci.yml/badge.svg?branch=master&event=push)](https://github.com/acme/bare-cr/actions/workflows/ci.yml?query=branch%3Amaster)\n\n",
                    "tail", 13>>,
        ?assertEqual(Expected, read(README))
    after
        rebar3_reltree_fixtures:cleanup(Root)
    end.

chinese_managed_block_must_match_but_prose_may_differ_test() ->
    Root = fixture("https://github.com/acme/zh.git"),
    try
        rebar3_reltree_fixtures:git_tag(Root, "v4.5.6"),
        English = filename:join(Root, "README.md"),
        Chinese = filename:join(Root, "README.zh.md"),
        Block = list_to_binary(master("acme/zh") ++ "\n\n" ++
                               release("acme/zh", "v4.5.6") ++ "\n"),
        ok = file:write_file(English, <<Block/binary, "English prose\n">>),
        ok = file:write_file(Chinese, <<Block/binary, "中文内容不同\n">>),
        ?assertMatch({ok, #{status := checked}}, run(Root, check, #{})),
        ok = file:write_file(Chinese, <<(list_to_binary(master("acme/zh")))/binary,
                                         "\n\n", (list_to_binary(release("acme/zh",
                                                                            "4.5.6")))/binary,
                                         "\n中文内容不同\n">>),
        ?assertMatch({error, {badge_mismatch, _}}, run(Root, check, #{}))
    after
        rebar3_reltree_fixtures:cleanup(Root)
    end.

equivalent_tags_write_fails_before_writes_and_check_warns_test() ->
    Root = fixture("https://github.com/acme/equivalent.git"),
    try
        rebar3_reltree_fixtures:git_tag(Root, "1.2.3"),
        rebar3_reltree_fixtures:git_tag(Root, "v1.2.3"),
        English = filename:join(Root, "README.md"),
        Chinese = filename:join(Root, "README.zh.md"),
        Bare = list_to_binary(master("acme/equivalent") ++ "\n\n" ++
                              release("acme/equivalent", "1.2.3") ++ "\n"),
        VTag = list_to_binary(master("acme/equivalent") ++ "\n\n" ++
                              release("acme/equivalent", "v1.2.3") ++ "\n"),
        ok = file:write_file(English, Bare),
        ok = file:write_file(Chinese, VTag),
        Before = snapshot(Root, [English, Chinese]),
        ?assertMatch({error, {equivalent_formal_tags, [_, _]}},
                     run(Root, write, #{})),
        ?assertEqual(Before, snapshot(Root, [English, Chinese])),
        ?assertMatch({error, {badge_mismatch, _}}, run(Root, check, #{})),
        ok = file:write_file(Chinese, Bare),
        {ok, #{status := checked, warnings := [Warning]}} =
            run(Root, check, #{}),
        ?assertEqual(equivalent_formal_tags, maps:get(code, Warning)),
        WarningText = lists:flatten(
                        rebar3_reltree_badge:format_result(
                          #{warnings => [Warning]})),
        ?assert(string:str(WarningText, "1.2.3") > 0),
        ?assert(string:str(WarningText, "v1.2.3") > 0)
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
        ?assertMatch({error, {workflow_invalid, Workflow, _}},
                     run(Root, check, #{})),
        remove_path(Workflow),
        rebar3_reltree_fixtures:write_file(Workflow, <<"name: ci\n">>),
        ok = file:delete(README),
        ?assertMatch({error, {readme_read, README, enoent}},
                     run(Root, check, #{})),
        ok = file:make_dir(README),
        ?assertMatch({error, {readme_invalid, README, _}},
                     run(Root, write, #{}))
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
        ?assertMatch({error, {readme_write, Chinese, replace,
                              injected_second_file}},
                     run(Root, write, #{atomic_write => Writer})),
        ?assertEqual([README, Chinese], get(write_calls)),
        ?assertNotEqual(<<"English\n">>, read(README)),
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
        ?assertEqual(ProviderRequest,
                     #{command => bgate, mode => check,
                       project_root => filename:absname(Root)}),
        ?assert(string:str(lists:flatten(rebar3_reltree_prv_bgate:help()),
                           "Usage: reltree bgate") > 0),
        ?assertMatch({ok, _}, rebar3_reltree_prv_bgate:do(State2))
    after
        rebar3_reltree_fixtures:cleanup(Root)
    end.

counted_options(Root) ->
    erase(git), erase(read_file), erase(write),
    #{fs => #{read_link_info => fun(Path) ->
                                      self() ! {read_link_info, Path},
                                      file:read_link_info(Path)
                              end,
              read_file => fun(Path) ->
                                   put(read_file, [Path | value(read_file, [])]),
                                   file:read_file(Path)
                           end},
      git_command => fun(_Path, _Args) ->
                             put(git, [called | value(git, [])]),
                             {error, unexpected_git_call}
                     end,
      atomic_write => fun(Path, _Content) ->
                              put(write, [Path | value(write, [])]),
                              {error, unexpected_write}
                      end,
      root => Root}.

get_counter(Key) ->
    lists:reverse(value(Key, [])).

value(Key, Default) ->
    case get(Key) of
        undefined -> Default;
        Value -> Value
    end.

run(Root, Mode, Options) ->
    rebar3_reltree_badge:run(#{project_root => Root, mode => Mode},
                              maps:remove(root, Options)).

fixture(Origin) ->
    Root = rebar3_reltree_fixtures:new_root(),
    rebar3_reltree_fixtures:write_project(Root, bgate_fixture, [], "0.1.0"),
    rebar3_reltree_fixtures:add_origin(Root, Origin),
    rebar3_reltree_fixtures:write_file(workflow(Root), <<"name: ci\n">>),
    Root.

workflow(Root) -> filename:join([Root, ".github", "workflows", "ci.yml"]).

master(Repo) ->
    "[![master CI](https://github.com/" ++ Repo ++
    "/actions/workflows/ci.yml/badge.svg?branch=master&event=push)](https://github.com/" ++
    Repo ++ "/actions/workflows/ci.yml?query=branch%3Amaster)".

release(Repo, Tag) ->
    Display = case Tag of
                  [$v | Rest] -> Rest;
                  _ -> Tag
              end,
    "[![" ++ Display ++ " release CI](https://github.com/" ++ Repo ++
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
            lists:foreach(fun(Name) -> remove_path(filename:join(Path, Name))
                          end, Names),
            file:del_dir(Path);
        {ok, _} -> file:delete(Path);
        {error, _} -> ok
    end.

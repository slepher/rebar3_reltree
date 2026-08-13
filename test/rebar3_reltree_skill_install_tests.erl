-module(rebar3_reltree_skill_install_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("kernel/include/file.hrl").

first_install_is_exact_and_cleans_stage_test() ->
    {Source, Parent, Root} = fixture("first"),
    try
        Target = filename:join(Parent, "reltree"),
        ?assertEqual({ok, filename:absname(Target)},
                     rebar3_reltree_skill_install:install(Source, Parent,
                                                           false)),
        ?assertEqual(["SKILL.md", "agents"], entries(Target)),
        ?assertEqual(["openai.yaml"], entries(filename:join(Target, "agents"))),
        ?assertEqual(<<"skill bytes\n">>, read(filename:join(Target, "SKILL.md"))),
        ?assertEqual(<<"agent bytes\n">>,
                     read(filename:join([Target, "agents", "openai.yaml"]))),
        ?assertEqual([], owned_siblings(Parent))
    after
        remove_path(Root)
    end.

default_conflict_does_not_mutate_target_test() ->
    {Source, Parent, Root} = fixture("conflict"),
    try
        Target = filename:join(Parent, "reltree"),
        make_target(Target, <<"old skill\n">>, <<"old agent\n">>, true),
        Before = snapshot(Target),
        ?assertMatch({error, {install, target_conflict, Target, _}},
                     rebar3_reltree_skill_install:install(Source, Parent,
                                                           false)),
        ?assertEqual(Before, snapshot(Target)),
        ?assertEqual([], owned_siblings(Parent))
    after
        remove_path(Root)
    end.

file_target_conflict_does_not_mutate_target_test() ->
    {Source, Parent, Root} = fixture("file-conflict"),
    try
        Target = filename:join(Parent, "reltree"),
        ok = file:write_file(Target, <<"old target\n">>),
        ?assertMatch({error, {install, target_conflict, Target, _}},
                     rebar3_reltree_skill_install:install(Source, Parent,
                                                           false)),
        ?assertEqual(<<"old target\n">>, read(Target)),
        ?assertEqual([], owned_siblings(Parent))
    after
        remove_path(Root)
    end.

force_is_full_replacement_test() ->
    {Source, Parent, Root} = fixture("force"),
    try
        Target = filename:join(Parent, "reltree"),
        make_target(Target, <<"old skill\n">>, <<"old agent\n">>, true),
        ok = file:write_file(filename:join(Target, "obsolete.txt"), <<"old\n">>),
        ?assertEqual({ok, filename:absname(Target)},
                     rebar3_reltree_skill_install:install(Source, Parent,
                                                           true)),
        ?assertEqual(["SKILL.md", "agents"], entries(Target)),
        ?assertEqual(<<"skill bytes\n">>, read(filename:join(Target, "SKILL.md"))),
        ?assertEqual([], owned_siblings(Parent))
    after
        remove_path(Root)
    end.

destination_precedence_is_explicit_and_bounded_test() ->
    Env = fun("HOME") -> "/tmp/user-home";
             (_Name) -> erlang:error(unexpected_read)
          end,
    ?assertEqual({ok, filename:absname("/tmp/explicit")},
                 rebar3_reltree_skill_install:resolve_destination(
                   #{dest => "/tmp/explicit"},
                   fun(_Name) -> erlang:error(unexpected_read) end)),
    ?assertEqual({ok, filename:absname("/tmp/user-home/.agents/skills")},
                 rebar3_reltree_skill_install:resolve_destination(#{}, Env)),
    ?assertEqual({error, unavailable},
                 rebar3_reltree_skill_install:resolve_destination(
                   #{}, fun("HOME") -> false;
                           (_Name) -> erlang:error(unexpected_read)
                       end)),
    ?assertEqual({error, empty},
                 rebar3_reltree_skill_install:resolve_destination(
                   #{}, fun("HOME") -> [];
                           (_Name) -> erlang:error(unexpected_read)
                       end)).

source_shape_is_exact_and_no_follow_test() ->
    {Source, Parent, Root} = fixture("shape"),
    try
        ok = file:write_file(filename:join(Source, "README.md"), <<"extra">>),
        ?assertMatch({error, {install, source_validation, Source, _}},
                     rebar3_reltree_skill_install:install(Source, Parent,
                                                           false)),
        ok = file:delete(filename:join(Source, "README.md")),
        ok = file:write_file(filename:join(Source, "agents/extra.yaml"),
                             <<"extra">>),
        ?assertMatch({error, {install, source_validation, _, _}},
                     rebar3_reltree_skill_install:install(Source, Parent,
                                                           false)),
        ok = file:delete(filename:join(Source, "agents/extra.yaml")),
        ok = file:delete(filename:join(Source, "SKILL.md")),
        ok = file:make_symlink(filename:join(Root, "outside"),
                               filename:join(Source, "SKILL.md")),
        ok = file:write_file(filename:join(Root, "outside"), <<"outside">>),
        ?assertMatch({error, {install, source_validation, _, _}},
                     rebar3_reltree_skill_install:install(Source, Parent,
                                                           false)),
        ?assertNot(filelib:is_dir(filename:join(Parent, "reltree")))
    after
        remove_path(Root)
    end.

overlap_and_invalid_parent_fail_before_writes_test() ->
    {Source, _Parent, Root} = fixture("overlap"),
    try
        ?assertMatch({error, {install, source_validation, Source, _}},
                     rebar3_reltree_skill_install:install(Source, Source,
                                                           false)),
        ParentFile = filename:join(Root, "parent-file"),
        ok = file:write_file(ParentFile, <<"not a directory">>),
        ?assertMatch({error, {install, parent, ParentFile, _}},
                     rebar3_reltree_skill_install:install(Source, ParentFile,
                                                           false)),
        ?assertNot(filelib:is_dir(filename:join(ParentFile, "reltree")))
    after
        remove_path(Root)
    end.

replace_failure_rolls_back_complete_old_target_test() ->
    {Source, Parent, Root} = fixture("replace-failure"),
    try
        Target = filename:join(Parent, "reltree"),
        make_target(Target, <<"old skill\n">>, <<"old agent\n">>, false),
        Result = with_failure(
                   {rename, replace},
                   fun() -> rebar3_reltree_skill_install:install(Source, Parent,
                                                                  true)
                   end),
        ?assertMatch({error, {install, replace, Target, _}}, Result),
        ?assertEqual(["SKILL.md", "agents"], entries(Target)),
        ?assertEqual(<<"old skill\n">>, read(filename:join(Target, "SKILL.md"))),
        ?assertEqual(<<"old agent\n">>,
                     read(filename:join([Target, "agents", "openai.yaml"]))),
        ?assertEqual([], owned_siblings(Parent))
    after
        remove_path(Root)
    end.

target_symlink_is_never_followed_test() ->
    {Source, Parent, Root} = fixture("target-symlink"),
    try
        Outside = filename:join(Root, "outside-target"),
        make_target(Outside, <<"outside skill\n">>, <<"outside agent\n">>, false),
        Target = filename:join(Parent, "reltree"),
        ok = file:make_symlink(Outside, Target),
        ?assertMatch({error, {install, target_conflict, Target, _}},
                     rebar3_reltree_skill_install:install(Source, Parent,
                                                           false)),
        ?assertEqual(<<"outside skill\n">>, read(filename:join(Outside,
                                                            "SKILL.md"))),
        {ok, _} = rebar3_reltree_skill_install:install(Source, Parent, true),
        ?assertEqual(<<"outside skill\n">>, read(filename:join(Outside,
                                                            "SKILL.md"))),
        ?assertEqual(<<"skill bytes\n">>, read(filename:join(Target,
                                                               "SKILL.md")))
    after
        remove_path(Root)
    end.

stage_failure_is_clean_and_target_free_test() ->
    {Source, Parent, Root} = fixture("stage-failure"),
    try
        Result = with_failure(
                   {stage_copy, agent},
                   fun() -> rebar3_reltree_skill_install:install(Source, Parent,
                                                                  false)
                   end),
        ?assertMatch({error, {install, stage_copy, _, _}}, Result),
        ?assertNot(filelib:is_dir(filename:join(Parent, "reltree"))),
        ?assertEqual([], owned_siblings(Parent))
    after
        remove_path(Root)
    end.

fixture(Name) ->
    Root = filename:join("/tmp", "reltree-task10-installer-" ++ Name ++ "-" ++
                         integer_to_list(erlang:unique_integer([positive]))),
    Source = filename:join(Root, "source"),
    Parent = filename:join(Root, "parent with space/" ++ unicode_dir()),
    ok = filelib:ensure_dir(filename:join(Source, "placeholder")),
    ok = file:make_dir(filename:join(Source, "agents")),
    ok = file:write_file(filename:join(Source, "SKILL.md"),
                         <<"skill bytes\n">>),
    ok = file:write_file(filename:join(Source, "agents/openai.yaml"),
                         <<"agent bytes\n">>),
    ok = filelib:ensure_dir(filename:join(Parent, "placeholder")),
    {Source, Parent, Root}.

unicode_dir() ->
    Codepoints = [16#4E2D, 16#6587],
    case file:native_name_encoding() of
        utf8 -> Codepoints;
        latin1 -> binary_to_list(unicode:characters_to_binary(Codepoints))
    end.

make_target(Target, Skill, Agent, Extra) ->
    ok = filelib:ensure_dir(filename:join(Target, "agents/placeholder")),
    ok = file:write_file(filename:join(Target, "SKILL.md"), Skill),
    ok = file:write_file(filename:join([Target, "agents", "openai.yaml"]),
                         Agent),
    case Extra of
        true -> ok = file:write_file(filename:join(Target, "old.txt"), <<"old">>);
        false -> ok
    end.

snapshot(Target) ->
    {read(filename:join(Target, "SKILL.md")),
     read(filename:join([Target, "agents", "openai.yaml"])),
     entries(Target)}.

entries(Path) ->
    {ok, Names} = file:list_dir(Path),
    lists:sort(Names).

owned_siblings(Parent) ->
    {ok, Names} = file:list_dir(Parent),
    [Name || Name <- Names, lists:prefix(".reltree-", Name)].

read(Path) ->
    {ok, Bytes} = file:read_file(Path),
    Bytes.

with_failure(Failure, Fun) ->
    put({rebar3_reltree_skill_install, test_failure}, Failure),
    try Fun()
    after
        erase({rebar3_reltree_skill_install, test_failure})
    end.

remove_path(Path) ->
    case file:read_link_info(Path) of
        {ok, #file_info{type = directory}} ->
            {ok, Names} = file:list_dir(Path),
            lists:foreach(fun(Name) -> remove_path(filename:join(Path, Name)) end,
                          Names),
            file:del_dir(Path);
        {ok, _} -> file:delete(Path);
        {error, enoent} -> ok
    end.

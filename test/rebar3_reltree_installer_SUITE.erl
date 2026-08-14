-module(rebar3_reltree_installer_SUITE).

-include_lib("common_test/include/ct.hrl").
-include_lib("eunit/include/eunit.hrl").

-export([
    all/0,
    script_is_executable_and_help_is_bare_installer/1,
    bare_install_uses_agents_home_and_reports_exact_target/1,
    explicit_destination_installs_exact_two_files/1,
    install_options_are_order_independent/1,
    existing_target_conflict_then_force_replaces_completely/1,
    malformed_source_and_overlap_fail_without_writes/1,
    target_symlink_is_replaced_without_following_it/1,
    retired_commands_and_invalid_options_fail_without_writes/1
]).

all() ->
    [
        script_is_executable_and_help_is_bare_installer,
        bare_install_uses_agents_home_and_reports_exact_target,
        explicit_destination_installs_exact_two_files,
        install_options_are_order_independent,
        existing_target_conflict_then_force_replaces_completely,
        malformed_source_and_overlap_fail_without_writes,
        target_symlink_is_replaced_without_following_it,
        retired_commands_and_invalid_options_fail_without_writes
    ].
-include_lib("kernel/include/file.hrl").

script_is_executable_and_help_is_bare_installer(_Config) ->
    Script = script_path(),
    {ok, #file_info{mode = Mode}} = file:read_file_info(Script),
    ?assertNotEqual(0, Mode band 8#111),
    with_root(
        "help",
        fun(Root) ->
            {Exit, Output} = run_script(["--help"], Root),
            Text = binary_to_list(Output),
            ?assertEqual(0, Exit),
            ?assert(
                string:str(
                    Text,
                    "Usage: scripts/install_reltree.escript [--dest DIR] [--force]"
                ) > 0
            ),
            ?assert(string:str(Text, "--dest DIR") > 0),
            ?assert(string:str(Text, "--force") > 0),
            ?assertEqual(0, string:str(Text, "reltree tree")),
            ?assertEqual(0, string:str(Text, "reltree checkvsn")),
            ?assertEqual(0, string:str(Text, "reltree bgate")),
            ?assertEqual([], entries(Root))
        end
    ).

bare_install_uses_agents_home_and_reports_exact_target(_Config) ->
    with_root(
        "bare",
        fun(Root) ->
            {Exit, Output} = run_script([], Root),
            Target = filename:join([
                Root,
                "home",
                ".agents",
                "skills",
                "reltree"
            ]),
            ?assertEqual(0, Exit),
            assert_install_output(Output, Target),
            assert_exact_install(Target),
            ?assertEqual([], owned_siblings(filename:dirname(Target)))
        end
    ).

explicit_destination_installs_exact_two_files(_Config) ->
    with_root(
        "explicit",
        fun(Root) ->
            Dest = filename:join(
                Root,
                "destination with space/" ++ unicode_dir()
            ),
            {Exit, Output} = run_script(["--dest", Dest], Root),
            Target = filename:join(filename:absname(Dest), "reltree"),
            ?assertEqual(0, Exit),
            assert_install_output(Output, Target),
            assert_exact_install(Target),
            ?assertEqual([], owned_siblings(filename:dirname(Target)))
        end
    ).

install_options_are_order_independent(_Config) ->
    with_root(
        "order",
        fun(Root) ->
            Dest = filename:join(Root, "ordered-destination"),
            {Exit, Output} = run_script(["--force", "--dest", Dest], Root),
            Target = filename:join(filename:absname(Dest), "reltree"),
            ?assertEqual(0, Exit),
            assert_install_output(Output, Target),
            assert_exact_install(Target)
        end
    ).

existing_target_conflict_then_force_replaces_completely(_Config) ->
    with_root(
        "conflict-force",
        fun(Root) ->
            {0, _} = run_script([], Root),
            Target = filename:join([
                Root,
                "home",
                ".agents",
                "skills",
                "reltree"
            ]),
            ok = file:write_file(
                filename:join(Target, "SKILL.md"),
                <<"old skill\n">>
            ),
            ok = file:write_file(
                filename:join(Target, "obsolete.txt"),
                <<"old\n">>
            ),
            Before = snapshot(Target),
            {ConflictExit, ConflictOutput} = run_script([], Root),
            ?assertEqual(1, ConflictExit),
            ?assert(
                string:str(
                    binary_to_list(ConflictOutput),
                    "target_conflict"
                ) > 0
            ),
            ?assertEqual(Before, snapshot(Target)),
            ?assertEqual([], owned_siblings(filename:dirname(Target))),
            {ForceExit, ForceOutput} = run_script(["--force"], Root),
            ?assertEqual(0, ForceExit),
            assert_install_output(ForceOutput, Target),
            assert_exact_install(Target),
            ?assertEqual([], owned_siblings(filename:dirname(Target)))
        end
    ).

malformed_source_and_overlap_fail_without_writes(_Config) ->
    with_root(
        "source-validation",
        fun(Root) ->
            Script = make_repository_fixture(Root),
            Source = filename:join([Root, "priv", "skills", "reltree"]),
            Dest = filename:join(Root, "destination"),
            ok = file:write_file(
                filename:join(Source, "README.md"),
                <<"unexpected\n">>
            ),
            {ShapeExit, ShapeOutput} =
                run_script_at(Script, ["--dest", Dest], Root),
            ?assertEqual(1, ShapeExit),
            ?assertNotEqual(
                nomatch,
                binary:match(
                    ShapeOutput,
                    <<"source_validation">>
                )
            ),
            ?assertNot(filelib:is_dir(filename:join(Dest, "reltree"))),
            ok = file:delete(filename:join(Source, "README.md")),
            {OverlapExit, OverlapOutput} =
                run_script_at(
                    Script,
                    [
                        "--force",
                        "--dest",
                        filename:join([Root, "priv", "skills"])
                    ],
                    Root
                ),
            ?assertEqual(1, OverlapExit),
            ?assertNotEqual(
                nomatch,
                binary:match(
                    OverlapOutput,
                    <<"source_target_overlap">>
                )
            ),
            ?assert(filelib:is_regular(filename:join(Source, "SKILL.md"))),
            ?assert(
                filelib:is_regular(
                    filename:join(
                        [Source, "agents", "openai.yaml"]
                    )
                )
            )
        end
    ).

target_symlink_is_replaced_without_following_it(_Config) ->
    with_root(
        "target-symlink",
        fun(Root) ->
            Parent = filename:join(Root, "destination"),
            Outside = filename:join(Root, "outside"),
            ok = filelib:ensure_dir(filename:join(Parent, "placeholder")),
            ok = filelib:ensure_dir(filename:join(Outside, "placeholder")),
            OutsideSkill = filename:join(Outside, "SKILL.md"),
            ok = file:write_file(OutsideSkill, <<"outside\n">>),
            Target = filename:join(Parent, "reltree"),
            ok = file:make_symlink(Outside, Target),
            {ConflictExit, _} = run_script(["--dest", Parent], Root),
            ?assertEqual(1, ConflictExit),
            ?assertEqual(
                {ok, <<"outside\n">>},
                file:read_file(OutsideSkill)
            ),
            {ForceExit, _} =
                run_script(["--force", "--dest", Parent], Root),
            ?assertEqual(0, ForceExit),
            ?assertEqual(
                {ok, <<"outside\n">>},
                file:read_file(OutsideSkill)
            ),
            assert_exact_install(Target),
            ?assertEqual([], owned_siblings(Parent))
        end
    ).

retired_commands_and_invalid_options_fail_without_writes(_Config) ->
    with_root(
        "invalid",
        fun(Root) ->
            ArgsList = [
                ["skill", "--install"],
                ["tree"],
                ["checkvsn"],
                ["bgate"],
                ["unknown"],
                ["--dest"],
                ["--force=yes"],
                ["--force", "--force"],
                [
                    "--dest",
                    filename:join(Root, "one"),
                    "--dest",
                    filename:join(Root, "two")
                ],
                ["extra"]
            ],
            lists:foreach(
                fun(Args) ->
                    {Exit, _Output} = run_script(Args, Root),
                    ?assertEqual(2, Exit),
                    ?assertEqual([], entries(Root)),
                    ?assertEqual([], owned_siblings(Root))
                end,
                ArgsList
            )
        end
    ).

assert_exact_install(Target) ->
    ?assertEqual(["SKILL.md", "agents"], entries(Target)),
    ?assertEqual(["openai.yaml"], entries(filename:join(Target, "agents"))),
    {ok, SkillBytes} = file:read_file(filename:join(source_path(), "SKILL.md")),
    {ok, AgentBytes} = file:read_file(
        filename:join([
            source_path(),
            "agents",
            "openai.yaml"
        ])
    ),
    ?assertEqual(
        {ok, SkillBytes},
        file:read_file(filename:join(Target, "SKILL.md"))
    ),
    ?assertEqual(
        {ok, AgentBytes},
        file:read_file(
            filename:join([
                Target,
                "agents",
                "openai.yaml"
            ])
        )
    ),
    ok.

assert_install_output(Output, Target) ->
    ?assertEqual(
        native_path_binary(
            "reltree skill installed at " ++ Target ++ "\n"
        ),
        Output
    ).

native_path_binary(Path) ->
    case file:native_name_encoding() of
        utf8 -> unicode:characters_to_binary(Path);
        latin1 -> list_to_binary(Path)
    end.

snapshot(Target) ->
    {
        read(filename:join(Target, "SKILL.md")),
        entries(Target),
        read(filename:join(Target, "obsolete.txt"))
    }.

run_script(Args, Root) ->
    run_script_at(script_path(), Args, Root).

run_script_at(Script, Args, Root) ->
    Port = open_port(
        {spawn_executable, Script},
        [
            binary,
            exit_status,
            stderr_to_stdout,
            {args, Args},
            {env, [
                {"HOME", filename:join(Root, "home")},
                {"PATH", runtime_path()}
            ]}
        ]
    ),
    collect_port(Port, []).

collect_port(Port, Acc) ->
    receive
        {Port, {data, Data}} ->
            collect_port(Port, [Data | Acc]);
        {Port, {exit_status, Status}} ->
            {Status, iolist_to_binary(lists:reverse(Acc))}
    end.

runtime_path() ->
    filename:join([code:root_dir(), "bin"]) ++ ":/usr/bin:/bin".

script_path() ->
    filename:join([project_root(), "scripts", "install_reltree.escript"]).

project_root() ->
    AppDir = code:lib_dir(rebar3_reltree),
    filename:dirname(
        filename:dirname(
            filename:dirname(
                filename:dirname(
                    AppDir
                )
            )
        )
    ).

source_path() ->
    filename:join([
        filename:dirname(filename:dirname(script_path())),
        "priv",
        "skills",
        "reltree"
    ]).

make_repository_fixture(Root) ->
    Script = filename:join([Root, "scripts", "install_reltree.escript"]),
    Source = filename:join([Root, "priv", "skills", "reltree"]),
    ok = filelib:ensure_dir(Script),
    ok = filelib:ensure_dir(filename:join([Source, "agents", "placeholder"])),
    {ok, _} = file:copy(script_path(), Script),
    ok = file:change_mode(Script, 8#755),
    ok = file:write_file(
        filename:join(Source, "SKILL.md"),
        <<"skill bytes\n">>
    ),
    ok = file:write_file(
        filename:join([Source, "agents", "openai.yaml"]),
        <<"agent bytes\n">>
    ),
    Script.

with_root(Name, Fun) ->
    Root = filename:join(
        "/tmp",
        "reltree-installer-tests-" ++ Name ++ "-" ++
            integer_to_list(erlang:unique_integer([positive]))
    ),
    ok = filelib:ensure_dir(filename:join(Root, "placeholder")),
    try
        Fun(Root)
    after
        remove_path(Root)
    end.

unicode_dir() ->
    Codepoints = [16#4E2D, 16#6587],
    case file:native_name_encoding() of
        utf8 -> Codepoints;
        latin1 -> binary_to_list(unicode:characters_to_binary(Codepoints))
    end.

entries(Path) ->
    {ok, Names} = file:list_dir(Path),
    lists:sort(Names).

owned_siblings(Parent) ->
    case file:list_dir(Parent) of
        {ok, Names} ->
            [
                Name
             || Name <- Names,
                lists:prefix(".reltree-stage-", Name) orelse
                    lists:prefix(".reltree-backup-", Name)
            ];
        {error, enoent} ->
            []
    end.

read(Path) ->
    {ok, Bytes} = file:read_file(Path),
    Bytes.

remove_path(Path) ->
    case file:read_link_info(Path) of
        {ok, #file_info{type = directory}} ->
            {ok, Names} = file:list_dir(Path),
            lists:foreach(
                fun(Name) -> remove_path(filename:join(Path, Name)) end,
                Names
            ),
            file:del_dir(Path);
        {ok, _} ->
            file:delete(Path);
        {error, enoent} ->
            ok
    end.

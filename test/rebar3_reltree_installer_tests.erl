-module(rebar3_reltree_installer_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("kernel/include/file.hrl").

script_is_executable_and_help_is_bare_installer_test() ->
    Script = script_path(),
    {ok, #file_info{mode = Mode}} = file:read_file_info(Script),
    ?assertNotEqual(0, Mode band 8#111),
    with_root(
      "help",
      fun(Root) ->
              {Exit, Output} = run_script(["--help"], Root),
              Text = binary_to_list(Output),
              ?assertEqual(0, Exit),
              ?assert(string:str(Text,
                                 "Usage: scripts/install_reltree [--dest DIR] [--force]") > 0),
              ?assert(string:str(Text, "--dest DIR") > 0),
              ?assert(string:str(Text, "--force") > 0),
              ?assertEqual(0, string:str(Text, "reltree tree")),
              ?assertEqual(0, string:str(Text, "reltree checkvsn")),
              ?assertEqual(0, string:str(Text, "reltree bgate")),
              ?assertEqual([], entries(Root))
      end).

bare_install_uses_codex_home_and_reports_exact_target_test() ->
    with_root(
      "bare",
      fun(Root) ->
              {Exit, Output} = run_script([], Root),
              Target = filename:join([Root, "codex-home", "skills", "reltree"]),
              ?assertEqual(0, Exit),
              assert_install_output(Output, Target),
              assert_exact_install(Target),
              ?assertEqual([], owned_siblings(filename:dirname(Target)))
      end).

explicit_destination_installs_exact_two_files_test() ->
    with_root(
      "explicit",
      fun(Root) ->
              Dest = filename:join(Root, "destination with space/中文"),
              {Exit, Output} = run_script(["--dest", Dest], Root),
              Target = filename:join(filename:absname(Dest), "reltree"),
              ?assertEqual(0, Exit),
              assert_install_output(Output, Target),
              assert_exact_install(Target),
              ?assertEqual([], owned_siblings(filename:dirname(Target)))
      end).

install_options_are_order_independent_test() ->
    with_root(
      "order",
      fun(Root) ->
              Dest = filename:join(Root, "ordered-destination"),
              {Exit, Output} = run_script(["--force", "--dest", Dest], Root),
              Target = filename:join(filename:absname(Dest), "reltree"),
              ?assertEqual(0, Exit),
              assert_install_output(Output, Target),
              assert_exact_install(Target)
      end).

existing_target_conflict_then_force_replaces_completely_test() ->
    with_root(
      "conflict-force",
      fun(Root) ->
              {0, _} = run_script([], Root),
              Target = filename:join([Root, "codex-home", "skills", "reltree"]),
              ok = file:write_file(filename:join(Target, "SKILL.md"),
                                   <<"old skill\n">>),
              ok = file:write_file(filename:join(Target, "obsolete.txt"),
                                   <<"old\n">>),
              Before = snapshot(Target),
              {ConflictExit, ConflictOutput} = run_script([], Root),
              ?assertEqual(1, ConflictExit),
              ?assert(string:str(binary_to_list(ConflictOutput),
                                 "target_conflict") > 0),
              ?assertEqual(Before, snapshot(Target)),
              ?assertEqual([], owned_siblings(filename:dirname(Target))),
              {ForceExit, ForceOutput} = run_script(["--force"], Root),
              ?assertEqual(0, ForceExit),
              assert_install_output(ForceOutput, Target),
              assert_exact_install(Target),
              ?assertEqual([], owned_siblings(filename:dirname(Target)))
      end).

retired_commands_and_invalid_options_fail_without_writes_test() ->
    with_root(
      "invalid",
      fun(Root) ->
              ArgsList = [["skill", "--install"],
                          ["tree"],
                          ["checkvsn"],
                          ["bgate"],
                          ["unknown"],
                          ["--dest"],
                          ["--force=yes"],
                          ["--force", "--force"],
                          ["--dest", filename:join(Root, "one"),
                           "--dest", filename:join(Root, "two")],
                          ["extra"]],
              lists:foreach(
                fun(Args) ->
                        {Exit, _Output} = run_script(Args, Root),
                        ?assertEqual(2, Exit),
                        ?assertEqual([], entries(Root)),
                        ?assertEqual([], owned_siblings(Root))
                end,
                ArgsList)
      end).

assert_exact_install(Target) ->
    ?assertEqual(["SKILL.md", "agents"], entries(Target)),
    ?assertEqual(["openai.yaml"], entries(filename:join(Target, "agents"))),
    {ok, SkillBytes} = file:read_file(filename:join(source_path(), "SKILL.md")),
    {ok, AgentBytes} = file:read_file(filename:join([source_path(), "agents",
                                                     "openai.yaml"])),
    ?assertEqual({ok, SkillBytes},
                 file:read_file(filename:join(Target, "SKILL.md"))),
    ?assertEqual({ok, AgentBytes},
                 file:read_file(filename:join([Target, "agents",
                                                "openai.yaml"]))),
    ok.

assert_install_output(Output, Target) ->
    ?assertEqual(unicode:characters_to_binary(
                   "reltree skill installed at " ++ Target ++ "\n"),
                 Output).

snapshot(Target) ->
    {read(filename:join(Target, "SKILL.md")),
     entries(Target),
     read(filename:join(Target, "obsolete.txt"))}.

run_script(Args, Root) ->
    Port = open_port(
             {spawn_executable, script_path()},
             [binary, exit_status, stderr_to_stdout,
              {args, Args},
              {env, [{"CODEX_HOME", filename:join(Root, "codex-home")},
                     {"HOME", filename:join(Root, "home")},
                     {"PATH", runtime_path()}]}]),
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
    filename:absname("scripts/install_reltree").

source_path() ->
    filename:join([filename:dirname(filename:dirname(script_path())),
                   "priv", "skills", "reltree"]).

with_root(Name, Fun) ->
    Root = filename:join(
             "/tmp",
             "reltree-installer-tests-" ++ Name ++ "-" ++
                 integer_to_list(erlang:unique_integer([positive]))),
    ok = filelib:ensure_dir(filename:join(Root, "placeholder")),
    try Fun(Root)
    after
        remove_path(Root)
    end.

entries(Path) ->
    {ok, Names} = file:list_dir(Path),
    lists:sort(Names).

owned_siblings(Parent) ->
    case file:list_dir(Parent) of
        {ok, Names} ->
            [Name || Name <- Names,
                     lists:prefix(".reltree-stage-", Name) orelse
                     lists:prefix(".reltree-backup-", Name)];
        {error, enoent} -> []
    end.

read(Path) ->
    {ok, Bytes} = file:read_file(Path),
    Bytes.

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

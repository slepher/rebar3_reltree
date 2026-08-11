-module(rebar3_reltree_cli_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("kernel/include/file.hrl").

top_help_is_bare_installer_only_test() ->
    Root = unique_root(),
    {Exit, Output} = rebar3_reltree_cli:run(["--help"],
                                             #{priv_dir => Root}),
    Text = lists:flatten(Output),
    ?assertEqual(0, Exit),
    ?assert(string:str(Text, "Usage: reltree [--dest DIR] [--force]") > 0),
    ?assert(string:str(Text, "--dest DIR") > 0),
    ?assert(string:str(Text, "--force") > 0),
    ?assertEqual(0, string:str(Text, " tree ")),
    ?assertEqual(0, string:str(Text, "bgate ")),
    ?assertEqual(0, string:str(Text, "checkvsn ")),
    ?assertNot(filelib:is_dir(Root)).

retired_skill_command_is_a_usage_error_test() ->
    Root = unique_root(),
    {Exit, Output} = rebar3_reltree_cli:run(["skill", "--help"],
                                             #{priv_dir => Root}),
    Text = lists:flatten(Output),
    ?assertEqual(2, Exit),
    ?assert(string:str(Text, "unknown command") > 0),
    ?assert(string:str(Text, "run 'reltree' or 'reltree --help'") > 0),
    ?assertEqual(0, string:str(Text, "skill --install")),
    ?assertEqual(0, string:str(Text, "reltree tree")),
    ?assertEqual(0, string:str(Text, "reltree checkvsn")),
    ?assertEqual(0, string:str(Text, "reltree bgate")),
    ?assertNot(filelib:is_dir(Root)).

bare_invocation_installs_from_codex_home_test() ->
    {Priv, Source, Root} = package_fixture("cli-bare"),
    try
        CodexHome = filename:join(Root, "codex home/中文"),
        Env = fun("CODEX_HOME") -> CodexHome;
                  ("HOME") -> filename:join(Root, "home")
               end,
        {Exit, Output} = rebar3_reltree_cli:run([], #{priv_dir => Priv,
                                                       env => Env}),
        Target = filename:join(CodexHome, "skills/reltree"),
        ?assertEqual(0, Exit),
        ?assert(string:str(lists:flatten(Output), filename:absname(Target)) > 0),
        ?assertEqual(package_bytes(Source), installed_bytes(Target)),
        ?assertEqual(["SKILL.md", "agents"], entries(Target)),
        ?assertEqual(["openai.yaml"], entries(filename:join(Target, "agents")))
    after
        remove_fixture(Root)
    end.

explicit_destination_installs_packaged_source_test() ->
    {Priv, Source, Root} = package_fixture("cli"),
    try
        Dest = filename:join(Root, "destination with space/中文"),
        {Exit, Output} = rebar3_reltree_cli:run(
                           ["--dest", Dest],
                           #{priv_dir => Priv}),
        Target = filename:join(filename:absname(Dest), "reltree"),
        ?assertEqual(0, Exit),
        ?assert(string:str(lists:flatten(Output), Target) > 0),
        ?assertEqual(package_bytes(Source), installed_bytes(Target)),
        ?assertEqual([], sibling_entries(filename:dirname(Target)))
    after
        remove_fixture(Root)
    end.

explicit_destination_does_not_read_environment_test() ->
    {Priv, _Source, Root} = package_fixture("cli-explicit"),
    try
        Dest = filename:join(Root, "explicit"),
        Env = fun(_Name) -> erlang:error(unexpected_environment_read) end,
        {0, _} = rebar3_reltree_cli:run(
                    ["--dest", Dest, "--force"],
                    #{priv_dir => Priv, env => Env}),
        ?assert(filelib:is_dir(filename:join(Dest, "reltree")))
    after
        remove_fixture(Root)
    end.

install_options_are_order_independent_test() ->
    {Priv, _Source, Root} = package_fixture("cli-order"),
    try
        Dest = filename:join(Root, "dest"),
        {0, _} = rebar3_reltree_cli:run(
                    ["--force", "--dest", Dest],
                    #{priv_dir => Priv}),
        ?assert(filelib:is_dir(filename:join(Dest, "reltree")))
    after
        remove_fixture(Root)
    end.

retired_project_commands_are_usage_errors_without_writes_test() ->
    Root = unique_root(),
    lists:foreach(
      fun(Args) ->
              {Exit, Output} = rebar3_reltree_cli:run(Args,
                                                     #{priv_dir => Root}),
              ?assertEqual(2, Exit),
              Text = lists:flatten(Output),
              ?assert(string:str(Text, "run 'reltree' or 'reltree --help'") > 0),
              ?assertEqual(0, string:str(Text, "skill --install")),
              ?assertEqual(0, string:str(Text, "reltree tree")),
              ?assertEqual(0, string:str(Text, "reltree checkvsn")),
              ?assertEqual(0, string:str(Text, "reltree bgate"))
      end,
      [["tree"], ["checkvsn"], ["bgate"], ["unknown"]]),
    ?assertNot(filelib:is_dir(Root)).

invalid_install_arguments_are_usage_errors_test() ->
    Root = unique_root(),
    ArgsList = [["--dest"],
                ["--dest", ""],
                ["--force=yes"],
                ["--force", "--force"],
                ["--dest", "one", "--dest", "two"],
                ["extra"]],
    lists:foreach(
      fun(Args) ->
              {Exit, _Output} = rebar3_reltree_cli:run(
                                  Args, #{priv_dir => Root}),
              ?assertEqual(2, Exit)
      end, ArgsList),
    ?assertNot(filelib:is_dir(Root)).

source_failure_is_runtime_error_test() ->
    {Priv, _Source, Root} = package_fixture("cli-source-error"),
    try
        ok = file:delete(filename:join([Priv, "skills", "reltree", "SKILL.md"])),
        Dest = filename:join(Root, "dest"),
        {Exit, Output} = rebar3_reltree_cli:run(
                           ["--dest", Dest],
                           #{priv_dir => Priv}),
        Text = lists:flatten(Output),
        ?assertEqual(1, Exit),
        ?assert(string:str(Text, "source_validation") > 0),
        ?assertNot(filelib:is_dir(Dest))
    after
        remove_fixture(Root)
    end.

package_fixture(Name) ->
    Root = filename:join("/tmp", "reltree-task10-cli-" ++ Name ++ "-" ++
                         integer_to_list(erlang:unique_integer([positive]))),
    Priv = filename:join(Root, "priv"),
    Source = filename:join([Priv, "skills", "reltree"]),
    ok = filelib:ensure_dir(filename:join(Source, "placeholder")),
    ok = file:make_dir(filename:join(Source, "agents")),
    ok = file:write_file(filename:join(Source, "SKILL.md"), <<"skill\n">>),
    ok = file:write_file(filename:join(Source, "agents/openai.yaml"),
                         <<"agent\n">>),
    {Priv, Source, Root}.

package_bytes(Source) ->
    [{"SKILL.md", read(filename:join(Source, "SKILL.md"))},
     {"agents/openai.yaml", read(filename:join(Source, "agents/openai.yaml"))}].

installed_bytes(Target) ->
    [{"SKILL.md", read(filename:join(Target, "SKILL.md"))},
     {"agents/openai.yaml", read(filename:join(Target, "agents/openai.yaml"))}].

entries(Path) ->
    {ok, Names} = file:list_dir(Path),
    lists:sort(Names).

sibling_entries(Parent) ->
    {ok, Names} = file:list_dir(Parent),
    [Name || Name <- Names,
             lists:prefix(".reltree-", Name)].

read(Path) ->
    {ok, Bytes} = file:read_file(Path),
    Bytes.

unique_root() ->
    filename:join("/tmp", "reltree-task10-cli-root-" ++
                         integer_to_list(erlang:unique_integer([positive]))).

remove_fixture(Root) ->
    remove_path(Root),
    ok.

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

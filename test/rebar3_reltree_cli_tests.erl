-module(rebar3_reltree_cli_tests).

-include_lib("eunit/include/eunit.hrl").

top_help_test() ->
    Root = unique_root(),
    {Exit, Output} = rebar3_reltree_cli:run(["--help"], context(Root)),
    ?assertEqual(0, Exit),
    ?assert(string:str(lists:flatten(Output), "tree") > 0),
    ?assertNot(filelib:is_dir(output_dir(Root))).

tree_help_test() ->
    Root = unique_root(),
    {Exit, Output} = rebar3_reltree_cli:run(["tree", "--help"], context(Root)),
    Text = lists:flatten(Output),
    ?assertEqual(0, Exit),
    ?assert(string:str(Text, "--scan-roots PATH[:deep]") > 0),
    ?assert(string:str(Text, "--rev false|auto|true") > 0),
    ?assertNot(filelib:is_dir(output_dir(Root))).

current_project_failure_is_fatal_without_writes_test() ->
    Root = unique_root(),
    {Exit, Output} = rebar3_reltree_cli:run(["tree", "--rev", "false"],
                                             context(Root)),
    ?assertEqual(1, Exit),
    ?assert(string:str(lists:flatten(Output), "current_project") > 0),
    ?assertNot(filelib:is_dir(output_dir(Root))),
    ?assertNot(filelib:is_regular(filename:join(output_dir(Root), "project.md"))).

default_tree_current_project_failure_test() ->
    Root = unique_root(),
    {Exit, Output} = rebar3_reltree_cli:run(["tree"], context(Root)),
    ?assertEqual(1, Exit),
    ?assert(string:str(lists:flatten(Output), "current_project") > 0).

invalid_revision_is_exit_two_test() ->
    Root = unique_root(),
    {Exit, Output} = rebar3_reltree_cli:run(
                       ["tree", "--rev", "invalid"], context(Root)),
    ?assertEqual(2, Exit),
    ?assert(string:str(lists:flatten(Output), "rev") > 0),
    ?assert(string:str(lists:flatten(Output), "invalid") > 0),
    ?assertNot(filelib:is_dir(output_dir(Root))).

invalid_arguments_are_exit_two_test() ->
    Root = unique_root(),
    ?assertMatch({2, _}, rebar3_reltree_cli:run(["tree", "--root", "x"],
                                                  context(Root))),
    ?assertMatch({2, _}, rebar3_reltree_cli:run(["tree", "extra"],
                                                  context(Root))),
    ?assertNot(filelib:is_dir(output_dir(Root))).

configured_options_are_loaded_test() ->
    Root = unique_root(),
    Context = (context(Root))#{
                 config_options => [{scan_roots, []}, {rev, true}]},
    {Exit, Output} = rebar3_reltree_cli:run(["tree"], Context),
    ?assertEqual(1, Exit),
    ?assert(string:str(lists:flatten(Output), "current_project") > 0),
    ?assertNot(filelib:is_dir(output_dir(Root))).

missing_config_is_empty_test() ->
    Root = unique_root(),
    ?assertEqual({ok, []}, rebar3_reltree_cli:load_config(Root)).

config_file_uses_last_top_level_value_test() ->
    Root = make_fixture("{reltree, []}.\n{reltree, []}.\n"),
    try
        {Exit, Output} = rebar3_reltree_cli:run(["tree"], #{cwd => Root}),
        ?assertEqual(1, Exit),
        ?assert(string:str(lists:flatten(Output), "current_project") > 0),
        ?assertNot(filelib:is_dir(output_dir(Root)))
    after
        remove_fixture(Root)
    end.

configured_invalid_root_fails_without_writes_test() ->
    Root = unique_root(),
    Context = (context(Root))#{config_options => [{scan_roots, [[]]}]},
    {Exit, Output} = rebar3_reltree_cli:run(["tree"], Context),
    ?assertEqual(2, Exit),
    ?assert(string:str(lists:flatten(Output), "invalid reltree config") > 0),
    ?assert(string:str(lists:flatten(Output), "scan_roots") > 0),
    ?assertNot(filelib:is_dir(output_dir(Root))).

malformed_config_fails_before_dispatch_test() ->
    Root = make_fixture("{reltree, [}.\n"),
    try
        {Exit, Output} = rebar3_reltree_cli:run(["tree"], #{cwd => Root}),
        ?assertEqual(2, Exit),
        ?assert(string:str(lists:flatten(Output), "config") > 0),
        ?assertNot(filelib:is_dir(output_dir(Root)))
    after
        remove_fixture(Root)
    end.

cli_dispatches_valid_project_and_writes_report_test() ->
    Root = rebar3_reltree_fixtures:new_root(),
    try
        rebar3_reltree_fixtures:write_project(Root, cli_fixture, [], "0.1.0"),
        {Exit, Output} = rebar3_reltree_cli:run(["tree"], #{cwd => Root}),
        ?assertEqual(0, Exit),
        ?assertEqual([], Output),
        Report = filename:join([Root, "_build", "default", "reltree",
                                "project.md"]),
        ?assert(filelib:is_regular(Report)),
        {ok, Bytes} = file:read_file(Report),
        ?assert(string:str(binary_to_list(Bytes), "network_sync_at") > 0)
    after
        rebar3_reltree_fixtures:cleanup(Root)
    end.

context(Root) ->
    #{cwd => Root,
      project_root => Root,
      build_base_dir => filename:join([Root, "_build", "default"]),
      config_options => [],
      profile => default}.

output_dir(Root) ->
    filename:join([Root, "_build", "default", "reltree"]).

unique_root() ->
    filename:join("/tmp", "reltree-task1-cli-" ++
                         integer_to_list(erlang:unique_integer([positive]))).

make_fixture(Content) ->
    Root = unique_root(),
    ok = file:make_dir(Root),
    ok = file:write_file(filename:join(Root, "rebar.config"), Content),
    Root.

remove_fixture(Root) ->
    _ = file:delete(filename:join(Root, "rebar.config")),
    _ = file:del_dir(Root),
    ok.

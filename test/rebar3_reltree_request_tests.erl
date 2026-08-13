-module(rebar3_reltree_request_tests).

-include_lib("eunit/include/eunit.hrl").

default_request_test() ->
    {ok, Request} = rebar3_reltree_request:normalize(context([])),
    ?assertEqual(tree, maps:get(command, Request)),
    ?assertEqual("/workspace/project", maps:get(project_root, Request)),
    ?assertEqual(default, maps:get(profile, Request)),
    ?assertEqual("/workspace/project/_build/default",
                 maps:get(build_base_dir, Request)),
    ?assertEqual("/workspace/project/_build/default/reltree/project.md",
                 maps:get(output_path, Request)),
    ?assertEqual([{ "/workspace", shallow}], maps:get(scan_roots, Request)),
    ?assertEqual(auto, maps:get(rev, Request)).

configured_values_test() ->
    Config = [{scan_roots, ["../one", {"../two", deep}]}, {rev, false}],
    {ok, Request} = rebar3_reltree_request:normalize(context(Config)),
    ?assertEqual([{ "/workspace/one", shallow},
                  { "/workspace/two", deep}], maps:get(scan_roots, Request)),
    ?assertEqual(false, maps:get(rev, Request)).

cli_precedence_and_deduplication_test() ->
    Context = (context([{scan_roots, ["../configured"]}, {rev, false}]))#{
                 cli_scan_roots => ["../first", "../first", "../second:deep"],
                 cli_rev => "true"},
    {ok, Request} = rebar3_reltree_request:normalize(Context),
    ?assertEqual([{ "/workspace/first", shallow},
                  { "/workspace/second", deep}], maps:get(scan_roots, Request)),
    ?assertEqual(true, maps:get(rev, Request)).

empty_configured_roots_test() ->
    {ok, Request} = rebar3_reltree_request:normalize(
                       context([{scan_roots, []}])),
    ?assertEqual([], maps:get(scan_roots, Request)).

relative_paths_are_lexical_test() ->
    Context = (context([]))#{cli_scan_roots => ["does-not-exist/../new"]},
    {ok, Request} = rebar3_reltree_request:normalize(Context),
    ?assertEqual([{ "/workspace/project/new", shallow}],
                 maps:get(scan_roots, Request)).

same_mode_duplicate_is_collapsed_test() ->
    Context = (context([]))#{cli_scan_roots => ["../one", "/workspace/one"]},
    {ok, Request} = rebar3_reltree_request:normalize(Context),
    ?assertEqual([{ "/workspace/one", shallow}], maps:get(scan_roots, Request)).

contradictory_modes_fail_test() ->
    Context = (context([]))#{cli_scan_roots => ["../one", "../one:deep"]},
    ?assertMatch({error, {conflicting_roots, "/workspace/one", shallow, deep}},
                 rebar3_reltree_request:normalize(Context)).

invalid_configured_root_fails_test() ->
    ?assertMatch({error, {invalid_config, scan_roots, [{bad, root}]}},
                 rebar3_reltree_request:normalize(
                   context([{scan_roots, [{bad, root}]}]))).

empty_configured_root_fails_as_config_test() ->
    ?assertMatch({error, {invalid_config, scan_roots, []}},
                 rebar3_reltree_request:normalize(
                   context([{scan_roots, [[]]}]))).

malformed_configured_path_fails_as_config_test() ->
    ?assertMatch({error, {invalid_config, scan_roots, [bad]}},
                 rebar3_reltree_request:normalize(
                   context([{scan_roots, [[bad]]}]))).

malformed_deep_configured_root_fails_test() ->
    ?assertMatch({error, {invalid_config, scan_roots, [ {"../one", shallow} ]}},
                 rebar3_reltree_request:normalize(
                   context([{scan_roots, [{"../one", shallow}]}]))).

invalid_configured_revision_fails_test() ->
    ?assertMatch({error, {invalid_config, rev, "auto"}},
                 rebar3_reltree_request:normalize(context([{rev, "auto"}]))).

invalid_cli_revision_fails_test() ->
    ?assertMatch({error, {invalid_option, rev, "invalid"}},
                 rebar3_reltree_request:normalize(
                   (context([]))#{cli_rev => "invalid"})).

invalid_cli_root_fails_test() ->
    ?assertMatch({error, {invalid_option, scan_roots, ":deep"}},
                 rebar3_reltree_request:normalize(
                   (context([]))#{cli_scan_roots => [":deep"]})).

cli_parser_success_test() ->
    ?assertEqual(
       {ok, #{cli_scan_roots => ["one", "two:deep"], cli_rev => "false"}},
       rebar3_reltree_request:parse_cli(
         ["tree", "--scan-roots", "one", "--scan-roots", "two:deep",
          "--rev", "false"])).

cli_parser_help_test() ->
    ?assertEqual({help, top}, rebar3_reltree_request:parse_cli([])),
    ?assertEqual({help, top}, rebar3_reltree_request:parse_cli(["--help"])),
    ?assertEqual({help, tree}, rebar3_reltree_request:parse_cli(["tree", "--help"])),
    ?assertEqual({help, bgate}, rebar3_reltree_request:parse_cli(
                                  ["bgate", "--help"])).

bgate_parser_and_normalization_test() ->
    ?assertEqual({ok, #{command => bgate, mode => check}},
                 rebar3_reltree_request:parse_cli(["bgate", "--check"])),
    ?assertEqual({ok, #{command => bgate, mode => write}},
                 rebar3_reltree_request:parse_cli(["bgate", "--write"])),
    ?assertEqual({ok, #{command => bgate, mode => write, tag => true}},
                 rebar3_reltree_request:parse_cli(
                   ["bgate", "--write", "--tag"])),
    ?assertEqual({ok, #{command => bgate, mode => write, tag => true}},
                 rebar3_reltree_request:parse_cli(
                   ["bgate", "--tag", "--write"])),
    ?assertMatch({error, {invalid_mode, missing}},
                 rebar3_reltree_request:parse_cli(["bgate"])),
    ?assertMatch({error, {invalid_mode, missing}},
                 rebar3_reltree_request:parse_cli(["bgate", "--tag"])),
    ?assertMatch({error, {conflicting_modes, _, _}},
                 rebar3_reltree_request:parse_cli(
                   ["bgate", "--check", "--write"])),
    ?assertMatch({error, {duplicate_option, check}},
                 rebar3_reltree_request:parse_cli(
                   ["bgate", "--check", "--check"])),
    ?assertMatch({error, {extra_argument, _}},
                 rebar3_reltree_request:parse_cli(["bgate", "--check", "x"])),
    ?assertMatch({error, {invalid_option, _, _}},
                 rebar3_reltree_request:parse_cli(["bgate", "--check=true"])),
    ?assertMatch({error, {tag_requires_write, check}},
                 rebar3_reltree_request:parse_cli(
                   ["bgate", "--check", "--tag"])),
    ?assertMatch({error, {tag_requires_write, check}},
                 rebar3_reltree_request:parse_cli(
                   ["bgate", "--tag", "--check"])),
    ?assertMatch({error, {duplicate_option, tag}},
                 rebar3_reltree_request:parse_cli(
                   ["bgate", "--write", "--tag", "--tag"])),
    ?assertMatch({error, {invalid_option, _, _}},
                 rebar3_reltree_request:parse_cli(
                   ["bgate", "--write", "--tag=true"])),
    {ok, Request} = rebar3_reltree_request:normalize_bgate(
                      #{cwd => "/workspace/project", mode => check}),
    ?assertEqual(bgate, maps:get(command, Request)),
    ?assertEqual(check, maps:get(mode, Request)),
    ?assertEqual("/workspace/project", maps:get(project_root, Request)),
    {ok, TagRequest} = rebar3_reltree_request:normalize_bgate(
                         #{cwd => "/workspace/project", mode => write,
                           tag => true}),
    ?assertEqual(bgate, maps:get(command, TagRequest)),
    ?assertEqual(write, maps:get(mode, TagRequest)),
    ?assertEqual(true, maps:get(tag, TagRequest)),
    {ok, PlainRequest} = rebar3_reltree_request:normalize_bgate(
                           #{cwd => "/workspace/project", mode => write}),
    ?assertNot(maps:is_key(tag, PlainRequest)).

cli_parser_failures_test() ->
    ?assertMatch({error, {invalid_command, "other"}},
                 rebar3_reltree_request:parse_cli(["other"])),
    ?assertMatch({error, {invalid_option, root, "--root"}},
                 rebar3_reltree_request:parse_cli(["tree", "--root", "x"])),
    ?assertMatch({error, {extra_argument, "extra"}},
                 rebar3_reltree_request:parse_cli(["tree", "extra"])),
    ?assertMatch({error, {duplicate_option, rev}},
                 rebar3_reltree_request:parse_cli(
                   ["tree", "--rev", "false", "--rev", "true"])),
    ?assertMatch({error, {missing_option_value, scan_roots}},
                 rebar3_reltree_request:parse_cli(["tree", "--scan-roots"])),
    ?assertMatch({error, {invalid_option, scan_roots, ":deep"}},
                 rebar3_reltree_request:parse_cli(
                   ["tree", "--scan-roots", ":deep"])).

last_top_level_config_wins_test() ->
    ?assertEqual({ok, [{rev, true}]},
                 rebar3_reltree_request:extract_config(
                   [{reltree, [{rev, "invalid"}]},
                    {reltree, [{rev, true}]}])).

duplicate_relevant_config_key_test() ->
    ?assertEqual({error, {duplicate_config, scan_roots}},
                 rebar3_reltree_request:extract_config(
                   [{reltree, [{scan_roots, []}, {scan_roots, []}]}])).

malformed_config_container_test() ->
    ?assertMatch({error, {invalid_config, options, bad}},
                 rebar3_reltree_request:extract_config([{reltree, bad}])),
    ?assertMatch({error, {invalid_config, options, bad}},
                 rebar3_reltree_request:extract_config([{reltree, [bad]}])).

parse_root_test() ->
    ?assertEqual({ok, {"path", shallow}},
                 rebar3_reltree_request:parse_cli_root("path")),
    ?assertEqual({ok, {"path", deep}},
                 rebar3_reltree_request:parse_cli_root("path:deep")),
    ?assertEqual({error, {invalid_option, scan_roots, ":deep"}},
                 rebar3_reltree_request:parse_cli_root(":deep")).

context(ConfigOptions) ->
    #{cwd => "/workspace/project",
      project_root => "/workspace/project",
      profile => default,
      build_base_dir => "/workspace/project/_build/default",
      config_options => ConfigOptions,
      cli_scan_roots => undefined,
      cli_rev => undefined}.

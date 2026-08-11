-module(rebar3_reltree_cli).

-export([main/1, run/1, run/2, help/1, load_config/1]).

-spec main([string()]) -> no_return().
main(Args) ->
    {Exit, Output} = run(Args),
    io:put_chars(Output),
    erlang:halt(Exit).

-spec run([string()]) -> {non_neg_integer(), iolist()}.
run(Args) ->
    case file:get_cwd() of
        {ok, Cwd} -> run(Args, #{cwd => Cwd});
        {error, Reason} ->
            {2, ["reltree: ", rebar3_reltree_request:format_error(
                              {config_read, ".", Reason}), "\n"]}
    end.

-spec run([string()], map()) -> {non_neg_integer(), iolist()}.
run(Args, Context0) when is_list(Args), is_map(Context0) ->
    case rebar3_reltree_request:parse_cli(Args) of
        {help, Kind} ->
            {0, help(Kind)};
        {error, Reason} ->
            {2, error_output(Reason)};
        {ok, Cli} ->
            case maps:get(command, Cli, tree) of
                bgate ->
                    run_bgate(Cli, Context0);
                tree ->
                    run_tree(Cli, Context0)
            end
    end.

-spec help(top | tree | bgate) -> iolist().
help(top) ->
    ["Usage: reltree <command> [options]\n\n",
    "Commands:\n",
     "  tree   inspect the local project tree\n",
     "  bgate  check or update local CI badges\n\n",
     "Run 'reltree tree --help' or 'reltree bgate --help' for options.\n"];
help(tree) ->
    ["Usage: reltree tree [options]\n\n",
     "Options:\n",
     "  --scan-roots PATH[:deep]  repeatable; replaces configured roots\n",
     "  --rev false|auto|true     revision lookup policy\n\n",
     "Defaults: scan root '..' shallow; rev auto.\n",
     "Output: _build/<profile>/reltree/project.md\n"];

help(bgate) ->
    ["Usage: reltree bgate [options]\n\n",
     "Options (exactly one required):\n",
     "  --check  verify local README CI badges\n",
     "  --write  update local README CI badges\n"].

-spec load_config(string()) -> {ok, list()} | {error, term()}.
load_config(Cwd) ->
    Path = filename:join(Cwd, "rebar.config"),
    case file:consult(Path) of
        {ok, Terms} ->
            rebar3_reltree_request:extract_config(Terms);
        {error, enoent} ->
            {ok, []};
        {error, {enoent, _}} ->
            {ok, []};
        {error, Reason} ->
            {error, {config_read, Path, Reason}}
    end.

config_for(Context) ->
    case maps:find(config_options, Context) of
        {ok, Config} ->
            rebar3_reltree_request:extract_config([{reltree, Config}]);
        error ->
            case maps:find(cwd, Context) of
                {ok, Cwd} -> load_config(Cwd);
                error -> {error, {invalid_context, cwd, missing}}
            end
    end.

error_output(Reason) ->
    ["reltree: ", rebar3_reltree_request:format_error(Reason), "\n"].

run_tree(Cli, Context0) ->
    case config_for(Context0) of
        {ok, ConfigOptions} ->
            Context = maps:merge(
                #{project_root => maps:get(cwd, Context0, "."),
                  build_base_dir => filename:join(
                    [maps:get(cwd, Context0, "."), "_build", "default"]),
                  profile => default,
                  cli_scan_roots => maps:get(cli_scan_roots, Cli),
                  cli_rev => maps:get(cli_rev, Cli)}, Context0),
            case rebar3_reltree_request:normalize(
                   Context#{config_options => ConfigOptions}) of
                {ok, Request} ->
                    case rebar3_reltree:dispatch_tree(Request) of
                        {error, Reason} ->
                            {1, error_output(Reason)};
                        {ok, _Result} ->
                            {0, []}
                    end;
                {error, Reason} ->
                    {2, error_output(Reason)}
            end;
        {error, Reason} ->
            {2, error_output(Reason)}
    end.

run_bgate(Cli, Context0) ->
    Cwd = maps:get(cwd, Context0, "."),
    case rebar3_reltree_request:normalize_bgate(
           #{cwd => Cwd, mode => maps:get(mode, Cli)}) of
        {ok, Request} ->
            case rebar3_reltree:dispatch_bgate(Request) of
                {error, Reason} ->
                    {1, error_output(Reason)};
                {ok, Result} ->
                    {0, rebar3_reltree_badge:format_result(Result)}
            end;
        {error, Reason} ->
            {2, error_output(Reason)}
    end.

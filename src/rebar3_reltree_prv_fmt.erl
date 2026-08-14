-module(rebar3_reltree_prv_fmt).
-behaviour(provider).

-export([init/1, do/1, format_error/1, option_spec/0, help/0, file_set/1]).

-define(SKIP_NAMES, [".git", "_build", "_checkouts", "deps", "node_modules"]).

-define(DEFAULT_FILES, [
    "{src,include,test}/*.{hrl,erl,app.src}",
    "rebar.config"
]).

-spec init(term()) -> {ok, term()}.
init(State) ->
    {ok, State}.

-spec option_spec() -> [tuple()].
option_spec() ->
    [
        {check, $c, "check", undefined, "Check formatting without modifying files."}
    ].

-spec do(term()) -> term().
do(State) ->
    case command_mode(State) of
        help ->
            io:put_chars(help()),
            {ok, State};
        {ok, check} ->
            run_check(State);
        {error, Reason} ->
            provider_error(Reason)
    end.

-spec format_error(term()) -> iolist().
format_error({rebar3_reltree_prv_fmt, Reason}) ->
    ["reltree fmt: ", reason_text(Reason), "\n"];
format_error(Reason) ->
    ["reltree fmt: ", reason_text(Reason), "\n"].

-spec help() -> iolist().
help() ->
    [
        "Usage: rebar3 reltree fmt --check\n\n",
        "Proxy for rebar3 fmt --check with the file set required by\n",
        "~/.agents/AGENT.md: erlfmt defaults plus *.escript and\n",
        "rebar.config.script. --write is intentionally not supported;\n",
        "format with `rebar3 fmt -w <files>` yourself.\n"
    ].

-spec file_set(filename:filename_all()) -> [string()].
file_set(Root) ->
    ?DEFAULT_FILES ++ extra_files(Root).

command_mode(State) ->
    case command_args(State) of
        ["fmt" | Rest] ->
            mode_from_args(Rest);
        Rest when is_list(Rest) ->
            mode_from_args(Rest)
    end.

mode_from_args(["--help"]) ->
    help;
mode_from_args(["--check"]) ->
    {ok, check};
mode_from_args(["-c"]) ->
    {ok, check};
mode_from_args(["--write" | _]) ->
    {error, write_unsupported};
mode_from_args(["-w" | _]) ->
    {error, write_unsupported};
mode_from_args([]) ->
    {error, mode_missing};
mode_from_args(_) ->
    {error, invalid_arguments}.

command_args(State) ->
    case rebar_state:command_args(State) of
        Args when is_list(Args) ->
            Args;
        _ ->
            []
    end.

run_check(State) ->
    Root = rebar_state:dir(State),
    case fmt_plugin_available() of
        false ->
            provider_error(erlfmt_unavailable);
        true ->
            Files = file_set(Root),
            Config0 = rebar_state:get(State, erlfmt, []),
            State1 = rebar_state:set(
                State,
                erlfmt,
                Config0 ++ [{files, Files}]
            ),
            io:put_chars("reltree fmt: checking erlfmt style\n"),
            erlang:apply(rebar3_fmt_prv, do, [State1])
    end.

fmt_plugin_available() ->
    case code:ensure_loaded(rebar3_fmt_prv) of
        {module, rebar3_fmt_prv} ->
            erlang:function_exported(rebar3_fmt_prv, do, 1);
        _ ->
            false
    end.

extra_files(Root0) ->
    Root = rebar3_reltree_fs:canonical(Root0),
    Escripts = escript_files(Root, Root, []),
    ConfigScript =
        case
            rebar3_reltree_fs:regular(
                filename:join(Root, "rebar.config.script")
            )
        of
            true -> ["rebar.config.script"];
            false -> []
        end,
    lists:sort(Escripts ++ ConfigScript).

escript_files(Root, Dir, Acc) ->
    case rebar3_reltree_fs:list_dir(Dir) of
        {ok, Names} ->
            lists:foldl(
                fun(Name, Acc0) ->
                    case lists:member(Name, ?SKIP_NAMES) of
                        true ->
                            Acc0;
                        false ->
                            scan_entry(
                                Root,
                                filename:join(Dir, Name),
                                Acc0
                            )
                    end
                end,
                Acc,
                Names
            );
        {error, _} ->
            Acc
    end.

scan_entry(Root, Path, Acc) ->
    case rebar3_reltree_fs:directory(Path) of
        true ->
            escript_files(Root, Path, Acc);
        false ->
            case rebar3_reltree_fs:regular(Path) of
                true ->
                    case filename:extension(Path) of
                        ".escript" ->
                            [relative_to(Root, Path) | Acc];
                        _ ->
                            Acc
                    end;
                false ->
                    Acc
            end
    end.

relative_to(Root, Path) ->
    RootParts = filename:split(filename:absname(Root)),
    PathParts = filename:split(filename:absname(Path)),
    case lists:prefix(RootParts, PathParts) of
        true ->
            filename:join(lists:nthtail(length(RootParts), PathParts));
        false ->
            Path
    end.

provider_error(Reason) ->
    {error, {?MODULE, Reason}}.

reason_text(write_unsupported) ->
    "--write is not supported; run `rebar3 fmt -w` to write";
reason_text(mode_missing) ->
    "missing mode; use --check";
reason_text(invalid_arguments) ->
    "only --check is supported";
reason_text(erlfmt_unavailable) ->
    "rebar3 fmt (the erlfmt plugin) is not installed";
reason_text(Reason) ->
    lists:flatten(io_lib:format("~tp", [Reason])).

-module(rebar3_reltree_request).

-export([
    extract_config/1,
    normalize/1,
    normalize_bgate/1,
    parse_cli/1,
    parse_cli_root/1,
    format_error/1
]).

-define(DEFAULT_ROOT, "..").
-define(DEFAULT_REV, auto).

%% The request module is deliberately independent of Rebar3 and the
%% filesystem.  Adapters supply cwd, config, profile, and build context.

-spec extract_config(term()) -> {ok, list()} | {error, term()}.
extract_config(Terms) when is_list(Terms) ->
    Reltree = [
        Term
     || Term <- Terms,
        is_tuple(Term),
        tuple_size(Term) >= 1,
        element(1, Term) =:= reltree
    ],
    case lists:reverse(Reltree) of
        [] ->
            {ok, []};
        [{reltree, Options} | _Earlier] ->
            validate_config_options(Options);
        [Malformed | _Earlier] ->
            {error, {invalid_config, reltree, Malformed}}
    end;
extract_config(Other) ->
    {error, {invalid_config, reltree, Other}}.

-spec normalize(map()) -> {ok, map()} | {error, term()}.
normalize(Context) when is_map(Context) ->
    case required_context(Context) of
        {ok, ProjectRoot0, Cwd0, Profile, BuildBase0, ConfigOptions, CliRoots, CliRev} ->
            case valid_profile(Profile) of
                true ->
                    case absolute_path(ProjectRoot0, Cwd0) of
                        {ok, ProjectRoot} ->
                            case absolute_path(BuildBase0, ProjectRoot) of
                                {ok, BuildBase} ->
                                    normalize_configured(
                                        ProjectRoot,
                                        Profile,
                                        BuildBase,
                                        ConfigOptions,
                                        CliRoots,
                                        CliRev
                                    );
                                {error, _} = Error ->
                                    Error
                            end;
                        {error, _} = Error ->
                            Error
                    end;
                false ->
                    {error, {invalid_context, profile, Profile}}
            end;
        {error, _} = Error ->
            Error
    end;
normalize(Other) ->
    {error, {invalid_context, request, Other}}.

-spec parse_cli([term()]) ->
    {ok, map()} | {help, top | tree} | {error, term()}.
parse_cli([]) ->
    {help, top};
parse_cli(["--help"]) ->
    {help, top};
parse_cli(["-h"]) ->
    {help, top};
parse_cli(["tree" | Args]) ->
    parse_tree_args(Args, undefined, undefined);
parse_cli(["bgate" | Args]) ->
    parse_bgate_args(Args);
parse_cli([Command | _]) ->
    {error, {invalid_command, Command}}.

-spec normalize_bgate(map()) -> {ok, map()} | {error, term()}.
normalize_bgate(Context) when is_map(Context) ->
    case {maps:find(cwd, Context), maps:find(mode, Context)} of
        {{ok, Cwd}, {ok, Mode}} when is_list(Cwd) ->
            case Mode of
                check ->
                    {ok, #{
                        command => bgate,
                        mode => check,
                        project_root => filename:absname(Cwd)
                    }};
                write ->
                    Request0 = #{
                        command => bgate,
                        mode => write,
                        project_root => filename:absname(Cwd)
                    },
                    Request =
                        case maps:get(tag, Context, false) of
                            true -> Request0#{tag => true};
                            _ -> Request0
                        end,
                    {ok, Request};
                _ ->
                    {error, {invalid_context, mode, Mode}}
            end;
        _ ->
            {error, {invalid_context, missing, bgate_request}}
    end;
normalize_bgate(Other) ->
    {error, {invalid_context, request, Other}}.

-spec parse_cli_root(term()) ->
    {ok, {term(), shallow | deep}} | {error, term()}.
parse_cli_root(Path) when is_list(Path), Path =/= [] ->
    case terminal_deep(Path) of
        true ->
            PlainPath = lists:sublist(Path, length(Path) - 5),
            case PlainPath of
                [] -> {error, {invalid_option, scan_roots, Path}};
                _ -> {ok, {PlainPath, deep}}
            end;
        false ->
            {ok, {Path, shallow}}
    end;
parse_cli_root(Path) ->
    {error, {invalid_option, scan_roots, Path}}.

-spec format_error(term()) -> iolist().
format_error({invalid_command, Command}) ->
    io_lib:format("unknown command ~p; use 'tree' or 'bgate'", [Command]);
format_error({invalid_mode, Detail}) ->
    io_lib:format("invalid bgate mode: ~p", [Detail]);
format_error({conflicting_modes, First, Second}) ->
    io_lib:format(
        "bgate modes --~ts and --~ts cannot be combined",
        [First, Second]
    );
format_error({tag_requires_write, Mode}) ->
    io_lib:format("bgate option --tag requires --write (mode ~p)", [Mode]);
format_error({invalid_option, Option, Value}) ->
    io_lib:format("invalid ~p value ~p", [Option, Value]);
format_error({missing_option_value, Option}) ->
    io_lib:format("option --~ts requires a value", [option_name(Option)]);
format_error({duplicate_option, Option}) ->
    io_lib:format("option --~ts may be specified only once", [option_name(Option)]);
format_error({extra_argument, Argument}) ->
    io_lib:format("unexpected argument ~p", [Argument]);
format_error({duplicate_config, Key}) ->
    io_lib:format("duplicate reltree config key ~p", [Key]);
format_error({invalid_config, Key, Value}) ->
    io_lib:format("invalid reltree config ~p value ~p", [Key, Value]);
format_error({conflicting_roots, Path, ExistingMode, NewMode}) ->
    io_lib:format(
        "scan root ~ts has conflicting modes ~p and ~p",
        [Path, ExistingMode, NewMode]
    );
format_error({invalid_context, Key, Value}) ->
    io_lib:format("invalid request context ~p value ~p", [Key, Value]);
format_error({config_read, Path, Reason}) ->
    io_lib:format("cannot read config ~ts: ~p", [Path, Reason]);
format_error({bgate, Reason}) ->
    rebar3_reltree_badge:format_error(Reason);
format_error(Reason) ->
    io_lib:format("reltree request failed: ~p", [Reason]).

required_context(Context) ->
    case
        {
            maps:find(project_root, Context),
            maps:find(profile, Context),
            maps:find(build_base_dir, Context),
            maps:find(config_options, Context),
            maps:find(cli_scan_roots, Context),
            maps:find(cli_rev, Context)
        }
    of
        {
            {ok, ProjectRoot},
            {ok, Profile},
            {ok, BuildBase},
            {ok, ConfigOptions},
            {ok, CliRoots},
            {ok, CliRev}
        } ->
            Cwd = maps:get(cwd, Context, ProjectRoot),
            {ok, ProjectRoot, Cwd, Profile, BuildBase, ConfigOptions, CliRoots, CliRev};
        _ ->
            {error, {invalid_context, missing, request}}
    end.

normalize_configured(
    ProjectRoot,
    Profile,
    BuildBase,
    ConfigOptions,
    CliRoots,
    CliRev
) ->
    case validate_config_options(ConfigOptions) of
        {ok, ValidOptions} ->
            ConfigRoots = config_value(scan_roots, ValidOptions),
            ConfigRev = config_value(rev, ValidOptions),
            Roots0 =
                case CliRoots of
                    undefined ->
                        case ConfigRoots of
                            undefined -> [{?DEFAULT_ROOT, shallow}];
                            Value -> configured_roots(Value)
                        end;
                    Values when is_list(Values) ->
                        cli_roots(Values);
                    Other ->
                        {error, {invalid_option, scan_roots, Other}}
                end,
            case Roots0 of
                {error, _} = Error ->
                    Error;
                Roots ->
                    case normalize_roots(Roots, ProjectRoot) of
                        {ok, NormalizedRoots} ->
                            case effective_rev(CliRev, ConfigRev) of
                                {ok, Rev} ->
                                    {ok, #{
                                        command => tree,
                                        project_root => ProjectRoot,
                                        profile => Profile,
                                        build_base_dir => BuildBase,
                                        output_path => lexical_join(
                                            BuildBase, "reltree/project.md"
                                        ),
                                        scan_roots => NormalizedRoots,
                                        rev => Rev
                                    }};
                                {error, _} = Error ->
                                    Error
                            end;
                        {error, _} = Error ->
                            Error
                    end
            end;
        {error, _} = Error ->
            Error
    end.

parse_tree_args([], Roots, Rev) ->
    {ok, #{cli_scan_roots => Roots, cli_rev => Rev}};
parse_tree_args(["--help" | _], _Roots, _Rev) ->
    {help, tree};
parse_tree_args(["-h" | _], _Roots, _Rev) ->
    {help, tree};
parse_tree_args(["--scan-roots"], _Roots, _Rev) ->
    {error, {missing_option_value, scan_roots}};
parse_tree_args(["--scan-roots", Value | Rest], Roots, Rev) ->
    case lists:prefix("--", Value) of
        true ->
            {error, {missing_option_value, scan_roots}};
        false ->
            case parse_cli_root(Value) of
                {ok, _} ->
                    NextRoots =
                        case Roots of
                            undefined -> [Value];
                            Existing -> Existing ++ [Value]
                        end,
                    parse_tree_args(Rest, NextRoots, Rev);
                {error, _} = Error ->
                    Error
            end
    end;
parse_tree_args(["--rev"], _Roots, _Rev) ->
    {error, {missing_option_value, rev}};
parse_tree_args(["--rev", Value | Rest], Roots, undefined) ->
    case lists:prefix("--", Value) of
        true ->
            {error, {missing_option_value, rev}};
        false ->
            parse_tree_args(Rest, Roots, Value)
    end;
parse_tree_args(["--rev", _Value | _Rest], _Roots, _Rev) ->
    {error, {duplicate_option, rev}};
parse_tree_args([Option | _], _Roots, _Rev) when
    is_list(Option),
    Option =/= [],
    hd(Option) =:= $-
->
    {error, {invalid_option, option_atom(Option), Option}};
parse_tree_args([Argument | _], _Roots, _Rev) ->
    {error, {extra_argument, Argument}}.

parse_bgate_args(Args) ->
    parse_bgate_args(Args, undefined, false).

parse_bgate_args([], undefined, _Tag) ->
    {error, {invalid_mode, missing}};
parse_bgate_args([], check, _Tag) ->
    {ok, #{command => bgate, mode => check}};
parse_bgate_args([], write, false) ->
    {ok, #{command => bgate, mode => write}};
parse_bgate_args([], write, true) ->
    {ok, #{command => bgate, mode => write, tag => true}};
parse_bgate_args(["--help" | _], _Mode, _Tag) ->
    {help, bgate};
parse_bgate_args(["-h" | _], _Mode, _Tag) ->
    {help, bgate};
parse_bgate_args(["--check" | Rest], Mode, Tag) ->
    case {Mode, Tag} of
        {undefined, false} -> parse_bgate_args(Rest, check, Tag);
        {undefined, _} -> {error, {tag_requires_write, check}};
        {check, _} -> {error, {duplicate_option, check}};
        {write, _} -> {error, {conflicting_modes, "write", "check"}}
    end;
parse_bgate_args(["--write" | Rest], Mode, Tag) ->
    case Mode of
        undefined -> parse_bgate_args(Rest, write, Tag);
        write -> {error, {duplicate_option, write}};
        check -> {error, {conflicting_modes, "check", "write"}}
    end;
parse_bgate_args(["--tag" | Rest], Mode, Tag) ->
    case {Mode, Tag} of
        {write, false} -> parse_bgate_args(Rest, write, true);
        {_, true} -> {error, {duplicate_option, tag}};
        {undefined, _} -> parse_bgate_args(Rest, undefined, true);
        {check, _} -> {error, {tag_requires_write, check}}
    end;
parse_bgate_args([Option | _], _Mode, _Tag) when
    is_list(Option), Option =/= [], hd(Option) =:= $-
->
    {error, {invalid_option, option_atom(Option), Option}};
parse_bgate_args([Argument | _], _Mode, _Tag) ->
    {error, {extra_argument, Argument}}.

option_atom("--root") -> root;
option_atom("--project") -> project;
option_atom("--profile") -> profile;
option_atom(Option) -> Option.

option_name(scan_roots) -> "scan-roots";
option_name(rev) -> "rev";
option_name(Option) when is_atom(Option) -> atom_to_list(Option);
option_name(Option) -> io_lib:format("~p", [Option]).

configured_roots(Value) when is_list(Value) ->
    case lists:all(fun configured_root_term/1, Value) of
        true -> validate_configured_roots(Value, []);
        false -> {error, {invalid_config, scan_roots, Value}}
    end;
configured_roots(Value) ->
    {error, {invalid_config, scan_roots, Value}}.

validate_configured_roots([], Acc) ->
    lists:reverse(Acc);
validate_configured_roots([Root | Rest], Acc) ->
    {Path, Mode} = configured_root(Root),
    case valid_path(Path) of
        true ->
            validate_configured_roots(Rest, [{Path, Mode} | Acc]);
        false ->
            {error, {invalid_config, scan_roots, Path}}
    end.

configured_root(Path) when is_list(Path) ->
    {Path, shallow};
configured_root({Path, deep}) ->
    {Path, deep}.

configured_root_term(Path) when is_list(Path) ->
    true;
configured_root_term({Path, deep}) when is_list(Path) ->
    true;
configured_root_term(_) ->
    false.

cli_roots(Values) ->
    parse_cli_roots(Values, []).

parse_cli_roots([], Acc) ->
    lists:reverse(Acc);
parse_cli_roots([Value | Rest], Acc) ->
    case parse_cli_root(Value) of
        {ok, Root} -> parse_cli_roots(Rest, [Root | Acc]);
        {error, _} = Error -> Error
    end.

normalize_roots(Roots, ProjectRoot) ->
    normalize_roots(Roots, ProjectRoot, [], []).

normalize_roots([], _ProjectRoot, _Seen, Acc) ->
    {ok, lists:reverse(Acc)};
normalize_roots([{Path, Mode} | Rest], ProjectRoot, Seen, Acc) ->
    case valid_path(Path) of
        true ->
            case absolute_path(Path, ProjectRoot) of
                {ok, Absolute} ->
                    case lists:keyfind(Absolute, 1, Seen) of
                        false ->
                            normalize_roots(
                                Rest,
                                ProjectRoot,
                                [{Absolute, Mode} | Seen],
                                [{Absolute, Mode} | Acc]
                            );
                        {Absolute, Mode} ->
                            normalize_roots(Rest, ProjectRoot, Seen, Acc);
                        {Absolute, ExistingMode} ->
                            {error, {conflicting_roots, Absolute, ExistingMode, Mode}}
                    end;
                {error, _} = Error ->
                    Error
            end;
        false ->
            {error, {invalid_option, scan_roots, Path}}
    end;
normalize_roots([Other | _], _ProjectRoot, _Seen, _Acc) ->
    {error, {invalid_option, scan_roots, Other}}.

effective_rev(undefined, undefined) ->
    {ok, ?DEFAULT_REV};
effective_rev(undefined, ConfigRev) ->
    valid_config_rev(ConfigRev);
effective_rev(CliRev, _ConfigRev) ->
    case CliRev of
        "false" -> {ok, false};
        "auto" -> {ok, auto};
        "true" -> {ok, true};
        Other -> {error, {invalid_option, rev, Other}}
    end.

valid_config_rev(false) -> {ok, false};
valid_config_rev(auto) -> {ok, auto};
valid_config_rev(true) -> {ok, true};
valid_config_rev(Other) -> {error, {invalid_config, rev, Other}}.

validate_config_options(Options) when is_list(Options) ->
    case lists:all(fun valid_config_option/1, Options) of
        false ->
            Bad = hd([Item || Item <- Options, not valid_config_option(Item)]),
            {error, {invalid_config, options, Bad}};
        true ->
            case duplicate_config_key(scan_roots, Options) of
                true ->
                    {error, {duplicate_config, scan_roots}};
                false ->
                    case duplicate_config_key(rev, Options) of
                        true -> {error, {duplicate_config, rev}};
                        false -> {ok, Options}
                    end
            end
    end;
validate_config_options(Other) ->
    {error, {invalid_config, options, Other}}.

valid_config_option(Item) when is_tuple(Item), tuple_size(Item) >= 1 ->
    Key = element(1, Item),
    case Key of
        scan_roots -> tuple_size(Item) =:= 2;
        rev -> tuple_size(Item) =:= 2;
        _ -> true
    end;
valid_config_option(_) ->
    false.

duplicate_config_key(Key, Options) ->
    length([
        ok
     || Item <- Options,
        is_tuple(Item),
        tuple_size(Item) =:= 2,
        element(1, Item) =:= Key
    ]) > 1.

config_value(Key, Options) ->
    case [Value || {Option, Value} <- Options, Option =:= Key] of
        [] -> undefined;
        [Value] -> Value
    end.

valid_profile(Profile) ->
    is_atom(Profile) andalso Profile =/= undefined.

valid_path(Path) ->
    is_list(Path) andalso Path =/= [] andalso
        lists:all(
            fun(Char) ->
                is_integer(Char) andalso Char >= 0 andalso
                    Char =< 16#10ffff
            end,
            Path
        ).

absolute_path(Path, Base) ->
    case {valid_path(Path), valid_path(Base)} of
        {true, true} ->
            Combined =
                case filename:pathtype(Path) of
                    absolute -> Path;
                    relative -> filename:join(Base, Path)
                end,
            {ok, lexical_normalize(Combined)};
        _ ->
            {error, {invalid_context, path, Path}}
    end.

lexical_join(Base, Relative) ->
    lexical_normalize(filename:join(Base, Relative)).

lexical_normalize(Path) ->
    case Path of
        [$/ | Rest] ->
            Parts = string:tokens(Rest, "/"),
            "/" ++ string:join(normalize_parts(Parts, []), "/");
        _ ->
            Path
    end.

normalize_parts([], Acc) ->
    lists:reverse(Acc);
normalize_parts(["" | Rest], Acc) ->
    normalize_parts(Rest, Acc);
normalize_parts(["." | Rest], Acc) ->
    normalize_parts(Rest, Acc);
normalize_parts([".." | Rest], []) ->
    normalize_parts(Rest, []);
normalize_parts([".." | Rest], [_ | Acc]) ->
    normalize_parts(Rest, Acc);
normalize_parts([Part | Rest], Acc) ->
    normalize_parts(Rest, [Part | Acc]).

terminal_deep(Path) when length(Path) >= 5 ->
    lists:nthtail(length(Path) - 5, Path) =:= ":deep";
terminal_deep(_Path) ->
    false.

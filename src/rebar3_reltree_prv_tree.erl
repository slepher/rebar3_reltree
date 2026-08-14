-module(rebar3_reltree_prv_tree).
-behaviour(provider).

-export([init/1, do/1, format_error/1, option_spec/0, request/1, help/0]).

-spec init(term()) -> {ok, term()}.
init(State) ->
    {ok, State}.

-spec option_spec() -> [tuple()].
option_spec() ->
    [
        {scan_roots, undefined, "scan-roots", string,
            "Repeatable scan root, optionally ending in :deep."},
        {rev, undefined, "rev", string, "Revision lookup policy: false, auto, or true."}
    ].

-spec do(term()) -> term().
do(State) ->
    case request_from_state(State) of
        {ok, Request} ->
            case rebar3_reltree_project:generate(Request) of
                {error, Reason} -> provider_error(Reason);
                {ok, _Result} -> {ok, State}
            end;
        {help, Kind} ->
            io:put_chars(help_for(Kind)),
            {ok, State};
        {error, Reason} ->
            provider_error(Reason)
    end.

-spec format_error(term()) -> iolist().
format_error({rebar3_reltree_prv_tree, Reason}) ->
    rebar3_reltree_request:format_error(Reason);
format_error(Reason) ->
    rebar3_reltree_request:format_error(Reason).

-spec request(term()) -> term().
request(State) ->
    request_from_state(State).

request_from_state(State) ->
    ProjectRoot = rebar_state:dir(State),
    BuildBase = rebar_dir:base_dir(State),
    Profile = active_profile(rebar_state:current_profiles(State)),
    case command_cli(State) of
        {help, tree} ->
            {help, tree};
        {error, _} = Error ->
            Error;
        {ok, Cli} ->
            ConfigOptions = rebar_state:get(State, reltree, []),
            rebar3_reltree_request:normalize(
                #{
                    cwd => ProjectRoot,
                    project_root => ProjectRoot,
                    profile => Profile,
                    build_base_dir => BuildBase,
                    config_options => ConfigOptions,
                    cli_scan_roots => maps:get(cli_scan_roots, Cli),
                    cli_rev => maps:get(cli_rev, Cli)
                }
            )
    end.

command_cli(State) ->
    Args0 = rebar_state:command_args(State),
    Args =
        case Args0 of
            ["tree" | Rest] -> Rest;
            Rest when is_list(Rest) -> Rest
        end,
    case rebar3_reltree_request:parse_cli(["tree" | Args]) of
        {ok, Cli} -> {ok, Cli};
        {error, Reason} -> {error, Reason};
        {help, tree} -> {help, tree}
    end.

active_profile([]) ->
    default;
active_profile(Profiles) ->
    lists:last(Profiles).

provider_error(Reason) ->
    {error, {?MODULE, Reason}}.

help() ->
    help_for(tree).

help_for(tree) ->
    [
        "Usage: reltree tree [options]\n\n",
        "Options:\n",
        "  --scan-roots PATH[:deep]  repeatable; replaces configured roots\n",
        "  --rev false|auto|true     revision lookup policy\n\n",
        "Defaults: scan root '..' shallow; rev auto.\n",
        "Output: _build/<profile>/reltree/project.md\n"
    ].

-module(rebar3_reltree_prv_bgate).
-behaviour(provider).

-export([init/1, do/1, format_error/1, option_spec/0, request/1, help/0]).

-spec init(term()) -> {ok, term()}.
init(State) ->
    {ok, State}.

-spec option_spec() -> [tuple()].
option_spec() ->
    [
        {check, undefined, "check", boolean, "Check workflow names and local README CI badges."},
        {write, undefined, "write", boolean, "Write the master README CI badge."},
        {tag, undefined, "tag", boolean,
            "With --write, prepare release.yml and write the release badge."}
    ].

-spec do(term()) -> term().
do(State) ->
    case request(State) of
        {ok, Request} ->
            case rebar3_reltree_badge:run(Request) of
                {error, Reason} ->
                    provider_error(Reason);
                {ok, Result} ->
                    io:put_chars(rebar3_reltree_badge:format_result(Result)),
                    {ok, State}
            end;
        {help, bgate} ->
            io:put_chars(help()),
            {ok, State};
        {error, Reason} ->
            provider_error(Reason)
    end.

-spec format_error(term()) -> iolist().
format_error({rebar3_reltree_prv_bgate, Reason}) ->
    rebar3_reltree_request:format_error(Reason);
format_error(Reason) ->
    rebar3_reltree_request:format_error(Reason).

-spec request(term()) -> term().
request(State) ->
    ProjectRoot = rebar_state:dir(State),
    Args0 = rebar_state:command_args(State),
    Args =
        case Args0 of
            ["bgate" | Rest] -> Rest;
            Rest when is_list(Rest) -> Rest
        end,
    case rebar3_reltree_request:parse_cli(["bgate" | Args]) of
        {ok, #{mode := Mode} = Parsed} ->
            rebar3_reltree_request:normalize_bgate(
                #{
                    cwd => ProjectRoot,
                    mode => Mode,
                    tag => maps:get(tag, Parsed, false)
                }
            );
        {help, bgate} ->
            {help, bgate};
        {error, _} = Error ->
            Error
    end.

provider_error(Reason) ->
    {error, {?MODULE, Reason}}.

help() ->
    [
        "Usage: reltree bgate [options]\n\n",
        "Options (exactly one mode required):\n",
        "  --check        verify workflow names and local README CI badges\n",
        "  --write        update the master README CI badge\n",
        "  --write --tag  prepare release.yml and write the release badge\n"
    ].

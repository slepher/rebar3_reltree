-module(rebar3_reltree_prv_checkvsn).
-behaviour(provider).

-export([init/1, do/1, format_error/1, option_spec/0]).

-spec init(term()) -> {ok, term()}.
init(State) ->
    {ok, State}.

-spec option_spec() -> [].
option_spec() ->
    [].

-spec do(term()) -> term().
do(State) ->
    case command_args(State) of
        help ->
            io:put_chars(help()),
            {ok, State};
        ok ->
            run(State);
        {error, Reason} ->
            provider_error(Reason)
    end.

-spec format_error(term()) -> iolist().
format_error({?MODULE, Reason}) ->
    ["checkvsn: ", reason_text(Reason), "\n"];
format_error(Reason) ->
    ["checkvsn: ", reason_text(Reason), "\n"].

command_args(State) ->
    case rebar_state:command_args(State) of
        [] ->
            ok;
        ["checkvsn"] ->
            ok;
        ["--help"] ->
            help;
        ["checkvsn", "--help"] ->
            help;
        _Other ->
            {error, {invalid_arguments, checkvsn}}
    end.

run(State) ->
    Root = rebar_state:dir(State),
    case rebar3_reltree_config:app_identity(Root) of
        {ok, App} ->
            case rebar3_reltree_git:read(Root) of
                {ok, GitFacts} ->
                    case rebar3_reltree_version:check(
                           maps:get(app_vsn, App), GitFacts) of
                        {ok, _Facts} ->
                            io:put_chars("reltree checkvsn: passed\n"),
                            {ok, State};
                        {error, Reason} ->
                            provider_error(Reason)
                    end;
                {error, Reason} ->
                    provider_error(Reason)
            end;
        {error, Reason} ->
            provider_error(Reason)
    end.

provider_error(Reason) ->
    {error, {?MODULE, Reason}}.

help() ->
    ["Usage: rebar3 reltree checkvsn\n",
     "Check local app.src version and reachable tag continuity.\n"].

reason_text(no_app_src) ->
    "no app.src file found";
reason_text(multiple_app_src) ->
    "multiple app.src files found";
reason_text(invalid_app_vsn) ->
    "app.src has an invalid or missing vsn";
reason_text(ambiguous_app_vsn) ->
    "app.src has multiple vsn values";
reason_text({invalid_app_version, AppVsn}) ->
    ["invalid app version: ", bounded_term(AppVsn)];
reason_text({current_tag_base_mismatch, Tags}) ->
    ["current tag base does not match app version: ", bounded_term(Tags)];
reason_text({version_not_continuous, Facts}) ->
    ["version is not continuous from highest formal tag: ",
     bounded_term(Facts)];
reason_text({git_head, Reason}) ->
    ["unable to read Git HEAD (", git_reason_text(Reason), ")"];
reason_text({git_tags, Reason}) ->
    ["unable to read reachable Git tags (", git_reason_text(Reason), ")"];
reason_text({git_head_tags, Reason}) ->
    ["unable to read current HEAD tags (", git_reason_text(Reason), ")"];
reason_text({app_src_directory, _Path}) ->
    "unable to read app.src directory";
reason_text({app_src_directory_read, _Path, Reason}) ->
    ["unable to read app.src directory (", bounded_term(Reason), ")"];
reason_text({app_src_read, _Path, Reason}) ->
    ["unable to read app.src (", bounded_term(Reason), ")"];
reason_text({invalid_app_src_term, _Terms}) ->
    "app.src has an invalid application term";
reason_text({invalid_arguments, checkvsn}) ->
    "checkvsn accepts no options or arguments";
reason_text(invalid_git_facts) ->
    "invalid Git facts";
reason_text(Reason) ->
    bounded_term(Reason).

git_reason_text({exit, Status, _Output}) when is_integer(Status) ->
    lists:flatten(io_lib:format("git exited with status ~p", [Status]));
git_reason_text(timeout) ->
    "timeout";
git_reason_text(output_too_large) ->
    "output too large";
git_reason_text(git_executable_unavailable) ->
    "git executable unavailable";
git_reason_text({port_open, _}) ->
    "unable to start git";
git_reason_text(Reason) ->
    bounded_term(Reason).

bounded_term(Term) ->
    Text = lists:flatten(io_lib:format("~tp", [Term])),
    case length(Text) > 512 of
        true -> lists:sublist(Text, 512) ++ "...";
        false -> Text
    end.

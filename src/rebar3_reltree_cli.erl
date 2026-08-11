-module(rebar3_reltree_cli).

-export([main/1, run/1, run/2, help/1]).

-spec main([string()]) -> no_return().
main(Args) ->
    {Exit, Output} = run(Args),
    io:put_chars(Output),
    erlang:halt(Exit).

-spec run([string()]) -> {non_neg_integer(), iolist()}.
run(Args) ->
    run(Args, #{}).

-spec run([string()], map()) -> {non_neg_integer(), iolist()}.
run(Args, Context) when is_list(Args), is_map(Context) ->
    case parse(Args) of
        {help, Kind} ->
            {0, help(Kind)};
        {error, Reason} ->
            {2, error_output(Reason)};
        {ok, Request} ->
            run_install(Request, Context)
    end.

-spec help(top | skill) -> iolist().
help(top) ->
    ["Usage: reltree skill --install [--dest DIR] [--force]\n\n",
     "Commands:\n",
     "  skill --install  install the packaged reltree skill\n\n",
     "Run 'reltree skill --help' for help.\n"];
help(skill) ->
    ["Usage: reltree skill --install [--dest DIR] [--force]\n\n",
     "Options:\n",
     "  --dest DIR  install below DIR/reltree\n",
     "  --force     replace an existing reltree skill\n"].

parse([]) ->
    {help, top};
parse(["--help"]) ->
    {help, top};
parse(["-h"]) ->
    {help, top};
parse(["skill", "--help"]) ->
    {help, skill};
parse(["skill", "-h"]) ->
    {help, skill};
parse(["skill", "--install" | Args]) ->
    parse_install_args(Args, #{force => false});
parse([Command | _]) ->
    {error, {invalid_command, Command}}.

parse_install_args([], Options) ->
    {ok, Options#{command => skill_install}};
parse_install_args(["--force" | Rest], #{force := false} = Options) ->
    parse_install_args(Rest, Options#{force => true});
parse_install_args(["--force" | _], _Options) ->
    {error, {duplicate_option, force}};
parse_install_args(["--dest"], _Options) ->
    {error, {missing_option_value, dest}};
parse_install_args(["--dest", Value | _Rest], #{dest := _} = _Options)
  when Value =/= [] ->
    {error, {duplicate_option, dest}};
parse_install_args(["--dest", Value | Rest], Options) when Value =/= [] ->
    case lists:prefix("--", Value) of
        true -> {error, {missing_option_value, dest}};
        false -> parse_install_args(Rest, Options#{dest => Value})
    end;
parse_install_args(["--dest", [] | _], _Options) ->
    {error, {invalid_option, dest, []}};
parse_install_args([Option | _], _Options) when is_list(Option),
                                               Option =/= [],
                                               hd(Option) =:= $- ->
    {error, {invalid_option, option_name(Option), Option}};
parse_install_args([Argument | _], _Options) ->
    {error, {extra_argument, Argument}}.

run_install(Request, Context) ->
    case resolve_parent(Request, Context) of
        {ok, Parent} ->
            case packaged_source(Context) of
                {ok, Source} ->
                    Options = maps:get(installer_options, Context, #{}),
                    Result = rebar3_reltree_skill_install:install(
                               Source, Parent, maps:get(force, Request),
                               Options),
                    case Result of
                        {ok, Target} ->
                            {0, ["reltree skill installed at ", Target, "\n"]};
                        {error, Reason} ->
                            {1, error_output(Reason)}
                    end;
                {error, Reason} ->
                    {1, error_output(Reason)}
            end;
        {error, Reason} ->
            {1, error_output(Reason)}
    end.

resolve_parent(#{dest := Dest}, _Context) ->
    {ok, filename:absname(Dest)};
resolve_parent(_Request, Context) ->
    Env = maps:get(env, Context, fun os:getenv/1),
    case environment_value("CODEX_HOME", Env) of
        {ok, CodexHome} ->
            {ok, filename:absname(filename:join(CodexHome, "skills"))};
        absent ->
            case user_home(Context) of
                {ok, Home} ->
                    {ok, filename:absname(filename:join([Home, ".codex",
                                                         "skills"]))};
                {error, Reason} ->
                    {error, {install, parent, "user-home", Reason}}
            end;
        {error, Reason} ->
            {error, {install, parent, "CODEX_HOME", Reason}}
    end.

environment_value(Name, Env) when is_function(Env, 1) ->
    case Env(Name) of
        false -> absent;
        [] -> {error, empty};
        Value when is_list(Value) -> {ok, Value};
        Value -> {error, {invalid_value, Value}}
    end;
environment_value(Name, Env) when is_map(Env) ->
    environment_value(Name, fun(Key) -> maps:get(Key, Env, false) end);
environment_value(_Name, _Env) ->
    {error, invalid_environment_source}.

user_home(Context) ->
    case maps:find(user_home, Context) of
        {ok, Home} when is_list(Home), Home =/= [] ->
            {ok, Home};
        {ok, []} ->
            {error, empty};
        {ok, Value} ->
            {error, {invalid_value, Value}};
        error ->
            user_home_from_os()
    end.

user_home_from_os() ->
    case os:getenv("HOME") of
        false ->
            case os:getenv("USERPROFILE") of
                false -> {error, unavailable};
                [] -> {error, empty};
                Home when is_list(Home) -> {ok, Home};
                Value -> {error, {invalid_value, Value}}
            end;
        [] ->
            {error, empty};
        Home when is_list(Home) ->
            {ok, Home};
        Value ->
            {error, {invalid_value, Value}}
    end.

packaged_source(Context) ->
    case maps:find(priv_dir, Context) of
        {ok, PrivDir} when is_list(PrivDir), PrivDir =/= [] ->
            {ok, filename:join(filename:absname(PrivDir),
                               "skills/reltree")};
        {ok, Value} ->
            {error, {install, source_validation, "priv_dir",
                     {invalid_value, Value}}};
        error ->
            case code:priv_dir(rebar3_reltree) of
                PrivDir when is_list(PrivDir) ->
                    {ok, filename:join(filename:absname(PrivDir),
                                       "skills/reltree")};
                {error, Reason} ->
                    {error, {install, source_validation,
                             "code:priv_dir(rebar3_reltree)", Reason}}
            end
    end.

error_output({install, Stage, Path, Reason}) ->
    ["reltree: install ", atom_to_list(Stage), " at ", path_text(Path),
     ": ", io_lib:format("~p", [Reason]), "\n"];
error_output({invalid_command, Command}) ->
    ["reltree: unknown command ", io_lib:format("~p", [Command]),
     "; use 'skill --install'\n"];
error_output({invalid_option, Option, Value}) ->
    ["reltree: invalid option ", io_lib:format("~p", [Option]),
     " value ", io_lib:format("~p", [Value]), "\n"];
error_output({missing_option_value, Option}) ->
    ["reltree: option --", atom_to_list(Option), " requires a value\n"];
error_output({duplicate_option, Option}) ->
    ["reltree: option --", atom_to_list(Option),
     " may be specified only once\n"];
error_output({extra_argument, Argument}) ->
    ["reltree: unexpected argument ", io_lib:format("~p", [Argument]),
     "\n"];
error_output(Reason) ->
    ["reltree: ", io_lib:format("~p", [Reason]), "\n"].

path_text(Path) when is_list(Path) ->
    Path;
path_text(Path) ->
    io_lib:format("~p", [Path]).

option_name(Option) -> Option.

-module(rebar3_reltree_git).

-export([read/1, command/3, executable/0, lookup/3]).

-define(MAX_OUTPUT, 1024 * 1024).
-define(TIMEOUT, 5000).

-spec executable() -> {ok, string()} | {error, term()}.
executable() ->
    case os:find_executable("git") of
        false -> {error, git_executable_unavailable};
        Path -> {ok, Path}
    end.

-spec read(filename:filename_all()) -> {ok, map()} | {error, term()}.
read(ProjectPath) ->
    case command(ProjectPath, ["rev-parse", "HEAD"], #{}) of
        {ok, Head0} ->
            case command(ProjectPath, ["tag", "--merged", "HEAD"], #{}) of
                {ok, Tags0} ->
                    Origin = case command(ProjectPath,
                                           ["config", "--get",
                                            "remote.origin.url"], #{}) of
                                 {ok, Url} -> {ok, Url};
                                 {error, {exit, 1, _}} -> none;
                                 {error, _} -> none
                             end,
                    {ok, #{head => trim(Head0),
                           tags => lines(Tags0),
                           origin => Origin}};
                {error, Reason} ->
                    {error, {git_tags, Reason}}
            end;
        {error, Reason} ->
            {error, {git_head, Reason}}
    end.

%% Execute a local Git command with an executable and argv.  There is no shell
%% interpolation and stderr is captured with stdout for bounded diagnostics.
-spec command(filename:filename_all(), [string()], map()) ->
    {ok, binary()} | {error, term()}.
command(Directory, Args, Options) when is_list(Args), is_map(Options) ->
    case executable() of
        {ok, Executable} ->
            Timeout = maps:get(timeout, Options, ?TIMEOUT),
            case open_port({spawn_executable, Executable},
                           [{args, Args}, {cd, rebar3_reltree_fs:absolute(
                                             Directory)}, binary,
                            exit_status, stderr_to_stdout, hide,
                            {env, [{"GIT_TERMINAL_PROMPT", "0"},
                                   {"GIT_ASKPASS", ""}]}]) of
                Port when is_port(Port) ->
                    collect(Port, [], 0, Timeout);
                Other ->
                    {error, {port_open, Other}}
            end;
        {error, _} = Error ->
            Error
    end.

collect(Port, Chunks, Size, Timeout) ->
    receive
        {Port, {data, Data}} when is_binary(Data) ->
            NewSize = Size + byte_size(Data),
            case NewSize > ?MAX_OUTPUT of
                true ->
                    port_close(Port),
                    {error, output_too_large};
                false ->
                    collect(Port, [Data | Chunks], NewSize, Timeout)
            end;
        {Port, {exit_status, 0}} ->
            {ok, iolist_to_binary(lists:reverse(Chunks))};
        {Port, {exit_status, Status}} ->
            {error, {exit, Status, iolist_to_binary(lists:reverse(Chunks))}}
    after Timeout ->
        port_close(Port),
        {error, timeout}
    end.

%% The external revision boundary intentionally uses one fixed argv shape for
%% every selector.  Selection is performed on the bounded, read-only output;
%% no shell or Git command other than ls-remote is involved.
-spec lookup(string(), map(), map()) -> {ok, string()} | {error, term()}.
lookup(Url, Selector, Options) when is_list(Url), is_map(Selector),
                                   is_map(Options) ->
    Args = ["ls-remote", "--", Url],
    case command("/", Args, Options) of
        {ok, Output} ->
            case parse_rows(Output) of
                {ok, Rows} -> select_revision(Rows, Selector);
                {error, _} = Error -> Error
            end;
        {error, Reason} ->
            {error, sanitize_reason(Reason)}
    end.

parse_rows(Output) when is_binary(Output) ->
    try
        Lines = string:split(binary_to_list(Output), "\n", all),
        parse_rows(Lines, [])
    catch
        _:_ -> {error, malformed_output}
    end.

parse_rows([], Acc) ->
    {ok, lists:reverse(Acc)};
parse_rows(["" | Rest], Acc) ->
    parse_rows(Rest, Acc);
parse_rows([Line | Rest], Acc) ->
    case string:split(Line, "\t", all) of
        [Object, Ref] when Object =/= [], Ref =/= [] ->
            parse_rows(Rest, [{Ref, Object} | Acc]);
        _ ->
            {error, malformed_output}
    end.

select_revision(Rows, #{kind := head}) ->
    select_one([Object || {"HEAD", Object} <- Rows]);
select_revision(Rows, #{kind := branch, value := Value}) ->
    select_one([Object || {Ref, Object} <- Rows,
                          Ref =:= "refs/heads/" ++ Value]);
select_revision(Rows, #{kind := tag, value := Value}) ->
    PeeledRef = "refs/tags/" ++ Value ++ "^{}",
    DirectRef = "refs/tags/" ++ Value,
    case [Object || {Ref, Object} <- Rows, Ref =:= PeeledRef] of
        [] -> select_one([Object || {Ref, Object} <- Rows,
                                    Ref =:= DirectRef]);
        Peeled -> select_one(Peeled)
    end;
select_revision(Rows, #{kind := ref, value := Pattern}) ->
    select_one([Object || {Ref, Object} <- Rows, glob_match(Pattern, Ref)]);
select_revision(_Rows, _Selector) ->
    {error, invalid_selector}.

select_one([]) ->
    {error, no_matching_revision};
select_one(Objects) ->
    case lists:all(fun valid_object_id/1, Objects) of
        false -> {error, malformed_object_id};
        true ->
            case lists:usort(Objects) of
                [Object] -> {ok, Object};
                _ -> {error, incompatible_revisions}
            end
    end.

valid_object_id(Object) when is_list(Object) ->
    (length(Object) =:= 40 orelse length(Object) =:= 64) andalso
    lists:all(fun is_hex/1, Object);
valid_object_id(_Object) ->
    false.

is_hex(Char) when Char >= $0, Char =< $9 -> true;
is_hex(Char) when Char >= $a, Char =< $f -> true;
is_hex(Char) when Char >= $A, Char =< $F -> true;
is_hex(_Char) -> false.

glob_match([], []) -> true;
glob_match([$* | Rest], Value) ->
    glob_match(Rest, Value) orelse
    case Value of
        [] -> false;
        [_ | Tail] -> glob_match([$* | Rest], Tail)
    end;
glob_match([Expected | Pattern], [Expected | Value]) ->
    glob_match(Pattern, Value);
glob_match([], _Value) -> false;
glob_match(_Pattern, []) -> false;
glob_match(_Pattern, _Value) -> false.

sanitize_reason({exit, Status, _Output}) when is_integer(Status) ->
    {git_exit, Status};
sanitize_reason(timeout) -> timeout;
sanitize_reason(output_too_large) -> output_too_large;
sanitize_reason(git_executable_unavailable) -> git_executable_unavailable;
sanitize_reason({port_open, _}) -> port_open;
sanitize_reason(_Other) -> git_lookup_failed.

trim(Binary) when is_binary(Binary) ->
    unicode:characters_to_binary(string:trim(binary_to_list(Binary)));
trim(List) when is_list(List) ->
    unicode:characters_to_binary(string:trim(List)).

lines(Binary) ->
    [Line || Line <- string:split(binary_to_list(Binary), "\n", all),
             string:trim(Line) =/= ""].

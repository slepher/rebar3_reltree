-module(rebar3_reltree_git).

-export([read/1, command/3, executable/0]).

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
                            exit_status, stderr_to_stdout, hide]) of
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

trim(Binary) when is_binary(Binary) ->
    unicode:characters_to_binary(string:trim(binary_to_list(Binary)));
trim(List) when is_list(List) ->
    unicode:characters_to_binary(string:trim(List)).

lines(Binary) ->
    [Line || Line <- string:split(binary_to_list(Binary), "\n", all),
             string:trim(Line) =/= ""].

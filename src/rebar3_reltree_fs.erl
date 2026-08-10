-module(rebar3_reltree_fs).

-include_lib("kernel/include/file.hrl").

-export([
    absolute/1,
    canonical/1,
    directory/1,
    regular/1,
    identity/1,
    list_dir/1,
    read_file/1,
    resolve_checkout/1,
    atomic_write/3
]).

%% Filesystem operations used by the local scanner.  Directory inspection is
%% deliberately based on read_link_info/1 so that the general scanner never
%% follows a symlink.

-spec absolute(filename:filename_all()) -> string().
absolute(Path) ->
    filename:absname(Path).

-spec canonical(filename:filename_all()) -> string().
canonical(Path) ->
    filename:absname(Path).

-spec directory(filename:filename_all()) -> boolean().
directory(Path) ->
    case file:read_link_info(Path) of
        {ok, #file_info{type = directory}} -> true;
        _ -> false
    end.

-spec regular(filename:filename_all()) -> boolean().
regular(Path) ->
    case file:read_link_info(Path) of
        {ok, #file_info{type = regular}} -> true;
        _ -> false
    end.

-spec identity(filename:filename_all()) -> {ok, term()} | {error, term()}.
identity(Path) ->
    case file:read_link_info(Path) of
        {ok, #file_info{type = directory,
                        major_device = Major,
                        minor_device = Minor,
                        inode = Inode}}
          when is_integer(Inode), is_integer(Major), is_integer(Minor) ->
            {ok, {device_inode, Major, Minor, Inode}};
        {ok, #file_info{type = directory}} ->
            {ok, {path, canonical(Path)}};
        {ok, Info} ->
            {error, {not_directory, Info#file_info.type}};
        {error, Reason} ->
            {error, Reason}
    end.

-spec list_dir(filename:filename_all()) -> {ok, [string()]} | {error, term()}.
list_dir(Path) ->
    file:list_dir(Path).

-spec read_file(filename:filename_all()) -> {ok, binary()} | {error, term()}.
read_file(Path) ->
    file:read_file(Path).

%% Resolve only an explicitly requested checkout entry.  The returned path is
%% absolute and the link chain is bounded and cycle-checked.
-spec resolve_checkout(filename:filename_all()) -> {ok, string()} | {error, term()}.
resolve_checkout(Path) ->
    resolve_checkout(canonical(Path), [], 0).

resolve_checkout(_Path, _Seen, Depth) when Depth > 64 ->
    {error, symlink_loop};
resolve_checkout(Path, Seen, Depth) ->
    case lists:member(Path, Seen) of
        true ->
            {error, symlink_loop};
        false ->
            case file:read_link_info(Path) of
                {ok, #file_info{type = symlink}} ->
                    case file:read_link(Path) of
                        {ok, Target0} ->
                            Target = case filename:pathtype(Target0) of
                                         absolute -> Target0;
                                         relative -> filename:join(
                                           filename:dirname(Path), Target0)
                                     end,
                            resolve_checkout(canonical(Target),
                                             [Path | Seen], Depth + 1);
                        {error, Reason} ->
                            {error, {link_read, Reason}}
                    end;
                {ok, #file_info{type = directory}} ->
                    {ok, canonical(Path)};
                {ok, #file_info{type = Type}} ->
                    {error, {not_directory, Type}};
                {error, Reason} ->
                    {error, Reason}
            end
    end.

%% The temporary file is created beside the destination, and the destination
%% is touched only by the final rename.  Options are intentionally small and
%% test-oriented: fail_stage may be write, close, or rename.
-spec atomic_write(filename:filename_all(), iodata(), map()) ->
    {ok, string()} | {error, term()}.
atomic_write(Output0, Data0, Options) when is_map(Options) ->
    Output = canonical(Output0),
    Data = iolist_to_binary(Data0),
    case filelib:ensure_dir(Output) of
        ok ->
            Temp = temporary_path(Output),
            case file:open(Temp, [write, binary, exclusive]) of
                {ok, IoDevice} ->
                    Result = write_and_replace(IoDevice, Temp, Output,
                                               Data, Options),
                    case Result of
                        {ok, _} -> Result;
                        {error, _} = Error ->
                            _ = file:delete(Temp),
                            Error
                    end;
                {error, Reason} ->
                    {error, {atomic_write, open, Reason}}
            end;
        {error, Reason} ->
            {error, {atomic_write, parent, Reason}}
    end.

write_and_replace(IoDevice, Temp, Output, Data, Options) ->
    Fail = maps:get(fail_stage, Options, maps:get(fail, Options, none)),
    WriteResult = case Fail of
                      write -> {error, injected};
                      _ -> file:write(IoDevice, Data)
                  end,
    case WriteResult of
        ok ->
            CloseResult = case Fail of
                              close -> {error, injected};
                              _ -> file:close(IoDevice)
                          end,
            case CloseResult of
                ok ->
                    case revalidate_temp(Temp, Data) of
                        ok ->
                            case Fail of
                                rename ->
                                    {error, {atomic_write, rename, injected}};
                                _ ->
                                    case file:rename(Temp, Output) of
                                        ok -> {ok, Output};
                                        {error, Reason} ->
                                            {error, {atomic_write, rename,
                                                     Reason}}
                                    end
                            end;
                        {error, Reason} ->
                            {error, {atomic_write, validate, Reason}}
                    end;
                {error, Reason} ->
                    _ = file:close(IoDevice),
                    {error, {atomic_write, close, Reason}}
            end;
        {error, Reason} ->
            _ = file:close(IoDevice),
            {error, {atomic_write, write, Reason}}
    end.

revalidate_temp(Temp, Expected) ->
    case file:read_file(Temp) of
        {ok, Expected} -> ok;
        {ok, _Other} -> {error, content_mismatch};
        {error, Reason} -> {error, Reason}
    end.

temporary_path(Output) ->
    Token = integer_to_list(erlang:unique_integer([positive, monotonic])),
    filename:join(filename:dirname(Output),
                  "." ++ filename:basename(Output) ++ ".reltree-" ++ Token).

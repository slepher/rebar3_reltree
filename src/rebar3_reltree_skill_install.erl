-module(rebar3_reltree_skill_install).

-include_lib("kernel/include/file.hrl").

-export([install/3, resolve_destination/2]).

-define(SKILL_NAME, "reltree").
-define(MAX_PATH_HOPS, 64).
-define(MAX_NAME_ATTEMPTS, 128).
-define(STAGE_PREFIX, ".reltree-stage-").
-define(BACKUP_PREFIX, ".reltree-backup-").

-spec resolve_destination(map() | list(), fun((string()) -> term())) ->
    {ok, string()} | {error, term()}.
resolve_destination(Options, EnvFun) when is_function(EnvFun, 1) ->
    case option_value(dest, Options) of
        {ok, Dest} when is_list(Dest), Dest =/= [] ->
            {ok, filename:absname(Dest)};
        {ok, Dest} ->
            {error, {invalid_destination, Dest}};
        absent ->
            case environment_value("CODEX_HOME", EnvFun) of
                {ok, CodexHome} ->
                    {ok, filename:absname(filename:join(CodexHome,
                                                        "skills"))};
                absent ->
                    case first_environment_value(["HOME", "USERPROFILE"],
                                                 EnvFun) of
                        {ok, Home} ->
                            {ok, filename:absname(filename:join(
                                                       [Home, ".codex",
                                                        "skills"]))};
                        {error, Reason} -> {error, Reason}
                    end;
                {error, Reason} ->
                    {error, {invalid_codex_home, Reason}}
            end
    end.

-spec install(string(), string(), boolean()) ->
    {ok, string()} | {error, term()}.
install(Source0, Parent0, Force)
  when is_boolean(Force) ->
    case absolute_path(Source0, source) of
        {ok, Source} ->
            case absolute_path(Parent0, parent) of
                {ok, Parent} ->
                    Target = target_for_parent(Parent),
                    install_paths(Source, Parent, Target, Force);
                {error, Error} ->
                    Error
            end;
        {error, Error} ->
            Error
    end;

install(_Source, _Parent, _Force) ->
    install_error(parent, ".", invalid_arguments).

install_paths(Source, Parent, Target, Force) ->
    case validate_source(Source) of
        {ok, Files} ->
            case validate_parent_path(Parent) of
                ok ->
                    case paths_overlap(Source, Parent, Target) of
                        {ok, false} ->
                            case ensure_parent_directory(Parent) of
                                ok ->
                                    case preflight_target(Target, Force) of
                                        ok -> stage(Source, Parent, Target,
                                                    Force, Files);
                                        {error, {target_conflict, Reason}} ->
                                            install_error(target_conflict,
                                                          Target, Reason);
                                        {error, {target, Reason}} ->
                                            install_error(target, Target,
                                                          Reason)
                                    end;
                                {error, Reason} ->
                                    install_error(parent, Parent, Reason)
                            end;
                        {ok, true} ->
                            install_error(source_validation, Source,
                                          {source_target_overlap, Target});
                        {error, Reason} ->
                            install_error(source_validation, Source, Reason)
                    end;
                {error, Reason} ->
                    install_error(parent, Parent, Reason)
            end;
        {error, Path, Reason} ->
            install_error(source_validation, Path, Reason)
    end.

validate_parent_path(Path) ->
    case file:read_link_info(Path) of
        {ok, #file_info{type = directory}} -> ok;
        {ok, #file_info{type = Type}} -> {error, {not_directory, Type}};
        {error, enoent} -> ok;
        {error, Reason} -> {error, Reason}
    end.

preflight_target(Target, true) ->
    case target_state(Target) of
        absent -> ok;
        {exists, _Type} -> ok;
        {error, Reason} -> {error, {target, Reason}}
    end;
preflight_target(Target, false) ->
    case target_state(Target) of
        absent -> ok;
        {exists, Type} -> {error, {target_conflict, {exists, Type}}};
        {error, Reason} -> {error, {target, Reason}}
    end.

stage(Source, Parent, Target, Force, Files) ->
    case create_stage(Parent) of
        {ok, Stage} ->
            case copy_stage(Source, Stage, Files) of
                ok ->
                    case validate_stage(Stage, Files) of
                        ok -> activate(Stage, Parent, Target, Force);
                        {error, Reason} ->
                            cleanup_after_error(
                              Stage,
                              install_error(stage_validate, Stage, Reason))
                    end;
                {error, Reason} ->
                    cleanup_after_error(
                      Stage, install_error(stage_copy, Stage, Reason))
            end;
        {error, Reason} ->
            install_error(stage_create, Parent, Reason)
    end.

create_stage(Parent) ->
    create_owned_directory(Parent, ?STAGE_PREFIX, 0).

create_owned_directory(_Parent, _Prefix, Attempts) when Attempts >= 128 ->
    {error, name_allocation_exhausted};
create_owned_directory(Parent, Prefix, Attempts) ->
    Path = sibling_path(Parent, Prefix),
    case file:make_dir(Path) of
        ok -> {ok, Path};
        {error, eexist} ->
            create_owned_directory(Parent, Prefix, Attempts + 1);
        {error, Reason} ->
            {error, {Path, Reason}}
    end.

copy_stage(_Source, Stage, {SkillBytes, AgentBytes}) ->
    Agents = filename:join(Stage, "agents"),
    copy_stage_files(Agents, Stage, SkillBytes, AgentBytes).

copy_stage_files(Agents, Stage, SkillBytes, AgentBytes) ->
    case file:make_dir(Agents) of
        ok ->
            case copy_leaf(SkillBytes, filename:join(Stage, "SKILL.md"),
                           skill) of
                ok ->
                    copy_leaf(AgentBytes,
                              filename:join(Agents, "openai.yaml"),
                              agent);
                {error, _} = Error -> Error
            end;
        {error, Reason} ->
            {error, {agents, Reason}}
    end.

copy_leaf(Bytes, Path, Name) ->
    case test_failure({stage_copy, Name}) of
        {error, Reason} ->
            {error, {Name, Reason}};
        ok ->
            case file:open(Path, [write, binary, exclusive]) of
                {ok, IoDevice} ->
                    case file:write(IoDevice, Bytes) of
                        ok ->
                            case file:close(IoDevice) of
                                ok -> ok;
                                {error, CloseFailure} ->
                                    _ = file:close(IoDevice),
                                    {error, {Name, close, CloseFailure}}
                            end;
                        {error, WriteFailure} ->
                            _ = file:close(IoDevice),
                            {error, {Name, write, WriteFailure}}
                    end;
                {error, Reason} ->
                    {error, {Name, open, Reason}}
            end
    end.

validate_stage(Stage, Files) ->
    case validate_directory(Stage, ["SKILL.md", "agents"]) of
        ok ->
            case validate_directory(filename:join(Stage, "agents"),
                                    ["openai.yaml"]) of
                ok ->
                    validate_stage_files(Stage, Files);
                {error, _Path, Reason} -> {error, Reason}
            end;
        {error, _Path, Reason} ->
            {error, Reason}
    end.

validate_stage_files(Stage, {SkillBytes, AgentBytes}) ->
    case read_regular(filename:join(Stage, "SKILL.md")) of
        {ok, SkillBytes} ->
            case read_regular(filename:join([Stage, "agents", "openai.yaml"])) of
                {ok, AgentBytes} -> ok;
                {ok, _Other} -> {error, {content_mismatch, openai_yaml}};
                {error, Reason} -> {error, {openai_yaml, Reason}}
            end;
        {ok, _Other} ->
            {error, {content_mismatch, skill_md}};
        {error, Reason} ->
            {error, {skill_md, Reason}}
    end.

activate(Stage, _Parent, Target, false) ->
    case target_state(Target) of
        absent ->
            case rename_path(Stage, Target, first_install) of
                ok -> {ok, Target};
                {error, Reason} ->
                    cleanup_after_error(
                      Stage, install_error(replace, Target, Reason))
            end;
        {exists, Type} ->
            cleanup_after_error(
              Stage,
              install_error(target_conflict, Target, {exists, Type}));
        {error, Reason} ->
            cleanup_after_error(
              Stage, install_error(target, Target, Reason))
    end;
activate(Stage, Parent, Target, true) ->
    case target_state(Target) of
        absent ->
            case rename_path(Stage, Target, first_install) of
                ok -> {ok, Target};
                {error, Reason} ->
                    cleanup_after_error(
                      Stage, install_error(replace, Target, Reason))
            end;
        {exists, _Type} ->
            case rename_backup(Target, Parent) of
                {ok, ActualBackup} ->
                    case rename_path(Stage, Target, replace) of
                        ok ->
                            case cleanup_owned(ActualBackup) of
                                ok -> {ok, Target};
                                {error, Reason} ->
                                    install_error(cleanup, ActualBackup,
                                                  Reason)
                            end;
                        {error, ReplaceReason} ->
                            rollback(Stage, Target, ActualBackup, ReplaceReason)
                    end;
                {error, Reason} ->
                    cleanup_after_error(
                      Stage, install_error(backup, Target, Reason))
            end;
        {error, Reason} ->
            cleanup_after_error(
              Stage, install_error(target, Target, Reason))
    end.

target_state(Target) ->
    case file:read_link_info(Target) of
        {ok, #file_info{type = Type}} -> {exists, Type};
        {error, enoent} -> absent;
        {error, Reason} -> {error, Reason}
    end.

rename_backup(Target, Parent) ->
    rename_backup(Target, Parent, 0).

rename_backup(_Target, _Parent, Attempts)
  when Attempts >= ?MAX_NAME_ATTEMPTS ->
    {error, name_allocation_exhausted};
rename_backup(Target, Parent, Attempts) ->
    Backup = sibling_path(Parent, ?BACKUP_PREFIX),
    case file:read_link_info(Backup) of
        {error, enoent} ->
            case rename_path(Target, Backup, backup) of
                ok -> {ok, Backup};
                {error, eexist} ->
                    rename_backup(Target, Parent, Attempts + 1);
                {error, Reason} ->
                    {error, Reason}
            end;
        {ok, _Info} ->
            rename_backup(Target, Parent, Attempts + 1);
        {error, Reason} ->
            {error, {Backup, Reason}}
    end.

rollback(Stage, Target, Backup, ReplaceReason) ->
    case rename_path(Backup, Target, rollback) of
        ok ->
            case cleanup_owned(Stage) of
                ok -> install_error(replace, Target, ReplaceReason);
                {error, CleanupReason} ->
                    install_error(rollback, Stage,
                                  {replace, ReplaceReason,
                                   {stage_cleanup, CleanupReason}})
            end;
        {error, RollbackReason} ->
            case cleanup_owned(Stage) of
                ok ->
                    install_error(rollback, Backup,
                                  {replace, ReplaceReason, RollbackReason});
                {error, CleanupReason} ->
                    install_error(rollback, Backup,
                                  {replace, ReplaceReason, RollbackReason,
                                   {stage_cleanup, CleanupReason}})
            end
    end.

rename_path(From, To, Phase) ->
    case test_failure({rename, Phase}) of
        {error, Reason} ->
            {error, Reason};
        ok ->
            file:rename(From, To)
    end.

cleanup_after_error(Path, Original) ->
    case cleanup_owned(Path) of
        ok -> Original;
        {error, Reason} ->
            install_error(cleanup, Path, {original, Original, Reason})
    end.

cleanup_owned(Path) ->
    remove_owned(Path).

remove_owned(Path) ->
    case file:read_link_info(Path) of
        {error, enoent} ->
            ok;
        {error, Reason} ->
            {error, Reason};
        {ok, #file_info{type = directory}} ->
            case file:list_dir(Path) of
                {ok, Names} ->
                    case remove_owned_entries(Path, Names) of
                        ok -> file:del_dir(Path);
                        {error, Reason} -> {error, Reason}
                    end;
                {error, Reason} ->
                    {error, Reason}
            end;
        {ok, _Info} ->
            file:delete(Path)
    end.

remove_owned_entries(_Parent, []) ->
    ok;
remove_owned_entries(Parent, [Name | Rest]) ->
    case remove_owned(filename:join(Parent, Name)) of
        ok -> remove_owned_entries(Parent, Rest);
        {error, _} = Error -> Error
    end.

validate_source(Source) ->
    case validate_directory(Source, ["SKILL.md", "agents"]) of
        ok ->
            Agents = filename:join(Source, "agents"),
            case validate_directory(Agents, ["openai.yaml"]) of
                ok ->
                    case read_regular(filename:join(Source, "SKILL.md")) of
                        {ok, SkillBytes} ->
                            case read_regular(filename:join(
                                                       [Agents, "openai.yaml"])) of
                                {ok, AgentBytes} ->
                                    {ok, {SkillBytes, AgentBytes}};
                                {error, Reason} ->
                                    {error, filename:join(
                                              [Agents, "openai.yaml"]),
                                     Reason}
                            end;
                        {error, Reason} ->
                            {error, filename:join(Source, "SKILL.md"),
                             Reason}
                    end;
                {error, Path, Reason} -> {error, Path, Reason}
            end;
        {error, Path, Reason} ->
            {error, Path, Reason}
    end.

validate_directory(Path, ExpectedNames) ->
    case loader_read_link_info(Path) of
        {ok, #file_info{type = directory}} ->
            case loader_list_dir(Path) of
                {ok, Names} ->
                    case lists:sort(Names) of
                        ExpectedNames -> ok;
                        Actual -> {error, Path, {entries, ExpectedNames, Actual}}
                    end;
                {error, Reason} -> {error, Path, Reason}
            end;
        {ok, #file_info{type = Type}} ->
            {error, Path, {not_directory, Type}};
        {error, Reason} ->
            {error, Path, Reason}
    end.

read_regular(Path) ->
    case loader_read_link_info(Path) of
        {ok, #file_info{type = regular}} ->
            loader_read_file(Path);
        {ok, #file_info{type = Type}} ->
            {error, {not_regular, Type}};
        {error, Reason} ->
            {error, Reason}
    end.

ensure_parent_directory(Path) ->
    case file:read_link_info(Path) of
        {ok, #file_info{type = directory}} -> ok;
        {ok, #file_info{type = Type}} -> {error, {not_directory, Type}};
        {error, enoent} ->
            Parent = filename:dirname(Path),
            case Parent =:= Path of
                true -> {error, enoent};
                false ->
                    case ensure_parent_directory(Parent) of
                        ok ->
                            case file:make_dir(Path) of
                                ok -> ok;
                                {error, eexist} ->
                                    ensure_parent_directory(Path);
                                {error, Reason} -> {error, Reason}
                            end;
                        {error, _} = Error -> Error
                    end
            end;
        {error, Reason} -> {error, Reason}
    end.

paths_overlap(Source, Parent, Target) ->
    case {canonical_location(Source), canonical_location(Parent),
          canonical_location(Target)} of
        {{ok, CanonicalSource}, {ok, CanonicalParent}, {ok, CanonicalTarget}} ->
            {ok, locations_overlap(CanonicalSource, CanonicalParent,
                                   CanonicalTarget)};
        {SourceResult, ParentResult, TargetResult} ->
            {error, {canonical_path_failed,
                     canonical_path_reason(SourceResult, ParentResult,
                                            TargetResult)}}
    end.

locations_overlap(Source, Parent, Target) ->
    path_prefix(Source, Parent) orelse path_prefix(Parent, Source) orelse
    path_prefix(Source, Target) orelse path_prefix(Target, Source).

canonical_path_reason({error, Reason}, _ParentResult, _TargetResult) ->
    {source, Reason};
canonical_path_reason(_SourceResult, {error, Reason}, _TargetResult) ->
    {parent, Reason};
canonical_path_reason(_SourceResult, _ParentResult, {error, Reason}) ->
    {target, Reason}.

path_prefix(Left, Right) ->
    lists:prefix(filename:split(Left), filename:split(Right)).

canonical_location(Path) ->
    Components = normalized_components(filename:split(filename:absname(Path))),
    canonical_components(Components, "", 0).

canonical_components([], Current, _Hops) ->
    {ok, Current};
canonical_components([Root | Rest], "", Hops) ->
    canonical_components(Rest, Root, Hops);
canonical_components(["." | Rest], Current, Hops) ->
    canonical_components(Rest, Current, Hops);
canonical_components([".." | Rest], Current, Hops) ->
    canonical_components(Rest, filename:dirname(Current), Hops);
canonical_components([Component | Rest], Current, Hops) ->
    Candidate = filename:join(Current, Component),
    case loader_read_link_info(Candidate) of
        {ok, #file_info{type = symlink}} when Hops >= ?MAX_PATH_HOPS ->
            {error, {symlink_loop, Candidate}};
        {ok, #file_info{type = symlink}} ->
            case file:read_link(Candidate) of
                {ok, Link} ->
                    LinkPath = case filename:pathtype(Link) of
                                   absolute -> Link;
                                   relative -> filename:join(Current, Link)
                               end,
                    LinkComponents = normalized_components(
                                       filename:split(filename:absname(
                                                       LinkPath))),
                    canonical_components(LinkComponents ++ Rest, "",
                                         Hops + 1);
                {error, Reason} -> {error, {Candidate, Reason}}
            end;
        {ok, #file_info{type = Type}} when Rest =/= [], Type =/= directory ->
            {error, {not_directory, Candidate, Type}};
        {ok, _Info} ->
            canonical_components(Rest, Candidate, Hops);
        {error, enoent} ->
            {ok, append_components(Candidate, Rest)};
        {error, Reason} ->
            {error, {Candidate, Reason}}
    end.

normalized_components([Root | Rest]) ->
    [Root | normalize_components(Rest, [])].

normalize_components([], Acc) -> lists:reverse(Acc);
normalize_components(["." | Rest], Acc) -> normalize_components(Rest, Acc);
normalize_components([".." | Rest], [_ | Acc]) -> normalize_components(Rest, Acc);
normalize_components([".." | Rest], []) -> normalize_components(Rest, []);
normalize_components([Component | Rest], Acc) ->
    normalize_components(Rest, [Component | Acc]).

append_components(Current, Components) ->
    lists:foldl(fun(Component, Acc) -> filename:join(Acc, Component) end,
                Current, Components).

absolute_path(Path, _Kind) when is_list(Path), Path =/= [] ->
    try {ok, filename:absname(Path)}
    catch Class:Reason -> install_error(parent, Path,
                                        {invalid_path, Class, Reason})
    end;
absolute_path(Path, Kind) ->
    install_error(Kind, ".", {invalid_path, Path}).

target_for_parent(Parent) ->
    filename:absname(filename:join(Parent, ?SKILL_NAME)).

sibling_path(Parent, Prefix) ->
    Token = integer_to_list(erlang:unique_integer([positive, monotonic])),
    filename:join(Parent, Prefix ++ Token).

option_value(Key, Options) when is_map(Options) ->
    case maps:find(Key, Options) of
        {ok, Value} -> {ok, Value};
        error -> absent
    end;
option_value(Key, Options) when is_list(Options) ->
    case lists:keyfind(Key, 1, Options) of
        {Key, Value} -> {ok, Value};
        false -> absent
    end;
option_value(_Key, _Options) ->
    absent.

environment_value(Name, EnvFun) ->
    case EnvFun(Name) of
        false -> absent;
        [] -> {error, empty};
        Value when is_list(Value) -> {ok, Value};
        Value -> {error, {invalid_value, Value}}
    end.

first_environment_value([], _EnvFun) ->
    {error, unavailable};
first_environment_value([Name | Rest], EnvFun) ->
    case environment_value(Name, EnvFun) of
        absent -> first_environment_value(Rest, EnvFun);
        Result -> Result
    end.

%% Tests set this process-local marker directly; there is no production
%% failure-injection API or transaction option surface.
test_failure(Key) ->
    case get({?MODULE, test_failure}) of
        Key -> {error, injected};
        Keys when is_list(Keys) ->
            case lists:member(Key, Keys) of
                true -> {error, injected};
                false -> ok
            end;
        _ -> ok
    end.

install_error(Stage, Path, Reason) ->
    {error, {install, Stage, Path, Reason}}.

loader_read_link_info(Path) ->
    case erl_prim_loader:read_link_info(Path) of
        error -> {error, enoent};
        Result -> Result
    end.

loader_list_dir(Path) ->
    case erl_prim_loader:list_dir(Path) of
        error -> {error, enoent};
        Result -> Result
    end.

loader_read_file(Path) ->
    case erl_prim_loader:read_file(Path) of
        error -> {error, enoent};
        Result -> Result
    end.

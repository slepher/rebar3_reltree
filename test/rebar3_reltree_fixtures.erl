-module(rebar3_reltree_fixtures).

-include_lib("kernel/include/file.hrl").

-export([
    new_root/0,
    write_project/4,
    checkout/3,
    request/3,
    read_report/1,
    cleanup/1,
    git_tag/2,
    add_origin/2,
    write_file/2
]).

new_root() ->
    Root = filename:join("/tmp", "reltree-task2-" ++
                          integer_to_list(erlang:unique_integer([positive]))),
    ok = file:make_dir(Root),
    Root.

write_project(Root, App, Deps, Vsn) ->
    Src = filename:join(Root, "src"),
    ok = file:make_dir(Src),
    Config = io_lib:format("{deps, ~tp}.~n", [Deps]),
    AppSrc = io_lib:format("{application, ~p, [{vsn, ~tp}]}.~n",
                           [App, Vsn]),
    ok = file:write_file(filename:join(Root, "rebar.config"), Config),
    ok = file:write_file(filename:join(Src,
                                       atom_to_list(App) ++ ".app.src"),
                         AppSrc),
    ok = git_run(Root, ["init", "-q"]),
    ok = git_run(Root, ["config", "user.email", "reltree@example.invalid"]),
    ok = git_run(Root, ["config", "user.name", "reltree fixture"]),
    ok = git_run(Root, ["add", "."]),
    ok = git_run(Root, ["commit", "-qm", "fixture"]),
    Root.

checkout(Consumer, Name, Target) ->
    Dir = filename:join(Consumer, "_checkouts"),
    case filelib:is_dir(Dir) of
        true -> ok;
        false -> ok = file:make_dir(Dir)
    end,
    file:make_symlink(Target, filename:join(Dir, atom_to_list(Name))).

request(Root, ScanRoots, Profile) ->
    BuildBase = filename:join([Root, "_build", atom_to_list(Profile)]),
    #{command => tree,
      project_root => Root,
      profile => Profile,
      build_base_dir => BuildBase,
      output_path => filename:join([BuildBase, "reltree", "project.md"]),
      scan_roots => ScanRoots,
      rev => auto}.

read_report(Request) ->
    {ok, Bytes} = file:read_file(maps:get(output_path, Request)),
    Bytes.

git_tag(Root, Tag) ->
    ok = git_run(Root, ["tag", Tag]),
    ok.

add_origin(Root, Url) ->
    ok = git_run(Root, ["remote", "add", "origin", Url]),
    ok.

write_file(Path, Contents) ->
    ok = filelib:ensure_dir(Path),
    ok = file:write_file(Path, Contents),
    ok.

cleanup(Root) ->
    remove(Root),
    ok.

git_run(Directory, Args) ->
    {ok, Git} = rebar3_reltree_git:executable(),
    Port = open_port({spawn_executable, Git},
                     [{args, Args}, {cd, Directory}, binary, exit_status,
                      stderr_to_stdout, hide]),
    collect_git(Port, <<>>).

collect_git(Port, Acc) ->
    receive
        {Port, {data, Data}} -> collect_git(Port, <<Acc/binary, Data/binary>>);
        {Port, {exit_status, 0}} -> ok;
        {Port, {exit_status, Status}} ->
            erlang:error({fixture_git, Status, Acc})
    after 10000 ->
        port_close(Port),
        erlang:error(fixture_git_timeout)
    end.

remove(Path) ->
    case file:read_link_info(Path) of
        {ok, #file_info{type = symlink}} ->
            _ = file:delete(Path), ok;
        {ok, #file_info{type = directory}} ->
            case file:list_dir(Path) of
                {ok, Names} ->
                    lists:foreach(fun(Name) -> remove(filename:join(Path, Name))
                                  end, Names),
                    _ = file:del_dir(Path), ok;
                {error, _} -> ok
            end;
        {ok, _} ->
            _ = file:delete(Path), ok;
        {error, enoent} -> ok;
        {error, {enoent, _}} -> ok;
        {error, _} -> ok
    end.

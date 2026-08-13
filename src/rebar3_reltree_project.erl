-module(rebar3_reltree_project).

-export([generate/1, generate/2, enrich/3]).

-spec generate(map()) -> {ok, map()} | {error, term()}.
generate(Request) ->
    generate(Request, #{}).

-spec generate(map(), map()) -> {ok, map()} | {error, term()}.
generate(Request, Options) when is_map(Request), is_map(Options) ->
    case rebar3_reltree_graph:build(Request) of
        {error, _} = Error ->
            Error;
        {ok, Graph} ->
            case enrich(Graph, Options, Request) of
                {error, _} = Error ->
                    Error;
                {ok, Model} ->
                    case rebar3_reltree_report:render(Model, Options) of
                        {ok, Bytes} ->
                            WriteOptions = maps:with([fail, fail_stage],
                                                     Options),
                            Output = maps:get(output_path, Request),
                            case rebar3_reltree_fs:atomic_write(
                                   Output, Bytes, WriteOptions) of
                                {ok, _Path} ->
                                    {ok, #{output_path => Output,
                                           bytes => Bytes,
                                           model => Model}};
                                {error, Reason} ->
                                    {error, Reason}
                            end;
                        {error, Reason} ->
                            {error, {report_render, Reason}}
                    end
            end
    end.

-spec enrich(map(), map(), map()) -> {ok, map()} | {error, term()}.
enrich(Graph, Options, Request) ->
    Current = maps:get(current, Graph),
    Included = maps:get(included, Graph),
    Entries = maps:get(entries, Graph),
    RelationshipFacts = maps:get(relationship_facts, Graph, #{}),
    case enrich_nodes(Included, Current, Entries, RelationshipFacts,
                      [], [], []) of
        {error, _} = Error ->
            Error;
        {ok, Nodes, Omitted, Warnings} ->
            UnincludedWarnings = enrich_unincluded(Graph, Included),
            Edges0 = maps:get(edges, Graph),
            Edges = [Edge || Edge <- Edges0,
                             not lists:member(maps:get(source, Edge), Omitted),
                             not lists:member(maps:get(target, Edge), Omitted)],
            GraphIssues0 = maps:get(graph_issues, Graph, []),
            GraphIssues = lists:usort(GraphIssues0 ++
                                      [{Path, omitted_candidate} ||
                                       Path <- Omitted]),
            BaseModel = #{format_version => 2,
                      current => Current,
                      current_name => filename:basename(Current),
                      nodes => Nodes,
                      edges => Edges,
                      warnings => sort_warnings(
                                    maps:get(warnings, Graph) ++ Warnings ++
                                    UnincludedWarnings),
                      graph_issues => GraphIssues,
                      request => Request},
            case rebar3_reltree_rev:enrich(
                   BaseModel, Edges, maps:get(rev, Request, auto),
                   maps:get(output_path, Request), Options) of
                {error, _} = Error ->
                    Error;
                {ok, RevisionModel} ->
                    StatusInput = #{nodes => maps:get(nodes, RevisionModel),
                                    graph_issues => GraphIssues,
                                    revision_reasons => maps:get(
                                      revision_reasons, RevisionModel, [])},
                    {Status, StatusReasons} =
                        rebar3_reltree_status:evaluate(StatusInput),
                    case rebar3_reltree_clock:now(Options) of
                        {error, Reason} -> {error, Reason};
                        {ok, LocalSyncAt} ->
                            {ok, RevisionModel#{status => Status,
                                                status_reasons => StatusReasons,
                                                local_sync_at => LocalSyncAt}}
                    end
            end
    end.

enrich_unincluded(Graph, Included) ->
    IncludedSet = maps:from_list([{Path, true} || Path <- Included]),
    Entries = maps:get(entries, Graph),
    maps:fold(
      fun(Path, Entry, Acc) ->
              case maps:is_key(Path, IncludedSet) of
                  true -> Acc;
                  false ->
                      case enrich_candidate(Entry) of
                          {ok, _Node} -> Acc;
                          {error, Reason} ->
                              [rebar3_reltree_graph:warning(
                                 Path, candidate_incomplete, Reason) | Acc]
                      end
              end
      end, [], Entries).

enrich_nodes([], _Current, _Entries, _RelationshipFacts, Nodes, Omitted,
             Warnings) ->
    {ok, lists:reverse(Nodes), lists:reverse(Omitted), Warnings};
enrich_nodes([Path | Rest], Current, Entries, RelationshipFacts, Nodes0,
             Omitted0, Warnings0) ->
    Entry = maps:get(Path, Entries),
    RelationshipFactsForPath = maps:get(Path, RelationshipFacts, #{}),
    case enrich_candidate(Entry, RelationshipFactsForPath) of
        {ok, Node} ->
            enrich_nodes(Rest, Current, Entries, RelationshipFacts,
                         [Node | Nodes0], Omitted0, Warnings0);
        {error, Reason} when Path =:= Current ->
            {error, {current_project, Path, Reason}};
        {error, Reason} ->
            Warning = rebar3_reltree_graph:warning(Path, candidate_incomplete,
                                                    Reason),
            enrich_nodes(Rest, Current, Entries, RelationshipFacts, Nodes0,
                         [Path | Omitted0], [Warning | Warnings0])
    end.

enrich_candidate(Entry) ->
    enrich_candidate(Entry, #{}).

enrich_candidate(Entry, RelationshipFacts) ->
    Path = maps:get(path, Entry),
    Facts = maps:get(facts, Entry),
    case rebar3_reltree_config:app_identity(Path) of
        {ok, App} ->
            case rebar3_reltree_git:read(Path) of
                {ok, Git} ->
                    Version = rebar3_reltree_version:evaluate(
                                maps:get(app_vsn, App), maps:get(tags, Git)),
                    Badge = badge_state(Path, Git, Version),
                    {ok, #{path => Path,
                           name => filename:basename(Path),
                           app => maps:get(app, App),
                           app_vsn => maps:get(app_vsn, App),
                           app_src => maps:get(app_src, App),
                           head => maps:get(head, Git),
                           origin => maps:get(origin, Git),
                           version => Version,
                           dependencies => maps:get(dependencies, Facts),
                           dependency_relationships => RelationshipFacts,
                           project_plugins => maps:get(project_plugins, Facts),
                           plugins => maps:get(plugins, Facts),
                           readme => readme_presence(Path),
                           ci_workflow => workflow_presence(Path),
                           badge => Badge}};
                {error, Reason} ->
                    {error, Reason}
            end;
        {error, Reason} ->
            {error, Reason}
    end.

readme_presence(Path) ->
    #{readme => rebar3_reltree_fs:regular(filename:join(Path, "README.md")),
      readme_zh => rebar3_reltree_fs:regular(
                    filename:join(Path, "README.zh.md"))}.

workflow_presence(Path) ->
    Workflow = filename:join([Path, ".github", "workflows", "ci.yml"]),
    rebar3_reltree_fs:regular(Workflow).

badge_state(Path, Git, Version) ->
    case workflow_presence(Path) of
        false ->
            #{state => skip_no_ci, files => []};
        true ->
            case origin_repo(maps:get(origin, Git)) of
                {ok, Repo} ->
                    Highest = maps:get(highest_formal, Version),
                    Expected = expected_badges(Repo, Highest),
                    Files = badge_files(Path),
                    States = [badge_file_state(File, Expected) ||
                              File <- Files],
                    HasReadme = rebar3_reltree_fs:regular(
                                  filename:join(Path, "README.md")),
                    case HasReadme andalso
                         lists:all(fun(State) -> State =:= ok end, States) of
                        true -> #{state => ok, files => Files};
                        false -> #{state => badge_mismatch, files => Files,
                                   expected => Expected}
                    end;
                error ->
                    #{state => badge_mismatch, files => badge_files(Path),
                      reason => origin_unavailable}
            end
    end.

badge_files(Path) ->
    Names = ["README.md", "README.zh.md"],
    [badge_file(Path, Name) || Name <- Names,
       rebar3_reltree_fs:regular(filename:join(Path, Name))].

badge_file(Path, Name) ->
    File = filename:join(Path, Name),
    Base = #{path => File, name => Name},
    case rebar3_reltree_fs:read_file(File) of
        {ok, Content} -> Base#{content => Content};
        {error, Reason} -> Base#{read_error => Reason}
    end.

expected_badges(Repo, none) ->
    #{master => master_badge(Repo), release => none};
expected_badges(Repo, #{tag := Tag}) ->
    #{master => master_badge(Repo), release => release_badge(Repo, Tag)}.

master_badge(Repo) ->
    Base = "https://github.com/" ++ Repo ++
           "/actions/workflows/ci.yml",
    "**master CI** [![CI](" ++ Base ++
    "/badge.svg?branch=master&event=push)](" ++ Base ++
    "?query=branch%3Amaster)".

release_badge(Repo, Tag) ->
    Base = "https://github.com/" ++ Repo ++
           "/actions/workflows/ci.yml",
    Label = case Tag of
                [$v | Rest] -> Rest;
                _ -> Tag
            end,
    "**" ++ Label ++ " release CI** [![CI](" ++ Base ++
    "/badge.svg?branch=" ++ Tag ++ "&event=push)](" ++ Base ++
    "?query=branch%3A" ++ Tag ++ ")".

badge_file_state(#{content := Content}, Expected) ->
    Master = maps:get(master, Expected),
    Release = maps:get(release, Expected),
    MasterCount = count_substring(binary_to_list(Content), Master),
    ReleaseCount = case Release of
                       none -> 0;
                       Value -> count_substring(binary_to_list(Content), Value)
                   end,
    case {MasterCount, Release} of
        {1, none} -> ok;
        {1, _} when ReleaseCount =:= 1 -> ok;
        _ -> mismatch
    end;
badge_file_state(#{read_error := _Reason}, _Expected) ->
    mismatch.

origin_repo(none) ->
    error;
origin_repo({ok, Url0}) ->
    Url = string:trim(binary_to_list(Url0)),
    case re:run(Url, "github\\.com[/:]([^/]+)/([^/]+?)(?:\\.git)?/?$",
                [{capture, [1, 2], list}]) of
        {match, [Owner, Repo]} -> {ok, Owner ++ "/" ++ Repo};
        nomatch -> error
    end.

count_substring(Text, Needle) ->
    count_substring(Text, Needle, 0).

count_substring([], _Needle, Count) -> Count;
count_substring(Text, Needle, Count) ->
    case lists:prefix(Needle, Text) of
        true -> count_substring(lists:nthtail(length(Needle), Text), Needle,
                                Count + 1);
        false -> count_substring(tl(Text), Needle, Count)
    end.

sort_warnings(Warnings) ->
    Unique = maps:values(maps:from_list([
                         {{maps:get(path, W), maps:get(reason, W),
                           detail_text(maps:get(detail, W))}, W} ||
                         W <- Warnings])),
    lists:sort(fun(A, B) ->
                       {maps:get(path, A), maps:get(reason, A),
                        detail_text(maps:get(detail, A))} =<
                       {maps:get(path, B), maps:get(reason, B),
                        detail_text(maps:get(detail, B))}
               end, Unique).

detail_text(Detail) ->
    lists:flatten(io_lib:format("~tp", [Detail])).

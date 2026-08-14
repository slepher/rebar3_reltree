-module(rebar3_reltree_graph).

-export([build/1, warning/3]).

-spec build(map()) -> {ok, map()} | {error, term()}.
build(Request) ->
    ProjectRoot = maps:get(project_root, Request),
    Current = rebar3_reltree_fs:canonical(ProjectRoot),
    {Catalog, ScanWarnings} = rebar3_reltree_scan:catalog(
        ProjectRoot,
        maps:get(scan_roots, Request, [])
    ),
    State0 = #{
        current => Current,
        entries => #{},
        invalid => #{},
        warnings => ScanWarnings,
        relation_bad => #{},
        relations => #{},
        relationship_facts => #{},
        processed => #{}
    },
    case load_catalog(maps:to_list(Catalog), Current, State0) of
        {error, _} = Error ->
            Error;
        {ok, State1} ->
            case maps:is_key(Current, maps:get(entries, State1)) of
                false ->
                    {error, {current_project, Current, missing_candidate}};
                true ->
                    State2 = relation_pass(State1),
                    {ok, finalize(State2)}
            end
    end.

load_catalog([], _Current, State) ->
    {ok, State};
load_catalog([{Path, Candidate} | Rest], Current, State0) ->
    Source = maps:get(sources, Candidate, []),
    case load_entry(Path, Source, Current, State0) of
        {error, _} = Error -> Error;
        {ok, State1} -> load_catalog(Rest, Current, State1)
    end.

load_entry(Path, Sources, Current, State0) ->
    case rebar3_reltree_config:read(Path) of
        {ok, Facts} ->
            Entry = #{path => Path, sources => Sources, facts => Facts},
            Entries = maps:put(Path, Entry, maps:get(entries, State0)),
            {ok, State0#{entries => Entries}};
        {error, Reason} when Path =:= Current ->
            {error, {current_project, Path, Reason}};
        {error, Reason} ->
            {ok, invalid_entry(Path, Reason, State0)}
    end.

relation_pass(State0) ->
    Paths = lists:sort(maps:keys(maps:get(entries, State0))),
    relation_queue(Paths, State0).

relation_queue([], State) ->
    State;
relation_queue([Path | Rest], State0) ->
    case maps:is_key(Path, maps:get(processed, State0)) of
        true ->
            relation_queue(Rest, State0);
        false ->
            State1 = State0#{
                processed => maps:put(
                    Path, true, maps:get(processed, State0)
                )
            },
            case maps:find(Path, maps:get(entries, State1)) of
                error ->
                    relation_queue(Rest, State1);
                {ok, Entry} ->
                    {State2, NewPaths} = inspect_dependencies(Entry, State1),
                    relation_queue(lists:usort(Rest ++ NewPaths), State2)
            end
    end.

inspect_dependencies(Entry, State0) ->
    Path = maps:get(path, Entry),
    Deps = rebar3_reltree_config:dependency_declarations(
        maps:get(facts, Entry)
    ),
    inspect_dependencies(Deps, Path, State0, []).

inspect_dependencies([], _Path, State, NewPaths) ->
    {State, NewPaths};
inspect_dependencies([Declaration | Rest], Path, State0, NewPaths0) ->
    {ok, Name} = rebar3_reltree_config:dependency_name(Declaration),
    Checkout = filename:join([Path, "_checkouts", atom_to_list(Name)]),
    case file:read_link_info(Checkout) of
        {error, enoent} ->
            State1 = set_relationship(Path, Name, external, State0),
            inspect_dependencies(Rest, Path, State1, NewPaths0);
        {error, {enoent, _}} ->
            State1 = set_relationship(Path, Name, external, State0),
            inspect_dependencies(Rest, Path, State1, NewPaths0);
        {error, Reason} ->
            State1 = relation_anomaly(Path, Checkout, Reason, State0),
            State2 = set_relationship(
                Path,
                Name,
                omitted_local_checkout,
                State1
            ),
            inspect_dependencies(Rest, Path, State2, NewPaths0);
        {ok, _Info} ->
            case rebar3_reltree_fs:resolve_checkout(Checkout) of
                {ok, Target} ->
                    case ensure_target(Target, Path, Name, State0) of
                        {ok, State1, New} ->
                            case
                                maps:is_key(
                                    Target,
                                    maps:get(entries, State1)
                                )
                            of
                                true ->
                                    State2 = add_relation(
                                        Path,
                                        Target,
                                        Name,
                                        Declaration,
                                        State1
                                    ),
                                    State3 = set_relationship(
                                        Path,
                                        Name,
                                        local_checkout,
                                        State2
                                    ),
                                    inspect_dependencies(
                                        Rest,
                                        Path,
                                        State3,
                                        add_new(
                                            NewPaths0,
                                            New
                                        )
                                    );
                                false ->
                                    State2 = relation_anomaly(
                                        Path,
                                        Target,
                                        target_not_valid_project,
                                        State1
                                    ),
                                    State3 = set_relationship(
                                        Path,
                                        Name,
                                        omitted_local_checkout,
                                        State2
                                    ),
                                    inspect_dependencies(
                                        Rest,
                                        Path,
                                        State3,
                                        add_new(NewPaths0, New)
                                    )
                            end;
                        {invalid, State1} ->
                            State2 = relation_anomaly(
                                Path,
                                Target,
                                target_not_valid_project,
                                State1
                            ),
                            State3 = set_relationship(
                                Path,
                                Name,
                                omitted_local_checkout,
                                State2
                            ),
                            inspect_dependencies(
                                Rest,
                                Path,
                                State3,
                                NewPaths0
                            );
                        {error, State1} ->
                            State2 = relation_anomaly(
                                Path,
                                Target,
                                target_read_failed,
                                State1
                            ),
                            State3 = set_relationship(
                                Path,
                                Name,
                                omitted_local_checkout,
                                State2
                            ),
                            inspect_dependencies(
                                Rest,
                                Path,
                                State3,
                                NewPaths0
                            )
                    end;
                {error, Reason} ->
                    State1 = relation_anomaly(Path, Checkout, Reason, State0),
                    State2 = set_relationship(
                        Path,
                        Name,
                        omitted_local_checkout,
                        State1
                    ),
                    inspect_dependencies(Rest, Path, State2, NewPaths0)
            end
    end.

ensure_target(Target, SourcePath, Name, State0) ->
    Entries0 = maps:get(entries, State0),
    case maps:find(Target, Entries0) of
        {ok, Entry} ->
            Sources0 = maps:get(sources, Entry, []),
            Source = #{
                kind => checkout,
                path => SourcePath,
                dependency => Name
            },
            Entry1 = Entry#{sources => merge_sources([Source | Sources0])},
            {ok, State0#{entries => maps:put(Target, Entry1, Entries0)}, none};
        error ->
            case maps:find(Target, maps:get(invalid, State0)) of
                {ok, _Reason} ->
                    {invalid, State0};
                error ->
                    case rebar3_reltree_config:read(Target) of
                        {ok, Facts} ->
                            Entry = #{
                                path => Target,
                                sources => [
                                    #{
                                        kind => checkout,
                                        path => SourcePath,
                                        dependency => Name
                                    }
                                ],
                                facts => Facts
                            },
                            {ok,
                                State0#{
                                    entries => maps:put(
                                        Target,
                                        Entry,
                                        Entries0
                                    )
                                },
                                Target};
                        {error, Reason} ->
                            {invalid, invalid_entry(Target, Reason, State0)}
                    end
            end
    end.

add_relation(Source, Target, Name, Declaration, State0) ->
    Relations0 = maps:get(relations, State0),
    Existing = maps:get(Source, Relations0, []),
    case
        lists:any(
            fun(Edge) -> maps:get(dependency, Edge) =:= Name end,
            Existing
        )
    of
        true ->
            State0;
        false ->
            Edge = #{
                source => Source,
                target => Target,
                dependency => Name,
                declaration => Declaration
            },
            State0#{
                relations => maps:put(
                    Source,
                    [Edge | Existing],
                    Relations0
                )
            }
    end.

invalid_entry(Path, Reason, State0) ->
    Invalid = maps:put(Path, Reason, maps:get(invalid, State0)),
    add_warning(
        warning(Path, candidate_invalid, Reason),
        State0#{invalid => Invalid}
    ).

set_relationship(Path, Name, Relationship, State0) ->
    Facts0 = maps:get(relationship_facts, State0),
    PathFacts0 = maps:get(Path, Facts0, #{}),
    PathFacts = maps:put(Name, Relationship, PathFacts0),
    State0#{relationship_facts => maps:put(Path, PathFacts, Facts0)}.

relation_anomaly(Path, RelatedPath, Detail, State0) ->
    Existing = maps:get(Path, maps:get(relation_bad, State0), []),
    Key = {rebar3_reltree_fs:canonical(RelatedPath), Detail},
    Bad =
        case lists:member(Key, Existing) of
            true -> Existing;
            false -> [Key | Existing]
        end,
    RelationBad = maps:put(Path, Bad, maps:get(relation_bad, State0)),
    add_warning(
        warning(
            Path,
            checkout_invalid,
            #{checkout => RelatedPath, detail => Detail}
        ),
        State0#{relation_bad => RelationBad}
    ).

add_warning(Warning, State0) ->
    State0#{warnings => [Warning | maps:get(warnings, State0)]}.

add_new(Paths, false) -> Paths;
add_new(Paths, none) -> Paths;
add_new(Paths, Path) -> [Path | Paths].

%% A target is included when it is connected to the current node through a
%% valid declaration-plus-checkout edge in either direction.  Nodes with a
%% broken relevant checkout are omitted, except that the current node remains
%% renderable so its insufficient-local-data status can explain the problem.
finalize(State0) ->
    Current = maps:get(current, State0),
    Entries = maps:get(entries, State0),
    Relations = maps:get(relations, State0),
    RelationBad = maps:get(relation_bad, State0),
    ValidPaths = maps:keys(Entries),
    Allowed = fun(Path) ->
        Path =:= Current orelse
            not maps:is_key(Path, RelationBad)
    end,
    Adjacency = adjacency(Relations, ValidPaths, Allowed, #{}),
    IncludedSet = connected([Current], Adjacency, #{Current => true}),
    Included = lists:sort(maps:keys(IncludedSet)),
    GraphIssues = incident_issues(Included, Relations, RelationBad),
    Edges = [
        Edge
     || {_Source, EdgeList} <- maps:to_list(Relations),
        Edge <- EdgeList,
        maps:is_key(maps:get(source, Edge), IncludedSet),
        maps:is_key(maps:get(target, Edge), IncludedSet),
        Allowed(maps:get(source, Edge)),
        Allowed(maps:get(target, Edge))
    ],
    #{
        current => Current,
        entries => Entries,
        included => Included,
        edges => unique_edges(Edges),
        graph_issues => GraphIssues,
        relationship_facts => maps:get(relationship_facts, State0),
        warnings => sort_warnings(maps:get(warnings, State0))
    }.

adjacency(Relations, ValidPaths, Allowed, Acc0) ->
    Acc1 = lists:foldl(
        fun(Path, Acc) -> maps:put(Path, [], Acc) end,
        Acc0,
        ValidPaths
    ),
    lists:foldl(
        fun({_Source, EdgeList}, Acc) ->
            lists:foldl(
                fun(Edge, AccIn) ->
                    Source = maps:get(source, Edge),
                    Target = maps:get(target, Edge),
                    case Allowed(Source) andalso Allowed(Target) of
                        true ->
                            AccA = maps:update_with(
                                Source,
                                fun(V) -> [Target | V] end,
                                [Target],
                                AccIn
                            ),
                            maps:update_with(
                                Target,
                                fun(V) -> [Source | V] end,
                                [Source],
                                AccA
                            );
                        false ->
                            AccIn
                    end
                end,
                Acc,
                EdgeList
            )
        end,
        Acc1,
        maps:to_list(Relations)
    ).

connected([], _Adjacency, Seen) ->
    Seen;
connected([Path | Rest], Adjacency, Seen0) ->
    Neighbours = maps:get(Path, Adjacency, []),
    {New, Seen} = lists:foldl(
        fun(Neighbour, {Queue, SeenIn}) ->
            case maps:is_key(Neighbour, SeenIn) of
                true -> {Queue, SeenIn};
                false -> {[Neighbour | Queue], maps:put(Neighbour, true, SeenIn)}
            end
        end,
        {Rest, Seen0},
        Neighbours
    ),
    connected(New, Adjacency, Seen).

incident_issues(Included, Relations, RelationBad) ->
    IncludedSet = maps:from_list([{Path, true} || Path <- Included]),
    BadIssues = [
        {Path, relation_anomaly}
     || Path <- Included,
        maps:is_key(Path, RelationBad)
    ],
    Omitted = lists:foldl(
        fun({_Source, EdgeList}, Acc) ->
            lists:foldl(
                fun(Edge, AccIn) ->
                    Source = maps:get(source, Edge),
                    Target = maps:get(target, Edge),
                    SourceIncluded = maps:is_key(
                        Source,
                        IncludedSet
                    ),
                    TargetIncluded = maps:is_key(
                        Target,
                        IncludedSet
                    ),
                    SourceBad = maps:is_key(Source, RelationBad),
                    TargetBad = maps:is_key(Target, RelationBad),
                    case
                        (SourceIncluded orelse TargetIncluded) andalso
                            (SourceBad orelse TargetBad)
                    of
                        true ->
                            [
                                {Source, omitted_relation}
                                | AccIn
                            ];
                        false ->
                            AccIn
                    end
                end,
                Acc,
                EdgeList
            )
        end,
        [],
        maps:to_list(Relations)
    ),
    lists:usort(BadIssues ++ Omitted).

unique_edges(Edges) ->
    lists:sort(
        fun edge_less/2,
        maps:values(
            maps:from_list([
                {{maps:get(source, E), maps:get(target, E), maps:get(dependency, E)}, E}
             || E <- Edges
            ])
        )
    ).

edge_less(A, B) ->
    {maps:get(source, A), maps:get(target, A), maps:get(dependency, A)} =<
        {maps:get(source, B), maps:get(target, B), maps:get(dependency, B)}.

merge_sources(Sources) ->
    lists:usort(Sources).

sort_warnings(Warnings) ->
    Unique = maps:values(
        maps:from_list([
            {{maps:get(path, W), maps:get(reason, W), detail_text(maps:get(detail, W))}, W}
         || W <- Warnings
        ])
    ),
    lists:sort(
        fun(A, B) ->
            {maps:get(path, A), maps:get(reason, A), detail_text(maps:get(detail, A))} =<
                {maps:get(path, B), maps:get(reason, B), detail_text(maps:get(detail, B))}
        end,
        Unique
    ).

detail_text(Detail) ->
    lists:flatten(io_lib:format("~tp", [Detail])).

-spec warning(filename:filename_all(), atom(), term()) -> map().
warning(Path, Reason, Detail) ->
    #{
        path => rebar3_reltree_fs:canonical(Path),
        reason => Reason,
        detail => Detail
    }.

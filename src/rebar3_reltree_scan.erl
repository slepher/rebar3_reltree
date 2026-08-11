-module(rebar3_reltree_scan).

-export([catalog/2]).

-define(SKIP_NAMES, [".git", "_build", "_checkouts", "node_modules"]).

-spec catalog(filename:filename_all(), [{string(), shallow | deep}]) ->
    {map(), [map()]}.
catalog(ProjectRoot, Roots) ->
    Current = rebar3_reltree_fs:canonical(ProjectRoot),
    Initial = #{Current => #{path => Current,
                             sources => [#{kind => current,
                                           path => Current}]}},
    CandidateIdentities = initial_identity(ProjectRoot, Current),
    State0 = #{candidates => Initial,
               candidate_identities => CandidateIdentities,
               warnings => [],
               visited => #{}},
    State = scan_roots(Roots, State0),
    {maps:get(candidates, State), maps:get(warnings, State)}.

initial_identity(ProjectRoot, Current) ->
    case rebar3_reltree_fs:identity(ProjectRoot) of
        {ok, Identity} -> #{Identity => Current};
        {error, _} -> #{}
    end.

scan_roots([], State) ->
    State;
scan_roots([{Root, Mode} | Rest], State0) ->
    State1 = case rebar3_reltree_fs:identity(Root) of
                 {ok, _Identity} ->
                     case rebar3_reltree_fs:directory(Root) of
                         true ->
                             %% An explicit root must be readable before it
                             %% can become a candidate.  This keeps an
                             %% unreadable root to one warning and no entry.
                             case rebar3_reltree_fs:list_dir(Root) of
                                 {ok, Names} ->
                                     scan_directory(Root, Mode, State0,
                                                    {ok, Names});
                                 {error, Reason} ->
                                     add_warning(
                                       warning(Root, scan_root_skipped,
                                               Reason), State0)
                             end;
                         false ->
                             add_warning(
                               warning(Root, scan_root_skipped,
                                       not_directory), State0)
                     end;
                 {error, Reason} ->
                     add_warning(warning(Root, scan_root_skipped, Reason),
                                 State0)
             end,
    scan_roots(Rest, State1).

scan_directory(Path, Mode, State0, Names0) ->
    case rebar3_reltree_fs:identity(Path) of
        {ok, Identity} ->
            State1 = maybe_candidate(Path, Identity,
                                     {scan, Path, Mode}, State0),
            Level = mode_level(Mode),
            Visited0 = maps:get(visited, State1),
            case maps:get(Identity, Visited0, -1) >= Level of
                true ->
                    State1;
                false ->
                    State2 = State1#{visited => maps:put(Identity, Level,
                                                         Visited0)},
                    case directory_names(Path, Names0) of
                        {ok, Names} ->
                            scan_children(Path, Names, Mode, State2);
                        {error, Reason} ->
                            add_warning(
                              warning(Path, scan_directory_read, Reason),
                              State2)
                    end
            end;
        {error, Reason} ->
            add_warning(warning(Path, scan_directory_read, Reason), State0)
    end.

directory_names(_Path, {ok, Names}) ->
    {ok, Names};
directory_names(Path, none) ->
    rebar3_reltree_fs:list_dir(Path).

scan_children(_Parent, [], _Mode, State) ->
    State;
scan_children(Parent, [Name | Rest], Mode, State0) ->
    Child = filename:join(Parent, Name),
    State1 = case lists:member(Name, ?SKIP_NAMES) of
                 true ->
                     State0;
                 false ->
                     case rebar3_reltree_fs:directory(Child) of
                         true ->
                             case rebar3_reltree_fs:identity(Child) of
                                 {ok, Identity} ->
                                     State2 = maybe_candidate(
                                                Child, Identity,
                                                {scan, Child, Mode}, State0),
                                     case Mode of
                                         shallow -> State2;
                                         deep -> scan_directory(
                                                  Child, deep, State2, none)
                                     end;
                                 {error, _Reason} ->
                                     State0
                             end;
                         false ->
                             case rebar3_reltree_fs:identity(Child) of
                                 {error, {not_directory, symlink}} ->
                                     add_warning(
                                       warning(Child, scan_entry_skipped,
                                               symlink), State0);
                                 _ ->
                                     State0
                             end
                     end
             end,
    scan_children(Parent, Rest, Mode, State1).

maybe_candidate(Path0, Identity, Source, State0) ->
    Path = rebar3_reltree_fs:canonical(Path0),
    Candidates0 = maps:get(candidates, State0),
    Identities0 = maps:get(candidate_identities, State0),
    case maps:find(Identity, Identities0) of
        {ok, ExistingPath} ->
            merge_candidate_source(ExistingPath, Source, State0);
        error ->
            Config = filename:join(Path, "rebar.config"),
            case rebar3_reltree_fs:regular(Config) of
                true ->
                    State1 = case maps:find(Path, Candidates0) of
                                 error ->
                                     State0#{candidates => maps:put(
                                               Path,
                                               #{path => Path,
                                                 sources => [source(Source)]},
                                               Candidates0)};
                                 {ok, _Existing} ->
                                     merge_candidate_source(Path, Source,
                                                             State0)
                             end,
                    State1#{candidate_identities => maps:put(
                                  Identity, Path, Identities0)};
                false ->
                    State0
            end
    end.

merge_candidate_source(Path, Source, State0) ->
    Candidates0 = maps:get(candidates, State0),
    case maps:find(Path, Candidates0) of
        error ->
            State0;
        {ok, Existing} ->
            Sources = maps:get(sources, Existing, []),
            Candidates = maps:put(
                           Path,
                           Existing#{sources => merge_sources(
                                                  [source(Source) | Sources])},
                           Candidates0),
            State0#{candidates => Candidates}
    end.

source({scan, Path, Mode}) -> #{kind => scan, path => Path, mode => Mode};
source({current, Path}) -> #{kind => current, path => Path}.

merge_sources(Sources) ->
    merge_sources(Sources, #{}, []).

merge_sources([], _Seen, Acc) ->
    lists:reverse(Acc);
merge_sources([Source | Rest], Seen, Acc) ->
    Key = source_key(Source),
    case maps:is_key(Key, Seen) of
        true ->
            merge_sources(Rest, Seen, Acc);
        false ->
            merge_sources(Rest, maps:put(Key, true, Seen),
                          [Source | Acc])
    end.

source_key(#{kind := Kind, path := Path} = Source) ->
    {Kind, Path, maps:get(mode, Source, none)}.

mode_level(shallow) -> 0;
mode_level(deep) -> 1.

add_warning(Warning, State0) ->
    State0#{warnings => [Warning | maps:get(warnings, State0)]}.

warning(Path, Reason, Detail) ->
    #{path => rebar3_reltree_fs:canonical(Path),
      reason => Reason,
      detail => Detail}.

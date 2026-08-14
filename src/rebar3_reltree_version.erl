-module(rebar3_reltree_version).

-export([
    evaluate/2,
    check/2,
    parse_version/1,
    parse_tag/1,
    highest_formal/1
]).

-spec evaluate(string(), [string()]) -> map().
evaluate(AppVsn, Tags) ->
    ParsedApp = parse_version(AppVsn),
    {Formal, Prerelease} = classify_tags(Tags),
    SortedFormal = sort_formal(Formal),
    Highest = highest_formal(SortedFormal),
    PreMismatch = prerelease_mismatch(ParsedApp, Prerelease),
    {Reason, Status} = evaluate_line(ParsedApp, Highest, PreMismatch),
    #{
        app_vsn => AppVsn,
        parsed_app_vsn => ParsedApp,
        formal_tags => SortedFormal,
        prerelease_tags => sort_prerelease(Prerelease),
        highest_formal => Highest,
        reason => Reason,
        status => Status
    }.

%% The version gate consumes the richer Git fact map used by the provider.
%% `tags` remains accepted for the tree's existing fact shape; new callers
%% should provide `reachable_tags` and, when available, `head_tags`.
-spec check(string(), map()) -> {ok, map()} | {error, term()}.
check(AppVsn, GitFacts) when is_map(GitFacts) ->
    case parse_version(AppVsn) of
        error ->
            {error, {invalid_app_version, AppVsn}};
        {ok, ParsedApp} ->
            ReachableTags = maps:get(
                reachable_tags,
                GitFacts,
                maps:get(tags, GitFacts, [])
            ),
            HeadTags = maps:get(head_tags, GitFacts, []),
            {Formal, Prerelease} = classify_tags(ReachableTags),
            {HeadFormal, HeadPrerelease} = classify_tags(HeadTags),
            SortedFormal = sort_formal(Formal),
            SortedPrerelease = sort_prerelease(Prerelease),
            FormalVersions = group_formal(SortedFormal),
            Highest = highest_formal_version(FormalVersions),
            CurrentTags =
                sort_formal(HeadFormal) ++
                    sort_prerelease(HeadPrerelease),
            case current_tag_mismatch(ParsedApp, CurrentTags) of
                [] ->
                    case continuity(ParsedApp, Highest) of
                        invalid ->
                            {error,
                                {version_not_continuous, #{
                                    app => ParsedApp,
                                    highest_formal => Highest
                                }}};
                        Classification ->
                            {ok, #{
                                app_vsn => AppVsn,
                                parsed_app_vsn => ParsedApp,
                                formal_tags => SortedFormal,
                                formal_versions => FormalVersions,
                                prerelease_tags => SortedPrerelease,
                                head_tags => HeadTags,
                                highest_formal => Highest,
                                continuity => Classification
                            }}
                    end;
                Mismatches ->
                    {error, {current_tag_base_mismatch, Mismatches}}
            end
    end;
check(_AppVsn, _GitFacts) ->
    {error, invalid_git_facts}.

-spec parse_version(term()) ->
    {ok, {non_neg_integer(), non_neg_integer(), non_neg_integer()}}
    | error.
parse_version(Value) when is_list(Value), Value =/= [] ->
    case string:split(Value, ".", all) of
        [A, B, C] ->
            case {integer_part(A), integer_part(B), integer_part(C)} of
                {{ok, X}, {ok, Y}, {ok, Z}} -> {ok, {X, Y, Z}};
                _ -> error
            end;
        _ ->
            error
    end;
parse_version(_Other) ->
    error.

-spec parse_tag(string()) ->
    none
    | {formal, tuple(), string()}
    | {prerelease, tuple(), string()}.
parse_tag(Tag) when is_list(Tag), Tag =/= [] ->
    WithoutV =
        case Tag of
            [$v | Rest] -> Rest;
            _ -> Tag
        end,
    case parse_version(WithoutV) of
        {ok, Version} ->
            {formal, Version, Tag};
        error ->
            case string:split(WithoutV, "-", leading) of
                [Base, Suffix] when Suffix =/= [] ->
                    case parse_version(Base) of
                        {ok, Version} ->
                            case valid_prerelease_suffix(Suffix) of
                                true -> {prerelease, Version, Tag};
                                false -> none
                            end;
                        error ->
                            none
                    end;
                _ ->
                    none
            end
    end;
parse_tag(_Other) ->
    none.

classify_tags(Tags) when is_list(Tags) ->
    Parsed = [
        ParsedTag
     || Tag <- Tags,
        ParsedTag <- [parse_tag(Tag)],
        ParsedTag =/= none
    ],
    {
        [
            #{tag => Tag, version => Version}
         || {formal, Version, Tag} <- Parsed
        ],
        [
            #{tag => Tag, version => Version}
         || {prerelease, Version, Tag} <- Parsed
        ]
    };
classify_tags(_Other) ->
    {[], []}.

valid_prerelease_suffix(Suffix) ->
    case string:split(Suffix, ".", all) of
        [Kind, Serial] when
            (Kind =:= "rc" orelse Kind =:= "ci"),
            Serial =/= []
        ->
            case integer_part(Serial) of
                {ok, _} -> true;
                error -> false
            end;
        _ ->
            false
    end.

-spec highest_formal([map()]) -> none | map().
highest_formal([]) ->
    none;
highest_formal(Formal) ->
    lists:last(sort_formal(Formal)).

sort_formal(Formal) ->
    lists:sort(
        fun(A, B) ->
            {maps:get(version, A), maps:get(tag, A)} =<
                {maps:get(version, B), maps:get(tag, B)}
        end,
        Formal
    ).

sort_prerelease(Prerelease) ->
    lists:sort(
        fun(A, B) ->
            {maps:get(version, A), maps:get(tag, A)} =<
                {maps:get(version, B), maps:get(tag, B)}
        end,
        Prerelease
    ).

group_formal(Formal) ->
    Groups = lists:foldl(
        fun(#{tag := Tag, version := Version}, Acc) ->
            maps:update_with(
                Version,
                fun(Tags) -> [Tag | Tags] end,
                [Tag],
                Acc
            )
        end,
        #{},
        Formal
    ),
    lists:sort(
        fun(A, B) -> maps:get(version, A) =< maps:get(version, B) end,
        [
            #{
                version => Version,
                tags => lists:sort(lists:usort(Tags))
            }
         || {Version, Tags} <- maps:to_list(Groups)
        ]
    ).

highest_formal_version([]) ->
    none;
highest_formal_version(FormalVersions) ->
    lists:last(FormalVersions).

current_tag_mismatch(App, Tags) ->
    [
        #{tag => maps:get(tag, Tag), version => maps:get(version, Tag)}
     || Tag <- Tags, maps:get(version, Tag) =/= App
    ].

continuity(_App, none) ->
    initial;
continuity(App, #{version := Highest}) ->
    case {App, Highest} of
        {Highest, Highest} -> same;
        {{X, Y, Z}, {X, Y, HZ}} when Z =:= HZ + 1 -> next_patch;
        {{X, Y, 0}, {X, HY, _HZ}} when Y =:= HY + 1 -> next_minor;
        {{X, 0, 0}, {HX, _HY, _HZ}} when X =:= HX + 1 -> next_major;
        _ -> invalid
    end.

prerelease_mismatch(_App, []) ->
    false;
prerelease_mismatch({ok, App}, Tags) ->
    lists:any(fun(#{version := Version}) -> Version =/= App end, Tags);
prerelease_mismatch(error, _Tags) ->
    true.

evaluate_line(_ParsedApp, _Highest, true) ->
    {prerelease_base_mismatch, update_required};
evaluate_line(error, _Highest, false) ->
    {invalid_app_version, insufficient_local_data};
evaluate_line({ok, _App}, none, false) ->
    {no_formal_tag, up_to_date};
evaluate_line({ok, App}, #{version := _} = Highest, false) ->
    case continuity(App, Highest) of
        same ->
            {version_line_valid, up_to_date};
        next_patch ->
            {version_line_valid, up_to_date};
        next_minor ->
            {version_line_valid, up_to_date};
        next_major ->
            {generation_selection_needed, insufficient_local_data};
        invalid ->
            {version_line_mismatch, update_required}
    end.

integer_part([]) ->
    error;
integer_part(Value) ->
    case lists:all(fun(Char) -> Char >= $0 andalso Char =< $9 end, Value) of
        true ->
            try
                {ok, list_to_integer(Value)}
            catch
                error:badarg -> error
            end;
        false ->
            error
    end.

-module(rebar3_reltree_version).

-export([
    evaluate/2,
    parse_version/1,
    parse_tag/1,
    highest_formal/1
]).

-spec evaluate(string(), [string()]) -> map().
evaluate(AppVsn, Tags) ->
    ParsedApp = parse_version(AppVsn),
    Parsed = [ParsedTag || Tag <- Tags,
                           ParsedTag <- [parse_tag(Tag)],
                           ParsedTag =/= none],
    Formal = [#{tag => Tag, version => Version} ||
              {formal, Version, Tag} <- Parsed],
    Prerelease = [#{tag => Tag, version => Version} ||
                  {prerelease, Version, Tag} <- Parsed],
    SortedFormal = sort_formal(Formal),
    Highest = highest_formal(SortedFormal),
    PreMismatch = prerelease_mismatch(ParsedApp, Prerelease),
    {Reason, Status} = evaluate_line(ParsedApp, Highest, PreMismatch),
    #{app_vsn => AppVsn,
      parsed_app_vsn => ParsedApp,
      formal_tags => SortedFormal,
      prerelease_tags => sort_prerelease(Prerelease),
      highest_formal => Highest,
      reason => Reason,
      status => Status}.

-spec parse_version(term()) -> {ok, {non_neg_integer(), non_neg_integer(),
                                     non_neg_integer()}} | error.
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

-spec parse_tag(string()) -> none | {formal, tuple(), string()} |
    {prerelease, tuple(), string()}.
parse_tag(Tag) when is_list(Tag), Tag =/= [] ->
    WithoutV = case Tag of
                  [$v | Rest] -> Rest;
                  _ -> Tag
              end,
    case parse_version(WithoutV) of
        {ok, Version} -> {formal, Version, Tag};
        error ->
            case string:split(WithoutV, "-", leading) of
                [Base, Suffix] when Suffix =/= [] ->
                    case parse_version(Base) of
                        {ok, Version} ->
                            case valid_prerelease_suffix(Suffix) of
                                true -> {prerelease, Version, Tag};
                                false -> none
                            end;
                        error -> none
                    end;
                _ ->
                    none
            end
    end;
parse_tag(_Other) ->
    none.

valid_prerelease_suffix(Suffix) ->
    case string:split(Suffix, ".", all) of
        [Kind, Serial] when (Kind =:= "rc" orelse Kind =:= "ci"),
                            Serial =/= [] ->
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
    lists:sort(fun(A, B) ->
                       {maps:get(version, A), maps:get(tag, A)} =<
                       {maps:get(version, B), maps:get(tag, B)}
               end, Formal).

sort_prerelease(Prerelease) ->
    lists:sort(fun(A, B) ->
                       {maps:get(version, A), maps:get(tag, A)} =<
                       {maps:get(version, B), maps:get(tag, B)}
               end, Prerelease).

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
evaluate_line({ok, App}, #{version := Highest}, false) ->
    case App of
        Highest ->
            {version_line_valid, up_to_date};
        {X, Y, Z} ->
            case Highest of
                {X, Y, HZ} when Z =:= HZ + 1 ->
                    {version_line_valid, up_to_date};
                {X, HY, 0} when Y > 0, HY =:= Y - 1 ->
                    {version_line_valid, up_to_date};
                _ when Y =:= 0, Z =:= 0, X > 0,
                       element(1, Highest) =:= X - 1 ->
                    {generation_selection_needed, insufficient_local_data};
                _ ->
                    {version_line_mismatch, update_required}
            end
    end.

integer_part([]) ->
    error;
integer_part(Value) ->
    case lists:all(fun(Char) -> Char >= $0 andalso Char =< $9 end, Value) of
        true ->
            try {ok, list_to_integer(Value)}
            catch
                error:badarg -> error
            end;
        false ->
            error
    end.

-module(rebar3_reltree_clock).

-export([now/0, now/1, format/1, valid/1]).

-spec now() -> {ok, string()} | {error, term()}.
now() ->
    now(#{}).

-spec now(map()) -> {ok, string()} | {error, term()}.
now(Options) when is_map(Options) ->
    Clock = maps:get(clock, Options, fun calendar:universal_time/0),
    try
        Value = case Clock of
                    Fun when is_function(Fun, 0) -> Fun();
                    Other -> Other
                end,
        normalize(Value)
    catch
        Class:Reason -> {error, {invalid_clock, Class, Reason}}
    end.

-spec format(term()) -> string().
format(Calendar) ->
    format_rfc(Calendar).

format_rfc({{Year, Month, Day}, {Hour, Minute, Second}}) ->
    lists:flatten([pad(Year, 4), "-", pad(Month, 2), "-", pad(Day, 2),
                   "T", pad(Hour, 2), ":", pad(Minute, 2), ":",
                   pad(Second, 2), "Z"]).

pad(Value, Width) ->
    Digits = integer_to_list(Value),
    lists:duplicate(max(0, Width - length(Digits)), $0) ++ Digits.

-spec valid(term()) -> boolean().
%% timestamp validation is intentionally independent of the system timezone.
valid(Value) ->
    case normalize(Value) of
        {ok, _} -> true;
        {error, _} -> false
    end.

normalize({{Year, Month, Day}, {Hour, Minute, Second}} = Calendar) ->
    case is_integer(Year) andalso Year >= 0 andalso Year =< 9999 andalso
         is_integer(Hour) andalso Hour >= 0 andalso Hour =< 23 andalso
         is_integer(Minute) andalso Minute >= 0 andalso Minute =< 59 andalso
         is_integer(Second) andalso Second >= 0 andalso Second =< 59 andalso
         calendar:valid_date({Year, Month, Day}) of
        true -> {ok, format(Calendar)};
        false -> {error, {invalid_clock, Calendar}}
    end;
normalize(Value) when is_binary(Value) ->
    normalize(binary_to_list(Value));
normalize(Value) when is_list(Value) ->
    case re:run(Value, "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$",
                [{capture, none}]) of
        match ->
            case parse_rfc3339(Value) of
                {ok, Calendar} -> {ok, format(Calendar)};
                error -> {error, {invalid_clock, Value}}
            end;
        nomatch ->
            {error, {invalid_clock, Value}}
    end;
normalize(Value) ->
    {error, {invalid_clock, Value}}.

parse_rfc3339([Y1, Y2, Y3, Y4, $-, M1, M2, $-, D1, D2, $T,
               H1, H2, $:, N1, N2, $:, S1, S2, $Z]) ->
    Calendar = {{digits([Y1, Y2, Y3, Y4]), digits([M1, M2]),
                 digits([D1, D2])},
                {digits([H1, H2]), digits([N1, N2]), digits([S1, S2])}},
    case valid(Calendar) of
        true -> {ok, Calendar};
        false -> error
    end;
parse_rfc3339(_Other) ->
    error.

digits(Digits) ->
    lists:foldl(fun(Digit, Acc) -> Acc * 10 + Digit - $0 end, 0, Digits).

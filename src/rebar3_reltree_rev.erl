-module(rebar3_reltree_rev).

-include_lib("kernel/include/file.hrl").

-export([enrich/5, classify/1, parse_prior/1]).

-define(MAX_PRIOR_BYTES, 4 * 1024 * 1024).

-spec enrich(map(), [map()], false | auto | true, filename:filename_all(), map()) ->
    {ok, map()} | {error, term()}.
enrich(Model, Edges, Mode, Output, Options)
  when is_map(Model), is_list(Edges), is_map(Options) ->
    case prior_context(Mode, Output) of
        {error, _} = Error -> Error;
        {ok, Prior, PriorWarnings} ->
            Nodes = maps:get(nodes, Model, []),
            Items = declaration_items(Nodes, Edges),
            case resolve_items(Items, Nodes, Edges, Mode, Prior, Options,
                               #{}, #{}, [], []) of
                {error, _} = Error -> Error;
                {ok, FactsByOwner, Warnings, Reasons, Facts} ->
                    RevisionNodes = attach_facts(Nodes, FactsByOwner),
                    Caveats = caveats(Mode),
                    NodeCaveats = [set_node_caveats(Node, Caveats) ||
                                   Node <- RevisionNodes],
                    Network = network_sync_at(Facts),
                    {ok, Model#{nodes => NodeCaveats,
                                warnings => maps:get(warnings, Model, []) ++
                                           PriorWarnings ++ Warnings,
                                revision_reasons => lists:usort(Reasons),
                                network_sync_at => Network,
                                local_only_caveats => Caveats}}
            end
    end.

-spec classify(term()) -> {ok, not_applicable | map()} | {error, term()}.
classify(Declaration) when is_tuple(Declaration), tuple_size(Declaration) >= 1 ->
    case git_source(Declaration) of
        not_git -> {ok, not_applicable};
        {ok, Url0, Selector0} ->
            case normalize_text(Url0) of
                {ok, Url} when Url =/= [] ->
                    case normalize_selector(Selector0) of
                        {ok, Selector} ->
                            {ok, #{source_url => Url, selector => Selector}};
                        {error, Reason} -> {error, Reason}
                    end;
                {ok, _Empty} -> {error, empty_git_url};
                {error, _} -> {error, invalid_git_url}
            end;
        {error, _} = Error -> Error
    end;
classify(_Declaration) ->
    {ok, not_applicable}.

%% The parser is deliberately a small line parser for the exact renderer
%% format.  It never consults terms, creates atoms from bytes, or evaluates
%% input from the previous report.
-spec parse_prior(binary()) -> {ok, map()} | {error, term()}.
parse_prior(Bytes) when is_binary(Bytes), byte_size(Bytes) =< ?MAX_PRIOR_BYTES ->
    case unicode:characters_to_list(Bytes, utf8) of
        Lines when is_list(Lines) ->
            parse_prior_lines(string:split(Lines, "\n", all));
        _ ->
            {error, invalid_utf8}
    end;
parse_prior(Bytes) when is_binary(Bytes) ->
    {error, oversized};
parse_prior(_Other) ->
    {error, invalid_prior_input}.

prior_context(false, _Output) ->
    {ok, #{}, []};
prior_context(true, _Output) ->
    {ok, #{}, []};
prior_context(auto, Output) ->
    case read_prior(Output) of
        missing -> {ok, #{}, []};
        {ok, Entries} -> {ok, Entries, []};
        {error, Reason} ->
            {ok, #{}, [prior_warning(Output, Reason)]}
    end;
prior_context(_Mode, _Output) ->
    {error, {invalid_revision_mode, _Mode}}.

read_prior(Output) ->
    case file:read_file_info(Output) of
        {error, enoent} -> missing;
        {error, {enoent, _}} -> missing;
        {ok, #file_info{size = Size}} when Size > ?MAX_PRIOR_BYTES ->
            {error, oversized};
        {ok, _Info} ->
            case file:read_file(Output) of
                {ok, Bytes} ->
                    case parse_prior(Bytes) of
                        {ok, #{entries := Entries}} -> {ok, Entries};
                        {error, _} = Error -> Error
                    end;
                {error, _Reason} -> {error, unreadable}
            end;
        {error, _Reason} -> {error, unreadable}
    end.

prior_warning(Output, Reason) ->
    rebar3_reltree_graph:warning(Output, prior_revision_report_invalid,
                                  bounded_prior_reason(Reason)).

bounded_prior_reason(oversized) -> oversized;
bounded_prior_reason(invalid_utf8) -> invalid_utf8;
bounded_prior_reason(unreadable) -> unreadable;
bounded_prior_reason(unsupported_version) -> unsupported_version;
bounded_prior_reason(duplicate_identity) -> duplicate_identity;
bounded_prior_reason(_Other) -> malformed.

parse_prior_lines(Lines) ->
    case lists:member("- format_version: 2", Lines) of
        true -> parse_records(Lines, none, #{});
        false -> {error, unsupported_version}
    end.

parse_records([], _CurrentPath, Entries) ->
    {ok, #{entries => Entries}};
parse_records([Line | Rest], CurrentPath, Entries) ->
    case path_line(Line) of
        {ok, Path} ->
            parse_records(Rest, Path, Entries);
        no_path ->
            case external_header(Line) of
                no_header ->
                    case local_header(Line) of
                        true -> parse_records(Rest, CurrentPath, Entries);
                        false ->
                            case lists:prefix("  - name: ", Line) of
                                true -> {error, malformed_record};
                                false -> parse_records(Rest, CurrentPath,
                                                        Entries)
                            end
                    end;
                {error, _} = Error -> Error;
                {ok, Name, Declaration, HeaderState} ->
                    case CurrentPath of
                        none -> {error, malformed_record};
                        _ ->
                            case take_record(Rest, CurrentPath, Name,
                                              Declaration, HeaderState) of
                                {ok, Record, Tail} ->
                                    Identity = maps:get(identity, Record),
                                    case maps:find(Identity, Entries) of
                                        error -> parse_records(
                                          Tail, CurrentPath,
                                          maps:put(Identity, Record, Entries));
                                        {ok, Existing} ->
                                            case same_prior_evidence(
                                                   Existing, Record) of
                                                true ->
                                                    parse_records(
                                                      Tail, CurrentPath,
                                                      Entries);
                                                false ->
                                                    {error, duplicate_identity}
                                            end
                                    end;
                                {error, _} = Error -> Error
                            end
                    end
            end
    end.

same_prior_evidence(Left, Right) ->
    Evidence = [identity, state, resolved_revision,
                revision_observed_at, network_sync_at],
    maps:with(Evidence, Left) =:= maps:with(Evidence, Right).

local_header(Line) ->
    Prefix = "  - name: ",
    Marker = "; declaration: ",
    Local = "; relationship: local-checkout",
    Omitted = "; relationship: omitted-local-checkout",
    case lists:prefix(Prefix, Line) of
        false -> false;
        true ->
            Tail = lists:nthtail(length(Prefix), Line),
            case {first_substring(Tail, Marker),
                  last_substring(Tail, Local),
                  last_substring(Tail, Omitted)} of
                {NamePosition, LocalPosition, OmittedPosition}
                  when NamePosition =/= nomatch,
                       (LocalPosition =/= nomatch orelse
                        OmittedPosition =/= nomatch) ->
                    RelationshipPosition = case LocalPosition of
                        nomatch -> OmittedPosition;
                        _ -> LocalPosition
                    end,
                    DeclarationStart = NamePosition + length(Marker),
                    Name = lists:sublist(Tail, NamePosition),
                    DeclarationLength = RelationshipPosition -
                                        DeclarationStart,
                    Declaration = lists:sublist(
                                    Tail, DeclarationStart + 1,
                                    DeclarationLength),
                    Name =/= [] andalso Declaration =/= [];
                _ -> false
            end
    end.

path_line(Line) ->
    Prefix = "- path: ",
    case lists:prefix(Prefix, Line) of
        true ->
            case unescape_text(lists:nthtail(length(Prefix), Line)) of
                {ok, Path} when Path =/= [] -> {ok, Path};
                _ -> {error, malformed_path}
            end;
        false -> no_path
    end.

external_header(Line) ->
    Prefix = "  - name: ",
    Marker = "; declaration: ",
    Relationship = "; relationship: external; revision_state: ",
    case lists:prefix(Prefix, Line) of
        false -> no_header;
        true ->
            Tail = lists:nthtail(length(Prefix), Line),
            case first_substring(Tail, Marker) of
                nomatch -> no_header;
                MarkerPosition ->
                    case last_substring(Tail, Relationship) of
                        nomatch -> no_header;
                        Position ->
                            Name0 = lists:sublist(Tail, MarkerPosition),
                            DeclarationStart = MarkerPosition +
                                               length(Marker),
                            DeclarationLength = Position - DeclarationStart,
                            Declaration = lists:sublist(
                                            Tail, DeclarationStart + 1,
                                            DeclarationLength),
                            State0 = lists:nthtail(
                                       Position + length(Relationship), Tail),
                            case {unescape_text(Name0), Declaration,
                                  state_text(State0)} of
                                {{ok, Name}, [_ | _], {ok, State}} ->
                                    {ok, Name, Declaration, State};
                                _ -> {error, malformed_record}
                            end
                    end
            end
    end.

take_record([UrlLine, KindLine, ValueLine, RevisionLine, ObservedLine,
             NetworkLine | Tail], Path, Name, Declaration, State) ->
    Prefixes = ["    source_url: ", "    selector_kind: ",
                "    selector_value: ",
                "    resolved_revision: ", "    revision_observed_at: ",
                "    network_sync_at: "],
    Lines = [UrlLine, KindLine, ValueLine, RevisionLine, ObservedLine,
             NetworkLine],
    case fields(Prefixes, Lines, []) of
        {ok, [UrlText, KindText, ValueText, RevisionText, ObservedText,
              NetworkText]} ->
            validate_prior_record(Path, Name, Declaration, State, UrlText,
                                  KindText, ValueText, RevisionText,
                                  ObservedText, NetworkText, Tail);
        {error, _} = Error -> Error
    end;
take_record(_Lines, _Path, _Name, _Declaration, _State) ->
    {error, malformed_record}.

fields([], [], Acc) -> {ok, lists:reverse(Acc)};
fields([Prefix | Prefixes], [Line | Lines], Acc) ->
    case lists:prefix(Prefix, Line) of
        true -> fields(Prefixes, Lines,
                       [lists:nthtail(length(Prefix), Line) | Acc]);
        false -> {error, malformed_record}
    end;
fields(_Prefixes, _Lines, _Acc) ->
    {error, malformed_record}.

validate_prior_record(Path, Name, Declaration, State, Url0, Kind0, Value0,
                      Revision0, Observed0, Network0, Tail) ->
    case {Path, Name, unescape_text(Url0),
          unescape_text(Kind0), unescape_text(Value0),
          unescape_text(Revision0), unescape_text(Observed0),
          unescape_text(Network0)} of
        {Path, Name, {ok, Url}, {ok, Kind}, {ok, Value}, {ok, Revision},
         {ok, Observed}, {ok, Network}} ->
            case valid_prior_fields(Path, Name, Declaration, State, Url,
                                    Kind, Value, Revision, Observed,
                                    Network) of
                {ok, Record0} ->
                    case Tail of
                        _ -> {ok, Record0, Tail}
                    end;
                {error, _} = Error -> Error
            end;
        _ -> {error, malformed_record}
    end.

valid_prior_fields(Path, Name, Declaration, State, Url, Kind, Value,
                   Revision, Observed, Network) ->
    case {valid_state(State), valid_report_text(Path),
          valid_report_text(Name), valid_report_text(Declaration),
          state_fields_valid(
            State, Url, Kind, Value, Revision, Observed, Network)} of
        {true, true, true, true, true} ->
            Identity = {rebar3_reltree_fs:canonical(Path), Name, Url,
                        selector_kind(Kind), selector_value(Kind, Value)},
            {ok, #{identity => Identity, owner =>
                       rebar3_reltree_fs:canonical(Path), name => Name,
                   declaration => Declaration,
                   source_url => source_value(Url),
                   selector_kind => selector_kind(Kind),
                   selector_value => selector_value(Kind, Value),
                   state => State, resolved_revision => revision_value(Revision),
                   revision_observed_at => time_value(Observed),
                   network_sync_at => time_value(Network)}};
        _ -> {error, malformed_record}
    end.

state_fields_valid(resolved, Url, Kind, Value, Revision, Observed, Network) ->
    external_fields_valid(Url, Kind, Value) andalso
    valid_object_id(Revision) andalso valid_timestamp(Observed) andalso
    valid_timestamp(Network);
state_fields_valid(reused, Url, Kind, Value, Revision, Observed, Network) ->
    external_fields_valid(Url, Kind, Value) andalso
    valid_object_id(Revision) andalso valid_timestamp(Observed) andalso
    valid_timestamp(Network);
state_fields_valid(stale, Url, Kind, Value, Revision, Observed, Network) ->
    external_fields_valid(Url, Kind, Value) andalso
    valid_object_id(Revision) andalso valid_timestamp(Observed) andalso
    valid_timestamp(Network);
state_fields_valid(missing, Url, Kind, Value, Revision, Observed, Network) ->
    valid_missing_fields(Url, Kind, Value, Revision, Observed, Network);
state_fields_valid(tracking_disabled, Url, Kind, Value, Revision, Observed,
                   Network) ->
    (valid_external_disabled_fields(Url, Kind, Value, Revision, Observed,
                                    Network) orelse
     all_unperformed_fields(Url, Kind, Value, Revision, Observed, Network));
state_fields_valid(not_applicable, Url, Kind, Value, Revision, Observed,
                   Network) ->
    all_unperformed_fields(Url, Kind, Value, Revision, Observed, Network);
state_fields_valid(_State, _Url, _Kind, _Value, _Revision, _Observed,
                   _Network) ->
    false.

external_fields_valid(Url, Kind, Value) ->
    valid_source_field(Url) andalso Url =/= "none" andalso
    valid_selector_fields(Url, Kind, Value).

valid_timestamp(Text) ->
    Text =/= "not-performed" andalso valid_time_field(Text).

valid_missing_fields("none", "none", "none", "none", "not-performed",
                     "not-performed") -> true;
valid_missing_fields(Url, Kind, Value, "none", "not-performed", Network) ->
    external_fields_valid(Url, Kind, Value) andalso valid_timestamp(Network);
valid_missing_fields(_Url, _Kind, _Value, _Revision, _Observed, _Network) ->
    false.

valid_external_disabled_fields(Url, Kind, Value, Revision, Observed, Network) ->
    external_fields_valid(Url, Kind, Value) andalso
    Revision =:= "none" andalso Observed =:= "not-performed" andalso
    Network =:= "not-performed".

all_unperformed_fields("none", "none", "none", "none", "not-performed",
                       "not-performed") -> true;
all_unperformed_fields(_Url, _Kind, _Value, _Revision, _Observed, _Network) ->
    false.

valid_state(resolved) -> true;
valid_state(reused) -> true;
valid_state(stale) -> true;
valid_state(missing) -> true;
valid_state(tracking_disabled) -> true;
valid_state(not_applicable) -> true;
valid_state(_Other) -> false.

valid_report_text(Text) ->
    Text =/= [] andalso unicode:characters_to_binary(Text, unicode, utf8) =/= {error, Text, []}.

valid_source_field("none") -> true;
valid_source_field(Text) -> valid_report_text(Text).

valid_selector_fields("none", "none", "none") -> true;
valid_selector_fields(Url, Kind, Value) when Url =/= "none" ->
    lists:member(Kind, ["head", "branch", "tag", "ref"]) andalso
    Value =/= "none" andalso valid_report_text(Value);
valid_selector_fields(_Url, _Kind, _Value) -> false.

valid_time_field("not-performed") -> true;
valid_time_field(Text) -> rebar3_reltree_clock:valid(Text).

state_text("resolved") -> {ok, resolved};
state_text("reused") -> {ok, reused};
state_text("stale") -> {ok, stale};
state_text("missing") -> {ok, missing};
state_text("tracking-disabled") -> {ok, tracking_disabled};
state_text("not-applicable") -> {ok, not_applicable};
state_text("local-checkout") -> {ok, local_checkout};
state_text("local-unavailable") -> {ok, local_unavailable};
state_text(_Other) -> error.

source_value("none") -> none;
source_value(Value) -> Value.

selector_kind("none") -> none;
selector_kind("head") -> head;
selector_kind("branch") -> branch;
selector_kind("tag") -> tag;
selector_kind("ref") -> ref.

selector_value("none", "none") -> none;
selector_value(_Kind, Value) -> Value.

revision_value("none") -> none;
revision_value(Value) -> Value.

time_value("not-performed") -> not_performed;
time_value(Value) -> Value.

valid_object_id(Text) when is_list(Text) ->
    (length(Text) =:= 40 orelse length(Text) =:= 64) andalso
    lists:all(fun is_hex/1, Text);
valid_object_id(_Other) -> false.

is_hex(Char) when Char >= $0, Char =< $9 -> true;
is_hex(Char) when Char >= $a, Char =< $f -> true;
is_hex(Char) when Char >= $A, Char =< $F -> true;
is_hex(_Char) -> false.

declaration_items(Nodes, Edges) ->
    lists:append([node_items(Node, Edges) || Node <-
                  lists:sort(fun node_less/2, Nodes)]).

node_items(Node, Edges) ->
    Owner = rebar3_reltree_fs:canonical(maps:get(path, Node)),
    Relationships = maps:get(dependency_relationships, Node, #{}),
    Declarations = lists:sort(fun declaration_less/2,
                              maps:get(dependencies, Node, [])),
    [{Owner, Name, Declaration,
      relationship(Name, Relationships, Owner, Edges), Node} ||
     Declaration <- Declarations,
     {ok, Name} <- [rebar3_reltree_config:dependency_name(Declaration)]]
.

node_less(A, B) -> maps:get(path, A) =< maps:get(path, B).

declaration_less(A, B) ->
    {declaration_name(A), term_text(A)} =< {declaration_name(B), term_text(B)}.

declaration_name(Declaration) ->
    {ok, Name} = rebar3_reltree_config:dependency_name(Declaration), Name.

relationship(Name, Relationships, _Owner, _Edges) when
    is_map_key(Name, Relationships) -> maps:get(Name, Relationships);
relationship(Name, _Relationships, Owner, Edges) ->
    case lists:any(fun(Edge) -> maps:get(source, Edge) =:= Owner andalso
                              maps:get(dependency, Edge) =:= Name end, Edges) of
        true -> local_checkout;
        false -> external
    end.

resolve_items([], _Nodes, _Edges, _Mode, _Prior, _Options, FactsByOwner,
              _Cache, Warnings, Reasons) ->
    Facts = lists:append(maps:values(FactsByOwner)),
    {ok, FactsByOwner, Warnings, Reasons, Facts};
resolve_items([{Owner, Name, Declaration, Relationship, Node} | Rest], Nodes,
              Edges, Mode, Prior, Options, FactsByOwner, Cache, Warnings,
              Reasons) ->
    Base = base_fact(Owner, Name, Declaration, Relationship),
    case resolve_one(Base, Node, Nodes, Edges, Mode, Prior, Options, Cache) of
        {error, _} = Error -> Error;
        {ok, Fact, MaybeWarning, MaybeReason} ->
            OwnerFacts = maps:get(Owner, FactsByOwner, []),
            NextFacts = maps:put(Owner, [Fact | OwnerFacts], FactsByOwner),
            NextCache = cache_fact(Fact, MaybeWarning, MaybeReason, Cache),
            NextWarnings = add_optional(MaybeWarning, Warnings),
            NextReasons = add_optional(MaybeReason, Reasons),
            resolve_items(Rest, Nodes, Edges, Mode, Prior, Options, NextFacts,
                          NextCache, NextWarnings, NextReasons)
    end.

base_fact(Owner, Name, Declaration, Relationship) ->
    #{owner => Owner, name => Name, declaration => Declaration,
      relationship => Relationship, revision_state => not_applicable,
      source_url => none, selector_kind => none, selector_value => none,
      resolved_revision => none, revision_observed_at => not_performed,
      network_sync_at => not_performed}.

resolve_one(Base, _Node, Nodes, Edges, Mode, Prior, Options, Cache) ->
    case maps:get(relationship, Base) of
        local_checkout ->
            Name = maps:get(name, Base), Owner = maps:get(owner, Base),
            case local_target_head(Owner, Name, Edges, Nodes) of
                {ok, Head} ->
                    {ok, Base#{revision_state => local_checkout,
                               resolved_revision => Head}, none, none};
                error ->
                    {ok, Base#{relationship => omitted_local_checkout,
                               revision_state => local_unavailable}, none,
                     none}
            end;
        omitted_local_checkout ->
            {ok, Base#{revision_state => local_unavailable}, none, none};
        external when Mode =:= false ->
            case classify(maps:get(declaration, Base)) of
                {ok, not_applicable} -> {ok, Base, none, none};
                {ok, Source} ->
                    {ok, source_fact(Base, Source, tracking_disabled), none,
                     none};
                {error, _} ->
                    {ok, Base#{revision_state => tracking_disabled}, none,
                     none}
            end;
        external ->
            case classify(maps:get(declaration, Base)) of
                {ok, not_applicable} -> {ok, Base, none, none};
                {error, Reason} ->
                    Warning = revision_warning(Base,
                                               external_revision_invalid,
                                               Reason),
                    {ok, Base#{revision_state => missing}, Warning,
                     external_revision_missing};
                {ok, Source} ->
                    Applicable = source_fact(Base, Source, unresolved),
                    Identity = identity(Applicable),
                    case maps:find(Identity, Cache) of
                        {ok, {CachedFact, _CachedWarning, _CachedReason}} ->
                            {ok, copy_declaration(Base, CachedFact), none,
                             none};
                        error ->
                            resolve_external_or_prior(Applicable, Identity,
                                                      Mode, Prior, Options)
                    end
            end;
        _Other ->
            {ok, Base, none, none}
    end.

resolve_external_or_prior(Applicable, Identity, Mode, Prior, Options) ->
    case {Mode, maps:find(Identity, Prior)} of
        {auto, {ok, PriorRecord}} ->
                            case reusable(PriorRecord) of
                                true ->
                                    {ok, reused_fact(Applicable, PriorRecord),
                                     none, none};
                                false ->
                                    resolve_external(Applicable, Identity,
                                                      Mode, Prior, Options)
                            end;
        _ ->
            resolve_external(Applicable, Identity, Mode, Prior, Options)
    end.

cache_fact(Fact, Warning, Reason, Cache) ->
    case maps:get(source_url, Fact, none) of
        none -> Cache;
        _ -> maps:put(identity(Fact), {Fact, Warning, Reason}, Cache)
    end.

copy_declaration(Base, CachedFact) ->
    CachedFact#{declaration => maps:get(declaration, Base),
                name => maps:get(name, Base), owner => maps:get(owner, Base),
                relationship => maps:get(relationship, Base)}.

source_fact(Base, #{source_url := Url, selector := Selector}, State) ->
    Base#{source_url => Url, selector_kind => maps:get(kind, Selector),
          selector_value => maps:get(value, Selector),
          revision_state => State}.

identity(Fact) ->
    {maps:get(owner, Fact), name_text(maps:get(name, Fact)),
     maps:get(source_url, Fact),
     maps:get(selector_kind, Fact), maps:get(selector_value, Fact)}.

name_text(Name) when is_atom(Name) -> atom_to_list(Name);
name_text(Name) when is_binary(Name) -> binary_to_list(Name);
name_text(Name) -> Name.

reusable(#{state := State, resolved_revision := Revision,
           revision_observed_at := Observed}) ->
    (State =:= resolved orelse State =:= reused) andalso
    Revision =/= none andalso Observed =/= not_performed;
reusable(_Other) -> false.

reused_fact(Fact, Prior) ->
    Fact#{revision_state => reused,
          resolved_revision => maps:get(resolved_revision, Prior),
          revision_observed_at => maps:get(revision_observed_at, Prior),
          network_sync_at => maps:get(network_sync_at, Prior)}.

resolve_external(Fact, Identity, Mode, Prior, Options) ->
    case maps:get(lookup, Options, maps:get(git_lookup, Options, undefined)) of
        undefined ->
            attempt_external(Fact, Identity, Mode, Prior, Options,
                             fun(Url, Selector) ->
                                     rebar3_reltree_git:lookup(
                                       Url, Selector, Options)
                             end);
        Fun when is_function(Fun) ->
            attempt_external(Fact, Identity, Mode, Prior, Options,
                             fun(Url, Selector) ->
                                     invoke_lookup(Fun, Url, Selector, Fact)
                             end);
        _Other ->
            attempt_external(Fact, Identity, Mode, Prior, Options,
                             fun(_Url, _Selector) ->
                                     {error, invalid_lookup_dependency}
                             end)
    end.

attempt_external(Fact, Identity, auto, Prior, Options, Lookup) ->
    attempt_external1(Fact, Identity, maps:find(Identity, Prior), Options,
                      Lookup);
attempt_external(Fact, Identity, true, Prior, Options, Lookup) ->
    attempt_external1(Fact, Identity, maps:find(Identity, Prior), Options,
                      Lookup);
attempt_external(Fact, Identity, _Mode, Prior, Options, Lookup) ->
    attempt_external1(Fact, Identity, maps:find(Identity, Prior), Options,
                      Lookup).

attempt_external1(Fact, _Identity, PriorResult, Options, Lookup) ->
    case rebar3_reltree_clock:now(Options) of
        {error, Reason} -> {error, {revision_clock, Reason}};
        {ok, AttemptAt} ->
            Selector = #{kind => maps:get(selector_kind, Fact),
                         value => maps:get(selector_value, Fact)},
            Url = maps:get(source_url, Fact),
            case normalize_lookup(Lookup(Url, Selector)) of
                {ok, Revision} ->
                    {ok, Fact#{revision_state => resolved,
                               resolved_revision => Revision,
                               revision_observed_at => AttemptAt,
                               network_sync_at => AttemptAt}, none, none};
                {error, Reason0} ->
                    case stale_fallback(PriorResult) of
                        {ok, OldRevision, OldObserved} ->
                            Warning = revision_warning(
                                        Fact, external_revision_stale,
                                        bounded_lookup_reason(Reason0)),
                            {ok, Fact#{revision_state => stale,
                                       resolved_revision => OldRevision,
                                       revision_observed_at => OldObserved,
                                       network_sync_at => AttemptAt}, Warning,
                             external_revision_stale};
                        none ->
                            Warning = revision_warning(
                                        Fact, external_revision_missing,
                                        bounded_lookup_reason(Reason0)),
                            {ok, Fact#{revision_state => missing,
                                       network_sync_at => AttemptAt}, Warning,
                             external_revision_missing}
                    end
            end
    end.

stale_fallback({ok, Record}) ->
    case maps:get(state, Record, missing) of
        resolved -> prior_revision(Record);
        reused -> prior_revision(Record);
        stale -> prior_revision(Record);
        _ -> none
    end;
stale_fallback(error) -> none.

prior_revision(Record) ->
    case {maps:get(resolved_revision, Record, none),
          maps:get(revision_observed_at, Record, not_performed)} of
        {Revision, Observed} when Revision =/= none,
                                 Observed =/= not_performed ->
            {ok, Revision, Observed};
        _ -> none
    end.

normalize_lookup({ok, Revision}) ->
    case normalize_text(Revision) of
        {ok, Text} ->
            case valid_object_id(Text) of
                true -> {ok, Text};
                false -> {error, malformed_object_id}
            end;
        _ -> {error, malformed_object_id}
    end;
normalize_lookup(Revision) when is_binary(Revision); is_list(Revision) ->
    normalize_lookup({ok, Revision});
normalize_lookup({error, Reason}) -> {error, bounded_lookup_reason(Reason)};
normalize_lookup(_Other) -> {error, lookup_failed}.

invoke_lookup(Fun, Url, Selector, Fact) ->
    try
        case erlang:fun_info(Fun, arity) of
            {arity, 1} -> Fun(Fact);
            {arity, 2} -> Fun(Url, Selector);
            {arity, 3} -> Fun(Url, maps:get(kind, Selector),
                               maps:get(value, Selector));
            {arity, 4} -> Fun(Url, maps:get(kind, Selector),
                               maps:get(value, Selector), Fact)
        end
    catch
        _:_ -> {error, lookup_failed}
    end.

bounded_lookup_reason(timeout) -> timeout;
bounded_lookup_reason(git_executable_unavailable) -> git_executable_unavailable;
bounded_lookup_reason(no_matching_revision) -> no_matching_revision;
bounded_lookup_reason(malformed_object_id) -> malformed_object_id;
bounded_lookup_reason(incompatible_revisions) -> incompatible_revisions;
bounded_lookup_reason({git_exit, Status}) when is_integer(Status) ->
    {git_exit, Status};
bounded_lookup_reason(_Other) -> lookup_failed.

revision_warning(Fact, Reason, Detail) ->
    rebar3_reltree_graph:warning(maps:get(owner, Fact), Reason,
                                 {dependency, maps:get(name, Fact), Detail}).

local_target_head(Owner, Name, Edges, Nodes) ->
    case [maps:get(target, Edge) || Edge <- Edges,
          maps:get(source, Edge) =:= Owner,
          maps:get(dependency, Edge) =:= Name] of
        [Target | _] ->
            case [maps:get(head, Node) || Node <- Nodes,
                                            maps:get(path, Node) =:= Target] of
                [Head | _] -> {ok, Head};
                [] -> error
            end;
        [] -> error
    end.

attach_facts(Nodes, FactsByOwner) ->
    [Node#{revision_declarations => lists:reverse(
             maps:get(rebar3_reltree_fs:canonical(maps:get(path, Node)),
                      FactsByOwner, []))} || Node <- Nodes].

set_node_caveats(Node, Caveats) ->
    Node#{local_only_caveats => Caveats}.

caveats(false) -> [external_revision_tracking_disabled,
                   readme_mutation_not_performed];
caveats(_Mode) -> [external_revision_read_only, readme_mutation_not_performed].

network_sync_at(Facts) ->
    Times = [Time || Fact <- Facts,
                     maps:get(revision_state, Fact) =:= resolved orelse
                     maps:get(revision_state, Fact) =:= reused orelse
                     maps:get(revision_state, Fact) =:= stale orelse
                     maps:get(revision_state, Fact) =:= missing,
                     Time <- [maps:get(network_sync_at, Fact)],
                     Time =/= not_performed,
                     rebar3_reltree_clock:valid(Time)],
    case Times of
        [] -> not_performed;
        _ -> lists:max(Times)
    end.

add_optional(none, Acc) -> Acc;
add_optional(Value, Acc) -> [Value | Acc].

normalize_selector(undefined) -> {ok, #{kind => head, value => "HEAD"}};
normalize_selector({Kind, Value}) when Kind =:= branch; Kind =:= tag;
                                      Kind =:= ref ->
    case normalize_text(Value) of
        {ok, Text} when Text =/= [] -> {ok, #{kind => Kind, value => Text}};
        _ -> {error, invalid_git_selector}
    end;
normalize_selector(_Other) -> {error, invalid_git_selector}.

git_source(Declaration) when tuple_size(Declaration) =:= 2 ->
    source_term(element(2, Declaration));
git_source(Declaration) when tuple_size(Declaration) =:= 3 ->
    case element(3, Declaration) of
        {git, _Url} = Source -> source_term(Source);
        {git, _Url, _Selector} = Source -> source_term(Source);
        Source when is_tuple(Source), tuple_size(Source) >= 1,
                   element(1, Source) =:= git -> {error, unsupported_git_source};
        _ -> unsupported_or_not_git(Declaration)
    end;
git_source(Declaration) ->
    unsupported_or_not_git(Declaration).

source_term({git, Url}) -> {ok, Url, undefined};
source_term({git, Url, Selector}) -> {ok, Url, Selector};
source_term(Source) when is_tuple(Source), tuple_size(Source) >= 1,
                       element(1, Source) =:= git ->
    {error, unsupported_git_source};
source_term(_Other) -> not_git.

unsupported_or_not_git(Declaration) ->
    case contains_git_shape(Declaration) of
        true -> {error, unsupported_git_source};
        false -> not_git
    end.

contains_git_shape(Term) when is_tuple(Term), tuple_size(Term) >= 1 ->
    element(1, Term) =:= git orelse
    lists:any(fun contains_git_shape/1, tuple_to_list(Term));
contains_git_shape(Term) when is_list(Term) ->
    lists:any(fun contains_git_shape/1, Term);
contains_git_shape(_Term) ->
    false.

normalize_text(Value) when is_binary(Value) ->
    case unicode:characters_to_list(Value, utf8) of
        Text when is_list(Text) -> normalize_text(Text);
        _ -> {error, invalid_utf8}
    end;
normalize_text(Value) when is_list(Value), Value =/= [] ->
    try
        case unicode:characters_to_binary(Value, unicode, utf8) of
            Binary when is_binary(Binary) ->
                {ok, binary_to_list(Binary)};
            _ ->
                {error, invalid_utf8}
        end
    catch
        _:_ -> {error, invalid_utf8}
    end;
normalize_text([]) -> {ok, []};
normalize_text(_Other) -> {error, invalid_text}.

unescape_text(Text) ->
    unescape_text(Text, []).

unescape_text([], Acc) ->
    case unicode:characters_to_binary(lists:reverse(Acc), unicode, utf8) of
        Binary when is_binary(Binary) -> {ok, binary_to_list(Binary)};
        _ -> {error, invalid_utf8}
    end;
unescape_text([$\\, $n | Rest], Acc) -> unescape_text(Rest, [$\n | Acc]);
unescape_text([$\\, $r | Rest], Acc) -> unescape_text(Rest, [$\r | Acc]);
unescape_text([$\\, $\\ | Rest], Acc) -> unescape_text(Rest, [$\\ | Acc]);
unescape_text([$\\, $` | Rest], Acc) -> unescape_text(Rest, [$` | Acc]);
unescape_text([$\\, $| | Rest], Acc) -> unescape_text(Rest, [$| | Acc]);
unescape_text([$\\, $[ | Rest], Acc) -> unescape_text(Rest, [$[ | Acc]);
unescape_text([$\\, $] | Rest], Acc) -> unescape_text(Rest, [$] | Acc]);
unescape_text([$\\ | _Rest], _Acc) -> {error, invalid_escape};
unescape_text([Char | Rest], Acc) -> unescape_text(Rest, [Char | Acc]).

term_text(Term) -> lists:flatten(io_lib:format("~tp", [Term])).

last_substring(Text, Needle) ->
    last_substring(Text, Needle, 0, nomatch).

first_substring([], _Needle) -> nomatch;
first_substring(Text, Needle) ->
    first_substring(Text, Needle, 0).

first_substring([], _Needle, _Position) -> nomatch;
first_substring(Text, Needle, Position) ->
    case lists:prefix(Needle, Text) of
        true -> Position;
        false -> first_substring(tl(Text), Needle, Position + 1)
    end.

last_substring([], _Needle, _Position, Found) -> Found;
last_substring(Text, Needle, Position, Found) ->
    Next = case lists:prefix(Needle, Text) of
               true -> Position;
               false -> Found
           end,
    last_substring(tl(Text), Needle, Position + 1, Next).

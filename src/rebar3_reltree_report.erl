-module(rebar3_reltree_report).

-export([render/1, render/2, format_time/1, escape/1]).

-spec render(map()) -> {ok, binary()} | {error, term()}.
render(Model) ->
    render(Model, #{}).

-spec render(map(), map()) -> {ok, binary()} | {error, term()}.
render(Model, Options) when is_map(Model), is_map(Options) ->
    case local_sync_at(Options) of
        {ok, LocalSyncAt} ->
            try
                encode_utf8([
                    "# reltree project\n\n",
                    "## metadata\n",
                    "- format_version: ",
                    value(maps:get(format_version, Model)),
                    "\n",
                    "- status: ", display(maps:get(status, Model)), "\n",
                    "- local_sync_at: ", escape(LocalSyncAt), "\n",
                    "- network_sync_at: not-performed\n",
                    "- current_project_path: ",
                    value(maps:get(current, Model)), "\n",
                    "- current_project_name: ",
                    value(maps:get(current_name, Model)), "\n\n",
                    warnings_section(
                      sort_warnings(maps:get(warnings, Model, []))),
                    nodes_section(maps:get(nodes, Model, []),
                                  maps:get(edges, Model, [])),
                    "## local-only caveats\n",
                    bullet_values(maps:get(local_only_caveats, Model, [])),
                    "\n"
                ])
            catch
                error:{report_encoding, Detail} ->
                    {error, {report_encoding, Detail}};
                error:badarg ->
                    {error, {report_encoding, badarg}}
            end;
        {error, _} = Error ->
            Error
    end.

encode_utf8(Document) ->
    case unicode:characters_to_binary(Document, unicode, utf8) of
        Bytes when is_binary(Bytes) ->
            {ok, Bytes};
        {error, Valid, Invalid} ->
            {error, {report_encoding, {invalid_unicode, Valid, Invalid}}};
        {incomplete, Valid, Incomplete} ->
            {error, {report_encoding,
                     {incomplete_unicode, Valid, Incomplete}}}
    end.

local_sync_at(Options) ->
    Clock = maps:get(clock, Options, fun calendar:universal_time/0),
    try
        Value = case Clock of
                    Fun when is_function(Fun, 0) -> Fun();
                    Other -> Other
                end,
        case Value of
            Text when is_binary(Text) -> {ok, Text};
            Text when is_list(Text) -> {ok, Text};
            Calendar -> {ok, format_time(Calendar)}
        end
    catch
        Class:Reason -> {error, {clock, Class, Reason}}
    end.

warnings_section([]) ->
    "## warnings\n- none\n\n";
warnings_section(Warnings) ->
    ["## warnings\n",
     [["- path: ", value(maps:get(path, Warning)),
       "; reason: ", display(maps:get(reason, Warning)),
       "; detail: ", term_value(maps:get(detail, Warning)), "\n"] ||
      Warning <- Warnings],
     "\n"].

nodes_section([], _Edges) ->
    "## nodes\n- none\n\n";
nodes_section(Nodes0, Edges) ->
    Nodes = lists:sort(fun(A, B) -> maps:get(path, A) =< maps:get(path, B)
                       end, Nodes0),
    ["## nodes\n", [node_section(Node, Edges) || Node <- Nodes], "\n"].

node_section(Node, Edges) ->
    Path = maps:get(path, Node),
    ["### node: ", value(maps:get(name, Node)), "\n",
     "- path: ", value(Path), "\n",
     "- app: ", value(maps:get(app, Node)), "\n",
     "- app_src: ", value(maps:get(app_src, Node, none)), "\n",
     "- app_vsn: ", value(maps:get(app_vsn, Node)), "\n",
     "- git_head: ", value(maps:get(head, Node)), "\n",
     version_lines(maps:get(version, Node)),
     "- README.md: ", presence(maps:get(readme, Node), readme), "\n",
     "- README.zh.md: ", presence(maps:get(readme, Node), readme_zh), "\n",
     "- ci_workflow: ", presence_bool(maps:get(ci_workflow, Node)), "\n",
     "- badge_state: ", display(maps:get(state, maps:get(badge, Node))), "\n",
     declarations_section(Node, Edges),
     terms_section("project_plugins", maps:get(project_plugins, Node, [])),
     terms_section("plugins", maps:get(plugins, Node, [])),
     relation_section("upstream_edges", upstream_edges(Path, Edges), upstream),
     relation_section("downstream_edges", downstream_edges(Path, Edges),
                      downstream),
     "- local-only caveats:\n",
     indent_bullets([network_sync_not_performed,
                     external_revisions_pending_task_3,
                     readme_mutation_not_performed]),
     "\n"].

version_lines(Version) ->
    Highest = maps:get(highest_formal, Version),
    ["- highest_formal_version: ", value(highest_version(Highest)), "\n",
     "- version_line_reason: ", display(maps:get(reason, Version)), "\n",
     "- formal_tags:\n", tag_lines(maps:get(formal_tags, Version, [])),
     "- prerelease_tags:\n",
     tag_lines(maps:get(prerelease_tags, Version, []))].

highest_version(none) -> none;
highest_version(#{version := Version}) -> Version.

tag_lines([]) ->
    "  - none\n";
tag_lines(Tags) ->
    [["  - tag: ", value(maps:get(tag, Tag)), "; version: ",
      value(maps:get(version, Tag)), "\n"] || Tag <- Tags].

declarations_section(Node, Edges) ->
    Declarations = lists:sort(fun declaration_less/2,
                               maps:get(dependencies, Node, [])),
    LocalNames = [maps:get(dependency, Edge) || Edge <- Edges,
                  maps:get(source, Edge) =:= maps:get(path, Node)],
    Relationships = maps:get(dependency_relationships, Node, #{}),
    Rows = [declaration_row(Declaration,
                            relationship_for(declaration_name(Declaration),
                                             Relationships, LocalNames)) ||
            Declaration <- Declarations],
    ["- runtime_declarations:\n", none_or(Rows, "  - none\n"), "\n"].

relationship_for(Name, Relationships, _LocalNames)
  when is_map_key(Name, Relationships) ->
    maps:get(Name, Relationships);
relationship_for(Name, _Relationships, LocalNames) ->
    case lists:member(Name, LocalNames) of
        true -> local_checkout;
        false -> external
    end.

declaration_row(Declaration, local_checkout) ->
    ["  - name: ", value(declaration_name(Declaration)),
     "; declaration: ", term_value(Declaration),
     "; relationship: local-checkout\n"];
declaration_row(Declaration, omitted_local_checkout) ->
    ["  - name: ", value(declaration_name(Declaration)),
     "; declaration: ", term_value(Declaration),
     "; relationship: omitted-local-checkout\n"];
declaration_row(Declaration, _External) ->
    external_row(declaration_name(Declaration), Declaration).

external_row(Name, Declaration) ->
    ["  - name: ", value(Name), "; declaration: ", term_value(Declaration),
     "; relationship: external; revision_state: pending-task-3\n"].

declaration_name(Declaration) ->
    {ok, Name} = rebar3_reltree_config:dependency_name(Declaration),
    Name.

declaration_less(A, B) ->
    {declaration_name(A), term_text(A)} =<
    {declaration_name(B), term_text(B)}.

terms_section(Name, Terms) ->
    Sorted = lists:sort(fun(A, B) -> term_text(A) =< term_text(B) end, Terms),
    ["- ", Name, ":\n", none_or(["  - ", term_value(Term), "\n" ||
                                      Term <- Sorted], "  - none\n"), "\n"].

relation_section(Name, Edges, Direction) ->
    ["- ", Name, ":\n",
     none_or([["  - project: ", value(relation_project(Edge, Direction)),
               "; dependency: ", value(maps:get(dependency, Edge)), "\n"] ||
              Edge <- Edges], "  - none\n"), "\n"].

relation_project(Edge, upstream) -> maps:get(target, Edge);
relation_project(Edge, downstream) -> maps:get(source, Edge).

upstream_edges(Path, Edges) ->
    lists:sort(fun edge_less/2,
               [Edge || Edge <- Edges, maps:get(source, Edge) =:= Path]).

downstream_edges(Path, Edges) ->
    lists:sort(fun edge_less/2,
               [Edge || Edge <- Edges, maps:get(target, Edge) =:= Path]).

edge_less(A, B) ->
    {maps:get(source, A), maps:get(target, A), maps:get(dependency, A)} =<
    {maps:get(source, B), maps:get(target, B), maps:get(dependency, B)}.

none_or([], Empty) -> Empty;
none_or(Value, _Empty) -> Value.

bullet_values([]) -> "- none\n";
bullet_values(Values) -> [["- ", display(Value), "\n"] || Value <- Values].

indent_bullets(Values) ->
    [["  - ", display(Value), "\n"] || Value <- Values].

presence(Map, Key) ->
    presence_bool(maps:get(Key, Map, false)).

presence_bool(true) -> "present";
presence_bool(false) -> "absent";
presence_bool(Value) -> value(Value).

term_value(Term) ->
    escape(term_text(Term)).

value(Term) when is_atom(Term) -> escape(atom_to_list(Term));
value(Term) when is_binary(Term) -> escape(binary_text(Term));
value(Term) when is_list(Term) -> escape(Term);
value(Term) -> term_value(Term).

display(Term) when is_atom(Term) ->
    escape([case Char of $_ -> $-; Other -> Other end ||
            Char <- atom_to_list(Term)]);
display(Term) -> value(Term).

term_text(Term) ->
    lists:flatten(io_lib:format("~tp", [Term])).

-spec escape(string()) -> string().
escape(Text) when is_binary(Text) -> escape(binary_text(Text));
escape(Text) when is_list(Text) ->
    lists:flatten([escape_char(Char) || Char <- Text]).

binary_text(Text) ->
    case unicode:characters_to_list(Text, utf8) of
        Characters when is_list(Characters) -> Characters;
        {error, Valid, Invalid} ->
            erlang:error({report_encoding, {invalid_unicode, Valid, Invalid}});
        {incomplete, Valid, Incomplete} ->
            erlang:error({report_encoding,
                          {incomplete_unicode, Valid, Incomplete}})
    end.

escape_char($\n) -> "\\n";
escape_char($\r) -> "\\r";
escape_char($\\) -> "\\\\";
escape_char($`) -> "\\`";
escape_char($|) -> "\\|";
escape_char($[) -> "\\[";
escape_char($]) -> "\\]";
escape_char(Char) -> [Char].

sort_warnings(Warnings) ->
    Unique = maps:values(maps:from_list([
                         {{maps:get(path, W), maps:get(reason, W),
                           term_text(maps:get(detail, W))}, W} ||
                         W <- Warnings])),
    lists:sort(fun(A, B) ->
                       {maps:get(path, A), maps:get(reason, A),
                        term_text(maps:get(detail, A))} =<
                       {maps:get(path, B), maps:get(reason, B),
                        term_text(maps:get(detail, B))}
               end, Unique).

-spec format_time(term()) -> string().
format_time({{Year, Month, Day}, {Hour, Minute, Second}}) ->
    lists:flatten(io_lib:format("~4..0B-~2..0B-~2..0BT~2..0B:~2..0B:~2..0BZ",
                                [Year, Month, Day, Hour, Minute, Second]));
format_time(Other) ->
    lists:flatten(io_lib:format("~tp", [Other])).

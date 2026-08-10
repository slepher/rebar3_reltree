-module(rebar3_reltree_graph_tests).

-include_lib("eunit/include/eunit.hrl").

transitive_local_closure_and_external_declaration_test() ->
    Workspace = rebar3_reltree_fixtures:new_root(),
    try
        A = project_dir(Workspace, "a"),
        B = project_dir(Workspace, "b"),
        C = project_dir(Workspace, "c"),
        ok = file:make_dir(A), ok = file:make_dir(B), ok = file:make_dir(C),
        rebar3_reltree_fixtures:write_project(A, a, [b, external], "0.1.0"),
        rebar3_reltree_fixtures:write_project(B, b, [c], "0.1.0"),
        rebar3_reltree_fixtures:write_project(C, c, [], "0.1.0"),
        rebar3_reltree_fixtures:checkout(A, b, B),
        rebar3_reltree_fixtures:checkout(B, c, C),
        Request = rebar3_reltree_fixtures:request(A, [{Workspace, deep}], default),
        {ok, Graph} = rebar3_reltree_graph:build(Request),
        ?assertEqual(3, length(maps:get(included, Graph))),
        ?assertEqual(2, length(maps:get(edges, Graph))),
        ?assertEqual([], maps:get(graph_issues, Graph)),
        {ok, Model} = rebar3_reltree_project:enrich(Graph, #{}, Request),
        Report = report_bytes(Model),
        ?assert(string:str(Report, "external") > 0),
        ?assert(string:str(Report, "revision_state: not-applicable") > 0),
        ?assert(string:str(Report, "status: up-to-date") > 0)
    after
        rebar3_reltree_fixtures:cleanup(Workspace)
    end.

downstream_requires_declaration_and_matching_checkout_test() ->
    Workspace = rebar3_reltree_fixtures:new_root(),
    try
        A = project_dir(Workspace, "a"),
        B = project_dir(Workspace, "b"),
        C = project_dir(Workspace, "c"),
        ok = file:make_dir(A), ok = file:make_dir(B), ok = file:make_dir(C),
        rebar3_reltree_fixtures:write_project(A, a, [], "0.1.0"),
        rebar3_reltree_fixtures:write_project(B, b, [a], "0.1.0"),
        rebar3_reltree_fixtures:write_project(C, c, [], "0.1.0"),
        rebar3_reltree_fixtures:checkout(B, a, A),
        rebar3_reltree_fixtures:checkout(C, a, A),
        Request = rebar3_reltree_fixtures:request(A, [{Workspace, shallow}], default),
        {ok, Graph} = rebar3_reltree_graph:build(Request),
        ?assertEqual(2, length(maps:get(included, Graph))),
        ?assertEqual(1, length(maps:get(edges, Graph))),
        ?assertEqual([], maps:get(graph_issues, Graph))
    after
        rebar3_reltree_fixtures:cleanup(Workspace)
    end.

broken_checkout_is_insufficient_but_preserves_old_report_test() ->
    Workspace = rebar3_reltree_fixtures:new_root(),
    try
        A = project_dir(Workspace, "a"),
        ok = file:make_dir(A),
        rebar3_reltree_fixtures:write_project(A, a, [b], "0.1.0"),
        ok = file:make_dir(filename:join(A, "_checkouts")),
        Broken = filename:join([A, "_checkouts", "b"]),
        ok = file:make_symlink(filename:join(Workspace, "missing"), Broken),
        Request = rebar3_reltree_fixtures:request(A, [], default),
        {ok, Result} = rebar3_reltree_project:generate(
                         Request, #{clock => fun() ->
                                             {{2020, 1, 2}, {3, 4, 5}}
                                         end}),
        ?assert(filelib:is_regular(maps:get(output_path, Request))),
        Report = maps:get(bytes, Result),
        ?assert(string:str(binary_to_list(Report),
                           "status: insufficient-local-data") > 0),
        ?assert(string:str(binary_to_list(Report), "checkout-invalid") > 0)
    after
        rebar3_reltree_fixtures:cleanup(Workspace)
    end.

checkout_only_and_external_declarations_do_not_create_edges_test() ->
    Workspace = rebar3_reltree_fixtures:new_root(),
    try
        A = project_dir(Workspace, "a"),
        B = project_dir(Workspace, "b"),
        C = project_dir(Workspace, "c"),
        ok = file:make_dir(A), ok = file:make_dir(B), ok = file:make_dir(C),
        rebar3_reltree_fixtures:write_project(A, a, [external], "0.1.0"),
        rebar3_reltree_fixtures:write_project(B, b, [], "0.1.0"),
        rebar3_reltree_fixtures:write_project(C, c, [], "0.1.0"),
        rebar3_reltree_fixtures:checkout(A, b, B),
        rebar3_reltree_fixtures:checkout(C, a, A),
        Request = rebar3_reltree_fixtures:request(A, [{Workspace, deep}],
                                                  default),
        {ok, Graph} = rebar3_reltree_graph:build(Request),
        ?assertEqual([A], maps:get(included, Graph)),
        ?assertEqual([], maps:get(edges, Graph)),
        {ok, Model} = rebar3_reltree_project:enrich(Graph, #{}, Request),
        {ok, Report} = rebar3_reltree_report:render(Model),
        Text = binary_to_list(Report),
        ?assert(string:str(Text, "external") > 0),
        ?assert(string:str(Text, "revision_state: not-applicable") > 0)
    after
        rebar3_reltree_fixtures:cleanup(Workspace)
    end.

explicit_checkout_outside_scan_catalog_is_loaded_test() ->
    Workspace = rebar3_reltree_fixtures:new_root(),
    Outside = rebar3_reltree_fixtures:new_root(),
    try
        A = project_dir(Workspace, "a"),
        B = project_dir(Outside, "b"),
        ok = file:make_dir(A), ok = file:make_dir(B),
        rebar3_reltree_fixtures:write_project(A, a, [b], "0.1.0"),
        rebar3_reltree_fixtures:write_project(B, b, [], "0.1.0"),
        rebar3_reltree_fixtures:checkout(A, b, B),
        Request = rebar3_reltree_fixtures:request(A, [], default),
        {ok, Graph} = rebar3_reltree_graph:build(Request),
        ?assertEqual(2, length(maps:get(included, Graph))),
        ?assertEqual(1, length(maps:get(edges, Graph)))
    after
        rebar3_reltree_fixtures:cleanup(Workspace),
        rebar3_reltree_fixtures:cleanup(Outside)
    end.

regular_checkout_directory_is_a_relationship_entry_test() ->
    Workspace = rebar3_reltree_fixtures:new_root(),
    try
        A = project_dir(Workspace, "a"),
        ok = file:make_dir(A),
        rebar3_reltree_fixtures:write_project(A, a, [b], "0.1.0"),
        Checkout = filename:join([A, "_checkouts", "b"]),
        ok = filelib:ensure_dir(filename:join(Checkout, "placeholder")),
        rebar3_reltree_fixtures:write_project(Checkout, b, [], "0.1.0"),
        Request = rebar3_reltree_fixtures:request(A, [], default),
        {ok, Graph} = rebar3_reltree_graph:build(Request),
        ?assertEqual(2, length(maps:get(included, Graph))),
        ?assertEqual(1, length(maps:get(edges, Graph))),
        ?assertEqual([], maps:get(graph_issues, Graph))
    after
        rebar3_reltree_fixtures:cleanup(Workspace)
    end.

duplicate_dependency_declarations_share_one_canonical_edge_test() ->
    Workspace = rebar3_reltree_fixtures:new_root(),
    try
        A = project_dir(Workspace, "a"),
        B = project_dir(Workspace, "b"),
        ok = file:make_dir(A), ok = file:make_dir(B),
        rebar3_reltree_fixtures:write_project(
          A, a, [{b, "1.0"}, b, {b, git}], "0.1.0"),
        rebar3_reltree_fixtures:write_project(B, b, [], "0.1.0"),
        rebar3_reltree_fixtures:checkout(A, b, B),
        Request = rebar3_reltree_fixtures:request(A, [{Workspace, deep}],
                                                  default),
        {ok, Graph} = rebar3_reltree_graph:build(Request),
        ?assertEqual(1, length(maps:get(edges, Graph))),
        [Edge] = maps:get(edges, Graph),
        ?assertEqual(b, maps:get(dependency, Edge)),
        {ok, Model} = rebar3_reltree_project:enrich(Graph, #{}, Request),
        Text = report_bytes(Model),
        ?assert(string:str(Text, "declaration: {b,\"1.0\"}") > 0),
        ?assert(string:str(Text, "declaration: b") > 0),
        ?assert(string:str(Text, "declaration: {b,git}") > 0)
    after
        rebar3_reltree_fixtures:cleanup(Workspace)
    end.

malformed_unrelated_candidate_warns_without_changing_current_graph_test() ->
    Workspace = rebar3_reltree_fixtures:new_root(),
    try
        Current = project_dir(Workspace, "current"),
        Good = project_dir(Workspace, "good"),
        Bad = project_dir(Workspace, "bad"),
        ok = file:make_dir(Current), ok = file:make_dir(Good),
        ok = file:make_dir(Bad),
        rebar3_reltree_fixtures:write_project(Current, current, [], "0.1.0"),
        rebar3_reltree_fixtures:write_project(Good, good, [], "0.1.0"),
        rebar3_reltree_fixtures:write_file(
          filename:join(Bad, "rebar.config"), "{deps, [} .\n"),
        Request = rebar3_reltree_fixtures:request(Current,
                                                  [{Workspace, deep}], default),
        {ok, Graph} = rebar3_reltree_graph:build(Request),
        ?assertEqual([rebar3_reltree_fs:canonical(Current)],
                     maps:get(included, Graph)),
        ?assert(lists:any(fun(W) -> maps:get(path, W) =:=
                                      rebar3_reltree_fs:canonical(Bad) andalso
                                      maps:get(reason, W) =:= candidate_invalid
                          end, maps:get(warnings, Graph)))
    after
        rebar3_reltree_fixtures:cleanup(Workspace)
    end.

looping_checkout_is_an_insufficient_local_data_warning_test() ->
    Workspace = rebar3_reltree_fixtures:new_root(),
    try
        A = project_dir(Workspace, "a"),
        ok = file:make_dir(A),
        rebar3_reltree_fixtures:write_project(A, a, [b], "0.1.0"),
        CheckoutDir = filename:join(A, "_checkouts"),
        ok = file:make_dir(CheckoutDir),
        One = filename:join(CheckoutDir, "one"),
        Two = filename:join(CheckoutDir, "two"),
        ok = file:make_symlink(Two, One),
        ok = file:make_symlink(One, Two),
        ok = file:make_symlink(One, filename:join(CheckoutDir, "b")),
        Request = rebar3_reltree_fixtures:request(A, [], default),
        {ok, Result} = rebar3_reltree_project:generate(
                         Request, #{clock => fun() ->
                                             {{2020, 1, 2}, {3, 4, 5}}
                                         end}),
        Text = binary_to_list(maps:get(bytes, Result)),
        ?assert(string:str(Text, "status: insufficient-local-data") > 0),
        ?assert(string:str(Text, "symlink_loop") > 0)
    after
        rebar3_reltree_fixtures:cleanup(Workspace)
    end.

current_failure_preserves_existing_report_test() ->
    Workspace = rebar3_reltree_fixtures:new_root(),
    try
        Current = project_dir(Workspace, "current"),
        ok = file:make_dir(Current),
        rebar3_reltree_fixtures:write_file(
          filename:join(Current, "rebar.config"), "{deps, [} .\n"),
        Request = rebar3_reltree_fixtures:request(Current, [], default),
        {ok, _} = rebar3_reltree_fs:atomic_write(
                    maps:get(output_path, Request), <<"previous">>, #{}),
        {error, {current_project, _, _}} =
            rebar3_reltree_project:generate(Request),
        {ok, Bytes} = file:read_file(maps:get(output_path, Request)),
        ?assertEqual(<<"previous">>, Bytes),
        ?assertEqual([], temp_files(maps:get(output_path, Request)))
    after
        rebar3_reltree_fixtures:cleanup(Workspace)
    end.

project_dir(Workspace, Name) -> filename:join(Workspace, Name).

report_bytes(Model) ->
    {ok, Bytes} = rebar3_reltree_report:render(
                    Model, #{clock => fun() -> {{2020, 1, 2}, {3, 4, 5}} end}),
    binary_to_list(Bytes).

temp_files(Output) ->
    {ok, Names} = file:list_dir(filename:dirname(Output)),
    [Name || Name <- Names,
             lists:prefix(".project.md.reltree-", Name)].

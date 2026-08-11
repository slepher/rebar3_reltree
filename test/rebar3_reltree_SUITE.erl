-module(rebar3_reltree_SUITE).

-include_lib("common_test/include/ct.hrl").
-include_lib("eunit/include/eunit.hrl").

-export([all/0, provider_and_cli_surface/1, deep_relationship_closure/1,
         anomaly_and_atomic_boundary/1, status_and_report_facts/1,
         bgate_surface/1]).

all() ->
    [provider_and_cli_surface, deep_relationship_closure,
     anomaly_and_atomic_boundary, status_and_report_facts, bgate_surface].

provider_and_cli_surface(_Config) ->
    Root = rebar3_reltree_fixtures:new_root(),
    try
        rebar3_reltree_fixtures:write_project(Root, ct_surface, [], "0.1.0"),
        State0 = rebar_state:new([]),
        State1 = rebar_state:dir(State0, Root),
        State2 = rebar_state:command_args(State1, ["tree"]),
        {ok, State2} = rebar3_reltree_prv_tree:do(State2),
        ProviderReport = filename:join([Root, "_build", "default", "reltree",
                                        "project.md"]),
        {ok, ProviderBytes} = file:read_file(ProviderReport),
        ?assertMatch({_, _}, binary:match(ProviderBytes,
                                          <<"network_sync_at: not-performed">>)),
        rebar3_reltree_fixtures:cleanup(Root),
        Root2 = rebar3_reltree_fixtures:new_root(),
        try
            rebar3_reltree_fixtures:write_project(
              Root2, ct_cli, [], "0.1.0"),
            {0, []} = rebar3_reltree_cli:run(["tree"], #{cwd => Root2}),
            ?assert(filelib:is_regular(filename:join(
                       [Root2, "_build", "default", "reltree", "project.md"])))
        after
            rebar3_reltree_fixtures:cleanup(Root2)
        end
    after
        %% The first root may already have been cleaned before the CLI branch.
        rebar3_reltree_fixtures:cleanup(Root)
    end.

deep_relationship_closure(_Config) ->
    Workspace = rebar3_reltree_fixtures:new_root(),
    try
        A = filename:join(Workspace, "a"),
        B = filename:join([Workspace, "nested", "b"]),
        C = filename:join([Workspace, "nested", "deep", "c"]),
        ok = filelib:ensure_dir(filename:join(B, "placeholder")),
        ok = filelib:ensure_dir(filename:join(C, "placeholder")),
        ok = file:make_dir(A),
        rebar3_reltree_fixtures:write_project(A, a, [b], "0.1.0"),
        rebar3_reltree_fixtures:write_project(B, b, [c], "0.1.0"),
        rebar3_reltree_fixtures:write_project(C, c, [], "0.1.0"),
        rebar3_reltree_fixtures:checkout(A, b, B),
        rebar3_reltree_fixtures:checkout(B, c, C),
        Request = request(A, [{Workspace, deep}], default),
        {ok, Graph} = rebar3_reltree_graph:build(Request),
        ?assertEqual(3, length(maps:get(included, Graph))),
        ?assertEqual(2, length(maps:get(edges, Graph))),
        {ok, First} = rebar3_reltree_project:generate(
                        Request, #{clock => fixed_clock()}),
        {ok, Second} = rebar3_reltree_project:generate(
                         Request, #{clock => fixed_clock()}),
        ?assertEqual(maps:get(bytes, First), maps:get(bytes, Second))
    after
        rebar3_reltree_fixtures:cleanup(Workspace)
    end.

anomaly_and_atomic_boundary(_Config) ->
    Workspace = rebar3_reltree_fixtures:new_root(),
    try
        Current = filename:join(Workspace, "current"),
        ok = file:make_dir(Current),
        rebar3_reltree_fixtures:write_project(Current, current, [broken],
                                              "0.1.0"),
        CheckoutDir = filename:join(Current, "_checkouts"),
        ok = file:make_dir(CheckoutDir),
        ok = file:make_symlink(filename:join(Workspace, "missing"),
                               filename:join(CheckoutDir, "broken")),
        Request = request(Current, [], default),
        {ok, Result} = rebar3_reltree_project:generate(
                         Request, #{clock => fixed_clock()}),
        ?assertMatch({_, _}, binary:match(maps:get(bytes, Result),
                                          <<"insufficient-local-data">>)),
        {error, {atomic_write, close, injected}} =
            rebar3_reltree_fs:atomic_write(
              maps:get(output_path, Request), <<"replacement">>,
              #{fail_stage => close}),
        {ok, Prior} = file:read_file(maps:get(output_path, Request)),
        ?assertEqual(maps:get(bytes, Result), Prior)
    after
        rebar3_reltree_fixtures:cleanup(Workspace)
    end.

status_and_report_facts(_Config) ->
    ?assertEqual([insufficient_local_data, update_required, up_to_date],
                 rebar3_reltree_status:values()),
    ?assertEqual(insufficient_local_data,
                 maps:get(status, rebar3_reltree_version:evaluate(
                                   "2.0.0", ["1.2.0"]))),
    Model = #{format_version => 2, current => "/tmp/current",
              current_name => current, status => up_to_date,
              local_sync_at => "2020-01-02T03:04:05Z",
              nodes => [], edges => [], warnings => [],
              local_only_caveats => [network_sync_not_performed]},
    {ok, Bytes} = rebar3_reltree_report:render(Model),
    ?assertMatch({_, _}, binary:match(Bytes,
                                      <<"format_version: 2">>)),
    ?assertMatch({_, _}, binary:match(Bytes,
                                      <<"nodes\n- none">>)),
    ?assertMatch({_, _}, binary:match(Bytes,
                                      <<"network_sync_at: not-performed">>)).

bgate_surface(_Config) ->
    Root = rebar3_reltree_fixtures:new_root(),
    try
        rebar3_reltree_fixtures:write_project(Root, ct_bgate, [], "0.1.0"),
        rebar3_reltree_fixtures:add_origin(
          Root, "https://github.com/acme/ct-bgate.git"),
        rebar3_reltree_fixtures:write_file(
          filename:join([Root, ".github", "workflows", "ci.yml"]),
          <<"name: ci\n">>),
        README = filename:join(Root, "README.md"),
        rebar3_reltree_fixtures:write_file(README, <<"content\n">>),
        {0, []} = rebar3_reltree_cli:run(["bgate", "--write"],
                                          #{cwd => Root}),
        {0, []} = rebar3_reltree_cli:run(["bgate", "--check"],
                                          #{cwd => Root}),
        {ok, Bytes} = file:read_file(README),
        ?assertMatch({_, _}, binary:match(Bytes, <<"master CI">>)),
        ?assertNot(filelib:is_regular(filename:join(Root, "project.md")))
    after
        rebar3_reltree_fixtures:cleanup(Root)
    end.

request(Root, ScanRoots, Profile) ->
    Build = filename:join([Root, "_build", atom_to_list(Profile)]),
    #{command => tree, project_root => Root, profile => Profile,
      build_base_dir => Build,
      output_path => filename:join([Build, "reltree", "project.md"]),
      scan_roots => ScanRoots, rev => auto}.

fixed_clock() -> fun() -> {{2020, 1, 2}, {3, 4, 5}} end.

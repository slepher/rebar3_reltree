-module(rebar3_reltree_report_tests).

-include_lib("eunit/include/eunit.hrl").

deterministic_clock_and_fixed_metadata_test() ->
    Model = model(),
    {ok, One} = rebar3_reltree_report:render(Model),
    {ok, Two} = rebar3_reltree_report:render(Model),
    ?assertEqual(One, Two),
    Text = binary_to_list(One),
    ?assert(string:str(Text, "status: up-to-date") > 0),
    ?assert(string:str(Text, "network_sync_at: not-performed") > 0),
    ?assert(string:str(Text, "local_sync_at: 2020-01-02T03:04:05Z") > 0),
    ?assert(string:str(Text, "revision_state: not-applicable") > 0),
    ?assertEqual("a\\|b\\n", rebar3_reltree_report:escape("a|b\n")).

unicode_fields_are_utf8_and_unencodable_values_are_structured_test() ->
    Name = [16#9879, 16#76EE],
    Path = "/tmp/" ++ Name,
    Node = (hd(maps:get(nodes, model())))#{path => Path,
                                           name => Name,
                                           app_src => Path ++
                                               "/src/app.app.src",
                                           dependency_relationships => #{}},
    UnicodeModel = (model())#{current => Path,
                              current_name => Name,
                              nodes => [Node]},
    {ok, Bytes} = rebar3_reltree_report:render(UnicodeModel),
    ?assert(is_list(unicode:characters_to_list(Bytes, utf8))),
    ?assertMatch({_, _}, binary:match(Bytes, unicode:characters_to_binary(
                                                Path))),
    ?assertMatch({error, {report_encoding, _}},
                 rebar3_reltree_report:render(
                   (model())#{current => [16#110000]})),
    ?assertMatch({error, {report_encoding, _}},
                 rebar3_reltree_report:render(
                   (model())#{current => <<255>>})).

renderer_uses_only_model_relationship_facts_test() ->
    Node0 = hd(maps:get(nodes, model())),
    Node = Node0#{path => "/tmp/missing-renderer-project",
                  revision_declarations =>
                      [revision_fact(external, omitted_local_checkout,
                                     local_unavailable)],
                  dependency_relationships =>
                      #{external => omitted_local_checkout}},
    {ok, Bytes} = rebar3_reltree_report:render(
                    (model())#{current => "/tmp/missing-renderer-project",
                               nodes => [Node]}),
    ?assertMatch({_, _}, binary:match(Bytes,
                                      <<"relationship: omitted-local-checkout">>)).

renderer_requires_valid_model_clock_test() ->
    ?assertEqual({error, {clock, missing_local_sync_at}},
                 rebar3_reltree_report:render(
                   maps:remove(local_sync_at, model()))),
    ?assertEqual({error, {clock, invalid_clock}},
                 rebar3_reltree_report:render(
                   (model())#{local_sync_at => "not-a-timestamp"})).

atomic_replacement_preserves_prior_bytes_on_failure_test() ->
    Root = rebar3_reltree_fixtures:new_root(),
    try
        Output = filename:join([Root, "_build", "default", "reltree",
                                "project.md"]),
        {ok, Output} = rebar3_reltree_fs:atomic_write(Output, <<"old">>, #{}),
        {error, {atomic_write, rename, injected}} =
            rebar3_reltree_fs:atomic_write(Output, <<"new">>,
                                           #{fail_stage => rename}),
        {ok, Old} = file:read_file(Output),
        ?assertEqual(<<"old">>, Old),
        {ok, Names} = file:list_dir(filename:dirname(Output)),
        ?assertEqual([], [Name || Name <- Names,
                                  lists:prefix(".project.md.reltree-", Name)])
    after
        rebar3_reltree_fixtures:cleanup(Root)
    end.

all_atomic_failure_stages_preserve_prior_bytes_test() ->
    lists:foreach(fun(Stage) -> atomic_failure_stage(Stage) end,
                  [write, close, rename]).

declarations_are_sorted_by_name_and_term_test() ->
    %% This assertion uses the renderer's public bytes rather than its
    %% internal representation, so declaration ordering remains a contract.
    Node = #{path => "/tmp/current", name => current, app => current,
             app_vsn => "0.1.0", app_src => "/tmp/current/src/current.app.src",
             head => "head", version => #{highest_formal => none,
                 reason => no_formal_tag, formal_tags => [], prerelease_tags => [],
                 status => up_to_date},
             readme => #{readme => false, readme_zh => false},
             ci_workflow => false, badge => #{state => skip_no_ci},
             dependencies => [z, {a, "1.0"}], project_plugins => [],
             plugins => []},
    {ok, Bytes} = rebar3_reltree_report:render(
                    #{format_version => 2, current => "/tmp/current",
                      current_name => current, status => up_to_date,
                      nodes => [Node], edges => [], warnings => [],
                      local_only_caveats => [],
                      local_sync_at => "2020-01-02T03:04:05Z"}),
    Text = binary_to_list(Bytes),
    ?assert(string:str(Text, "name: a") < string:str(Text, "name: z")).

model() ->
    #{format_version => 2,
      current => "/tmp/current",
      current_name => current,
      status => up_to_date,
      local_sync_at => "2020-01-02T03:04:05Z",
      nodes => [#{path => "/tmp/current", name => current, app => current,
                  app_vsn => "0.1.0", head => "head",
                  version => #{highest_formal => none,
                               reason => no_formal_tag,
                               formal_tags => [], prerelease_tags => []},
                  readme => #{readme => false, readme_zh => false},
                  ci_workflow => false,
                  badge => #{state => skip_no_ci},
                  dependencies => [external], project_plugins => [],
                  plugins => [],
                  revision_declarations =>
                      [revision_fact(external, external, not_applicable)]}],
      edges => [], warnings => [],
      local_only_caveats => [network_sync_not_performed]}.

revision_fact(Name, Relationship, State) ->
    #{owner => "/tmp/current", name => Name, declaration => Name,
      relationship => Relationship, revision_state => State,
      source_url => none, selector_kind => none, selector_value => none,
      resolved_revision => none, revision_observed_at => not_performed,
      network_sync_at => not_performed}.

atomic_failure_stage(Stage) ->
    Root = rebar3_reltree_fixtures:new_root(),
    try
        Output = filename:join([Root, "_build", "default", "reltree",
                                "project.md"]),
        {ok, Output} = rebar3_reltree_fs:atomic_write(Output, <<"old">>, #{}),
        ?assertMatch({error, {atomic_write, Stage, injected}},
                     rebar3_reltree_fs:atomic_write(
                       Output, <<"new">>, #{fail_stage => Stage})),
        {ok, Old} = file:read_file(Output),
        ?assertEqual(<<"old">>, Old),
        {ok, Names} = file:list_dir(filename:dirname(Output)),
        ?assertEqual([], [Name || Name <- Names,
                                  lists:prefix(".project.md.reltree-", Name)])
    after
        rebar3_reltree_fixtures:cleanup(Root)
    end.

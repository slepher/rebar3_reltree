-module(rebar3_reltree_config_tests).

-include_lib("eunit/include/eunit.hrl").

dependency_terms_are_retained_and_malformed_terms_rejected_test() ->
    Root = rebar3_reltree_fixtures:new_root(),
    try
        ok = rebar3_reltree_fixtures:write_file(
               filename:join(Root, "rebar.config"),
               "{deps, [foo, {bar, \"1.0\"}]}.\n"),
        {ok, Facts} = rebar3_reltree_config:read(Root),
        ?assertEqual([foo, {bar, "1.0"}],
                     maps:get(dependencies, Facts)),
        ?assertEqual({ok, foo},
                     rebar3_reltree_config:dependency_name(foo)),
        ?assertEqual({ok, bar}, rebar3_reltree_config:dependency_name(
                                      {bar, "1.0"})),
        ok = file:write_file(filename:join(Root, "rebar.config"),
                             "{deps, [bad, {1, x}]}.\n"),
        ?assertMatch({error, {malformed_dependency, {1, x}}},
                     rebar3_reltree_config:read(Root))
    after
        rebar3_reltree_fixtures:cleanup(Root)
    end.

app_identity_requires_one_valid_app_src_test() ->
    Root = rebar3_reltree_fixtures:new_root(),
    try
        ok = file:make_dir(filename:join(Root, "src")),
        Path = filename:join([Root, "src", "one.app.src"]),
        ok = file:write_file(Path,
                             "{application, one, [{vsn, \"0.1.0\"}]}.\n"),
        {ok, Identity} = rebar3_reltree_config:app_identity(Root),
        ?assertEqual(one, maps:get(app, Identity)),
        ?assertEqual("0.1.0", maps:get(app_vsn, Identity)),
        ok = file:write_file(filename:join([Root, "src", "two.app.src"]),
                             "{application, two, [{vsn, \"0.1.0\"}]}.\n"),
        ?assertEqual({error, multiple_app_src},
                     rebar3_reltree_config:app_identity(Root))
    after
        rebar3_reltree_fixtures:cleanup(Root)
    end.

known_config_key_with_wrong_arity_is_rejected_test() ->
    Root = rebar3_reltree_fixtures:new_root(),
    try
        ok = rebar3_reltree_fixtures:write_file(
               filename:join(Root, "rebar.config"),
               "{deps, [foo], ignored} .\n"),
        ?assertMatch({error, {malformed_config_term, deps, _}},
                     rebar3_reltree_config:read(Root))
    after
        rebar3_reltree_fixtures:cleanup(Root)
    end.

app_identity_rejects_invalid_or_ambiguous_versions_test() ->
    Root = rebar3_reltree_fixtures:new_root(),
    try
        ok = file:make_dir(filename:join(Root, "src")),
        Path = filename:join([Root, "src", "one.app.src"]),
        ok = file:write_file(
               Path, "{application, one, [{vsn, 1}, {vsn, \"0.1.0\"}]}.\n"),
        ?assertEqual({error, ambiguous_app_vsn},
                     rebar3_reltree_config:app_identity(Root)),
        ok = file:write_file(Path,
                             "{application, one, [{vsn, 1}]}.\n"),
        ?assertEqual({error, invalid_app_vsn},
                     rebar3_reltree_config:app_identity(Root))
    after
        rebar3_reltree_fixtures:cleanup(Root)
    end.

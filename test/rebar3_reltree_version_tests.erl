-module(rebar3_reltree_version_tests).

-include_lib("eunit/include/eunit.hrl").

formal_tag_filtering_and_highest_version_test() ->
    Facts = rebar3_reltree_version:evaluate(
        "1.2.1", [
            "v1.2.0",
            "1.2.1-rc.1",
            "check-1.2.9",
            "1.0.0",
            "1.2.0"
        ]
    ),
    ?assertEqual(
        #{tag => "v1.2.0", version => {1, 2, 0}},
        maps:get(highest_formal, Facts)
    ),
    ?assertEqual(version_line_valid, maps:get(reason, Facts)),
    ?assertEqual(up_to_date, maps:get(status, Facts)),
    ?assertEqual(
        {formal, {1, 2, 0}, "v1.2.0"},
        rebar3_reltree_version:parse_tag("v1.2.0")
    ),
    ?assertEqual(none, rebar3_reltree_version:parse_tag("check-1.2.9")).

version_status_reasons_test() ->
    ?assertEqual(
        no_formal_tag,
        maps:get(
            reason,
            rebar3_reltree_version:evaluate(
                "9.0.0", []
            )
        )
    ),
    ?assertEqual(
        update_required,
        maps:get(
            status,
            rebar3_reltree_version:evaluate(
                "1.2.4", ["1.2.0"]
            )
        )
    ),
    ?assertEqual(
        insufficient_local_data,
        maps:get(
            status,
            rebar3_reltree_version:evaluate(
                "2.0.0", ["1.2.0"]
            )
        )
    ),
    ?assertEqual(
        generation_selection_needed,
        maps:get(
            reason,
            rebar3_reltree_version:evaluate(
                "2.0.0", ["1.2.0"]
            )
        )
    ),
    ?assertEqual(
        prerelease_base_mismatch,
        maps:get(
            reason,
            rebar3_reltree_version:evaluate(
                "1.2.0", ["1.2.0", "1.1.0-rc.1"]
            )
        )
    ).

continuous_patch_and_breaking_lines_are_valid_test() ->
    ?assertEqual(
        up_to_date,
        maps:get(
            status,
            rebar3_reltree_version:evaluate(
                "1.2.1", ["1.2.0"]
            )
        )
    ),
    ?assertEqual(
        up_to_date,
        maps:get(
            status,
            rebar3_reltree_version:evaluate(
                "1.3.0", ["1.2.0"]
            )
        )
    ).

only_release_prerelease_forms_are_accepted_test() ->
    ?assertEqual(
        {prerelease, {1, 2, 3}, "1.2.3-rc.1"},
        rebar3_reltree_version:parse_tag("1.2.3-rc.1")
    ),
    ?assertEqual(
        {prerelease, {1, 2, 3}, "v1.2.3-ci.2"},
        rebar3_reltree_version:parse_tag("v1.2.3-ci.2")
    ),
    ?assertEqual(
        none,
        rebar3_reltree_version:parse_tag("1.2.3-alpha.1")
    ),
    ?assertEqual(
        none,
        rebar3_reltree_version:parse_tag("1.2.3-beta")
    ),
    ?assertEqual(
        none,
        rebar3_reltree_version:parse_tag("1.2.3-rc")
    ),
    ?assertEqual(
        none,
        rebar3_reltree_version:parse_tag("1.2.3-rc.one")
    ),
    ?assertEqual(
        none,
        rebar3_reltree_version:parse_tag("1.2.3-rc.1.extra")
    ),
    ?assertEqual(
        [],
        maps:get(
            prerelease_tags,
            rebar3_reltree_version:evaluate(
                "1.2.3", ["1.2.3-alpha.1"]
            )
        )
    ).

checkvsn_groups_formal_versions_by_numeric_value_test() ->
    {ok, Facts} = rebar3_reltree_version:check(
        "1.2.1",
        #{
            reachable_tags => [
                "v1.2.0",
                "1.2.0",
                "check-9.0.0",
                "1.2.0-rc.1"
            ],
            head_tags => []
        }
    ),
    ?assertEqual(next_patch, maps:get(continuity, Facts)),
    ?assertEqual(
        [
            #{
                version => {1, 2, 0},
                tags => ["1.2.0", "v1.2.0"]
            }
        ],
        maps:get(formal_versions, Facts)
    ),
    ?assertEqual(
        ["1.2.0", "v1.2.0"],
        maps:get(tags, maps:get(highest_formal, Facts))
    ).

checkvsn_accepts_initial_and_continuous_lines_test() ->
    ?assertEqual(initial, continuity("8.4.12", [])),
    ?assertEqual(same, continuity("1.2.0", ["1.2.0"])),
    ?assertEqual(next_patch, continuity("1.2.1", ["1.2.0"])),
    ?assertEqual(next_minor, continuity("1.3.0", ["1.2.9"])),
    ?assertEqual(next_major, continuity("2.0.0", ["1.9.9"])).

checkvsn_rejects_gaps_and_current_tag_mismatch_test() ->
    ?assertMatch(
        {error, {version_not_continuous, _}},
        rebar3_reltree_version:check(
            "1.2.2", #{
                reachable_tags => ["1.2.0"],
                head_tags => []
            }
        )
    ),
    ?assertMatch(
        {error, {current_tag_base_mismatch, _}},
        rebar3_reltree_version:check(
            "1.2.0", #{
                reachable_tags => ["1.2.0"],
                head_tags => ["1.1.0-rc.1"]
            }
        )
    ),
    ?assertMatch(
        {error, {invalid_app_version, _}},
        rebar3_reltree_version:check(
            "1.2", #{reachable_tags => [], head_tags => []}
        )
    ).

checkvsn_rejects_independent_version_discontinuities_test() ->
    Facts = #{reachable_tags => ["1.2.0"], head_tags => []},
    ?assertMatch(
        {error, {version_not_continuous, _}},
        rebar3_reltree_version:check("1.1.9", Facts)
    ),
    ?assertMatch(
        {error, {version_not_continuous, _}},
        rebar3_reltree_version:check("1.4.0", Facts)
    ),
    ?assertMatch(
        {error, {version_not_continuous, _}},
        rebar3_reltree_version:check("1.3.1", Facts)
    ),
    ?assertMatch(
        {error, {version_not_continuous, _}},
        rebar3_reltree_version:check("3.0.0", Facts)
    ),
    ?assertMatch(
        {error, {version_not_continuous, _}},
        rebar3_reltree_version:check("2.1.0", Facts)
    ).

continuity(App, Tags) ->
    {ok, Facts} = rebar3_reltree_version:check(
        App, #{reachable_tags => Tags, head_tags => []}
    ),
    maps:get(continuity, Facts).

-module(rebar3_reltree_status_tests).

-include_lib("eunit/include/eunit.hrl").

status_precedence_and_values_test() ->
    Node = fun(VersionStatus, VersionReason, BadgeState) ->
                   #{version => #{status => VersionStatus,
                                  reason => VersionReason},
                     badge => #{state => BadgeState}}
           end,
    ?assertEqual({up_to_date, [version_line_valid]},
                 rebar3_reltree_status:evaluate(
                   #{nodes => [Node(up_to_date, version_line_valid,
                                    skip_no_ci)], graph_issues => []})),
    ?assertMatch({update_required, _},
                 rebar3_reltree_status:evaluate(
                   #{nodes => [Node(update_required, version_line_mismatch,
                                    skip_no_ci)], graph_issues => []})),
    ?assertMatch({update_required, _},
                 rebar3_reltree_status:evaluate(
                   #{nodes => [Node(up_to_date, version_line_valid,
                                    badge_mismatch)], graph_issues => []})),
    ?assertMatch({insufficient_local_data, _},
                 rebar3_reltree_status:evaluate(
                   #{nodes => [Node(update_required, version_line_mismatch,
                                    badge_mismatch)],
                     graph_issues => [{"/tmp/a", relation_anomaly}]})),
    ?assertEqual([insufficient_local_data, update_required, up_to_date],
                 rebar3_reltree_status:values()).

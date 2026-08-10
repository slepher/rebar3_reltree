-module(rebar3_reltree_status).

-export([evaluate/1, values/0]).

-spec values() -> [atom()].
values() ->
    [insufficient_local_data, update_required, up_to_date].

-spec evaluate(map()) -> {atom(), [atom()]}.
evaluate(#{nodes := Nodes, graph_issues := GraphIssues}) ->
    GraphReasons = [Reason || {_Path, Reason} <- GraphIssues],
    NodeResults = [node_result(Node) || Node <- Nodes],
    NodeStatuses = [Status || {Status, _Reasons} <- NodeResults],
    NodeReasons = lists:append([Reasons || {_Status, Reasons} <- NodeResults]),
    Status = case lists:member(insufficient_local_data,
                               [status_from_graph(GraphReasons) | NodeStatuses]) of
                 true -> insufficient_local_data;
                 false ->
                     case lists:member(update_required, NodeStatuses) of
                         true -> update_required;
                         false -> up_to_date
                     end
             end,
    Reasons = lists:usort(GraphReasons ++ NodeReasons),
    {Status, Reasons}.

node_result(Node) ->
    Version = maps:get(version, Node),
    VersionStatus = maps:get(status, Version),
    VersionReason = maps:get(reason, Version),
    Badge = maps:get(badge, Node),
    BadgeStatus = case maps:get(state, Badge) of
                      badge_mismatch -> update_required;
                      _ -> up_to_date
                  end,
    BadgeReasons = case BadgeStatus of
                       update_required -> [badge_mismatch];
                       up_to_date -> []
                   end,
    Status = case {VersionStatus, BadgeStatus} of
                 {insufficient_local_data, _} -> insufficient_local_data;
                 {_, insufficient_local_data} -> insufficient_local_data;
                 {update_required, _} -> update_required;
                 {_, update_required} -> update_required;
                 _ -> up_to_date
             end,
    {Status, [VersionReason | BadgeReasons]}.

status_from_graph([]) ->
    none;
status_from_graph(_GraphReasons) ->
    insufficient_local_data.

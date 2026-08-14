-module(rebar3_reltree_scan_tests).

-include_lib("eunit/include/eunit.hrl").

shallow_root_and_deep_descendant_test() ->
    Workspace = rebar3_reltree_fixtures:new_root(),
    try
        Current = filename:join(Workspace, "current"),
        Direct = filename:join(Workspace, "direct"),
        Nested = filename:join([Workspace, "nested", "project"]),
        ok = file:make_dir(Current),
        ok = file:make_dir(Direct),
        ok = file:make_dir(filename:join(Workspace, "nested")),
        ok = file:make_dir(Nested),
        rebar3_reltree_fixtures:write_project(Current, current, [], "0.1.0"),
        rebar3_reltree_fixtures:write_project(Direct, direct, [], "0.1.0"),
        rebar3_reltree_fixtures:write_project(Nested, nested, [], "0.1.0"),
        {Shallow, []} = rebar3_reltree_scan:catalog(
            Current, [{Workspace, shallow}]
        ),
        ?assert(maps:is_key(Direct, Shallow)),
        ?assertNot(maps:is_key(Nested, Shallow)),
        {Deep, []} = rebar3_reltree_scan:catalog(Current, [{Workspace, deep}]),
        ?assert(maps:is_key(Nested, Deep))
    after
        rebar3_reltree_fixtures:cleanup(Workspace)
    end.

explicit_root_is_examined_before_shallow_children_test() ->
    Workspace = rebar3_reltree_fixtures:new_root(),
    try
        RootProject = filename:join(Workspace, "root-project"),
        ChildProject = filename:join(RootProject, "child-project"),
        ok = file:make_dir(RootProject),
        rebar3_reltree_fixtures:write_project(
            RootProject, root_project, [], "0.1.0"
        ),
        ok = file:make_dir(ChildProject),
        rebar3_reltree_fixtures:write_project(
            ChildProject, child_project, [], "0.1.0"
        ),
        {Catalog, []} = rebar3_reltree_scan:catalog(
            RootProject, [{RootProject, shallow}]
        ),
        ?assert(
            maps:is_key(
                rebar3_reltree_fs:canonical(RootProject),
                Catalog
            )
        ),
        ?assert(
            maps:is_key(
                rebar3_reltree_fs:canonical(ChildProject),
                Catalog
            )
        ),
        ?assertEqual(2, length(maps:keys(Catalog)))
    after
        rebar3_reltree_fixtures:cleanup(Workspace)
    end.

skipped_directories_and_scan_symlink_warning_test() ->
    Workspace = rebar3_reltree_fixtures:new_root(),
    try
        Current = filename:join(Workspace, "current"),
        Hidden = filename:join([Workspace, "_build", "hidden"]),
        Node = filename:join([Workspace, "node_modules", "node"]),
        ok = file:make_dir(Current),
        ok = file:make_dir(filename:join(Workspace, "_build")),
        ok = file:make_dir(Hidden),
        ok = file:make_dir(filename:join(Workspace, "node_modules")),
        ok = file:make_dir(Node),
        rebar3_reltree_fixtures:write_project(Current, current, [], "0.1.0"),
        rebar3_reltree_fixtures:write_project(Hidden, hidden, [], "0.1.0"),
        rebar3_reltree_fixtures:write_project(Node, node, [], "0.1.0"),
        Link = filename:join(Workspace, "scan-link"),
        ok = file:make_symlink(Current, Link),
        {Catalog, Warnings} = rebar3_reltree_scan:catalog(
            Current, [{Workspace, deep}, {Link, shallow}]
        ),
        ?assertNot(maps:is_key(Hidden, Catalog)),
        ?assertNot(maps:is_key(Node, Catalog)),
        ?assert(lists:any(fun(W) -> maps:get(reason, W) =:= scan_root_skipped end, Warnings))
    after
        rebar3_reltree_fixtures:cleanup(Workspace)
    end.

current_project_is_retained_when_scan_roots_are_empty_test() ->
    Workspace = rebar3_reltree_fixtures:new_root(),
    try
        Current = filename:join(Workspace, "current"),
        ok = file:make_dir(Current),
        rebar3_reltree_fixtures:write_project(Current, current, [], "0.1.0"),
        {Catalog, []} = rebar3_reltree_scan:catalog(Current, []),
        ?assertEqual(
            [rebar3_reltree_fs:canonical(Current)],
            maps:keys(Catalog)
        ),
        ?assertEqual(
            current,
            maps:get(
                kind,
                hd(
                    maps:get(
                        sources,
                        maps:get(Current, Catalog)
                    )
                )
            )
        )
    after
        rebar3_reltree_fixtures:cleanup(Workspace)
    end.

repeated_roots_merge_sources_once_test() ->
    Workspace = rebar3_reltree_fixtures:new_root(),
    try
        Current = filename:join(Workspace, "current"),
        ok = file:make_dir(Current),
        rebar3_reltree_fixtures:write_project(Current, current, [], "0.1.0"),
        {Catalog, []} = rebar3_reltree_scan:catalog(
            Current, [{Workspace, deep}, {Workspace, deep}]
        ),
        Sources = maps:get(sources, maps:get(Current, Catalog)),
        ?assertEqual(length(Sources), length(lists:usort(Sources))),
        ?assertEqual(1, length(maps:keys(Catalog)))
    after
        rebar3_reltree_fixtures:cleanup(Workspace)
    end.

physical_aliases_deduplicate_candidates_before_insertion_test() ->
    Workspace = rebar3_reltree_fixtures:new_root(),
    try
        Current = filename:join(Workspace, "current"),
        Holder = filename:join(Workspace, "holder"),
        ok = file:make_dir(Current),
        ok = file:make_dir(Holder),
        rebar3_reltree_fixtures:write_project(Current, current, [], "0.1.0"),
        AliasRoot = filename:join([Workspace, "holder", ".."]),
        {Catalog, []} = rebar3_reltree_scan:catalog(
            Current, [
                {Workspace, shallow},
                {AliasRoot, deep}
            ]
        ),
        ?assertEqual(
            [rebar3_reltree_fs:canonical(Current)],
            maps:keys(Catalog)
        ),
        Sources = maps:get(sources, maps:get(Current, Catalog)),
        ?assert(
            lists:any(
                fun
                    (#{kind := scan, mode := shallow}) -> true;
                    (_) -> false
                end,
                Sources
            )
        ),
        ?assert(
            lists:any(
                fun
                    (#{kind := scan, mode := deep}) -> true;
                    (_) -> false
                end,
                Sources
            )
        )
    after
        rebar3_reltree_fixtures:cleanup(Workspace)
    end.

all_reserved_scan_directories_are_skipped_test() ->
    Workspace = rebar3_reltree_fixtures:new_root(),
    try
        Current = filename:join(Workspace, "current"),
        ok = file:make_dir(Current),
        rebar3_reltree_fixtures:write_project(Current, current, [], "0.1.0"),
        lists:foreach(
            fun(Name) ->
                Dir = filename:join(Workspace, Name),
                ok = file:make_dir(Dir),
                Hidden = filename:join(Dir, "hidden"),
                ok = file:make_dir(Hidden),
                rebar3_reltree_fixtures:write_project(
                    Hidden, hidden, [], "0.1.0"
                )
            end,
            [".git", "_build", "_checkouts", "node_modules"]
        ),
        {Catalog, []} = rebar3_reltree_scan:catalog(
            Current, [{Workspace, deep}]
        ),
        ?assertEqual(1, length(maps:keys(Catalog))),
        ?assertNot(
            lists:any(
                fun(Path) ->
                    lists:member(
                        filename:basename(Path),
                        [
                            ".git",
                            "_build",
                            "_checkouts",
                            "node_modules"
                        ]
                    )
                end,
                maps:keys(Catalog)
            )
        )
    after
        rebar3_reltree_fixtures:cleanup(Workspace)
    end.

missing_and_file_scan_roots_warn_and_continue_test() ->
    Workspace = rebar3_reltree_fixtures:new_root(),
    try
        Current = filename:join(Workspace, "current"),
        FileRoot = filename:join(Workspace, "not-a-directory"),
        ok = file:make_dir(Current),
        rebar3_reltree_fixtures:write_project(Current, current, [], "0.1.0"),
        ok = file:write_file(FileRoot, <<"file">>),
        Missing = filename:join(Workspace, "missing"),
        {Catalog, Warnings} = rebar3_reltree_scan:catalog(
            Current, [
                {Missing, shallow},
                {FileRoot, shallow}
            ]
        ),
        ?assert(maps:is_key(Current, Catalog)),
        ?assertEqual(
            2,
            length([
                W
             || W <- Warnings,
                maps:get(reason, W) =:= scan_root_skipped
            ])
        )
    after
        rebar3_reltree_fixtures:cleanup(Workspace)
    end.

unreadable_explicit_root_warns_once_without_candidate_test() ->
    case running_as_root() of
        true ->
            ok;
        false ->
            unreadable_explicit_root_warns_once_without_candidate()
    end.

unreadable_explicit_root_warns_once_without_candidate() ->
    Workspace = rebar3_reltree_fixtures:new_root(),
    try
        Current = filename:join(Workspace, "current"),
        Unreadable = filename:join(Workspace, "unreadable"),
        ok = file:make_dir(Current),
        ok = file:make_dir(Unreadable),
        rebar3_reltree_fixtures:write_project(Current, current, [], "0.1.0"),
        rebar3_reltree_fixtures:write_project(
            Unreadable, unreadable, [], "0.1.0"
        ),
        ok = file:change_mode(Unreadable, 0),
        {Catalog, Warnings} = rebar3_reltree_scan:catalog(
            Current, [{Unreadable, shallow}]
        ),
        ?assertNot(
            maps:is_key(
                rebar3_reltree_fs:canonical(Unreadable),
                Catalog
            )
        ),
        ?assertEqual(1, length(Warnings)),
        ?assertEqual(scan_root_skipped, maps:get(reason, hd(Warnings)))
    after
        _ = file:change_mode(filename:join(Workspace, "unreadable"), 8#755),
        rebar3_reltree_fixtures:cleanup(Workspace)
    end.

running_as_root() ->
    case os:type() of
        {unix, _} -> string:trim(os:cmd("id -u")) =:= "0";
        _ -> false
    end.

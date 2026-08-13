-module(rebar3_reltree_rev_tests).

-include_lib("eunit/include/eunit.hrl").

source_shapes_and_selectors_are_normalized_test() ->
    {ok, Head} = rebar3_reltree_rev:classify({dep, {git, "url"}}),
    ?assertEqual("url", maps:get(source_url, Head)),
    ?assertEqual(#{kind => head, value => "HEAD"},
                 maps:get(selector, Head)),
    {ok, Branch} = rebar3_reltree_rev:classify(
                     {dep, "1.0", {git, <<"url">>, {branch, <<"main">>}}}),
    ?assertEqual(#{kind => branch, value => "main"},
                 maps:get(selector, Branch)),
    ?assertEqual({ok, not_applicable},
                 rebar3_reltree_rev:classify({dep, "1.0"})),
    ?assertMatch({error, _},
                 rebar3_reltree_rev:classify({dep, {git, ""}})),
    ?assertMatch({error, invalid_git_selector},
                 rebar3_reltree_rev:classify(
                   {dep, {git, "url", {branch, ""}}})),
    ?assertEqual({error, invalid_git_url},
                 rebar3_reltree_rev:classify({dep, {git, [16#d800]}})),
    ?assertEqual({error, invalid_git_url},
                 rebar3_reltree_rev:classify({dep, {git, [16#110000]}})),
    ?assertEqual({error, invalid_git_selector},
                 rebar3_reltree_rev:classify(
                   {dep, {git, "url", {branch, [16#d800]}}})).

unsupported_git_shapes_are_invalid_without_lookup_test() ->
    ?assertEqual({error, unsupported_git_source},
                 rebar3_reltree_rev:classify(
                   {dep, "1.0", {git, "url", {branch, "main"}, extra}})),
    ?assertEqual({error, unsupported_git_source},
                 rebar3_reltree_rev:classify(
                   {dep, "1.0", {git, "url"}, extra})),
    ?assertEqual({error, unsupported_git_source},
                 rebar3_reltree_rev:classify(
                   {dep, "1.0", extra, {git, "url"}})),
    Declaration = {dep, "1.0", {git, "file:///repo"}, extra},
    Output = output_path(),
    try
        erase(lookup_count),
        {ok, Disabled} = rebar3_reltree_rev:enrich(
                           model([node("/tmp/owner", [Declaration], #{})]),
                           [], false, Output, #{lookup => counted_lookup()}),
        [DisabledFact] = maps:get(revision_declarations,
                                  hd(maps:get(nodes, Disabled))),
        ?assertEqual(tracking_disabled,
                     maps:get(revision_state, DisabledFact)),
        ?assertEqual([], maps:get(warnings, Disabled)),
        ?assertEqual(0, get_count()),
        {ok, Missing} = rebar3_reltree_rev:enrich(
                          model([node("/tmp/owner", [Declaration], #{})]),
                          [], auto, Output, #{lookup => counted_lookup()}),
        [MissingFact] = maps:get(revision_declarations,
                                 hd(maps:get(nodes, Missing))),
        ?assertEqual(missing, maps:get(revision_state, MissingFact)),
        ?assertEqual([external_revision_invalid],
                     [maps:get(reason, Warning) ||
                      Warning <- maps:get(warnings, Missing)]),
        ?assertEqual([external_revision_missing],
                     maps:get(revision_reasons, Missing)),
        ?assertEqual(0, get_count())
    after
        rebar3_reltree_fixtures:cleanup(output_root(Output))
    end.

local_checkout_wins_in_every_mode_test() ->
    Owner = "/tmp/reltree-rev-owner",
    Target = "/tmp/reltree-rev-target",
    Declaration = {dep, {git, "file:///should-not-be-used"}},
    Node = node(Owner, [Declaration], #{dep => local_checkout}),
    TargetNode = node(Target, [], #{}),
    Edge = #{source => Owner, target => Target, dependency => dep,
             declaration => Declaration},
    Output = output_path(),
    try
        lists:foreach(
          fun(Mode) ->
                  erase(lookup_count),
                  {ok, Model} = rebar3_reltree_rev:enrich(
                                   model([Node, TargetNode]), [Edge], Mode,
                                   Output, #{lookup => counted_lookup()}),
                  [Fact] = maps:get(revision_declarations, hd(
                                      maps:get(nodes, Model))),
                  ?assertEqual(local_checkout,
                               maps:get(revision_state, Fact)),
                  ?assertEqual(
                    "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
                    maps:get(resolved_revision, Fact)),
                  ?assertEqual(0, get_count())
          end, [false, auto, true])
    after
        rebar3_reltree_fixtures:cleanup(output_root(Output))
    end.

false_disables_without_read_or_lookup_test() ->
    Output = output_path(),
    ok = file:write_file(Output, <<"malformed prior">>),
    try
        Declaration = {dep, {git, "file:///repo"}},
        {ok, Model} = rebar3_reltree_rev:enrich(
                        model([node("/tmp/owner", [Declaration], #{})]), [],
                        false, Output, #{lookup => counted_lookup()}),
        [Fact] = maps:get(revision_declarations, hd(maps:get(nodes, Model))),
        ?assertEqual(tracking_disabled, maps:get(revision_state, Fact)),
        ?assertEqual([], maps:get(warnings, Model)),
        ?assertEqual(0, get_count())
    after
        _ = file:delete(Output)
    end.

auto_reuses_exact_v2_prior_and_true_does_not_test() ->
    Output = output_path(),
    Declaration = {dep, {git, "file:///repo", {branch, "main"}}},
    Base = model([node("/tmp/owner", [Declaration], #{})]),
    Options = #{lookup => counted_lookup(),
                clock => fun() -> {{2020, 1, 2}, {3, 4, 5}} end},
    try
        erase(lookup_count),
        {ok, First} = rebar3_reltree_rev:enrich(Base, [], auto, Output,
                                                Options),
        ?assertEqual(1, get_count()),
        ReportModel = First#{status => up_to_date,
                             local_sync_at => "2020-01-02T03:04:05Z"},
        {ok, Bytes} = rebar3_reltree_report:render(ReportModel),
        {ok, Output} = rebar3_reltree_fs:atomic_write(Output, Bytes, #{}),
        erase(lookup_count),
        {ok, Second} = rebar3_reltree_rev:enrich(Base, [], auto, Output,
                                                 Options),
        ?assertEqual([], maps:get(warnings, Second)),
        [Reused] = maps:get(revision_declarations,
                            hd(maps:get(nodes, Second))),
        ?assertEqual(reused, maps:get(revision_state, Reused)),
        ?assertEqual(0, get_count()),
        erase(lookup_count),
        {ok, TrueModel} = rebar3_reltree_rev:enrich(Base, [], true, Output,
                                                    Options),
        [Resolved] = maps:get(revision_declarations,
                              hd(maps:get(nodes, TrueModel))),
        ?assertEqual(resolved, maps:get(revision_state, Resolved)),
        ?assertEqual(1, get_count())
    after
        rebar3_reltree_fixtures:cleanup(output_root(Output))
    end.

duplicate_prior_records_fold_and_reuse_twice_test() ->
    Output = output_path(),
    Declaration = {dep, {git, "file:///repo"}},
    Revision = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    Time = "2020-01-02T03:04:05Z",
    Fact = resolved_fact("/tmp/owner", dep, Declaration, Revision, Time),
    DisplayVariant = Fact#{declaration =>
                             {dep, "1.0", {git, "file:///repo"}}},
    DuplicateNode = (node("/tmp/owner", [Declaration], #{}))#{
        revision_declarations => [Fact, DisplayVariant]},
    ReportModel = (model([DuplicateNode]))#{status => up_to_date,
                                          network_sync_at => Time},
    try
        {ok, Bytes} = rebar3_reltree_report:render(ReportModel),
        {ok, Output} = rebar3_reltree_fs:atomic_write(Output, Bytes, #{}),
        {ok, #{entries := Entries}} =
            rebar3_reltree_rev:parse_prior(Bytes),
        ?assertEqual(1, maps:size(Entries)),
        Base = model([node("/tmp/owner", [Declaration], #{})]),
        Options = #{lookup => counted_lookup(),
                    clock => fun() -> {{2020, 1, 2}, {3, 4, 5}} end},
        erase(lookup_count),
        {ok, First} = rebar3_reltree_rev:enrich(
                        Base, [], auto, Output, Options),
        ?assertEqual(0, get_count()),
        [FirstFact] = maps:get(revision_declarations,
                               hd(maps:get(nodes, First))),
        ?assertEqual(reused, maps:get(revision_state, FirstFact)),
        erase(lookup_count),
        {ok, Second} = rebar3_reltree_rev:enrich(
                         Base, [], auto, Output, Options),
        ?assertEqual(0, get_count()),
        [SecondFact] = maps:get(revision_declarations,
                                hd(maps:get(nodes, Second))),
        ?assertEqual(reused, maps:get(revision_state, SecondFact)),
        Conflict = Fact#{network_sync_at => "2020-01-02T03:04:06Z"},
        ConflictNode = (node("/tmp/owner", [Declaration], #{}))#{
            revision_declarations => [Fact, Conflict]},
        {ok, ConflictBytes} = rebar3_reltree_report:render(
                                (model([ConflictNode]))#{
                                  status => up_to_date,
                                  network_sync_at => Time}),
        ?assertEqual({error, duplicate_identity},
                     rebar3_reltree_rev:parse_prior(ConflictBytes))
    after
        rebar3_reltree_fixtures:cleanup(output_root(Output))
    end.

prior_path_backslash_round_trip_test() ->
    Output = output_path(),
    Path = "/tmp/reltree\\owner",
    Declaration = {dep, {git, "file:///repo"}},
    Revision = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    Time = "2020-01-02T03:04:05Z",
    Fact = resolved_fact(Path, dep, Declaration, Revision, Time),
    Node = (node(Path, [Declaration], #{}))#{revision_declarations => [Fact]},
    ReportModel = (model([Node]))#{current => Path,
                                 current_name => "owner",
                                 network_sync_at => Time},
    try
        {ok, Bytes} = rebar3_reltree_report:render(ReportModel),
        {ok, #{entries := Entries}} = rebar3_reltree_rev:parse_prior(Bytes),
        Identity = {rebar3_reltree_fs:canonical(Path), "dep", "file:///repo",
                    head, "HEAD"},
        Record = maps:get(Identity, Entries),
        ?assertEqual(rebar3_reltree_fs:canonical(Path),
                     maps:get(owner, Record)),
        ?assertEqual("dep", maps:get(name, Record))
    after
        rebar3_reltree_fixtures:cleanup(output_root(Output))
    end.

stale_and_missing_revisions_lower_status_reasons_test() ->
    Declaration = {dep, {git, "file:///repo"}},
    Base = model([node("/tmp/owner", [Declaration], #{})]),
    Prior = #{lookup => counted_lookup(),
              clock => fun() -> {{2020, 1, 2}, {3, 4, 5}} end},
    Output = output_path(),
    {ok, Resolved} = rebar3_reltree_rev:enrich(Base, [], true, Output, Prior),
    [Good] = maps:get(revision_declarations, hd(maps:get(nodes, Resolved))),
    ReportModel = Resolved#{status => up_to_date,
                            local_sync_at => "2020-01-02T03:04:05Z"},
    {ok, Bytes0} = rebar3_reltree_report:render(ReportModel),
    %% A valid stale prior record is deliberately not reusable, so the next
    %% auto run must attempt the lookup before retaining its old revision.
    Bytes = binary:replace(Bytes0, <<"revision_state: resolved">>,
                           <<"revision_state: stale">>, [global]),
    {ok, Output} = rebar3_reltree_fs:atomic_write(Output, Bytes, #{}),
    Failed = Prior#{lookup => fun(_Url, _Selector) -> {error, timeout} end,
                    clock => fun() -> {{2020, 1, 2}, {3, 4, 6}} end},
    {ok, Stale0} = rebar3_reltree_rev:enrich(Base, [], auto, Output, Failed),
    [Stale] = maps:get(revision_declarations, hd(maps:get(nodes, Stale0))),
    ?assertEqual(stale, maps:get(revision_state, Stale)),
    ?assertEqual([external_revision_stale],
                 maps:get(revision_reasons, Stale0)),
    ?assertEqual(maps:get(resolved_revision, Good),
                 maps:get(resolved_revision, Stale)),
    rebar3_reltree_fixtures:cleanup(output_root(Output)).

legacy_and_malformed_prior_are_bounded_test() ->
    ?assertEqual({error, unsupported_version},
                 rebar3_reltree_rev:parse_prior(
                   <<"# reltree project\n- format_version: 1\n">>)),
    ?assertMatch({error, _},
                 rebar3_reltree_rev:parse_prior(
                   <<"# reltree project\n- format_version: 2\n"
                     "  - name: bad\n">>)),
    ?assertMatch({error, oversized},
                 rebar3_reltree_rev:parse_prior(binary:copy(<<$x>>, 4194305))).

prior_state_field_combinations_are_strict_test() ->
    Revision = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    Time = "2020-01-02T03:04:05Z",
    Valid = [
        {"resolved", "file:///repo", "head", "HEAD", Revision, Time, Time},
        {"reused", "file:///repo", "head", "HEAD", Revision, Time, Time},
        {"stale", "file:///repo", "head", "HEAD", Revision, Time, Time},
        {"missing", "file:///repo", "head", "HEAD", "none",
         "not-performed", Time},
        {"missing", "none", "none", "none", "none", "not-performed",
         "not-performed"},
        {"tracking-disabled", "file:///repo", "head", "HEAD", "none",
         "not-performed", "not-performed"},
        {"tracking-disabled", "none", "none", "none", "none",
         "not-performed", "not-performed"},
        {"not-applicable", "none", "none", "none", "none",
         "not-performed", "not-performed"}],
    lists:foreach(fun(Fields) ->
                          ?assertMatch({ok, #{entries := _}},
                                       parse_record(Fields))
                  end, Valid),
    Invalid = [
        {"resolved", "file:///repo", "head", "HEAD", "none", Time, Time},
        {"reused", "file:///repo", "head", "HEAD", Revision,
         "not-performed", Time},
        {"stale", "file:///repo", "head", "HEAD", "none", Time, Time},
        {"missing", "file:///repo", "head", "HEAD", Revision,
         "not-performed", Time},
        {"not-applicable", "file:///repo", "head", "HEAD", "none",
         "not-performed", "not-performed"}],
    lists:foreach(fun(Fields) ->
                          ?assertMatch({error, malformed_record},
                                       parse_record(Fields))
                  end, Invalid).

local_bare_git_lookup_selectors_test() ->
    Root = rebar3_reltree_fixtures:new_root(),
    Work = filename:join(Root, "work"),
    Bare = filename:join(Root, "bare.git"),
    ok = file:make_dir(Work),
    try
        {ok, _} = git_fixture_command(Work, ["init", "-q"]),
        {ok, _} = git_fixture_command(Work, ["config", "user.email",
                                             "reltree@example.invalid"]),
        {ok, _} = git_fixture_command(Work, ["config", "user.name",
                                             "reltree fixture"]),
        ok = file:write_file(filename:join(Work, "README"), <<"fixture\n">>),
        {ok, _} = git_fixture_command(Work, ["add", "README"]),
        {ok, _} = git_fixture_command(Work, ["commit", "-qm", "fixture"]),
        {ok, Head0} = git_fixture_command(Work, ["rev-parse", "HEAD"]),
        Head = binary_to_list(string:trim(Head0)),
        {ok, _} = git_fixture_command(Work, ["tag", "light"]),
        {ok, _} = git_fixture_command(Work, ["tag", "-a", "annotated",
                                             "-m", "annotated"]),
        {ok, _} = git_fixture_command(Root, ["clone", "--bare", Work, Bare]),
        {ok, _} = git_fixture_command(
                    Bare, ["config", "--remove-section", "remote.origin"]),
        Url = filename:absname(Bare),
        {ok, Head} = rebar3_reltree_git:lookup(
                       Url, #{kind => head, value => "HEAD"}, #{}),
        {ok, Head} = rebar3_reltree_git:lookup(
                       Url, #{kind => branch, value => "master"}, #{}),
        {ok, Head} = rebar3_reltree_git:lookup(
                       Url, #{kind => tag, value => "light"}, #{}),
        {ok, Annotated0} = git_fixture_command(
                            Work, ["rev-parse", "refs/tags/annotated^{}"]),
        Annotated = binary_to_list(string:trim(Annotated0)),
        {ok, Annotated} = rebar3_reltree_git:lookup(
                            Url, #{kind => tag, value => "annotated"}, #{}),
        {ok, Head} = rebar3_reltree_git:lookup(
                       Url, #{kind => ref, value => "refs/heads/master"}, #{}),
        ?assertMatch({error, no_matching_revision},
                     rebar3_reltree_git:lookup(
                       Url, #{kind => branch, value => "missing"}, #{})),
        {ok, Rows} = rebar3_reltree_git:command(
                       "/", ["ls-remote", "--", Url], #{}),
        ?assert(binary:match(Rows, <<"refs/heads/master">>) =/= nomatch),
        ?assert(binary:match(Rows, <<"refs/tags/annotated^{}">>) =/= nomatch),
        ?assertMatch({error, {exit, 1, _}},
                     rebar3_reltree_git:command(
                       Bare, ["config", "--get-regexp", "^remote\\."], #{}))
    after
        rebar3_reltree_fixtures:cleanup(Root)
    end.

fixed_argv_and_bounded_git_output_test() ->
    Root = rebar3_reltree_fixtures:new_root(),
    Bin = filename:join(Root, "bin"),
    Script = filename:join(Bin, "git"),
    Log = filename:join(Root, "argv.log"),
    ok = file:make_dir(Bin),
    OldPath = os:getenv("PATH"),
    ScriptText = lists:flatten(io_lib:format(
      "#!/bin/sh\nprintf '%s\\n' \"$@\" > '~s'\n"
      "case \"$3\" in malformed) printf 'broken\\n' ;; "
      "*) printf 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\\tHEAD\\n' ;; esac\n",
      [Log])),
    ok = file:write_file(Script, ScriptText),
    ok = file:change_mode(Script, 8#755),
    try
        true = os:putenv("PATH", Bin ++ ":" ++ OldPath),
        ?assertEqual({ok, "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"},
                     rebar3_reltree_git:lookup(
                       "good", #{kind => head, value => "HEAD"}, #{})),
        {ok, Args} = file:read_file(Log),
        ?assertEqual(<<"ls-remote\n--\ngood\n">>, Args),
        ?assertEqual({error, malformed_output},
                     rebar3_reltree_git:lookup(
                       "malformed", #{kind => head, value => "HEAD"}, #{}))
    after
        restore_path(OldPath),
        rebar3_reltree_fixtures:cleanup(Root)
    end.

duplicate_identity_shares_lookup_test() ->
    Declaration = {dep, {git, "file:///repo"}},
    erase(lookup_count),
    {ok, Model} = rebar3_reltree_rev:enrich(
                    model([node("/tmp/owner", [Declaration, Declaration],
                                #{})]), [], true, output_path(),
                    #{lookup => counted_lookup(),
                      clock => fun() -> {{2020, 1, 2}, {3, 4, 5}} end}),
    Facts = maps:get(revision_declarations, hd(maps:get(nodes, Model))),
    ?assertEqual(2, length(Facts)),
    ?assertEqual([resolved, resolved],
                 [maps:get(revision_state, Fact) || Fact <- Facts]),
    ?assertEqual(1, get_count()).

node(Path, Deps, Relationships) ->
    #{path => Path, name => filename:basename(Path), app => app,
      app_vsn => "0.1.0", app_src => filename:join(Path, "app.app.src"),
      head => "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
      version => #{highest_formal => none, reason => no_formal_tag,
                   formal_tags => [], prerelease_tags => []},
      readme => #{readme => false, readme_zh => false}, ci_workflow => false,
      badge => #{state => skip_no_ci}, dependencies => Deps,
      dependency_relationships => Relationships, project_plugins => [],
      plugins => []}.

model(Nodes) ->
    #{format_version => 2, current => "/tmp/owner", current_name => owner,
      status => up_to_date, local_sync_at => "2020-01-02T03:04:05Z",
      nodes => Nodes, edges => [], warnings => [],
      local_only_caveats => []}.

resolved_fact(Owner, Name, Declaration, Revision, Time) ->
    #{owner => Owner, name => Name, declaration => Declaration,
      relationship => external, revision_state => resolved,
      source_url => "file:///repo", selector_kind => head,
      selector_value => "HEAD", resolved_revision => Revision,
      revision_observed_at => Time, network_sync_at => Time}.

output_path() ->
    Root = filename:join("/tmp", "reltree-rev-tests-" ++
                         integer_to_list(erlang:unique_integer([positive]))),
    ok = filelib:ensure_dir(filename:join(Root, "reltree/project.md")),
    filename:join(Root, "reltree/project.md").

output_root(Output) ->
    filename:dirname(filename:dirname(Output)).

parse_record({State, Url, Kind, Value, Revision, Observed, Network}) ->
    rebar3_reltree_rev:parse_prior(iolist_to_binary([
      "# reltree project\n- format_version: 2\n",
      "- path: /tmp/current\n",
      "  - name: external; declaration: {git, \"file:///repo\"} ",
      "; relationship: external; revision_state: ", State, "\n",
      "    source_url: ", Url, "\n",
      "    selector_kind: ", Kind, "\n",
      "    selector_value: ", Value, "\n",
      "    resolved_revision: ", Revision, "\n",
      "    revision_observed_at: ", Observed, "\n",
      "    network_sync_at: ", Network, "\n"])) .

git_fixture_command(Directory, Args) ->
    rebar3_reltree_git:command(Directory, Args, #{}).

restore_path(false) -> ok;
restore_path(Path) -> os:putenv("PATH", Path).

counted_lookup() ->
    fun(_Url, _Selector) ->
            put(lookup_count, get_count() + 1),
            {ok, "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}
    end.

get_count() ->
    case get(lookup_count) of undefined -> 0; Count -> Count end.

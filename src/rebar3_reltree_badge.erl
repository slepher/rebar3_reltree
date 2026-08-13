-module(rebar3_reltree_badge).

-include_lib("kernel/include/file.hrl").

-export([run/1, run/2, format_result/1, format_error/1]).

-spec run(map()) -> {ok, map()} | {error, term()}.
run(Request) ->
    run(Request, #{}).

-spec run(map(), map()) -> {ok, map()} | {error, term()}.
run(#{project_root := ProjectRoot, mode := Mode} = Request, Options)
  when (Mode =:= check orelse Mode =:= write), is_map(Options) ->
    RunOptions = Options#{tag => maps:get(tag, Request,
                                          maps:get(tag, Options, false))},
    Workflow = filename:join(ProjectRoot, ".github/workflows/ci.yml"),
    case read_workflow(Workflow, RunOptions) of
        absent ->
            {ok, #{status => skipped_no_workflow,
                   warnings => [#{code => skip_no_workflow,
                                  path => ".github/workflows/ci.yml"}]}};
        {error, _} = Error ->
            Error;
        present ->
            run_with_workflow(ProjectRoot, Mode, RunOptions)
    end;
run(_Request, _Options) ->
    {error, {invalid_mode, request}}.

-spec format_result(map()) -> iolist().
format_result(#{warnings := Warnings}) ->
    [format_warning(Warning) || Warning <- Warnings];
format_result(_Result) ->
    [].

-spec format_error(term()) -> iolist().
format_error({workflow_read, Path, Reason}) ->
    io_lib:format("workflow_read: ~ts: ~ts", [Path, reason_text(Reason)]);
format_error({workflow_invalid, Path, Reason}) ->
    io_lib:format("workflow_invalid: ~ts: ~ts", [Path, reason_text(Reason)]);
format_error({git_repository, Path, Reason}) ->
    io_lib:format("git_repository: ~ts: ~ts", [Path, reason_text(Reason)]);
format_error({git_origin, Path, Reason}) ->
    io_lib:format("git_origin: ~ts: ~ts", [Path, reason_text(Reason)]);
format_error({git_tags, Path, Reason}) ->
    io_lib:format("git_tags: ~ts: ~ts", [Path, reason_text(Reason)]);
format_error({readme_read, Path, Reason}) ->
    io_lib:format("readme_read: ~ts: ~ts", [Path, reason_text(Reason)]);
format_error({readme_invalid, Path, Reason}) ->
    io_lib:format("readme_invalid: ~ts: ~ts", [Path, reason_text(Reason)]);
format_error(no_app_src) ->
    "no app.src file found";
format_error(multiple_app_src) ->
    "multiple app.src files found";
format_error(invalid_app_vsn) ->
    "app.src has an invalid or missing vsn";
format_error(ambiguous_app_vsn) ->
    "app.src has multiple vsn values";
format_error({app_src_directory, Path}) ->
    io_lib:format("unable to read app.src directory: ~ts", [Path]);
format_error({app_src_directory_read, Path, Reason}) ->
    io_lib:format("unable to read app.src directory: ~ts (~ts)",
                  [Path, reason_text(Reason)]);
format_error({app_src_read, Path, Reason}) ->
    io_lib:format("unable to read app.src: ~ts (~ts)",
                  [Path, reason_text(Reason)]);
format_error({invalid_app_src_term, Terms}) ->
    io_lib:format("app.src has an invalid application term: ~ts",
                  [bounded_term(Terms)]);
format_error({badge_mismatch, Failures}) ->
    ["badge_mismatch: ", format_failures(Failures)];
format_error({equivalent_formal_tags, Tags}) ->
    io_lib:format("equivalent_formal_tags: ~ts", [string:join(Tags, ", ")]);
format_error({readme_write, Path, Stage, Reason}) ->
    io_lib:format("readme_write: ~ts (~p): ~ts",
                  [Path, Stage, reason_text(Reason)]);
format_error(Reason) ->
    io_lib:format("bgate_failed: ~ts", [reason_text(Reason)]).

run_with_workflow(ProjectRoot, Mode, Options) ->
    case git_facts(ProjectRoot, Options) of
        {error, _} = Error ->
            Error;
        {ok, #{repo := Repo, formal_tags := FormalTags}} ->
            case Mode of
                check ->
                    case tag_policy(FormalTags) of
                        {error, _} ->
                            run_readme_mode(ProjectRoot, Mode, Repo,
                                            FormalTags,
                                            #{release => equivalent,
                                              tags => equivalent_tags_list(
                                                       FormalTags)},
                                            Options);
                        {ok, Policy} ->
                            run_readme_mode(ProjectRoot, Mode, Repo,
                                            FormalTags, Policy, Options)
                    end;
                write ->
                    case write_policy(ProjectRoot, Options) of
                        {ok, Policy} ->
                            run_readme_mode(ProjectRoot, Mode, Repo,
                                            FormalTags, Policy, Options);
                        {error, _} = Error ->
                            Error
                    end
            end
    end.

write_policy(ProjectRoot, Options) ->
    case maps:get(tag, Options, false) of
        true ->
            case rebar3_reltree_config:app_identity(ProjectRoot) of
                {ok, #{app_vsn := AppVsn}} ->
                    {ok, #{release => {tag, AppVsn}}};
                {error, _} = Error ->
                    Error
            end;
        _ ->
            {ok, #{release => none}}
    end.

run_readme_mode(ProjectRoot, check, Repo, FormalTags, Policy, Options) ->
    case read_readmes(ProjectRoot, Options) of
        {error, _} = Error ->
            Error;
        {ok, Files} ->
            Expected = expected(Repo, FormalTags, Policy),
            Results = [{File, check_file(File, Expected)} || File <- Files],
            case check_results(Results, Policy) of
                ok ->
                    {ok, #{status => checked,
                           warnings => policy_warnings(Policy)}};
                {error, _} = Error ->
                    Error
            end
    end;
run_readme_mode(ProjectRoot, write, Repo, FormalTags, Policy, Options) ->
    case read_readmes(ProjectRoot, Options) of
        {error, _} = Error ->
            Error;
        {ok, Files} ->
            Expected = expected(Repo, FormalTags, Policy),
            Transformed = [{File, transform_file(File, Expected)} ||
                           File <- Files],
            case write_files(Transformed, Options) of
                ok ->
                    {ok, #{status => written,
                           warnings => policy_warnings(Policy)}};
                {error, _} = Error ->
                    Error
            end
    end.

read_workflow(Path, Options) ->
    case fs_call(read_link_info, [Path], Options) of
        {error, enoent} ->
            absent;
        {error, {enoent, _}} ->
            absent;
        {ok, #file_info{type = regular}} ->
            case fs_call(read_file, [Path], Options) of
                {ok, Content} when is_binary(Content) -> present;
                {ok, _Other} ->
                    {error, {workflow_invalid, Path, non_binary_data}};
                {error, Reason} ->
                    {error, {workflow_read, Path, Reason}}
            end;
        {ok, #file_info{type = Type}} ->
            {error, {workflow_invalid, Path, {not_regular, Type}}};
        {error, Reason} ->
            {error, {workflow_read, Path, Reason}}
    end.

git_facts(ProjectRoot, Options) ->
    case git_call(ProjectRoot, ["rev-parse", "--verify", "HEAD"], Options) of
        {ok, Head} when is_binary(Head), byte_size(Head) > 0 ->
            case git_call(ProjectRoot,
                          ["config", "--get-all", "remote.origin.url"],
                          Options) of
                {ok, OriginOutput} ->
                    case origin_repo(OriginOutput) of
                        {ok, Repo} ->
                            tags_facts(ProjectRoot, Repo, Options);
                        {error, Reason} ->
                            {error, {git_origin, ProjectRoot, Reason}}
                    end;
                {error, {exit, 1, _}} ->
                    {error, {git_origin, ProjectRoot, missing_origin}};
                {error, Reason} ->
                    {error, {git_origin, ProjectRoot,
                             sanitize_git_reason(Reason)}}
            end;
        {ok, _Other} ->
            {error, {git_repository, ProjectRoot, empty_head}};
        {error, Reason} ->
            {error, {git_repository, ProjectRoot,
                     sanitize_git_reason(Reason)}}
    end.

tags_facts(ProjectRoot, Repo, Options) ->
    case git_call(ProjectRoot, ["tag", "--merged", "HEAD"], Options) of
        {ok, Output} when is_binary(Output) ->
            Tags = [Tag || Tag <- output_lines(Output), Tag =/= ""],
            Formal = [#{tag => ParsedTag, version => Version} || Tag <- Tags,
                      {formal, Version, ParsedTag} <-
                          [rebar3_reltree_version:parse_tag(Tag)]],
            {ok, #{repo => Repo, formal_tags => sort_formal(Formal)}};
        {ok, _Other} ->
            {error, {git_tags, ProjectRoot, malformed_output}};
        {error, Reason} ->
            {error, {git_tags, ProjectRoot, sanitize_git_reason(Reason)}}
    end.

origin_repo(Output) when is_binary(Output) ->
    Values = lists:usort([string:trim(Value) || Value <-
                           output_lines(Output), Value =/= ""]),
    case Values of
        [] ->
            {error, missing_origin};
        [_One] ->
            parse_origin(hd(Values));
        _Many ->
            {error, multiple_distinct_origins}
    end;
origin_repo(_Other) ->
    {error, malformed_origin}.

parse_origin(Url) ->
    Patterns = [
        "^https://github\\.com/([^/]+)/([^/]+)/?$",
        "^ssh://[^/@]+@github\\.com/([^/]+)/([^/]+)/?$",
        "^git@github\\.com:([^/]+)/([^/]+)/?$"
    ],
    case first_origin_match(Patterns, Url) of
        {ok, Owner0, Repo0} ->
            Repo = strip_git_suffix(Repo0),
            case Owner0 =/= [] andalso Repo =/= [] of
                true -> {ok, Owner0 ++ "/" ++ Repo};
                false -> {error, malformed_origin}
            end;
        no_match ->
            {error, non_github_origin}
    end.

first_origin_match([], _Url) ->
    no_match;
first_origin_match([Pattern | Rest], Url) ->
    case re:run(Url, Pattern, [{capture, [1, 2], list}]) of
        {match, [Owner, Repo]} -> {ok, Owner, Repo};
        nomatch -> first_origin_match(Rest, Url)
    end.

strip_git_suffix(Repo) ->
    case lists:suffix(".git", Repo) of
        true -> lists:sublist(Repo, length(Repo) - 4);
        false -> Repo
    end.

tag_policy([]) ->
    {ok, #{release => none}};
tag_policy(Formal) ->
    HighestVersion = maps:get(version, lists:last(Formal)),
    Highest = [Tag || #{tag := Tag, version := Version} <- Formal,
                       Version =:= HighestVersion],
    case Highest of
        [Tag] ->
            {ok, #{release => {tag, Tag}}};
        [First, Second] ->
            case equivalent_tags(First, Second) of
                true ->
                    {error, {equivalent_formal_tags, [First, Second]}};
                false ->
                    {error, {equivalent_formal_tags, [First, Second]}}
            end;
        Many ->
            {error, {equivalent_formal_tags, Many}}
    end.

equivalent_tags(First, Second) ->
    (First =:= "v" ++ Second) orelse (Second =:= "v" ++ First).

sort_formal(Formal) ->
    lists:sort(fun(A, B) ->
                       {maps:get(version, A), maps:get(tag, A)} =<
                       {maps:get(version, B), maps:get(tag, B)}
               end, Formal).

expected(Repo, _FormalTags, #{release := none}) ->
    #{repo => Repo, master => master_badge(Repo), release => none,
      release_tags => []};
expected(Repo, _FormalTags, #{release := {tag, Tag}}) ->
    #{repo => Repo, master => master_badge(Repo),
      release => release_badge(Repo, Tag),
      release_tags => [Tag]};
expected(Repo, FormalTags, #{release := equivalent, tags := Tags}) ->
    HighestVersion = maps:get(version, lists:last(FormalTags)),
    HighestTags = [Tag || #{tag := Tag, version := Version} <- FormalTags,
                          Version =:= HighestVersion],
    #{repo => Repo, master => master_badge(Repo), release => equivalent,
      release_tags => Tags ++ (HighestTags -- Tags)}.

equivalent_tags_list(FormalTags) ->
    HighestVersion = maps:get(version, lists:last(FormalTags)),
    [Tag || #{tag := Tag, version := Version} <- FormalTags,
            Version =:= HighestVersion].

master_badge(Repo) ->
    Base = "https://github.com/" ++ Repo ++
           "/actions/workflows/ci.yml",
    "**master CI** [![CI](" ++ Base ++
    "/badge.svg?branch=master&event=push)](" ++ Base ++
    "?query=branch%3Amaster)".

release_badge(Repo, Tag) ->
    Base = "https://github.com/" ++ Repo ++
           "/actions/workflows/ci.yml",
    Label = case Tag of
                [$v | Rest] -> Rest;
                _ -> Tag
            end,
    "**" ++ Label ++ " release CI** [![CI](" ++ Base ++
    "/badge.svg?branch=" ++ Tag ++ "&event=push)](" ++ Base ++
    "?query=branch%3A" ++ Tag ++ ")".

read_readmes(ProjectRoot, Options) ->
    README = filename:join(ProjectRoot, "README.md"),
    Chinese = filename:join(ProjectRoot, "README.zh.md"),
    case read_required_readme(README, Options) of
        {error, _} = Error ->
            Error;
        {ok, English} ->
            case read_optional_readme(Chinese, Options) of
                absent -> {ok, [English]};
                {ok, Zh} -> {ok, [English, Zh]};
                {error, _} = Error -> Error
            end
    end.

read_required_readme(Path, Options) ->
    case read_readme(Path, Options) of
        absent -> {error, {readme_read, Path, enoent}};
        Result -> Result
    end.

read_optional_readme(Path, Options) ->
    read_readme(Path, Options).

read_readme(Path, Options) ->
    case fs_call(read_link_info, [Path], Options) of
        {error, enoent} ->
            absent;
        {error, {enoent, _}} ->
            absent;
        {ok, #file_info{type = regular}} ->
            case fs_call(read_file, [Path], Options) of
                {ok, Content} when is_binary(Content) ->
                    {ok, #{path => Path, content => Content}};
                {ok, _Other} ->
                    {error, {readme_invalid, Path, non_binary_data}};
                {error, Reason} ->
                    {error, {readme_read, Path, Reason}}
            end;
        {ok, #file_info{type = Type}} ->
            {error, {readme_invalid, Path, {not_regular, Type}}};
        {error, Reason} ->
            {error, {readme_read, Path, Reason}}
    end.

check_results(Results, Policy) ->
    Failures0 = [{maps:get(path, File), Categories} ||
                 {File, {error, Categories}} <- Results],
    case cross_file_tag_check(Results, Policy) of
        ok ->
            case Failures0 of
                [] -> ok;
                _ -> {error, {badge_mismatch, Failures0}}
            end;
        {error, CrossFailures} ->
            {error, {badge_mismatch, Failures0 ++ CrossFailures}}
    end.

cross_file_tag_check(_Results, #{release := none}) ->
    ok;
cross_file_tag_check(Results, #{release := equivalent}) ->
    ValidTags = [Tag || {_File, {ok, #{release_tag := Tag}}} <- Results],
    case lists:usort(ValidTags) of
        [] -> ok;
        [_] -> ok;
        _ ->
            {error, [{maps:get(path, File), [cross_file_tag_mismatch]} ||
                     {File, {ok, #{release_tag := _}}} <- Results]}
    end;
cross_file_tag_check(_Results, _Policy) ->
    ok.

check_file(#{content := Content}, Expected) ->
    Lines = split_lines(Content),
    Candidates = candidates(Lines),
    ExpectedKinds = case maps:get(release, Expected) of
                        none -> [master];
                        _ -> [master, release]
                    end,
    case length(Candidates) of
        0 -> {error, [missing]};
        Count when Count =/= length(ExpectedKinds) ->
            {error, count_categories(Candidates, ExpectedKinds)};
        _ ->
            Kinds = [Kind || {_Index, Kind, _Tag, _Text} <- Candidates],
            case Kinds =:= ExpectedKinds of
                false -> {error, [wrong_order]};
                true ->
                    case exact_candidates(Candidates, Expected) of
                        false -> {error, candidate_categories(Candidates,
                                                               Expected)};
                        true ->
                            case canonical_separator(Candidates, Lines) of
                                true ->
                                    ReleaseTag = release_tag(Candidates, Expected),
                                    {ok, #{release_tag => ReleaseTag}};
                                false -> {error, [wrong_separator]}
                            end
                    end
            end
    end.

count_categories(Candidates, ExpectedKinds) ->
    Kinds = [Kind || {_Index, Kind, _Tag, _Text} <- Candidates],
    case {lists:member(master, Kinds), lists:member(release, Kinds),
          lists:member(release, ExpectedKinds),
          length(Candidates) > length(ExpectedKinds)} of
        {false, _, _, _} -> [missing];
        {true, false, true, _} -> [missing];
        {true, true, false, _} -> [unexpected_release];
        {true, true, true, true} -> [duplicate];
        {true, false, false, true} -> [duplicate];
        _ -> [duplicate]
    end.

candidate_categories(Candidates, Expected) ->
    case lists:any(fun({_Index, _Kind, _Tag, Text}) ->
                           not exact_text(Text, Expected)
                   end, Candidates) of
        true -> [malformed];
        false -> [stale]
    end.

exact_candidates(Candidates, Expected) ->
    lists:all(fun({_Index, _Kind, _Tag, Text}) ->
                      exact_text(Text, Expected)
              end, Candidates).

exact_text(Text, Expected) ->
    case Text =:= maps:get(master, Expected) of
        true ->
            true;
        false ->
            case maps:get(release, Expected) of
                none -> false;
                equivalent ->
                    lists:member(Text,
                                 [release_badge_for_expected(Expected, Tag) ||
                                  Tag <- maps:get(release_tags, Expected)]);
                Release -> Text =:= Release
            end
    end.

release_badge_for_expected(Expected, Tag) ->
    release_badge(maps:get(repo, Expected), Tag).

canonical_separator([{First, _Kind1, _Tag1, _Text1},
                     {Second, _Kind2, _Tag2, _Text2}], Lines) ->
    Between = lists:sublist(lists:nthtail(First + 1, Lines),
                             Second - First - 1),
    length(Between) =:= 1 andalso
        lists:all(fun({Body, _Eol}) -> Body =:= <<>> end, Between);
canonical_separator(_Candidates, _Lines) ->
    true.

release_tag(Candidates, Expected) ->
    ReleaseTexts = [Text || {_Index, release, _Tag, Text} <- Candidates],
    case [Tag || Tag <- maps:get(release_tags, Expected),
                 Text <- ReleaseTexts,
                 Text =:= release_badge_for_expected(Expected, Tag)] of
        [Tag] -> Tag;
        _ -> none
    end.

transform_file(#{content := Content} = File, Expected) ->
    Lines = split_lines(Content),
    Candidates = candidates(Lines),
    NewContent = case Candidates of
                     [] -> insert_new_block(Lines, Expected);
                     _ -> replace_old_block(Lines, Candidates, Expected)
                 end,
    File#{content => NewContent}.

insert_new_block(Lines, Expected) ->
    Eol = default_eol(Lines),
    Block = canonical_block(Expected, Eol, Eol, true),
    iolist_to_binary([Block, render_lines(Lines)]).

replace_old_block(Lines, Candidates, Expected) ->
    Indices = [Index || {Index, _Kind, _Tag, _Text} <- Candidates],
    Remove = separator_indices(Indices, Lines),
    Remaining = [{Index, Line} || {Index, Line} <-
                                  lists:zip(lists:seq(0, length(Lines) - 1),
                                             Lines),
                                  not lists:member(Index, Remove)],
    First = hd(Indices),
    Last = lists:last(Indices),
    InternalEol = line_eol(lists:nth(First + 1, Lines),
                           default_eol(Lines)),
    BoundaryEol = line_eol(lists:nth(Last + 1, Lines), <<>>),
    Block = canonical_block(Expected, InternalEol, BoundaryEol, false),
    {Before, After} = lists:split(First, Remaining),
    iolist_to_binary([render_lines([Line || {_Index, Line} <- Before]), Block,
                      render_lines([Line || {_Index, Line} <- After])]).

separator_indices([], _Lines) ->
    [];
separator_indices([_Only], _Lines) ->
    [_Only];
separator_indices(Indices, Lines) ->
    Candidates = lists:zip(lists:sublist(Indices, length(Indices) - 1),
                           tl(Indices)),
    Blanks = lists:flatten([
        case lists:seq(First + 1, Second - 1) of
            [Index] ->
                case line_body(lists:nth(Index + 1, Lines)) of
                    <<>> -> [Index];
                    _ -> []
                end;
            _ ->
                []
        end ||
         {First, Second} <- Candidates]),
    lists:usort(Indices ++ Blanks).

canonical_block(Expected, InternalEol, BoundaryEol, AddTrailingBlank) ->
    Master = maps:get(master, Expected),
    Release = maps:get(release, Expected),
    Core = case Release of
               none -> [{list_to_binary(Master), BoundaryEol}];
               equivalent ->
                   Tag = hd(maps:get(release_tags, Expected)),
                   [{list_to_binary(Master), InternalEol},
                    {<<>>, InternalEol},
                    {list_to_binary(release_badge_for_expected(Expected, Tag)),
                     BoundaryEol}];
               _ ->
                   [{list_to_binary(Master), InternalEol},
                    {<<>>, InternalEol},
                    {list_to_binary(Release), BoundaryEol}]
           end,
    Core1 = case AddTrailingBlank of
                true -> Core ++ [{<<>>, BoundaryEol}];
                false -> Core
            end,
    iolist_to_binary(render_lines(Core1)).

write_files([], _Options) ->
    ok;
write_files([{File, Transformed} | Rest], Options) ->
    case maps:get(content, File) =:= maps:get(content, Transformed) of
        true -> write_files(Rest, Options);
        false ->
            Path = maps:get(path, File),
            case atomic_write(Path, maps:get(content, Transformed), Options) of
                {ok, _} -> write_files(Rest, Options);
                ok -> write_files(Rest, Options);
                {error, Reason} ->
                    {error, {readme_write, Path, replace, Reason}}
            end
    end.

candidates(Lines) ->
    candidates(Lines, 0, []).

candidates([], _Index, Acc) ->
    lists:reverse(Acc);
candidates([{Body, _Eol} | Rest], Index, Acc) ->
    Text = binary_to_list(trim_binary(Body)),
    case candidate(Text) of
        none -> candidates(Rest, Index + 1, Acc);
        {Kind, Tag} ->
            candidates(Rest, Index + 1,
                       [{Index, Kind, Tag, Text} | Acc])
    end.

candidate(Text) ->
    case lists:prefix("**master CI** [![CI]", Text) of
        true -> {master, none};
        false ->
            case lists:prefix("[![master CI]", Text) of
                true -> {master, none};
                false -> release_candidate(Text)
            end
    end.

release_candidate("**" ++ Rest) ->
    case string:split(Rest, " release CI** [![CI](", leading) of
        [Version, Image] when Version =/= [], Image =/= [] ->
            {release, Version};
        _ ->
            case string:split(Rest, "** [![release CI](", leading) of
                [Version, Image] when Version =/= [], Image =/= [] ->
                    {release, Version};
                _ ->
                    none
            end
    end;
release_candidate("[![" ++ Rest) ->
    case string:split(Rest, "]", leading) of
        [Label, _Rest] ->
            case lists:suffix(" release CI", Label) of
                true ->
                    Version = lists:sublist(Label, length(Label) - 11),
                    case Version of
                        [] -> none;
                        _ -> {release, Version}
                    end;
                false -> none
            end;
        _ -> none
    end;
release_candidate(_Text) ->
    none.

split_lines(Content) ->
    [line_part(Part, IsLast) ||
     {Part, IsLast} <- with_last(binary:split(Content, <<"\n">>, [global]))].

with_last(Parts) ->
    with_last(Parts, length(Parts), 1, []).

with_last([], _Count, _Index, Acc) ->
    lists:reverse(Acc);
with_last([Part | Rest], Count, Index, Acc) ->
    with_last(Rest, Count, Index + 1,
              [{Part, Index =:= Count} | Acc]).

line_part(Part, true) ->
    {Part, <<>>};
line_part(Part, false) ->
    case byte_size(Part) > 0 andalso binary:at(Part, byte_size(Part) - 1) =:= 13 of
        true -> {binary:part(Part, 0, byte_size(Part) - 1), <<"\r\n">>};
        false -> {Part, <<"\n">>}
    end.

line_body({Body, _Eol}) -> Body.

line_eol({Body, <<>>}, Default) ->
    case byte_size(Body) > 0 andalso
         binary:at(Body, byte_size(Body) - 1) =:= 13 of
        true -> <<"\r">>;
        false -> Default
    end;
line_eol({_Body, Eol}, _Default) ->
    Eol.

default_eol(Lines) ->
    case [Eol || {_Body, Eol} <- Lines, Eol =/= <<>>] of
        [Eol | _] -> Eol;
        [] -> <<"\n">>
    end.

render_lines(Lines) ->
    [[Body, Eol] || {Body, Eol} <- Lines].

trim_binary(Binary) ->
    list_to_binary(string:trim(binary_to_list(Binary), both, " \t\r" )).

output_lines(Binary) ->
    [string:trim(Line, trailing, "\r") ||
     Line <- string:split(binary_to_list(Binary), "\n", all)].

policy_warnings(#{release := equivalent, tags := Tags}) ->
    [#{code => equivalent_formal_tags, tags => Tags}];
policy_warnings(_Policy) ->
    [].

format_warning(#{code := skip_no_workflow, path := Path}) ->
    ["warning: ", Path, " is absent; bgate skipped\n"];
format_warning(#{code := equivalent_formal_tags, tags := Tags}) ->
    ["warning: equivalent formal tags (", string:join(Tags, ", "),
     "); either highest tag spelling accepted\n"];
format_warning(_Warning) ->
    [].

fs_call(Name, Args, Options) ->
    Fs = maps:get(fs, Options, #{}),
    Default = case Name of
                  read_link_info -> fun file:read_link_info/1;
                  read_file -> fun file:read_file/1
              end,
    Fun = maps:get(Name, Fs, maps:get(Name, Options, Default)),
    erlang:apply(Fun, Args).

git_call(ProjectRoot, Args, Options) ->
    case maps:get(git_command, Options, undefined) of
        Fun when is_function(Fun, 2) -> Fun(ProjectRoot, Args);
        _ -> rebar3_reltree_git:command(ProjectRoot, Args, #{})
    end.

atomic_write(Path, Content, Options) ->
    case maps:get(atomic_write, Options, undefined) of
        Fun when is_function(Fun, 2) -> Fun(Path, Content);
        _ -> rebar3_reltree_fs:atomic_write(Path, Content, #{})
    end.

sanitize_git_reason({exit, Status, _Output}) when is_integer(Status) ->
    {git_exit, Status};
sanitize_git_reason(timeout) -> timeout;
sanitize_git_reason(output_too_large) -> output_too_large;
sanitize_git_reason(git_executable_unavailable) -> git_executable_unavailable;
sanitize_git_reason({port_open, _}) -> port_open;
sanitize_git_reason(Reason) when is_atom(Reason) -> Reason;
sanitize_git_reason(_Other) -> git_command_failed.

format_failures(Failures) ->
    lists:join(", ", [io_lib:format("~ts (~p)", [Path, Categories]) ||
                       {Path, Categories} <- Failures]).

reason_text(Reason) when is_atom(Reason) -> atom_to_list(Reason);
reason_text(Reason) when is_binary(Reason) -> binary_to_list(Reason);
reason_text(Reason) when is_list(Reason) ->
    case io_lib:printable_list(Reason) of
        true -> Reason;
        false -> lists:flatten(io_lib:format("~p", [Reason]))
    end;
reason_text(Reason) ->
    lists:flatten(io_lib:format("~p", [Reason])).

bounded_term(Term) ->
    Text = lists:flatten(io_lib:format("~tp", [Term])),
    case length(Text) > 512 of
        true -> lists:sublist(Text, 512) ++ "...";
        false -> Text
    end.

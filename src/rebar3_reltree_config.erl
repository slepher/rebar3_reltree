-module(rebar3_reltree_config).

-export([
    read/1,
    read_terms/1,
    dependency_name/1,
    dependency_declarations/1,
    app_identity/1
]).

%% This module reads only ordinary consulted Erlang terms.  It never executes
%% a config value and keeps the original dependency terms for the renderer.

-spec read(filename:filename_all()) -> {ok, map()} | {error, term()}.
read(ProjectPath) ->
    ConfigPath = filename:join(ProjectPath, "rebar.config"),
    case read_terms(ConfigPath) of
        {ok, Terms} -> extract(Terms);
        {error, Reason} -> {error, {config_read, ConfigPath, Reason}}
    end.

-spec read_terms(filename:filename_all()) -> {ok, [term()]} | {error, term()}.
read_terms(Path) ->
    case file:consult(Path) of
        {ok, Terms} when is_list(Terms) -> {ok, Terms};
        {ok, Other} -> {error, {malformed_terms, Other}};
        {error, Reason} -> {error, Reason}
    end.

-spec dependency_name(term()) -> {ok, atom()} | error.
dependency_name(Name) when is_atom(Name) ->
    {ok, Name};
dependency_name(Declaration) when
    is_tuple(Declaration),
    tuple_size(Declaration) >= 1
->
    case element(1, Declaration) of
        Name when is_atom(Name) -> {ok, Name};
        _ -> error
    end;
dependency_name(_Other) ->
    error.

-spec dependency_declarations(map()) -> [term()].
dependency_declarations(#{dependencies := Deps}) -> Deps.

-spec app_identity(filename:filename_all()) -> {ok, map()} | {error, term()}.
app_identity(ProjectPath) ->
    SrcPath = filename:join(ProjectPath, "src"),
    case rebar3_reltree_fs:directory(SrcPath) of
        false ->
            {error, {app_src_directory, SrcPath}};
        true ->
            case rebar3_reltree_fs:list_dir(SrcPath) of
                {ok, Names} ->
                    Files = [
                        filename:join(SrcPath, Name)
                     || Name <- Names,
                        lists:suffix(".app.src", Name),
                        rebar3_reltree_fs:regular(
                            filename:join(SrcPath, Name)
                        )
                    ],
                    app_identity_files(ProjectPath, Files);
                {error, Reason} ->
                    {error, {app_src_directory_read, SrcPath, Reason}}
            end
    end.

app_identity_files(_ProjectPath, []) ->
    {error, no_app_src};
app_identity_files(_ProjectPath, [_One, _Two | _]) ->
    {error, multiple_app_src};
app_identity_files(_ProjectPath, [Path]) ->
    case read_terms(Path) of
        {ok, [{application, App, Properties}]} when
            is_atom(App),
            is_list(Properties)
        ->
            case app_version(Properties) of
                {ok, Vsn} ->
                    {ok, #{app => App, app_vsn => Vsn, app_src => Path}};
                {error, _} = Error ->
                    Error
            end;
        {ok, Terms} ->
            {error, {invalid_app_src_term, Terms}};
        {error, Reason} ->
            {error, {app_src_read, Path, Reason}}
    end.

app_version(Properties) ->
    VersionTerms = [Vsn || {vsn, Vsn} <- Properties],
    case VersionTerms of
        [Vsn] ->
            case valid_string(Vsn) of
                true -> {ok, Vsn};
                false -> {error, invalid_app_vsn}
            end;
        [] ->
            {error, invalid_app_vsn};
        _ ->
            {error, ambiguous_app_vsn}
    end.

extract(Terms) ->
    case fact_list(deps, Terms, []) of
        {ok, Deps} ->
            case fact_list(project_plugins, Terms, []) of
                {ok, ProjectPlugins} ->
                    case fact_list(plugins, Terms, []) of
                        {ok, Plugins} ->
                            case dependency_list(Deps) of
                                {ok, ValidDeps} ->
                                    {ok, #{
                                        dependencies => ValidDeps,
                                        project_plugins => ProjectPlugins,
                                        plugins => Plugins
                                    }};
                                {error, _} = Error ->
                                    Error
                            end;
                        {error, _} = Error ->
                            Error
                    end;
                {error, _} = Error ->
                    Error
            end;
        {error, _} = Error ->
            Error
    end.

fact_list(Key, Terms, Default) ->
    Malformed = [
        Term
     || Term <- Terms,
        config_term_for(Key, Term),
        not valid_config_term(Term)
    ],
    case Malformed of
        [Bad | _] ->
            {error, {malformed_config_term, Key, Bad}};
        [] ->
            fact_list_values(Key, Terms, Default)
    end.

fact_list_values(Key, Terms, Default) ->
    Values = [
        Value
     || Term <- Terms,
        is_tuple(Term),
        tuple_size(Term) =:= 2,
        element(1, Term) =:= Key,
        Value <- [element(2, Term)]
    ],
    case Values of
        [] ->
            {ok, Default};
        _ ->
            Value = lists:last(Values),
            case is_list(Value) of
                true -> {ok, Value};
                false -> {error, {malformed_config_list, Key, Value}}
            end
    end.

config_term_for(Key, Term) when Term =:= Key ->
    true;
config_term_for(Key, Term) when is_tuple(Term), tuple_size(Term) >= 1 ->
    element(1, Term) =:= Key;
config_term_for(_Key, _Term) ->
    false.

valid_config_term(Term) ->
    is_tuple(Term) andalso tuple_size(Term) =:= 2.

dependency_list(Deps) ->
    case lists:dropwhile(fun valid_dependency/1, Deps) of
        [] -> {ok, Deps};
        [Bad | _] -> {error, {malformed_dependency, Bad}}
    end.

-spec valid_dependency(term()) -> boolean().
valid_dependency(Declaration) ->
    dependency_name(Declaration) =/= error.

valid_string(Value) when is_list(Value), Value =/= [] ->
    lists:all(
        fun(Char) ->
            is_integer(Char) andalso Char >= 0 andalso
                Char =< 16#10ffff
        end,
        Value
    );
valid_string(_Value) ->
    false.

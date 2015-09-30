-module(xprof_web_handler).

-export([init/3,handle/2,terminate/3]).

%% Cowboy callbacks

init(_Type, Req, _Opts) ->
    {ok, Req, no_state}.

handle(Req, State) ->
    {What,_} = cowboy_req:binding(what, Req),
    handle_req(What, Req, State).

terminate(_Reason, _Req, _State) ->
    ok.

%% Private
%% Handling different HTTP requests

handle_req(<<"funs">>, Req, State) ->
    {Query, _} = cowboy_req:qs_val(<<"query">>, Req, <<"">>),

    Funs = lists:sort(xprof_vm_info:get_available_funs(Query)),
    Json = jiffy:encode(Funs),

    lager:debug("Returning ~b functions matching phrase \"~s\"",
                [length(Funs), Query]),


    {ok, Req2} = cowboy_req:reply(200,
                                  [{<<"content-type">>, <<"application/json">>}],
                                  Json,
                                  Req),
    {ok, Req2, State};
handle_req(<<"mon_start">>, Req, State) ->
    {M,F,A} = get_mfa(Req),

    lager:debug("Starting monitoring on ~w:~w:~b~n",[M,F,A]),

    xprof_tracer:monitor_fun({M,F,A}, true),
    {ok, Req, State};


handle_req(<<"mon_stop">>, Req, State) ->
    {M,F,A} = get_mfa(Req),

    lager:debug("Stopping monitoring on ~w:~w:~b~n",[M,F,A]),

    xprof_tracer:monitor_fun({M,F,A}, true),
    {ok, Req, State};

handle_req(<<"data">>, Req, State) ->
    Vals = xprof_tracer:pull_data(Req),
    Json = jiffy:encode({Vals}),
    {ok, Req2} = cowboy_req:reply(200,
                                  [{<<"content-type">>, <<"application/json">>}],
                                  Json, Req),
    {ok, Req2, State}.

%% Helpers

-spec get_mfa(cowboy:req()) -> {module(),atom(),non_neg_integer()}.
get_mfa(Req) ->
    {Params, _} = cowboy_req:qs_vals(Req),
    {list_to_atom(binary_to_list(proplists:get_value(<<"mod">>, Params))),
     list_to_atom(binary_to_list(proplists:get_value(<<"fun">>, Params))),
     binary_to_integer(proplists:get_value(<<"arity">>, Params))}.
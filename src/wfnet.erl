%%%-------------------------------------------------------------------
%%% @author Fred Youhanaie <fyrlang@anydata.co.uk>
%%% @copyright 2023, Fred Youhanaie
%%% @doc
%%%
%%% Client functions for the workflow server.
%%%
%%% @end
%%% Created : 28 Oct 2023 by Fred Youhanaie <fyrlang@anydata.co.uk>
%%%-------------------------------------------------------------------
-module(wfnet).

-export([start/0, stop/0]).
-export([load_wf/1, run_wf/0, task_done/2]).

%%--------------------------------------------------------------------
%% @doc start the application.
%%
%% @end
%%--------------------------------------------------------------------
-spec start() -> ok | {error, term()}.
start() ->
    application:start(wfnet).

%%--------------------------------------------------------------------
%% @doc stop the application.
%%
%% @end
%%--------------------------------------------------------------------
-spec stop() -> ok | {error, term()}.
stop() ->
    application:stop(wfnet).

%%--------------------------------------------------------------------
%% @doc load a workflow from file.
%%
%% @end
%%--------------------------------------------------------------------
-spec load_wf(file:name_all()) -> ok | {error, term()}.
load_wf(Filename) ->
    wfnet_srv:load_wf(Filename).

%%--------------------------------------------------------------------
%% @doc run the currently loaded workflow.
%%
%% @end
%%--------------------------------------------------------------------
-spec run_wf() -> ok | {error, term()}.
run_wf() ->
    wfnet_srv:run_wf().

%%--------------------------------------------------------------------
%% @doc Tell the server that a task has completed.
%%
%% @end
%%--------------------------------------------------------------------
-spec task_done(integer(), term()) -> ok | {error, term()}.
task_done(Id, Result) ->
    wfnet_srv:task_done(Id, Result).

%%--------------------------------------------------------------------

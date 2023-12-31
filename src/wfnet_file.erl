%%%-------------------------------------------------------------------
%%% @author Fred Youhanaie <fyrlang@anydata.co.uk>
%%% @copyright 2023, Fred Youhanaie
%%% @doc
%%%
%%% A set of functions for processing workflow definitions.
%%%
%%% @end
%%% Created : 28 Oct 2023 by Fred Youhanaie <fyrlang@anydata.co.uk>
%%%-------------------------------------------------------------------
-module(wfnet_file).

-export([read_file/1, load_ets/1, load_digraph/1]).

%%--------------------------------------------------------------------

-include_lib("kernel/include/logger.hrl").

%%--------------------------------------------------------------------
%% @doc read a workflow file and return it as a list of task tuples.
%%
%% @end
%%--------------------------------------------------------------------
-spec read_file(file:name_all()) -> {ok, [term()]} | {error, term()}.
read_file(File) ->
    case file:consult(File) of
        {ok, WF} ->
            {ok, WF};
        {error, Reason} ->
            ?LOG_ERROR("Could not read/parse file (~p) - ~p.", [File, Reason]),
            {error, Reason}
    end.

%%--------------------------------------------------------------------
%% @doc Load a workflow definition into an ETS table.
%%
%% An ETS table is created and the task tuples are loaded into it.
%%
%% @end
%%--------------------------------------------------------------------
-spec load_ets([term()]) -> ets:table().
load_ets(WF) ->
    Tab = ets:new(wfnet, [named_table, {keypos, 2}, ordered_set]),
    insert_tasks(WF, Tab),
    Tab.

%%--------------------------------------------------------------------
%% @doc insert a list of tasks into the ETS table.
%%
%% @end
%%--------------------------------------------------------------------
-spec insert_tasks([term()], ets:table()) -> ets:table().
insert_tasks([], Tab) ->
    Tab;

insert_tasks([Task|WF], Tab) ->
    ets:insert(Tab, Task),
    insert_tasks(WF, Tab).

%%--------------------------------------------------------------------
%% @doc load the workflow into a digraph.
%%
%% A new digraph containing the workflow is returned.
%%
%% @end
%%--------------------------------------------------------------------
-spec load_digraph(list()) -> digraph:graph().
load_digraph(WF) ->
    G = digraph:new(),
    add_tasks(WF, G),
    G.

%%--------------------------------------------------------------------
%% @doc add the tasks of a workflow to a digraph.
%%
%% @end
%%--------------------------------------------------------------------
-spec add_tasks(list(), digraph:graph()) -> digraph:graph().
add_tasks([], G) ->
    G;

add_tasks([{wfenter, Id=0, Succ}|WF], G) ->
    digraph:add_vertex(G, Id, {wfenter, Succ}),
    add_succ(G, Id, Succ),
    add_tasks(WF, G);

add_tasks([{wfexit, Id}|WF], G) ->
    digraph:add_vertex(G, Id, {wfexit}),
    add_tasks(WF, G);

add_tasks([{wftask, Id, Succ, Data}|WF], G) ->
    digraph:add_vertex(G, Id, {wftask, Succ, Data}),
    add_succ(G, Id, Succ),
    add_tasks(WF, G);

add_tasks([{wfands, Id, Succ}|WF], G) ->
    digraph:add_vertex(G, Id, {wfands, Succ}),
    [ add_succ(G, Id, S) || S <- Succ ],
    add_tasks(WF, G);

add_tasks([{wfandj, Id, Succ}|WF], G) ->
    digraph:add_vertex(G, Id, {wfandj, Succ}),
    add_succ(G, Id, Succ),
    add_tasks(WF, G);

add_tasks([{wfxors, Id, Succ}|WF], G) ->
    digraph:add_vertex(G, Id, {wfxors, Succ}),
    [ add_succ(G, Id, S) || S <- Succ ],
    add_tasks(WF, G);

add_tasks([{wfxorj, Id, Succ}|WF], G) ->
    digraph:add_vertex(G, Id, {wfxorj, Succ}),
    add_succ(G, Id, Succ),
    add_tasks(WF, G).

%%--------------------------------------------------------------------
%% @doc Add a successor edge, and the vertex.
%%
%% @end
%%--------------------------------------------------------------------
-spec add_succ(digraph:graph(), integer(), integer()) -> any().
add_succ(G, Id, Succ) ->
    case digraph:vertex(G, Succ) of
        false ->
            digraph:add_vertex(G, Succ, []);
        _ ->
            ok
    end,
    digraph:add_edge(G, Id, Succ).

%%--------------------------------------------------------------------

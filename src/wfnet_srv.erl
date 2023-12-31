%%%-------------------------------------------------------------------
%%% @author Fred Youhanaie <fyrlang@anydata.co.uk>
%%% @copyright 2023, Fred Youhanaie
%%% @doc
%%%
%%% This is tha main workflow engine/controller.
%%%
%%% Currently it can only handle one workflow at a time, within a
%%% single node.
%%%
%%% @end
%%% Created : 28 Oct 2023 by Fred Youhanaie <fyrlang@anydata.co.uk>
%%%-------------------------------------------------------------------
-module(wfnet_srv).

-behaviour(gen_server).

%% API
-export([start_link/0, load_wf/1, run_wf/0, task_done/2]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3, format_status/2]).

-define(SERVER, ?MODULE).

-include_lib("kernel/include/logger.hrl").

%%--------------------------------------------------------------------
%%
%% wf_state is one of `no_wf', `loaded', `running', `completed'
%% task_state, map of Id to state, `running' or `done', if
%% missing, not started.
%%
-record(state, {tabid=undefined,      %% worflow ETS table
                wf_state=no_wf,       %% workflow state
                queue=[],             %% queue of ready task Ids
                task_state=#{},       %% map of task states
                task_result=#{}       %% results from completed tasks
               }).

%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc tell the server to load a new workflow
%%
%% @end
%%--------------------------------------------------------------------
-spec load_wf(file:name_all()) -> ok | {error, term()}.
load_wf(Filename) ->
    gen_server:call(?SERVER, {load_wf, Filename}).

%%--------------------------------------------------------------------
%% @doc start the current workflow
%%
%% @end
%%--------------------------------------------------------------------
-spec run_wf() -> ok | {error, term()}.
run_wf() ->
    gen_server:call(?SERVER, run_wf).

%%--------------------------------------------------------------------
%% @doc handle task done
%%
%% @end
%%--------------------------------------------------------------------
-spec task_done(integer(), term()) -> ok | {error, term()}.
task_done(Id, Result) ->
    gen_server:call(?SERVER, {task_done, Id, Result}).

%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%% @end
%%--------------------------------------------------------------------
-spec start_link() -> {ok, Pid :: pid()} |
          {error, Error :: {already_started, pid()}} |
          {error, Error :: term()} |
          ignore.
start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the server
%% @end
%%--------------------------------------------------------------------
-spec init(Args :: term()) -> {ok, State :: term()} |
          {ok, State :: term(), Timeout :: timeout()} |
          {ok, State :: term(), hibernate} |
          {stop, Reason :: term()} |
          ignore.
init([]) ->
    process_flag(trap_exit, true),
    {ok, #state{}}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%% @end
%%--------------------------------------------------------------------
-spec handle_call(Request :: term(), From :: {pid(), term()}, State :: term()) ->
          {reply, Reply :: term(), NewState :: term()} |
          {reply, Reply :: term(), NewState :: term(), Timeout :: timeout()} |
          {reply, Reply :: term(), NewState :: term(), hibernate} |
          {noreply, NewState :: term()} |
          {noreply, NewState :: term(), Timeout :: timeout()} |
          {noreply, NewState :: term(), hibernate} |
          {stop, Reason :: term(), Reply :: term(), NewState :: term()} |
          {stop, Reason :: term(), NewState :: term()}.
handle_call({load_wf, Filename}, _From, State) ->
    {Reply, State2} = handle_load_wf(Filename, State),
    {reply, Reply, State2};

handle_call(run_wf, _From, State) ->
    {Reply, State2} = handle_run_wf(State),
    {reply, Reply, State2};

handle_call({task_done, Id, Result}, _From, State) ->
    {Reply, State2} = handle_task_done(Id, Result, State),
    {reply, Reply, State2};

handle_call(_Request, _From, State) ->
    Reply = ok,
    {reply, Reply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%% @end
%%--------------------------------------------------------------------
-spec handle_cast(Request :: term(), State :: term()) ->
          {noreply, NewState :: term()} |
          {noreply, NewState :: term(), Timeout :: timeout()} |
          {noreply, NewState :: term(), hibernate} |
          {stop, Reason :: term(), NewState :: term()}.
handle_cast(_Request, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%% @end
%%--------------------------------------------------------------------
-spec handle_info(Info :: timeout() | term(), State :: term()) ->
          {noreply, NewState :: term()} |
          {noreply, NewState :: term(), Timeout :: timeout()} |
          {noreply, NewState :: term(), hibernate} |
          {stop, Reason :: normal | term(), NewState :: term()}.
handle_info(_Info, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
%% @end
%%--------------------------------------------------------------------
-spec terminate(Reason :: normal | shutdown | {shutdown, term()} | term(),
                State :: term()) -> any().
terminate(_Reason, _State) ->
    ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%% @end
%%--------------------------------------------------------------------
-spec code_change(OldVsn :: term() | {down, term()},
                  State :: term(),
                  Extra :: term()) -> {ok, NewState :: term()} |
          {error, Reason :: term()}.
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called for changing the form and appearance
%% of gen_server status when it is returned from sys:get_status/1,2
%% or when it appears in termination error logs.
%% @end
%%--------------------------------------------------------------------
-spec format_status(Opt :: normal | terminate,
                    Status :: list()) -> Status :: term().
format_status(_Opt, Status) ->
    Status.

%%%===================================================================
%%% Internal functions
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc load a workflow file into an ETS table.
%%
%% @end
%%--------------------------------------------------------------------
-spec handle_load_wf(file:name_all(), term()) ->
          {ok | {error, term()}, term()}.
handle_load_wf(Filename, State) ->
    case State#state.wf_state of
        no_wf ->
            case wfnet_file:read_file(Filename) of
                {ok, WF} ->
                    Tab_id = wfnet_file:load_ets(WF),
                    {ok, State#state{tabid=Tab_id,
                                     wf_state=loaded}};
                Error ->
                    {Error, State}
            end;
        _ ->
            {{error, already_loaded}, State}
    end.

%%--------------------------------------------------------------------
%% @doc run the current workflow.
%%
%% We expect `wfenter' to have id 0.
%%
%% @end
%%--------------------------------------------------------------------
-spec handle_run_wf(term()) -> {ok | {error, term()}, term()}.
handle_run_wf(State) ->
    T = get_task(0, State),
    State2 = State#state{wf_state=running},
    run_task(T, State2).

%%--------------------------------------------------------------------
%% @doc lookup a task
%%
%% @end
%%--------------------------------------------------------------------
-spec get_task(integer(), term()) -> tuple().
get_task(Id, State) ->
    [Task] = ets:lookup(State#state.tabid, Id),
    Task.

%%--------------------------------------------------------------------
%% @doc initiate a task.
%%
%% @end
%%--------------------------------------------------------------------
-spec run_task(tuple(), term()) -> term().
run_task({wfenter, Id, _Succ}, State) ->
    handle_task_done(Id, 0, State);

run_task({wftask, Id, _Succ, Data}, State) ->
    wfnet_runner:run_task(Id, Data),
    Task_states = maps:put(Id, done, State#state.task_state),
    State2 = State#state{task_state=Task_states},
    {ok, State2};

run_task({wfexit, _Id}, State) ->
    case State#state.queue of
        [] ->
            ok;
        Queue ->
            ?LOG_ERROR("wfexit with non-empty queue (~p).", [Queue])
    end,
    {ok, State#state{wf_state=completed}};

run_task({wfands, Id, _Succ}, State) ->
    handle_task_done(Id, 0, State);

run_task({wfandj, Id, _Succ}, State) ->
    handle_task_done(Id, 0, State);

run_task({wfxorj, Id, _Succ}, State) ->
    handle_task_done(Id, 0, State);

run_task({wfxors, Id, _Succ}, State) ->
    handle_task_done(Id, 0, State);

run_task(Task, State) ->
    ?LOG_ERROR("Unknown task, task=~p, state=~p.", [Task, State]),
    {ok, State}.

%%--------------------------------------------------------------------
%% @doc upate task state/result for a completed task
%%
%% @end
%%--------------------------------------------------------------------
-spec handle_task_done(integer(), term(), term()) -> {ok, term()}.
handle_task_done(Id, Result, State) ->
    Task_states = maps:put(Id, done, State#state.task_state),
    Task_result = maps:put(Id, Result, State#state.task_result),
    State2 = State#state{task_state=Task_states, task_result=Task_result},
    State3 = process_next(Id, State2),
    State4 = process_queue(State3),
    {ok, State4}.

%%--------------------------------------------------------------------
%% @doc process the next task in the workflow.
%%
%% @end
%%--------------------------------------------------------------------
-spec process_next(integer(), term()) -> term().
process_next(Id, State) ->
    Task = get_task(Id, State),
    case Task of
        {wfenter, Id, Succ} ->
            Queue = State#state.queue,
            State#state{queue=Queue++[Succ]};
        {wftask, Id, Succ, _} ->
            Queue = State#state.queue,
            State#state{queue=Queue++[Succ]};
        {wfands, Id, Succ} ->
            Queue = State#state.queue,
            State#state{queue=Queue++Succ};
        {wfandj, Id, Succ} ->
            %% check preds
            %% for now assume all done
            Queue = State#state.queue,
            State#state{queue=Queue++[Succ]};
        {wfxors, Id, Succ} ->
            %% check result of pred
            %% for now take the first branch
            [First|_Rest] = Succ,
            Queue = State#state.queue,
            State#state{queue=Queue++[First]};
        {wfxorj, Id, Succ} ->
            Queue = State#state.queue,
            State#state{queue=Queue++[Succ]}
    end.

%%--------------------------------------------------------------------
%% @doc process and tasks remaining in the read queue.
%%
%% @end
%%--------------------------------------------------------------------
-spec process_queue(term()) -> term().
process_queue(State) ->
    Queue = State#state.queue,
    State2 = process_queue(Queue, State#state{queue=[]}),
    State2.

%%--------------------------------------------------------------------

-spec process_queue(list(), term()) -> term().
process_queue([], State) ->
    State;

process_queue([Id|Rest], State) ->
    Task = get_task(Id, State),
    {ok, State2} = run_task(Task, State),
    process_queue(Rest, State2).

%%--------------------------------------------------------------------

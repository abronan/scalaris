% @copyright 2010-2015 Zuse Institute Berlin

%   Licensed under the Apache License, Version 2.0 (the "License");
%   you may not use this file except in compliance with the License.
%   You may obtain a copy of the License at
%
%       http://www.apache.org/licenses/LICENSE-2.0
%
%   Unless required by applicable law or agreed to in writing, software
%   distributed under the License is distributed on an "AS IS" BASIS,
%   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%   See the License for the specific language governing permissions and
%   limitations under the License.

%% @author Thorsten Schuett <schuett@zib.de>
%% @doc Handling all Scalaris nodes inside an Erlang VM and Erlang VM wide
%%      maintenance tasks.
%% @version $Id$
-module(service_per_vm).
-author('schuett@zib.de').
-vsn('$Id$').

-behaviour(gen_component).

-export([dump_node_states/0, kill_nodes/1, kill_nodes_by_name/1, register_dht_node/1, 
         deregister_dht_node/1]).

-export([start_link/1, init/1, on/2]).

% state of the module
-type state() :: [{MonitorRef::reference(), DhtNode::comm:mypid()}].

% accepted messages the module
-type message() ::
    {get_dht_nodes, ReplyPid :: comm:mypid()} |
    {register_dht_node, PidToAdd :: comm:mypid()} |
    {deregister_dht_node, PidToRemove :: comm:mypid()} |
    {'DOWN', MonitorRef::reference(), process, Owner::comm:erl_local_pid(), Info::any()} |
    {delete_node, SupPid::pid() | atom(), SupId::pid() | term()} |
    {trigger_gc} | %% only internally inside the process
    {hi}.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Public API
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% @doc ask all local nodes for their state
-spec dump_node_states() -> [term()].
dump_node_states() ->
    [gen_component:get_state(Pid)
     || Pid <- pid_groups:find_all(dht_node)].

-spec kill_nodes(No::non_neg_integer()) -> ok.
kill_nodes(No) ->
    Childs = lists:sublist([X || X <- supervisor:which_children(main_sup),
                                 is_list(element(1, X))], No),
    _ = [begin
             SupDhtNode = element(2, Child),
             Id = element(1, Child),
             sup:sup_terminate_childs(SupDhtNode),
             _ = supervisor:terminate_child(main_sup, Id),
             supervisor:delete_child(main_sup, Id)
         end || Child <- Childs],
    ok.

% @doc kills Scalaris nodes from the current VM 
-spec kill_nodes_by_name(Names::list(pid_groups:groupname())) -> ok.
kill_nodes_by_name(Names) ->
    comm:send_local(service_per_vm, {kill_nodes_by_name, Names}),
    ok.

%% @doc Sends a register message to a running service_per_vm to register a
%%      local(!) dht_node process.
-spec register_dht_node(comm:mypid()) -> ok.
register_dht_node(Pid) ->
    case get_service() of
        failed  -> ok;
        Service -> comm:send_local(Service, {register_dht_node, Pid})
    end.

%% @doc Sends a deregister message to a running service_per_vm to remove a
%%      local(!) dht_node process.
-spec deregister_dht_node(comm:mypid()) -> ok.
deregister_dht_node(Pid) ->
    case get_service() of
        failed  -> ok;
        Service -> comm:send_local(Service, {deregister_dht_node, Pid})
    end.


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Server process
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

-spec start_link(pid_groups:groupname()) -> {ok, pid()}.
start_link(ServiceGroup) ->
    gen_component:start_link(?MODULE, fun ?MODULE:on/2, [],
                             [{erlang_register, service_per_vm},
                              {pid_groups_join_as, ServiceGroup, ?MODULE},
                              {wait_for_init}]).

-spec init(any()) -> state().
init(_Arg) ->
    %% find my IP address
    comm:init_and_wait_for_valid_IP(),
    msg_delay:send_trigger(10, {trigger_gc}),
    [].

-spec on(Message :: message(), State :: state()) -> state().

% @doc registers a dht node
on({register_dht_node, Pid}, State) ->
    % only local processes may register!
    MonRef = erlang:monitor(process, comm:make_local(comm:get_plain_pid(Pid))),
    [{MonRef, Pid} | State];

% @doc de-registers a dht node
on({deregister_dht_node, Pid}, State) ->
    case lists:keytake(Pid, 2, State) of
        {value, {MonRef, Pid}, Rest} ->
            % allow erlang_demonitor to take its DOWN message off the message
            % queue if present!
            erlang:demonitor(MonRef, [flush]),
            Rest;
        false -> State
    end;

on({'DOWN', MonitorRef, process, _LocalPid, _Info1}, State) ->
    % compare the monitor reference only (it is tied to the Pid and unique)
    [X || {MonRef, _Node} = X <- State, MonRef =/= MonitorRef];

% @doc replies with the list of registered dht nodes
on({get_dht_nodes, Pid}, State) ->
    case comm:is_valid(Pid) of
        true ->
            Nodes = [Node || {_MonRef, Node} <- State],
            comm:send(Pid, {get_dht_nodes_response, Nodes});
        false ->
            ok
    end,
    State;

on({delete_node, SupPid, SupId}, State) ->
    _ = admin:del_node({SupId, SupPid, supervisor, []}, false),
    State;

on({kill_nodes_by_name, Names}, State) ->
    _ = admin:del_nodes_by_name(Names, false),
    State;

on({add_node, Options}, State) ->
    _ = admin:add_node(Options),
    State;

on({trigger_gc}, State) ->
    %% Periodically garbage collect all processes of the VM.  This
    %% helps especially when running several VMs on the same machine.
    %% Otherwise the Erlang VM will not release allocated memory and
    %% the operating system may start swapping virtual memory,
    %% although the Erlang VM could easily reduce its memory footprint
    %% and swapping would not be necessary.  With periodic garbage
    %% collection, Erlang becomes much more cooperative with other
    %% processes running on the same machine.
    msg_delay:send_trigger(10, {trigger_gc}),
    %% io:format("Garbage collect all processes~n"),
    _ = [garbage_collect(X) || X <- processes()],
    State;

%% message from comm:init_and_wait_for_valid_IP/0 (no reply needed)
on({hi}, State) ->
    State.

-spec get_service() -> comm:mypid() | failed.
get_service() ->
    pid_groups:find_a(service_per_vm).

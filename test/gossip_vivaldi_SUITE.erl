% @copyright 2010-2014 Zuse Institute Berlin

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

%% @author Jens V. Fischer <jensvfischer@gmail.com>
%% @doc Unit tests for src/vivaldi.erl
%% @end
%% @version $Id$
-module(gossip_vivaldi_SUITE).
-author('jensvfischer@gmail.com').
-vsn('$Id$').

-compile(export_all).

-include("scalaris.hrl").
-include("unittest.hrl").


all() ->
    [
     test_init,
     test_get_coordinate,
     test_select_node,
     test_select_data,
     test_select_reply_data
    ].


suite() ->
    [
     {timetrap, {seconds, 10}}
    ].


init_per_suite(Config) ->
    unittest_helper:init_per_suite(Config).


end_per_suite(Config) ->
    unittest_helper:end_per_suite(Config).


init_per_testcase(TestCase, Config) ->
    Config2 = unittest_helper:init_per_suite(Config),
    NeedsRing = [test_get_coordinate, test_select_reply_data],
    case lists:member(TestCase, NeedsRing) of
        true ->
            unittest_helper:make_ring(2, [{config, [{monitor_perf_interval, 0},  % deactivate monitor_perf
                                                    {gossip_vivaldi_interval, 100}

                                                   ]}]),
            unittest_helper:wait_for_stable_ring_deep(),
            Config2;
        false ->
            unittest_helper:start_minimal_procs(Config2, [], true)
    end.


end_per_testcase(_TestCase, Config) ->
    unittest_helper:stop_minimal_procs(Config),
    unittest_helper:stop_ring(),
    %% reset_config(),
    Config.

test_get_coordinate(Config) ->
    pid_groups:join_as(pid_groups:group_with(gossip), ?MODULE),
    %% timer:sleep(30000),
    %% pid_groups:join_as(atom_to_list(?MODULE), gossip),
    gossip_vivaldi:get_coordinate(),
    ?expect_message({vivaldi_get_coordinate_response, _Coordinate, _Confidence}),
    Config.


test_init(Config) ->
    pid_groups:join_as(atom_to_list(?MODULE), gossip),
    ?expect_no_message(),
    Ret = gossip_vivaldi:init([]),
    ?equals_pattern(Ret, {ok, {_RandomCoordinate, 1.0}}),
    ?expect_message({trigger_action, {gossip_vivaldi, default}}),
    ?expect_no_message(),
    Config.


test_select_node(Config) ->
    Ret = gossip_vivaldi:select_node({[0.5, 0.5], 0.5}),
    ?equals(Ret, {false, {[0.5, 0.5], 0.5}}),
    Config.


test_select_data(Config) ->
    pid_groups:join_as(atom_to_list(?MODULE), gossip),
    Ret = gossip_vivaldi:select_data({[0.1, 0.1], 0.2}),
    ?equals(Ret, {ok, {[0.1, 0.1], 0.2}}),
    This = comm:this(),
    ?expect_message({selected_data, {gossip_vivaldi, default},
                     {This, [0.1, 0.1], 0.2}}),
    Config.

test_select_reply_data(Config) ->
    config:write(gossip_vivaldi_count_measurements, 1),
    config:write(gossip_vivaldi_measurements_delay, 0),

    Data = {comm:this(), [0.0, 0.0], 0.77},
    Ret = gossip_vivaldi:select_reply_data(Data, 0, 0, {[1.0, 1.0], 1.0}),
    ?equals(Ret, {ok, {[1.0, 1.0], 1.0}}),

    receive
        {ping, SourcePid} ->
            comm:send(SourcePid, {pong, gossip}, [{channel, prio}])
    end,
    ?expect_message({cb_msg, {gossip_vivaldi,default},
                     {update_vivaldi_coordinate, _Latency, {[0.0, 0.0], 0.77}}}),

    config:write(gossip_vivaldi_count_measurements, 10),
    config:write(gossip_vivaldi_measurements_delay, 1000),
    Config.

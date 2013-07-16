% @copyright 2013 Zuse Institute Berlin,

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

%% @author Jan Fajerski <fajerski@zib.de>
%% @doc    Behaviour for DB back-ends.
%% @end
%% @version $Id$
-module(backend_beh).
-author('fajerski@zib.de').
-vsn('$Id$').

-ifdef(have_callback_support).
-include("scalaris.hrl").

-type db() :: any().
-type key() :: term().
-type entry() :: tuple().

-callback new(nonempty_string()) -> db().
-callback close(db()) -> true.
-callback put(db(), entry()) -> db().
-callback get(db(), key()) -> entry() | {}.
-callback delete(db(), key()) -> db().

-callback get_name(db()) -> nonempty_string().
-callback get_load(db()) -> non_neg_integer().

-callback foldl(db(), fun((entry(), AccIn::A) -> AccOut::A), Acc0::A) -> Acc1::A.
-callback foldl(db(), fun((entry(), AccIn::A) -> AccOut::A), Acc0::A, intervals:simple_interval()) -> Acc1::A.
-callback foldl(db(), fun((entry(), AccIn::A) -> AccOut::A), Acc0::A, intervals:simple_interval(), non_neg_integer()) -> Acc1::A.

-callback foldr(db(), fun((entry(), AccIn::A) -> AccOut::A), Acc0::A) -> Acc1::A.
-callback foldr(db(), fun((entry(), AccIn::A) -> AccOut::A), Acc0::A, intervals:simple_interval()) -> Acc1::A.
-callback foldr(db(), fun((entry(), AccIn::A) -> AccOut::A), Acc0::A, intervals:simple_interval(), non_neg_integer()) -> Acc1::A.

-else.

-export([behaviour_info/1]).
-spec behaviour_info(atom()) -> [{atom(), arity()}] | undefined.
behaviour_info(callbacks) ->
    [
        {new, 1}, {close, 1}, {put, 2}, {get, 2}, {delete, 2},
        {get_name, 1}, {get_load, 1}, 
        {foldl, 3}, {foldl, 4}, {foldl, 5},
        {foldr, 3}, {foldr, 4}, {foldr, 5}
    ];
behaviour_info(_Other) ->
    undefined.

-endif.
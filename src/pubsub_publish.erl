% @copyright 2008-2013 Zuse Institute Berlin

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
%% @doc Publish function
%% @end
%% @version $Id$
-module(pubsub_publish).
-author('schuett@zib.de').
-vsn('$Id$').

-export([publish/3, publish_internal/3]).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% public functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% @doc publishs an event to a given url.
%% @todo use pool:pspawn
-spec publish(URL::string(), Topic::string(), Content::string()) -> ok.
publish(URL, Topic, Content) ->
    spawn(pubsub_publish, publish_internal, [URL, Topic, Content]),
    ok.

-spec publish_internal(URL::string(), Topic::string(), Content::string()) -> {ok, {response, Result::[term()]}} | {error, Reason::term()}.
publish_internal(URL, Topic, Content) ->
    jsonrpc:call(URL, [], {call, "notify", [Topic, Content]}).

%% ----------------------------------------------------------------------------
%% The MIT License
%%
%% Copyright (c) 2016 Andrei Nesterov <ae.nesterov@gmail.com>
%%
%% Permission is hereby granted, free of charge, to any person obtaining a copy
%% of this software and associated documentation files (the "Software"), to
%% deal in the Software without restriction, including without limitation the
%% rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
%% sell copies of the Software, and to permit persons to whom the Software is
%% furnished to do so, subject to the following conditions:
%%
%% The above copyright notice and this permission notice shall be included in
%% all copies or substantial portions of the Software.
%%
%% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
%% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
%% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
%% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
%% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
%% FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
%% IN THE SOFTWARE.
%% ----------------------------------------------------------------------------

-module(vmq_tbac).
-behaviour(auth_on_register_hook).
-behaviour(auth_on_subscribe_hook).
-behaviour(auth_on_publish_hook).

-include_lib("vmq_commons/include/vmq_types.hrl").

%% API
-export([
	read_configs/0,
	read_configs/1,
	read_config/2
]).

%% Hooks
-export([
	auth_on_register/5,
	auth_on_subscribe/3,
	auth_on_publish/6
]).

%% Plugin Callbacks
-export([
	start/0,
	stop/0
]).

%% Configuration
-export([
	auth_on_register_success_result/0,
	auth_on_subscribe_success_result/0,
	auth_on_publish_success_result/0,
	config_files/0
]).

%% Definitions
-define(APP, ?MODULE).
-define(IS_TOPIC_WILDCARD(C), (C =:= $#) or (C =:= $+)).

%% =============================================================================
%% API
%% =============================================================================

-spec read_configs() -> ok.
read_configs() ->
	Initial = config_files(),
	read_configs(Initial),
	case config_files() of
		Initial -> ok;
		Changed -> read_configs(Changed)
	end.

-spec read_configs([{atom(), binary()}]) -> ok.
read_configs(L) ->
	[read_config(App, Path) || {App, Path} <- L],
	ok.

-spec read_config(atom(), binary()) -> ok.
read_config(App, Path) ->
	_ =
		case file:consult(Path) of
			{ok, L} -> [application:set_env(App, Key, Val) || {Key, Val} <- L];
			_       -> ignore
		end,
	ok.

%% =============================================================================
%% Hooks
%% =============================================================================

auth_on_register(_Peer, _SubscriberId, UserName, _Password, _CleanSession) ->
	try
		verify_username(UserName),
		auth_on_register_success_result()
	catch _:R ->
		Reason = {bad_username, R},
		error_logger:info_report(
			[	{?MODULE, ?FUNCTION_NAME, ?FUNCTION_ARITY, erlang:get_stacktrace(), error, Reason},
				{username, UserName} ]),

		{error, Reason}
	end.

auth_on_subscribe(UserName, _SubscriberId, Topics) ->
	try
		[match_topic(UserName, Topic) || {Topic, _QoS} <- Topics],
		auth_on_subscribe_success_result()
	catch _:R ->
		Reason = {bad_username, R},
		error_logger:info_report([{?MODULE, ?FUNCTION_NAME, ?FUNCTION_ARITY, erlang:get_stacktrace(), error, Reason}]),
		{error, Reason}
	end.

auth_on_publish(UserName, _SubscriberId, _QoS, Topic, _Payload, _IsRetain) ->
	try
		match_topic(UserName, Topic),
		auth_on_publish_success_result()
	catch _:R ->
		Reason = {bad_username, R},
		error_logger:info_report([{?MODULE, ?FUNCTION_NAME, ?FUNCTION_ARITY, erlang:get_stacktrace(), error, Reason}]),
		{error, Reason}
	end.

%% =============================================================================
%% Plugin Callbacks
%% =============================================================================

-spec start() -> ok.
start() ->
	read_configs(),
	{ok, _} = application:ensure_all_started(?APP),
	ok.

-spec stop() -> ok.
stop() ->
	application:stop(?APP).

%% =============================================================================
%% Configuration
%% =============================================================================

-spec auth_on_register_success_result() -> ok | next.
auth_on_register_success_result() ->
	application:get_env(?APP, ?FUNCTION_NAME, ok).

-spec auth_on_subscribe_success_result() -> ok | next.
auth_on_subscribe_success_result() ->
	application:get_env(?APP, ?FUNCTION_NAME, ok).

-spec auth_on_publish_success_result() -> ok | next.
auth_on_publish_success_result() ->
	application:get_env(?APP, ?FUNCTION_NAME, ok).

-spec config_files() -> [{atom(), binary()}].
config_files() ->
	Default = [{?APP, "./etc/tbac.conf"}],
	[{App, list_to_binary(Val)}
		|| {App, Val} <- application:get_env(?APP, ?FUNCTION_NAME, Default)].

%% =============================================================================
%% Internal functions
%% =============================================================================

-spec verify_username(binary()) -> ok.
verify_username(<<C, _/binary>>) when ?IS_TOPIC_WILDCARD(C) -> error({bad_char, C});
verify_username(<<_, R/binary>>)                            -> verify_username(R);
verify_username(<<>>)                                       -> ok.

-spec match_topic(binary(), [binary()]) -> ok.
match_topic(Val, [])    -> error({nomatch_topic, Val, []});
match_topic(Val, [H|T]) -> match_topic(Val, T, H).

-spec match_topic(binary(), [binary()], binary()) -> ok.
match_topic(Val, _, Val)     -> ok;
match_topic(Val, [], Acc)    -> error({nomatch_topic, Val, Acc});
match_topic(Val, [H|T], Acc) -> match_topic(Val, T, <<Acc/binary, $/, H/binary>>).

%-spec match_topic(binary(), binary()) -> ok.
%match_topic(Root, Topic) ->
%	match_topic(byte_size(Root), Root, byte_size(Topic), Topic).
%
%-spec match_topic(non_neg_integer(), binary(), non_neg_integer(), binary()) -> ok.
%match_topic(RootSz, Root, TopicSz, Topic) when RootSz =< TopicSz ->
%	<<Val:RootSz/binary, _/bits>> = Topic,
%	case Val =:= Root of
%		true -> ok;
%		_    -> error({nomatch_topic, Root, Topic})
%	end;
%match_topic(_RootSz, Root, _TopicSz, Topic) ->
%	error({nomatch_topic, Root, Topic}).

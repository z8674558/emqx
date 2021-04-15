%%--------------------------------------------------------------------
%% Copyright (c) 2021 EMQ Technologies Co., Ltd. All Rights Reserved.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%--------------------------------------------------------------------

-module(emqx_ws_nginx_SUITE).

-include_lib("emqx/include/emqx.hrl").
-include_lib("emqx/include/emqx_mqtt.hrl").
-include_lib("eunit/include/eunit.hrl").

-compile(export_all).
-compile(nowarn_export_all).

all() -> emqx_ct:all(?MODULE).

%%--------------------------------------------------------------------
%% CT callbacks
%%--------------------------------------------------------------------

init_per_suite(Config) ->
    emqx_ct_helpers:start_apps([]),
    YamlFilePath = filename:join(["test", "emqx_SUITE_data", "docker-compose-nginx.yaml"]),
    Compose = emqx_ct_helpers:deps_path(emqx, YamlFilePath),
    DockerRes = emqx_ct_helpers_docker:compose(Compose, "musuite", "nginx", "", ""),
    ct:pal("Docker ~p~n", [DockerRes]),
    Config.


end_per_suite(_Config) ->
    emqx_ct_helpers_docker:force_remove("nginx", true),
    emqx_ct_helpers:stop_apps([]).

t_header(_) ->
    ClientId = <<"myws">>,
    {ok, C} = emqtt:start_link([{clean_start, true}, {host,"nginx"}, {port, 8080}, {clientid, ClientId}]),
    {ok, _} = emqtt:ws_connect(C),
    #{clientinfo := #{clientid := ClientId},
      conninfo := #{peername := {{100, 100, 100, 100}, 1000}}} = emqx_cm:get_chan_info(ClientId),
    ok = emqtt:disconnect(C).

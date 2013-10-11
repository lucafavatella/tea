%% See LICENSE for licensing information.
%% -*- coding: utf-8 -*-
-module(intension_tests).

-include_lib("eunit/include/eunit.hrl").


%% API tests.

i_test_() ->
  [
   temperatureAtInuvik()
  ].


temperatureAtInuvik() ->
  InuvikS = s("`Inuvik`"),
  ParisS = s("`Paris`"),
  DimLocation = {dim,"location"},
  T0 =
    {wherevar,
     {'@', {i_apply, "tempInuvik"}, {t, [{DimLocation,ParisS}]}},
     [{"temperature",
       t0(s("if #.location == `Inuvik` then
              46
            elsif #.location == `Paris` then
              58
            else
              1
            fi"))},
      {"tempAtLocation",
       {i_abs, [DimLocation], "temperature"}},
      {"tempInuvik",
       {'@', "tempAtLocation", {t, [{DimLocation,InuvikS}]}}}]},
  {setup,
   _Setup = fun() -> {ok, Pid} = tcache:start_link(100), Pid end,
   _Cleanup = fun(Pid) -> tcache_stop(Pid) end,
   [ ?_assertMatch({46,_}, tcore_eval(t1(T0))) ]}.


%% Internals

tcache_stop(Pid) ->
  catch tcache:stop(),
  case is_process_alive(Pid) of
    false ->
      ok;
    true ->
      tcache_stop(Pid)
  end.

s(S) ->
  {ok, T} = tea:string(S),
  T.

t0(T) ->
  ttransform0:transform0(T).

t1(T) ->
  ttransform1:transform1(T).

tcore_eval(T) ->
  tcore_eval(T, [], []).

tcore_eval(T, K, D) ->
  tcore:eval(T,[],[],K,D,{[],self()},0).

eval(S) ->
  {ok, T} = tea:string(S),
  tea:eval(T).

%% End of Module.

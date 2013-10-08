%% See LICENSE for licensing information.
%% -*- coding: utf-8 -*-
-module(fn_tests).

-include_lib("eunit/include/eunit.hrl").


%% API tests.

b_test_() ->
  [
   basic_b_abs(),
   basic_b_apply(),
   b_abs_w_two_formal_params(),
   b_abs_nested_in_wheredim_does_not_cause_wrong_substitution(),
   wheredim_nested_in_b_abs_does_not_cause_wrong_substitution(),
   b_abs_can_return_b_abs_and_formal_params_are_not_confused()
  ].

%% TODO: integration with parser for sequence of function declarations and calls

basic_b_abs() ->
  {ok, [FnT]} = tea:string("fun F.argAsVarId = argAsVarId"),
  ?assertEqual({fn, "F", [{b_param,"argAsVarId"}], "argAsVarId"},
               FnT),
  %% XXX Transform 0 at the moment converts a "fn" node to a
  %% "wherevar" with "b_abs". The wherevar is probably wrong and will
  %% therefore probably be removed in the future. Focussing the test
  %% only on the b_abs piece of the generated AST.
  {wherevar, "F", [{"F", BAbsT0}]} = t0(FnT),
  T0 = BAbsT0,
  ?assertEqual({b_abs, [], ["argAsVarId"], "argAsVarId"}, T0),
  T1 = t1(T0),
  ArgAsPhiDim = {phi,"argAsVarId"},
  ?assertEqual({b_abs, [], [ArgAsPhiDim], {'?',ArgAsPhiDim}}, T1),
  %% Eval
  {setup,
   _Setup = fun() -> {ok, Pid} = tcache:start_link(100), Pid end,
   _Cleanup = fun(Pid) -> tcache_stop(Pid) end,
   [
    begin
      ExpectedResult = {frozen_b_abs, [], [ArgAsPhiDim], {'?',ArgAsPhiDim}},
      ?_assertMatch({ExpectedResult,_}, tcore_eval(T1))
    end
   ]}.

basic_b_apply() ->
  BAbsT0 = abs_from_string("fun F.argAsVarId = argAsVarId"),
  %% Create an AST as if it were generated by transformation 0
  T0 = {wherevar, {b_apply, "F", [46]}, [{"F",BAbsT0}]},
  T1 = t1(T0),
  {setup,
   _Setup = fun() -> {ok, Pid} = tcache:start_link(100), Pid end,
   _Cleanup = fun(Pid) -> tcache_stop(Pid) end,
   [
    ?_assertMatch({46,_}, tcore_eval(T1))
   ]}.

b_abs_w_two_formal_params() ->
  BAbsT0 = abs_from_string("fun F.x .y = x - y"), %% Minus is not commutative
  ?assertMatch({b_abs, [], ["x", "y"], {primop, _, ["x", "y"]}}, BAbsT0),
  T0 = b_apply("F", BAbsT0, [46, 1]),
  T1 = t1(T0),
  %% Eval
  {setup,
   _Setup = fun() -> {ok, Pid} = tcache:start_link(100), Pid end,
   _Cleanup = fun(Pid) -> tcache_stop(Pid) end,
   [
    ?_assertMatch({45,_}, tcore_eval(T1))
   ]}.

b_abs_nested_in_wheredim_does_not_cause_wrong_substitution() ->
  %% HACK: Get the b_abs node without the wherevar
  BAbsT0 = abs_from_string("fun F.x = x + #.x"),
  %% Create an AST as if it were generated by transformation 0
  T0 = b_apply("FnReturnedByWheredim",
               {wheredim, BAbsT0, [{"x",46}]},
               [1]),
  WheredimX =
    {dim,{[1],1},"x"}, %% XXX Wherevar ATM changes position in evaluation tree
  BAbsX = {phi,"x"},
  T1 = t1(T0),
  ?assertMatch(
     {wherevar, {b_apply, _, _},
      [{_,
        {wheredim,
         {b_abs,
          %% "No wheredim clause can return an abstraction that varies
          %% in a local dimension identifier defined in that wheredim
          %% clause. To ensure that this is the case, if a local
          %% dimension identifier appears in the rank of the body of
          %% an abstraction, then that local dimension identifier must
          %% appear in the list of frozen dimensions for that
          %% abstraction."
          %%
          %% Ref: 14.1 "Assumptions" in paper "Multidimensional
          %% Infinite Data in the Language Lucid", Feb 2013
          [WheredimX],
          [BAbsX],
          {primop, _, [{'?',BAbsX},
                       {'#',WheredimX}
                      ]}},
         [{WheredimX,46}]}
       }]},
     T1),
  %% Eval
  {setup,
   _Setup = fun() -> {ok, Pid} = tcache:start_link(100), Pid end,
   _Cleanup = fun(Pid) -> tcache_stop(Pid) end,
   [
    ?_assertMatch({47,_}, tcore_eval(T1))
   ]}.

wheredim_nested_in_b_abs_does_not_cause_wrong_substitution() ->
  %% HACK: Get the b_abs node without the wherevar
  BAbsT0 = abs_from_string("fun F.x = (x + #.x) where dim x <- 46 end"),
  T0 = b_apply("F", BAbsT0, [1]),
  WheredimX = {dim,{[0,1],1},"x"},
  BAbsX = {phi,"x"},
  T1 = t1(T0),
  ?assertMatch(
     {wherevar, {b_apply, _, _},
      [{_,
        {b_abs, [], [BAbsX],
         {wheredim,
          {primop, _, [{'?',BAbsX},
                       {'#',WheredimX}]},
          [{WheredimX,46}]}}
       }]},
     T1),
  %% Eval
  {setup,
   _Setup = fun() -> {ok, Pid} = tcache:start_link(100), Pid end,
   _Cleanup = fun(Pid) -> tcache_stop(Pid) end,
   [
    ?_assertMatch({47,_}, tcore_eval(T1))
   ]}.

b_abs_can_return_b_abs_and_formal_params_are_not_confused() ->
  %% HACK: Get the b_abs node without the wherevar
  BAbsFT0 = abs_from_string("fun F.x.y = x - y"),
  BAbsGT0 = abs_from_string("fun G.x = F"),
  T0 =
    {wherevar,
     {b_apply,
      {b_apply, "G", [1]},
      [46,3]},
     [{"F",BAbsFT0},
      {"G",BAbsGT0}]},
  T1 = t1(T0),
  %% Eval
  {setup,
   _Setup = fun() -> {ok, Pid} = tcache:start_link(100), Pid end,
   _Cleanup = fun(Pid) -> tcache_stop(Pid) end,
   [
    ?_assertMatch({43,_}, tcore_eval(T1))
   ]}.


phi_is_recognized_as_a_dim_test_() ->
  %% Check that hidden dimensions replacing formal parameters are
  %% represented as e.g. {phi,"x"}...
  %%
  %% HACK: Get the b_abs node without the wherevar
  BAbsT0 = abs_from_string("fun F.x = x"),
  BAbsX = {phi,"x"},
  ?assertMatch({b_abs, _, [BAbsX], _}, t1(BAbsT0)),
  %% ... then check that such dimensions are treated as all other
  %% dimensions as far as missing dimensions are concerned.
  {setup,
   _Setup = fun() -> {ok, Pid} = tcache:start_link(100), Pid end,
   _Cleanup = fun(Pid) -> tcache_stop(Pid) end,
   [
    ?_assertMatch({[BAbsX],_},
                  tcore_eval({'if',{'?',BAbsX},46,58}, [], []))
   ]}.


%% Internals

tcache_stop(Pid) ->
  catch tcache:stop(),
  case is_process_alive(Pid) of
    false ->
      ok;
    true ->
      tcache_stop(Pid)
  end.

t0(T) ->
  ttransform0:transform0(T).

t1(T) ->
  ttransform1:transform1(T).

tcore_eval(T) ->
  tcore_eval(T, [], []).

tcore_eval(T, K, D) ->
  tcore:eval(T,[],[],K,D,{[],self()},0).

%% XXX Transform 0 at the moment converts a "fn" node to a "wherevar"
%% with "b_abs". The wherevar is probably wrong and will therefore
%% probably be removed in the future. This function enables the
%% developer writing tests to focus only on the b_abs piece of the
%% generated AST, without being distracted by the wherevar.
abs_from_string(String) ->
  {ok, [FnT]} = tea:string(String),
  {wherevar, FnName, [{FnName, AbsT0}]} = t0(FnT), %% XXX This wherevar in transform 0 smells badly
  AbsT0.

b_apply(FnName, BAbs, Args) ->
  {wherevar, {b_apply, FnName, Args}, [{FnName,BAbs}]}.

%% End of Module.

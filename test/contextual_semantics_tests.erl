%% See LICENSE for licensing information.
%% -*- coding: utf-8 -*-
-module(contextual_semantics_tests).

-include_lib("eunit/include/eunit.hrl").


%% API tests.

local_dim_in_wheredim_clause_test_() ->
  {foreach, fun setup/0, fun cleanup/1,
   [
    %% Ref: Feb 2013 cache semantics paper, section 14.1
    %% "Assumptions", point 2, sub-point 2.
    ?_test(wheredim_returning_abs_varying_in_dim_defined_in_same_wheredim()),
    %%
    %% Ref: Feb 2013 cache semantics paper, section 14.1
    %% "Assumptions", point 2, sub-point 1.
    ?_test(recursive_wheredim()),
    %%
    %% Ref: Nov 2013 semantics paper, section 2 page 5, 6
    ?_test(recursive_wheredim_nov2013_p5()),
    ?_test(recursive_wheredim_nov2013_p6_combined())
   ]}.


wheredim_returning_abs_varying_in_dim_defined_in_same_wheredim() ->
  S = "BadF!1
      where
        var BadF = // This is a tricky declaration
          (F where fun F!x = #.d end) // This is equivalent to an anonymous function
          where
            dim d <- 46
          end
      end",
  ?assertMatch(
     {46,_},
     %% Upstream TL returns spdim "Invalid dimension" (as the
     %% evaluation of "BadF" returns an abstraction that depends on
     %% dimension "d" without freezing it, and when the body of the
     %% abstraction is evaluated -in the application context-
     %% dimension "d" is not known).  See also:
     %% * Feb 2013 cache semantics paper (section 14.1 "Assumptions"
     %%   re static semantics, point 2, sub-point 2); and
     %% * Nov 2013 semantics paper (section 6 "Conclusions", page 18,
     %%   paragraph with text "... the cache supposes that a dimension
     %%   identifier in a wheredim clause can always be mapped to a
     %%   single dimension ... A proper static semantics is currently
     %%   under development...").
     %%
     %% Semantics alternative to the one currently used by upstream TL
     %% and described above are:
     %% * Ensure that a different dimension be allocated for each
     %%   instantiation of the same wheredim clause, i.e. in the
     %%   currently-being-evaluated expression tree (see Feb 2013
     %%   cache semantics paper, section 14.1 "Assumptions", point 2,
     %%   and Nov 2013 semantics paper, section 2, page 5); or
     %% * Distinguish (/ rename / enumerate) statically all local
     %%   dimensions in wheredim clauses based on their position in
     %%   the static AST, and freeze referenced dimensions in
     %%   abstractions as per transformation described in the Aug 2012
     %%   semantics paper, section 6.4 "Transformation" (notice the
     %%   usage of the "set of hidden dimensions allocated" in
     %%   wheredim clauses and in the list of frozen dimensions in
     %%   abstractions).
     eval(S)).

recursive_wheredim() ->
  S = "FactOf3
      where
        var FactOf3 = F @ [n <- 3]
        dim n <- 0
        var F =
          if #.d == 0 then 1 else #.d * (F @ [n <- #.d - 1]) fi
          where
            dim d <- #.n
          end
      end",
  {wheredim, {wherevar, _,
              [{"FactOf3", _},
               {"F", {wheredim, _,
                      [{{dim,_,"d"}, {'#',{dim,_,"n"}}}]}}]},
   [{{dim,_,"n"}, 0}]} = %% dim n is defined outside var F
    t1(t0(s(S))),
  ?assertMatch(
     {6,_},
     %% Upstream TL returns 6 too, even if, based on the Nov 2013
     %% semantics paper, the semantics implemented in upstream TL maps
     %% the local dimension of a wheredim clause always to the same
     %% dimension. This suggests that the first sub-point in
     %% assumption 2 in the Feb 2013 cache semantics paper (section
     %% 14.1 "Assumptions" re static semantics, point 2, sub-point 1)
     %% is not relevant.
     eval(S)).

recursive_wheredim_nov2013_p5() ->
  %% Ref: Nov 2013 semantics paper, section 2 page 5
  S = "fact.3
      where
        fun fact.n = F
        where
          var F =
            if #.d == 0 then 1 else #.d * (F @ [d <- #.d - 1]) fi
            where
              dim d <- n
            end
        end
      end",
  {wherevar, _,
   [{"fact", {b_abs, [], [{phi,"n"}],
              {wherevar, "F",
               [{"F", {wheredim, _,
                       [{{dim,_,"d"}, {'?', {phi,"n"}}}]}}]}}}]} =
    t1(t0(s(S))),
  ?assertMatch({6,_}, eval(S)).

recursive_wheredim_nov2013_p6_combined() ->
  %% Ref: Nov 2013 semantics paper, section 2 page 6 (wherevar and wheredim clauses combined into one)
  S = "fact.3
      where
        fun fact.n = F
        where
          dim d <- n
          var F =
            if #.d == 0 then 1 else #.d * (F @ [d <- #.d - 1]) fi
        end
      end",
  {wherevar, _,
   [{"fact", {b_abs, [], [{phi,"n"}],
              {wheredim, {wherevar, "F",
                          [{"F", _}]},
               [{{dim,_,"d"}, {'?',{phi,"n"}}}]}
             }}]} =
    t1(t0(s(S))),
  ?assertMatch({6,_}, eval(S)).


%% Internals

setup() ->
  {ok, Pid} = tcache:start_link(100),
  Pid.

cleanup(Pid) ->
  tcache_stop(Pid).

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

eval(S) when is_list(S) ->
  {ok, T} = tea:string(S),
  tea:eval(T).

%% End of Module.

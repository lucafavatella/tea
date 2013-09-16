%% See LICENSE for licensing information.
%% -*- coding: utf-8 -*-
-module(tea_tests).

%% tea_tests: tests for the interpreter.

-include_lib("eunit/include/eunit.hrl").


%% API tests.

const_test() ->
    %% replace with qc generators
    MaxN = 100000000000000000000,
    tcache:start_link(100),
    [begin
        N = random:uniform(MaxN),
        {ok, Tree} = tea:string(integer_to_list(N)),
        ?assertMatch({N, _},
            tcore:eval(Tree, fun(X)->X end,[],[], [], self(), 0))
    end || _ <- lists:seq(1,10)].

bool_test () ->
    {ok, Tree} = tea:string(" false "),
    tcache:start_link(100),
    ?assertMatch({false, _},
        tcore:eval(Tree, fun(X)->X end,[],[], [], self(), 0)).

string_test () ->
    {ok, Tree} = tea:string("`Test`"),
    S = {string,"Test"},
    tcache:start_link(100),
    ?assertMatch({S, _},
        tcore:eval(Tree, fun(X)->X end,[],[], [], self(), 0)).

constant_dim_test () ->
    {ok, Tree} = tea:string("#.t"),
    K = [{{[0],"t"}, 100}],
    D = [{[0],"t"}],
    tcache:start_link(100),
    ?assertMatch({100, _},
        tcore:eval(Tree, [],[],K, D, [0], 0)).

tuple1_test () ->
    {ok, Tree} = tea:string(" [t <- 1, s <- 2] "),
    TimeD = {[0],"t"},
    SpaceD = {[0],"s"},
    K = [{TimeD,100}, {SpaceD,100}],
    D = [TimeD,SpaceD],
    tcache:start_link(100),
    ?assertMatch({{te,[{TimeD,1},{SpaceD,2}]}, _}, % Uh? ‘te’? Is just ‘t’ the same?
        tcore:eval(Tree, [],[],K, D, [0], 0)).

tuple2_test () ->
    {ok, Tree} = tea:string(" [#.t <- 0, #.s <- 1] "),
    TimeD = {[0],"t"},
    SpaceD = {[0],"s"},
    tcache:start_link(100),
    ?assertMatch({[TimeD,SpaceD], _},
        tcore:eval(Tree, fun(X)->X end,[],[], [], self(), 0)).

primop1_test () ->
    {ok, Tree} = tea:string(" 10 + 20 "),
    tcache:start_link(100),
    ?assertMatch({30, _},
        tcore:eval(Tree, fun(X)->X end,[],[], [], self(), 0)).

primop2_test () ->
    {ok, Tree} = tea:string(" #.t + #.s "),
    TimeD = {[0],"t"},
    SpaceD = {[0],"s"},
    K = [{TimeD,100}, {SpaceD,100}],
    tcache:start_link(100),
    ?assertMatch({[TimeD,SpaceD], _},
        tcore:eval(Tree, [],[],K, [], [0], 0)).

primop3_test () ->
    {ok, Tree} = tea:string(" #.t + #.s "),
    TimeD = {[0],"t"},
    SpaceD = {[0],"s"},
    K = [{TimeD,100}, {SpaceD,100}],
    D = [SpaceD, TimeD],
    tcache:start_link(100),
    ?assertMatch({200, _},
        tcore:eval(Tree, [],[],K, D, [0], 0)).

perturb_test () ->
    TimeD = {[0],"t"},
    SpaceD = {[0],"s"},
    K = [{TimeD,100}, {SpaceD,100}],
    tcache:start_link(100),
    {ok, E1} = tea:string(" #.s @ [s <- 0] "),
    ?assertMatch({0, _},
        tcore:eval(E1, [],[],K, [SpaceD], [0], 0)),
    {ok, E2} = tea:string(" #.t @ [s <- 0] "),
    ?assertMatch({[TimeD], _},
        tcore:eval(E2, [],[],[], [], [0], 0)),
    {ok, E3} = tea:string(" #.t @ [s <- 0, t <- 1] "),
    ?assertMatch({1, _},
        tcore:eval(E3, [],[],K, [TimeD], [0], 0)),
    {ok, E4} = tea:string(" #.t @ [t <- 1, s <- 0] "),
    ?assertMatch({1, _},
        tcore:eval(E4, [],[],K, [TimeD], [0], 0)).


elsif_test () ->
    tcache:start_link(100),
    {ok, E1} = tea:string(" if 1 == 0 then 1
                         elsif 1 == 1 then 2 else 3 fi "),
    ?assertMatch({2,_},
        tcore:eval(E1, [],[],[], [], [0], 0)),
    {ok, E2} = tea:string(" if 1 == 0 then 1
                         elsif 0 == 1 then 2
                         elsif 1 == 1 then 3 else 4 fi "),
    ?assertMatch({3, _},
        tcore:eval(E2, [],[],[], [], [0], 0)).

%% Internals

%% End of Module.
%% See LICENSE for licensing information.
%% -*- coding: utf-8 -*-
-module(properties_tests).

%% Tests documented properties of semantics.

-include_lib("eunit/include/eunit.hrl").

%% API tests.

%% TODO Test propositions in Aug 2012 semantics paper listed below:
%%  7. [ ↓(↑{} E0)) ] == [ E0 ], i.e. eta-equivalence of i_apply of
%%     i_abs w/o frozen dims
%% 10. [ E0 wherevar x = E1 end ] == [ (\\ x -> E0) E1 ],
%%     i.e. eta-equivalence of wherevar and n_apply/n_abs
%% 13. Nested simple wherevar clauses can be collapsed

%% The propositions present in the Aug 2012 semantics paper and listed
%% below do not need to be tested as they are the ones implemented for
%% transforming named abs/apply:
%%  8. [ E0 E1 ] == [ E0 ! (↑{} E1) ], i.e. eta-equivalence of n_apply
%%     and tweaked v_apply
%%  9. [ \\ {Ei} x -> E0 ] == [ \ {Ei} x -> E0[x/↓x] ],
%%     i.e. eta-equivalence of n_abs and tweaked v_abs


%% Internals

%% End of Module.

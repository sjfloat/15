%        a
%       b c
%      d e f
%     g h i j
%    k l m n o

row([a, b, d, g, k]).
row([c, e, h, l]).
row([f, i, m]).
row([a, c, f, j, o]).
row([b, e, i, n]).
row([d, h, m]).
row([d, e, f]).
row([g, h, i, j]).
row([k, l, m, n, o]).

adjacent([A, B, C]) :-
  row(Row),
  (  append([_, [A,B,C], _], Row)
  ;  append([_, [C,B,A], _], Row)
  ).

jump([A, B], Pegs, [C | NewPegs]) :-
  adjacent([A, B, C]),
  not(member(C, Pegs)),
  select(A, Pegs, NewPegs1),
  select(B, NewPegs1, NewPegs).

start([b, c, d, e, f, g, h, i, j, k, l, m, n, o]).

solution([_], []).
solution(Pegs, [[A, B] | RemainingMoves]) :-
  jump([A, B], Pegs, NextPegs),
  solution(NextPegs, RemainingMoves).

Nonterminals sparql statement whereBlock block statementElems statementElem statementList.
Terminals variable '\.' '\{' '\}' where.
Rootsymbol sparql.

sparql -> whereBlock : {sparql, '$1' }.

whereBlock -> where '\{' block '\}' : {where, '$3'}.

block -> statementList : '$1'.

statementList -> statement: ['$1'].
statementList -> statement '\.': ['$1'].
statementList -> statement '\.' statementList : ['$1'|'$3'].

statement ->  statementElems : {statement, '$1'}.

statementElems -> statementElem : ['$1'].
statementElems -> statementElem statementElems : ['$1'|'$2'].

statementElem -> variable : {variable, extract_token('$1') }.

%% {INT}         : {token, {int,  TokenLine, list_to_integer(TokenChars)}}.
%% {ATOM}        : {token, {atom, TokenLine, to_atom(TokenChars)}}.
%% \[            : {token, {'[',  TokenLine}}.
%% \]            : {token, {']',  TokenLine}}.
%% ,             : {token, {',',  TokenLine}}.


%% Nonterminals list elems elem.
%% Terminals '[' ']' ',' int atom.
%% Rootsymbol list.


%% query -> {:}
%% list -> '[' ']'       : [].
%% list -> '[' elems ']' : '$2'.

%% elems -> elem           : ['$1'].
%% elems -> elem ',' elems : ['$1'|'$3'].

%% elem -> int  : extract_token('$1').
%% elem -> atom : extract_token('$1').
%% elem -> list : '$1'.

Erlang code.

extract_token({_Token, _Line, Value}) -> Value.

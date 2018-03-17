Nonterminals sparql statement whereBlock block statementElems statementElem statementList iri uri_symbol prefixed_name_symbol.
Terminals variable '\:' '\.' '\{' '\}' '\<' '\>' where name uri 'prefixed-name'.
Rootsymbol sparql.

sparql -> whereBlock : {sparql, '$1' }.

%% IRI
%% foaf:Person -> {:iri, {:"prefixed-name", {:prefix "foaf"} {:name "Person"}}}
%% <http://www.example.com/example/1> -> {:iri, {:uri "http://www.example.com/example/1"}}
iri -> '\<' uri_symbol '\>' : {iri, '$2'}.
iri -> prefixed_name_symbol : {iri, '$1'}.
uri_symbol -> uri : {uri, extract_token('$1')}.
prefixed_name_symbol -> 'prefixed-name' : {'prefixed-name', {prefix, extract_prefix_from_prefixed_name('$1')}, {name, extract_name_from_prefixed_name('$1')}}.

%% Where block
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
extract_prefix_from_prefixed_name({_Token, _line, {Prefix, _Name}}) -> Prefix.
extract_name_from_prefixed_name({_Token, _line, {_Prefix, Name}}) -> Name.

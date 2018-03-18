Nonterminals sparql statement whereBlock block statementElems statementElem statementList iri uri_symbol prefixed_name_symbol boolean_literal numerical_literal lang_tag rdf_literal.
Terminals variable '\:' '\.' '\{' '\}' '\<' '\>' where name uri 'prefixed-name' true false int float 'lang-tag' 'rdf-literal' 'double-quoted-string' 'rdf-type'.
Rootsymbol rdf_literal.

%% How to read this file?
%% I have tried to put the blocks as 'logically' consistent as possible
%% all parsable things also have examples. Look at these before modifying

sparql -> whereBlock : {sparql, '$1' }.

%% RDFLiteral
%% "test" -> {:"rdf-literal", {:value, "test"}}
%% "test"@en -> {:"rdf-literal", {:value, "test"}, {:"lang-tag", :en}}
%% "test"^^xsd:string -> {:"rdf-literal", {:value, "test"}, {"type", {:iri, {:"prefixed-name", {:prefix :xsd} {:name :string}} }}}
rdf_literal -> 'double-quoted-string' : {'rdf-literal', {value, extract_token('$1')}}.
rdf_literal -> 'double-quoted-string' 'lang-tag' : {'rdf-literal', {value, extract_token('$1')}, {'lang-tag', extract_token('$2')}}.
rdf_literal -> 'double-quoted-string' 'rdf-type' 'prefixed-name' : {'rdf-literal', {value, extract_token('$1')}, {type, {iri, {'prefixed-name', {prefix, extract_prefix_from_prefixed_name('$3')}, {name, extract_name_from_prefixed_name('$3')}}}}}.
rdf_literal -> 'double-quoted-string' 'rdf-type' 'uri' : {'rdf-literal', {value, extract_token('$1')}, {type, {uri, {iri, extract_token('$3')}}}}.

%% Language Tag
%% @en -> {:"lang-tag", :en}
lang_tag -> 'lang-tag' : {'lang-tag', extract_token('$1')}.

%% Boolean literals
%% true -> {:"boolean-literal", :true}
%% false -> {:"boolean-literal", :false}
boolean_literal -> true : {'boolean-literal', true}.
boolean_literal -> false : {'boolean-literal', false}.

%% Numerical literals
%% -1 -> {:"numerical-literal", {:type, :int}, {:value, -1}}
%% 3.14 -> {:"numerical-literal", {:type, :float}, {:value, 3.14}}
numerical_literal -> int : {'numerical-literal', {type, int}, {value, extract_int_token('$1')}}.
numerical_literal -> float : {'numerical-literal', {type, float}, {value, extract_float_token('$1')}}.

%% IRI
%% foaf:Person -> {:iri, {:"prefixed-name", {:prefix :foaf} {:name :Person}}}
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

%% extracts the exact value of the token
%% {:name, 45, "\"Jonathan\""} -> "\"Jonathan\""
extract_token({_Token, _Line, Value}) -> Value.

%% extracts the prefix from a prefixed name
%% {'prefixed-name', 1, {:foaf :Person}} -> :foaf
extract_prefix_from_prefixed_name({_Token, _line, {Prefix, _Name}}) -> Prefix.

%% extracts the name from a prefixed name
%% {'prefixed-name', 1, {:foaf :Person}} -> :Person
extract_name_from_prefixed_name({_Token, _line, {_Prefix, Name}}) -> Name.

%% extracts the value of a token as an integer
%% {'int', 1, '-1'} -> -1
extract_int_token(FullToken) ->
    StringValue = extract_token(FullToken),
    {IntValue, RestValue} = string:to_integer(StringValue),
    IntValue.

%% extracts the value of a token as a float
%% {'float', 1, '3.14'} -> 3.14
extract_float_token(FullToken) ->
    StringValue = extract_token(FullToken),
    {IntValue, RestValue} = string:to_float(StringValue),
    IntValue.

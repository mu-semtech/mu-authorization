Nonterminals sparql statement whereBlock block sameSubjectPathList iri uri_symbol prefixed_name_symbol boolean_literal numerical_literal lang_tag rdf_literal variable_symbol object blank_node nil_symbol subject predicate sameSubjectPath predicateList predicateExpression objectList.
Terminals variable '\:' '\.' '\{' '\}' '\<' '\>' ';' ',' where name uri 'prefixed-name' true false int float 'lang-tag' 'rdf-literal' 'double-quoted-string' 'rdf-type' nil 'blank-node'.
Rootsymbol whereBlock.

%% How to read this file?
%% I have tried to put the blocks as 'logically' consistent as possible.
%% All parsable things also have examples. Look at these before modifying.

sparql -> whereBlock : {sparql, '$1' }.

%% Where block
%% a where block is typically
%% where { ?s ?p ?o }
whereBlock -> where '\{' block '\}' : {where, '$3'}.

block -> sameSubjectPathList : '$1'.

sameSubjectPathList -> sameSubjectPath : ['$1'].
sameSubjectPathList -> sameSubjectPath '\.' : ['$1'].
sameSubjectPathList -> sameSubjectPath '\.' sameSubjectPathList: ['$1'|'$3'].

%% SameSubjectPath
%% a same subject path is a series of expressions connected to the same subject
%% examples of this are:
%%  ?s ?p ?o                    -> 
%%     {:same-subject-path, {:subject, {:variable, :s}}, {:predicate-list, [{:predicate, {:variable, :p}, {:object-list [{:object, {:variable, :o}}}]}}}]}}}
%%  ?s ?p ?o , ?o2              ->
%%     {:"same-subject-path", {:subject, {:variable, :s}},
%%     {:"predicate-list",
%%     [
%%     {{:predicate, {:variable, :p}},
%%     {:"object-list", [object: {:variable, :o},
%%                       object: {:variable, :o2}]}}
%%     ]}}
%%  ?s ?p ?o ; ?p2 ?o2 , ?o3    ->
%%     {:"same-subject-path", {:subject, {:variable, :s}},
%%     {:"predicate-list",
%%     [
%%       { {:predicate, {:variable, :p}},
%%         {:"object-list", [
%%                  object: {:variable, :o}
%%         ]}
%%       },
%%       { {:predicate, {:variable, :p2}},
%%         {:"object-list", [
%%                  object: {:variable, :o2},
%%                  object: {:variable, :o3}
%%         ]}
%%       }
%%     ]}}

sameSubjectPath -> subject predicateList : {'same-subject-path', '$1', {'predicate-list', '$2'}}.

predicateList -> predicateExpression : ['$1'].
predicateList -> predicateExpression ';' predicateList : ['$1'|'$3'].

predicateExpression -> predicate objectList :  {'$1', {'object-list', '$2'}}.

objectList -> object : ['$1'].
objectList -> object ',' objectList : ['$1'|'$3'].

%% Subject
%% IRI | BlankNode | Variable
subject -> iri : {subject, '$1'}.
subject -> blank_node : {subject, '$1'}.
subject -> variable_symbol : {subject, '$1'}.

%% Predicate
%% IRI | Variable
predicate -> iri : {predicate, '$1'}.
predicate -> variable_symbol : {predicate, '$1'}.

%% Object
%% IRI | RDFLiteral | NumericalLiteral | BooleanLiteral | BlankNode | NIL | Variable
object -> iri : {object, '$1'}.
object -> rdf_literal : {object, '$1'}.
object -> numerical_literal : {object, '$1'}.
object -> boolean_literal : {object, '$1'}.
object -> nil_symbol : {object, '$1'}.
object -> blank_node : {object, '$1'}.
object -> variable_symbol : {object, '$1'}.

%% nil
%% () -> {:nil}
nil_symbol -> nil : {nil}.

%% blank_node
%% _:exampleNode -> {:"blank-node", {:name, :exampleNode}}
blank_node -> 'blank-node' : {'blank-node', {name, extract_token('$1')}}.

%% RDFLiteral
%% "test" -> {:"rdf-literal", {:value, "test"}}
%% "test"@en -> {:"rdf-literal", {:value, "test"}, {:"lang-tag", :en}}
%% "test"^^xsd:string -> {:"rdf-literal", {:value, "test"}, {"type", {:iri, {:"prefixed-name", {:prefix :xsd} {:name :string}} }}}
rdf_literal -> 'double-quoted-string' : {'rdf-literal', {value, extract_token('$1')}}.
rdf_literal -> 'double-quoted-string' lang_tag : {'rdf-literal', {value, extract_token('$1')}, '$2'}.
rdf_literal -> 'double-quoted-string' 'rdf-type' iri : {'rdf-literal', {value, extract_token('$1')}, {type, '$3'}}.
rdf_literal -> 'double-quoted-string' 'rdf-type' uri_symbol : {'rdf-literal', {value, extract_token('$1')}, {type, {iri, '$3'}}}.

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

%% variable
%% ?s -> {:variable, :s}
%% $other-variable -> {:variable, :"other-variable"}
variable_symbol -> variable : {variable, extract_token('$1') }.

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

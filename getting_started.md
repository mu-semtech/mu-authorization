filesystem:
# What is currently in this repo?
This repo contains 2 separate things. On one hand we have implemented a W3C EBNF (yes it is a separate form of EBNF) parser generator which will generate a parser for the EBNF vocabulary passed. The other thing is a SPARQL parser which uses the previous parser generator to ... generate a parser.

# TODO's

# File structure
* lib
** sparql.ex -> still the original file, uses erlang parser generators, will take a SPARQL query and then shove it through the parser
** parser.ex -> W3C EBNF parser (now also sports the new SPARQL parser maybe needs to be separated)
** benchmark.ex -> single benchmark function, is completely separated from the rest of the source
** manipulator.ex -> must read the commit or ask Aad :), has a single method that applies manipulators from the regen.ex file
** regen.ex -> has 1 method make_regenerator that will produce an object that can take a parsed object and regenerate a string thingie from it again
** regen
*** constructor.ex has a single overloaded method that makes(x) x elementOf (:paren_group, :maybe_many, :one_of, ...)
*** protocol.ex has a bunch of types, need to check the elixir docs for this one
*** result.ex has a lot of SPARQL in its method names, not sure what it is about
*** status.ex has 1 (complicated) method; inspect(elements, produced_content, syntax)
*** processors = a directory that holds a bunch of ex files each of which is capable of generating 1 specific type of base thingie (Array, Many, Maybe, Some, Choice, ...)
** manipulators, these know about SPARQL btw
*** basics.ex, has 2 functions that walk solutions and decide which get 'emitted'
*** recipes.ex, has basic example manipulators
*** sparql_query.ex, has 2 manipulators: add_graph(element, graph) and add_sub_graph(element, graph)
** ebnf parser
*** tokenizer.ex, contains a fully functional W3C EBNF tokenizer
*** parser.ex, does parsing, most of the actions takes place in the smart_x methods, entry point is  tokenize_and_parse( string ) 
*** forms.ex, contains a constant that is equal to the W3C EBNF definition for SPARQL
*** generator_protocol.ex, defines 2 protocols, 1 that creates generators and 1 that emits generated results
*** generator_state.ex, defines helper methods (for state?) is_terminal, drop_spaces, split_off_whitespace, cut_whitespace
*** generator_result.ex, defines helper methods for results, length(generator_result) combine_results(resultA, resultB)
*** interpreter.ex, provides methods that take a string and a rule (as 'parsed' from the EBNF definition passed) and returns possible results
*** intepreter_terms (folder that contains helper methods, each of which is a [type].ex and [typle]_interpreter.ex, only nothing.ex, hex_character.ex, word.ex are not paired
**** array.ex
**** array_interpreter.ex
**** bracket.ex
**** choice.ex
**** choice_interpreter.ex
**** hex_character.ex
**** many.ex
**** many_interpreter.ex
**** maybe.ex
**** maybe_interpreter.ex
**** minus.ex
**** minus_interpreter.ex
**** not_bracket.ex
**** nothing.ex
**** some.ex
**** some_interpreter.ex
**** symbol.ex
**** symbol_interpreter.ex
**** word.ex

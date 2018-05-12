# What is currently in this repo?
This repo contains 2 separate things. On one hand we have implemented a W3C EBNF (yes it is a separate form of EBNF) parser generator which will generate a parser for the EBNF vocabulary passed. The other thing is a SPARQL parser which uses the previous parser generator to ... generate a parser.

## Getting started in iex
to start iex with all files loaded type the following in the root directory:
```
iex -S mix
```

### load the SPARQL EBNF vocabulary
```
> sparql_ebnf = EbnfParser.Forms.sparql() 
```

# Code documentation
This section is intended as a hands on code getting started. The key methods of all modules will be illustrated with simple examples. Each time the full method signature will be used as the section title. All examples work in iex.

## Parser.parse(query)
Parsing a query will give the following tree as a result:
```
> query = "SELECT * WHERE { ?s ?p ?o . }"
> Parser.parse(query)
>
> %Generator.Result{
  leftover: [],
  match_construct: [
    %InterpreterTerms.SymbolMatch{
      symbol: :QueryUnit,
      string: "SELECT * WHERE {?s ?p ?o .}",
      submatches: [
        %InterpreterTerms.SymbolMatch{
          symbol: :Query,
          string: "SELECT * WHERE {?s ?p ?o .}",
          submatches: [
            %InterpreterTerms.SymbolMatch{
              symbol: :Prologue,
              string: "",
              submatches: []
            },
            %InterpreterTerms.SymbolMatch{
              symbol: :SelectQuery,
              string: "SELECT * WHERE {?s ?p ?o .}",
              submatches: [
                %InterpreterTerms.SymbolMatch{
                  symbol: :SelectClause,
                  string: "SELECT *",
                  submatches: [
                    %InterpreterTerms.WordMatch{word: "SELECT"},
                    %InterpreterTerms.WordMatch{word: "*"}
                  ]
                },
                %InterpreterTerms.SymbolMatch{
                  symbol: :WhereClause,
                  string: " WHERE {?s ?p ?o .}",
                  submatches: [
                    %InterpreterTerms.WordMatch{word: "WHERE"},
                    %InterpreterTerms.SymbolMatch{
                      symbol: :GroupGraphPattern,
                      string: " {?s ?p ?o .}",
                      submatches: [
                        %InterpreterTerms.WordMatch{word: "{"},
                        %InterpreterTerms.SymbolMatch{
                          symbol: :GroupGraphPatternSub,
                          string: "?s ?p ?o .",
                          submatches: [
                            %InterpreterTerms.SymbolMatch{
                              symbol: :TriplesBlock,
                              string: "?s ?p ?o .",
                              submatches: [
                                %InterpreterTerms.SymbolMatch{
                                  symbol: :TriplesSameSubjectPath,
                                  string: "?s ?p ?o",
                                  submatches: [
                                    %InterpreterTerms.SymbolMatch{
                                      symbol: :VarOrTerm,
                                      string: "?s",
                                      submatches: [
                                        %InterpreterTerms.SymbolMatch{
                                          symbol: :Var,
                                          string: "?s",
                                          submatches: [
                                            %InterpreterTerms.SymbolMatch{
                                              symbol: :VAR1,
                                              string: "?s",
                                              submatches: :none
                                            }
                                          ]
                                        }
                                      ]
                                    },
                                    %InterpreterTerms.SymbolMatch{
                                      symbol: :PropertyListPathNotEmpty,
                                      string: " ?p ?o",
                                      submatches: [
                                        %InterpreterTerms.SymbolMatch{
                                          symbol: :VerbSimple,
                                          string: "?p",
                                          submatches: [
                                            %InterpreterTerms.SymbolMatch{
                                              symbol: :Var,
                                              string: "?p",
                                              submatches: [
                                                %InterpreterTerms.SymbolMatch{
                                                  symbol: :VAR1,
                                                  string: "?p",
                                                  submatches: :none
                                                }
                                              ]
                                            }
                                          ]
                                        },
                                        %InterpreterTerms.SymbolMatch{
                                          symbol: :ObjectListPath,
                                          string: " ?o",
                                          submatches: [
                                            %InterpreterTerms.SymbolMatch{
                                              symbol: :ObjectPath,
                                              string: "?o",
                                              submatches: [
                                                %InterpreterTerms.SymbolMatch{
                                                  symbol: :GraphNodePath,
                                                  string: "?o",
                                                  submatches: [
                                                    %InterpreterTerms.SymbolMatch{
                                                      symbol: :VarOrTerm,
                                                      string: "?o",
                                                      submatches: [
                                                        %InterpreterTerms.SymbolMatch{
                                                          symbol: :Var,
                                                          string: "?o",
                                                          submatches: [
                                                            %InterpreterTerms.SymbolMatch{
                                                              symbol: :VAR1,
                                                              string: "?o",
                                                              submatches: :none
                                                            }
                                                          ]
                                                        }
                                                      ]
                                                    }
                                                  ]
                                                }
                                              ]
                                            }
                                          ]
                                        }
                                      ]
                                    }
                                  ]
                                },
                                %InterpreterTerms.WordMatch{word: "."}
                              ]
                            }
                          ]
                        },
                        %InterpreterTerms.WordMatch{word: "}"}
                      ]
                    }
                  ]
                }, 
                %InterpreterTerms.SymbolMatch{
                  symbol: :SolutionModifier,
                  string: "",
                  submatches: []
                }
              ]
            },
            %InterpreterTerms.SymbolMatch{
              symbol: :ValuesClause,
              string: "",
              submatches: []
            }
          ]
        }
      ]
    }
  ],
  matched_string: "SELECT * WHERE {?s ?p ?o .}"
}
```

## EbnfParser.Tokenizer.tokenize(string)
Below are some examples of what can be expected when the example string is passed into the method. These input-output pairs should help understand what the tokenizer will produce for a given input. 

### Where to situate the inputs
The strings that the tokenize method consumes are the third part of an EBNF rule, the first is the name and the second is the mandatory splitting character series '::='.

### IRIREF ::= '<' ([^<>\"{}|^`\]-[#x00-#x20])* '>'
#### input
```
> input = "  \t'<' ([^<>\\\"{}|^`\\]-[#x00-#x20])* '>'"
```
#### ouput
```
> input |> EbnfParser.Tokenizer.tokenize
>[
  [
    {:single_quote, "<"},
    {:open_paren},
    {:open_bracket},
    {:negation},
    {:character, "<"},
    {:character, ">"},
    {:character, "\\"},
    {:character, "\""},
    {:character, "{"},
    {:character, "}"},
    {:character, "|"},
    {:character, "^"},
    {:character, "`"},
    {:character, "\\"},
    {:close_bracket},
    {:minus},
    {:open_bracket},
    {:hex_character, 0},
    {:range},
    {:hex_character, 32},
    {:close_bracket},
    {:close_paren},
    {:star},
    {:single_quote, ">"}p
  ]
```

### PNAME_NS ::= PN_PREFIX? ':
#### input
```
> input = "  \tPN_PREFIX? ':'"
```
#### output
```
> [{:symbol, :PN_PREFIX}, {:question_mark}, {:single_quote, ":"}]
```

### BLANK_NODE_LABEL ::= '_:' ( PN_CHARS_U | [0-9] ) ((PN_CHARS|'.')* PN_CHARS)?
#### input
```
> input = "  \t'_:' ( PN_CHARS_U | [0-9] ) ((PN_CHARS|'.')* PN_CHARS)?"
```
#### output
```
> [
    {:single_quote, "_:"},
    {:open_paren},
    {:symbol, :PN_CHARS_U},
    {:pipe},
    {:open_bracket},
    {:character, "0"},
    {:range},
    {:character, "9"},
    {:close_bracket},
    {:close_paren},
    {:open_paren},
    {:open_paren},
    {:symbol, :PN_CHARS},
    {:pipe},
    {:single_quote, "."},
    {:close_paren},
    {:star},
    {:symbol, :PN_CHARS},
    {:close_paren},
    {:question_mark}
  ]
```

### EbnfParser.Parser.tokenize_and_parse(rule)
This method takes the right hand side of an EBNF rule and transforms it into a well understood rule format. That well understood format will then be passed on to the methods validating that a certain input adheres to its form or to the generators that will produce output based on this rule.

#### INTEGER   ::=   [0-9]+
The integer rule has as input:
```
> input = "[0-9]+"
```

The parser generators the following output:
```
> input |> EbnfParser.Parser.tokenize_and_parse
> [ one_or_more: 
    [ bracket_selector: 
      [range: 
        [character: "0", character: "9"]
      ]
    ]
]
```

# TODO's

# File structure
* lib
  * sparql.ex -> still the original file, uses erlang parser generators, will take a SPARQL query and then shove it through the parser
  * parser.ex -> W3C EBNF parser (now also sports the new SPARQL parser maybe needs to be separated)
  * benchmark.ex -> single benchmark function, is completely separated from the rest of the source
  * manipulator.ex -> must read the commit or ask Aad :), has a single method that applies manipulators from the regen.ex file
  * regen.ex -> has 1 method make_regenerator that will produce an object that can take a parsed object and regenerate a string thingie from it again
  * regen
    * constructor.ex has a single overloaded method that makes(x) x elementOf (:paren_group, :maybe_many, :one_of, ...)
    * protocol.ex has a bunch of types, need to check the elixir docs for this one
    * result.ex has a lot of SPARQL in its method names, not sure what it is about
    * status.ex has 1 (complicated) method; inspect(elements, produced_content, syntax)
    * processors = a directory that holds a bunch of ex files each of which is capable of generating 1 specific type of base thingie (Array, Many, Maybe, Some, Choice, ...)
  * manipulators, these know about SPARQL btw
    * basics.ex, has 2 functions that walk solutions and decide which get 'emitted'
    * recipes.ex, has basic example manipulators
    * sparql_query.ex, has 2 manipulators: add_graph(element, graph) and add_sub_graph(element, graph)
  * ebnf parser
    * tokenizer.ex, contains a fully functional W3C EBNF tokenizer
    * parser.ex, does parsing, most of the actions takes place in the smart_x methods, entry point is  tokenize_and_parse( string ) 
    * forms.ex, contains a constant that is equal to the W3C EBNF definition for SPARQL
    * generator_protocol.ex, defines 2 protocols, 1 that creates generators and 1 that emits generated results
    * generator_state.ex, defines helper methods (for state?) is_terminal, drop_spaces, split_off_whitespace, cut_whitespace
    * generator_result.ex, defines helper methods for results, length(generator_result) combine_results(resultA, resultB)
    * interpreter.ex, provides methods that take a string and a rule (as 'parsed' from the EBNF definition passed) and returns possible results
    * intepreter_terms (folder that contains helper methods, each of which is a [type].ex and [typle]_interpreter.ex, only nothing.ex, hex_character.ex, word.ex are not paire 
      * array.ex
      * array_interpreter.ex
      * bracket.ex
      * choice.ex
      * choice_interpreter.ex
      * hex_character.ex
      * many.ex
      * many_interpreter.ex
      * maybe.ex
      * maybe_interpreter.ex
      * minus.ex
      * minus_interpreter.ex
      * not_bracket.ex
      * nothing.ex
      * some.ex
      * some_interpreter.ex
      * symbol.ex
      * symbol_interpreter.ex
      * word.ex

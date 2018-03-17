# Sparql
This module offers a SPARQL parser for elixir.

## Files

* sparql.xrl: contains the rules for tokenizing queries, can be transformed into a sparql.erl file by using :leex
* sparql.erl: a compiled file that contains a tokenizer for sparql queries
* sparql.yrl: contains the rules for parsing tokenized queries into elixir data structures

## Usage
To use in iex simply run
```
> :leex.file('parser-generator/sparql-tokenizer.xrl')
> c("parser-generator/sparql-tokenizer.erl")
```

To tokenize queries you can
```
> :"sparql-tokenizer".string('select ?s ?p ?o where { ?s ?p ?o }')
>
> {:ok,
  [
    {:select, 1},
    {:variable, 1, :s},
    {:variable, 1, :p},
    {:variable, 1, :o},
    {:where, 1},
    {:"{", 1},
    {:variable, 1, :s},
    {:variable, 1, :p},
    {:variable, 1, :o},
    {:"}", 1}
  ], 1}
```

To parse the tokenizers produce first load the parser
```
> :yecc.file('parser-generator/sparql-parser.yrl')
> c("parser-generator/sparql-parser.erl")
```

Extract the tokenized query
```
> {:ok, ps, 1} = :sparql-tokenizer.string('?s ?p ?o.')
```

And the parse it
```
> :"sparql-parser".parse(ps)
```

Or parse a custom tokenized string
```
> :"sparql-parser".parse([{:variable, 1, :s},{:variable, 1, :s}])
```

## Compiling your own tokenizer

## Compiling your own parser

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `sparql` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:sparql, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/sparql](https://hexdocs.pm/sparql).


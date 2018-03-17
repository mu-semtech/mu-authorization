# Sparql
This module offers a SPARQL parser for elixir.

## Files

* sparql.xrl: contains the rules for tokenizing queries, can be transformed into a sparql.erl file by using :leex
* sparql.erl: a compiled file that contains a tokenizer for sparql queries
* sparql.yrl: contains the rules for parsing tokenized queries into elixir data structures

## Usage
To use in iex simply run
```
> :leex.file('../sparql-tokenizer.xrl')
> c("../sparql-ebnf/sparql-tokenizer.erl")
```

To tokenize queries you can
```
> :sparql-tokenizer.string('select * where load graph named ?test insert delete data') 
>
> :sparql-tokenizer.string('select * where load graph named ?test insert delete data http://www.google.com/test \"test 12@3\ntest2\" 1.234 123.443 -123') 
```

To parse the tokenizers produce first load the parser
```
> :yecc.file('sparql-parser.yrl')
> c("sparql-parser.erl")
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


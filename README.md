# Sparql
[![Hex version badge](https://img.shields.io/hexpm/v/repo_example.svg)](https://hex.pm/packages/sparqlex)
[![License badge](https://img.shields.io/hexpm/l/repo_example.svg)](https://github.com/langens-jonathan/sparql/blob/master/LICENSE)
[![Build status badge](https://img.shields.io/circleci/project/github/surgeventures/repo-example-elixir/master.svg)](https://circleci.com/gh/surgeventures/repo-example-elixir/tree/master)
[![Code coverage badge](https://img.shields.io/codecov/c/github/surgeventures/repo-example-elixir/master.svg)](https://codecov.io/gh/surgeventures/repo-example-elixir/branch/master)
This module offers a SPARQL parser for elixir.

## Parsing SPARQL queries

### the simplest case
The most simple SPARQL query (which returns you your entire database) is:
```
SELECT * WHERE { ?s ?p ?o }
```

To parse this with our SPARQL parser you can type this inside your elixir module:
```
'SELECT * WHERE { ?s ?p ?o }' |> Sparql.parse
```
The response of this function will be
```
{:ok,
 {:sparql,
  {:select, {:"select-clause", {:"var-list", :asterisk}},
   {:where,
    [
      {:"same-subject-path", {:subject, {:variable, :s}},
       {:"predicate-list",
        [
          {{:predicate, {:variable, :p}},
           {:"object-list", [object: {:variable, :o}]}}
        ]}}
    ]}}}}
```


## SameSubjectPath
The SPARQL spec defines something that is a SameSubjectPath, in terms of SPARQL itself this could be for instance:
```
?s ?p ?o; ?p2 ?o2
```
which would of course expand to 2 SimpleSubjectPaths
```
?s ?p ?o .
?s ?p2 ?o2 .
```
We provide a helper function that converts these SameSubjectPath's into an array of SimpleSubjectPaths:
```
same_subject_path = {:"same-subject-path", {:subject, {:variable, :s}},
       {:"predicate-list",
        [p
          {{:predicate, {:variable, :p}},
           {:"object-list", [object: {:variable, :o}]}},
          {{:predicate, {:variable, :p2}},
           {:"object-list",
            [object: {:variable, :o2}, object: {:variable, :o3}]}}
        ]}}
simple_subject_path = Sparql.convert_to_simple_triples(same_subject_path)
```
which results in:
```
simple_subject_path = [
  {{:subject, {:variable, :s}}, {:predicate, {:variable, :p}}, {:object, {:object, {:variable, :o}}}},
  {{:subject, {:variable, :s}}, {:predicate, {:variable, :p2}},{:object, {:object, {:variable, :o2}}}},
  {{:subject, {:variable, :s}}, {:predicate, {:variable, :p2}},{:object, {:object, {:variable, :o3}}}}
]
```
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
> {:ok, ps, 1} = :"sparql-tokenizer".string('?s ?p ?o.')
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


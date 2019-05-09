[![Hex version badge](https://img.shields.io/hexpm/v/sparqlex.svg)](https://hex.pm/packages/sparqlex)
[![License badge](https://img.shields.io/hexpm/l/sparqlex.svg)](https://github.com/langens-jonathan/sparql/blob/master/LICENSE)
[![Build status badge](https://img.shields.io/circleci/project/github/langens-jonathan/sparql/master.svg)](https://circleci.com/gh/langens-jonathan/sparql/tree/master)
[![Code coverage badge](https://img.shields.io/codecov/c/github/langens-jonathan/sparql/master.svg)](https://codecov.io/gh/langens-jonathan/sparql/branch/master)

# About SEAS

The SPARQL endpoint authorization service (SEAS) is a layer that is placed in front of a SPARQL endpoint and that rewrites queries on this endpoint based on the session information of the user and the access rights on the data.

The idea is that data is organized into graphs and the access to these graphs is restricted to a certain set of roles. When an INSERT query is sent to the SPARQL endpoint it is intercepted by SEAS. SEAS then loops through its different group specifications and, per specification, distributes the triples across different graphs when they match the graph's constraint. When a service later tries to read data through SEAS, the session is examined and the access criterion of every group is evaluated. If the user has access to the group, the service is allowed to read from the group's graph.

<a id="orgf415637"></a>

## Session information

SEAS receives the current user's session's URI as the `SESSION_ID` variable. This variable can be included in the [`access` rule](#org37ab6e2)'s query. 


<a id="orgbf9e9a0"></a>

## Configuration structure

The configuration file for SEAS contains a `user_groups` function. This returns the entire configuration regarding user groups known to SEAS. The structure of its return type is shown below.


<a id="orgbe398dc"></a>

## GroupSpec

The result of the `user_groups` function is a list of GroupSpec objects. Every such object specifies a group access rule. The properties are: 

-   **name:** the name of the group specification rule
-   **useage:** a list of usage restrictions, from the set `:read`, `:write`, `:read_for_write`. Read and write are obvious, read for write means the data can be read while doing update queries only.
-   **access:** an [access rule](#org37ab6e2)
-   **graphs:** a list of [graph specifications](#orge2d6c30)


<a id="org37ab6e2"></a>

## Access Rules

There are two kinds of access rules, a rule that simply gives access to all users (`AlwaysAccessible`) and a rule that gives access according to a certain (`AccessByQuery`). The `AlwaysAccessible` rule is straight forward, the `AccessByQuery` rule deserves some explaining. It has two properties:

-   **vars:** the variables exported by the query. These will be consumed by the corresponding [`GraphSpecs`](#orge2d6c30) of this rule.
-   **query:** a query string that computes the access for the current user. `<SESSION_URI>` is replaced with the URI of the current session.

Here is an example of such an `access` query:

    PREFIX ext: <http://mu.semte.ch/vocabularies/ext/>
    PREFIX mu: <http://mu.semte.ch/vocabularies/core/>
    SELECT ?session_group ?session_role WHERE {
      <SESSION_ID> ext:sessionGroup/mu:uuid ?session_group;
                   ext:sessionRole ?session_role.
      FILTER( ?session_role = "SuperMegaAdmin" )
    }

If the query returns any results, the user has access. For every set of returned variables, a graph URI is resolved to use in the [`GraphSpecs`](#orge2d6c30) part of the rule.


<a id="orge2d6c30"></a>

## GraphSpec

The `graphs` property of the `GroupSpec` holds and array of `GraphSpec` objects that define which graphs are created and which triples are added to these graphs. Each of these `GraphSpec` object holds the following properties:

-   **graph:** the URI of the graph that should be created. **Note** that this name is appended with the results of the variables of the [`access` rule](#org37ab6e2)'s query. For instance, if the graph URI is `http://myorganization.org/group` and the `vars` array of the `access` rule was `['group_id', 'group_name']`, the graph being created will be something like `http://myorganization.org/group/9b2a5053-0967-425c-a1ee-c9b9bfe38b81/awesome_admins`.
-   **constraint:** the [constraint](#org9c057b3) that determines which triples should be sent to/read from this graph.


<a id="org9c057b3"></a>

## Constraints

A constraint defines which triples will be sent to or read from a graph. This section makes abstraction of whether triples are read from or written to the graph as the principle is the same. Both actions will be described as 'sent to the graph'.
There are two kinds of constraints, a `ResourceFormatConstraint` and a `ResourceConstraint`. The first one receives the `resource_prefix` URI, all URIs starting with this prefix will be sent to the graph. The second, again is more complex. A `ResourceConstraint` is a complex datatype that has the following variables:

-   `resource_types`: a list of type URIs. Resources with this type will be sent to the graph.
-   `predicates`: an additional constraint put on the predicates of such resources that will be sent to the graph. This is optional, the default is `AllPredicates`. This constraint is either an `AllPredicates` or a `NoPredicates` object with an optional `except` array of predicate URIs


<a id="orgf0ab75d"></a>

## Gotchas

-   Authorization examines the graphs the user has access to when writing triples and only writes to graphs a triple belongs to. If no such graph exists, nothing is written to the endpoint. A 201 status code is returned nonetheless.
-   Services should always strive to use SEAS to access the database. If session information is not necessary or should not be applied because the service validates access rights in its own way, the header `mu-auth-sudo` should be set to `true` in the SPARQL request sent to the service.
-   not all services can always use the SEAS because some triple patterns may not be understood by the service's rewrite rules. Note that a service should strive to be compliant with the SEAS service and I have yet to see a case where this is not possible. In a case where it is not possible to use SEAS, the service needs to write it's data to all graphs SEAS would normally write to. This is tough, hence the advice to always use SEAS.

## Logging

Logging can be configured using environment variables.  These properties can be set in the environment block in the docker-compose.yml

Flags which can be either on or off translate the environment variable string to an understood configuration.  Following are considered true: ["true", "yes", "1", "on"], all other strings are considered to be false.

- `LOG_OUTGOING_SPARQL_QUERIES` : Logs outgoing SPARQL queries by printing them on the console
- `INSPECT_OUTGOING_SPARQL_QUERIES`: Logs outgoing SPARQL queries by inspecting them (native string format)
- `LOG_INCOMING_SPARQL_QUERIES`: Logs incoming SPARQL queries by printing them on the console
- `INSPECT_INCOMING_SPARQL_QUERIES`: Logs incoming SPARQL queries by inspecting them (native string format)
- `LOG_SERVER_CONFIGURATION`: Logs some information about the server configuration on boot
- `LOG_ACCESS_RIGHTS` : Logs the incoming access rights
- `INSPECT_ACCESS_RIGHTS_PROCESSING` : Logs the processing of the access rights (verbose debugging)
- `LOG_DELTA_MESSAGES` : Allows logging of delta messages as they're sent to other consumers
- `LOG_DELTA_CLIENT_COMMUNICATION` : Allows logging of the communication caused by the delta system
- `LOG_TEMPLATE_MATCHER_PERFORMANCE` : Emits information regarding use of precalculated templates when analysing queries

## Working around database issues

Compatibility layers can rewrite SPRARQL queries to be in line with the expectations of a triplestore.  Use the `DATABASE_COMPATIBILITY` environment variable.

Sometimes triplestores can be a bit cranky.  mu-authorization tries to create sensible and valid SPARQL queries that express what it intends to achieve.  Although it's still a work in progress, it's the goal to generate clean SPARQL queries.  A triplestore could barf on a query but work with a rewritten version.  The compatibility layer solves that.

Supported values for `DATABASE_COMPATIBILITY` are:

- `Raw` : (default) Don't alter queries.
- `Virtuoso` : Support for Virtuoso.  Currently rewrites DELETE DATA to DELETE WHERE.

# Configuration files

mu-authorization can receive a configuration file for the user groups as well as for the delta system.

A standard mu-semtech stack ensures the configuration files are stored in `./config/authorization/`.  This can then be mounted with the volume `./config/authorization:/config`.


## User groups

The user groups should be accessible either on `/config/user_groups.ex` or in `/config/config.ex`.  In your standard mu-semtech stack you'll probably save this in `./config/authorization/user_groups.ex`.

## Delta

The delta system allows to configure which clients will receive messages.  This file needs to be accessible on `/config/delta.ex`.  In your standard mu-semtech stack you'll probably save this in `./config/deltas.ex`.


# Sparql parsing and rewriting
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
which would expand to 2 SimpleSubjectPaths
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


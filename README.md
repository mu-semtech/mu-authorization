[![Hex version badge](https://img.shields.io/hexpm/v/sparqlex.svg)](https://hex.pm/packages/sparqlex)
[![License badge](https://img.shields.io/hexpm/l/sparqlex.svg)](https://github.com/langens-jonathan/sparql/blob/master/LICENSE)

# mu-authorization (aka SEAS)
The SPARQL endpoint authorization service (SEAS) is a layer that is placed in front of a SPARQL endpoint and that rewrites queries on this endpoint based on the session information of the user and the access rights on the data.

The idea is that data is organized into graphs and the access to these graphs is restricted to a certain set of roles. Each set of roles is associated with a group. When an INSERT query is sent to the SPARQL endpoint it is intercepted by SEAS. SEAS then loops through its different group specifications and, per specification, distributes the triples across different graphs when they match the graph's constraint. When a service later tries to read data through SEAS, the session is examined and the access criterion of every group is evaluated. If the user has access to the group, the service is allowed to read from the group's graph.

## Tutorials
### Add mu-authorization to a stack
Your current stack contains a triplestore (Virtuoso, Blazegraph, ....). Because we will put mu-authorization in front of this triplestore, look up the name of the triplestore service in your `docker-compose.yml` file and rename it to `triplestore`.

E.g.

```yml
services:
  database:
    image: tenforce/virtuoso
    ...
```
should be updated to

```yml
services:
  triplestore:
    image: tenforce/virtuoso
    ...
```

Next, add the mu-authorization service to the `docker-compose.yml` file by adding the following snippet:

```yml
services:
  database:
    image: semtech/mu-authorization:0.6.0-beta.5
    environment:
      MU_SPARQL_ENDPOINT: "http://triplestore:8890/sparql"
    volumes:
      - ./config/authorization:/config

```

This snippet is typically added just above the `triplestore` service.

Create a file `./config/authorization/config.ex` with the following contents:

```elixir
alias Acl.Accessibility.Always, as: AlwaysAccessible
alias Acl.GraphSpec.Constraint.Resource, as: ResourceConstraint
alias Acl.GraphSpec, as: GraphSpec
alias Acl.GroupSpec, as: GroupSpec
alias Acl.GroupSpec.GraphCleanup, as: GraphCleanup

defmodule Acl.UserGroups.Config do
  def user_groups do
    # These elements are walked from top to bottom.  Each of them may
    # alter the quads to which the current query applies.  Quads are
    # represented in three sections: current_source_quads,
    # removed_source_quads, new_quads.  The quads may be calculated in
    # many ways.  The useage of a GroupSpec and GraphCleanup are
    # common.
    [
      # // PUBLIC
      %GroupSpec{
        name: "public",
        useage: [:read],
        access: %AlwaysAccessible{},
        graphs: [ %GraphSpec{
                    graph: "http://mu.semte.ch/graphs/public",
                    constraint: %ResourceConstraint{
                      resource_types: [
                      ]
                    } } ] },

      # // CLEANUP
      #
      %GraphCleanup{
        originating_graph: "http://mu.semte.ch/application",
        useage: [:write],
        name: "clean"
      }
    ]
  end
end
```

Start your stack using `docker-compose up -d`. The authorization service will be created.

*Note that you will probably not see any data in your application until you've correctly configured the authorization rules in `./config/authorization/config.ex`.*

## How-to guides
### Make data publicly available for unauthenticated users
This guide describes how to make data publicly available for unauthenticated users, i.e. users without any information attached to their session.

This guide assumes you've already added mu-authorization to your application as described in "Tutorial: Add mu-authorization to a stack" and that data is currently stored in the graph `http://mu.semte.ch/application`.

First, open `./config/authorization/config.ex` and make sure there is a `%GroupSpec` named `public` in the `user_groups` function like:
```elixir
%GroupSpec{
  name: "public",
  useage: [:read],
  access: %AlwaysAccessible{},
  graphs: [ %GraphSpec{
              graph: "http://mu.semte.ch/graphs/public",
              constraint: %ResourceConstraint{
                resource_types: [
                ]
              } } ] },
```

Next, add all resource types (rdf:Class) that you want to make publicly available to the `resource_types` array in `%ResourceConstraint`.

E.g.

```elixir
%GroupSpec{
  name: "public",
  useage: [:read],
  access: %AlwaysAccessible{},
  graphs: [ %GraphSpec{
              graph: "http://mu.semte.ch/graphs/public",
              constraint: %ResourceConstraint{
                resource_types: [
                  "http://www.w3.org/ns/dcat#Catalog",
                  "http://www.w3.org/ns/dcat#Dataset",
                  "http://www.w3.org/ns/dcat#Distribution"
                ]
              } } ] },
```

Restart the authorization service to pick up the updated config:

```bash
docker-compose restart database
```

Next, move the data in your database from the graph `http://mu.semte.ch/application` to the graph `http://mu.semte.ch/graphs/public`. If your stack contains the [mu-migrations-service](https://github.com/mu-semtech/mu-migrations-service), you can generate a migration like:
```sparql
DELETE {
  GRAPH  <http://mu.semte.ch/application> {
    ?s ?p ?o .
  }
} INSERT {
  GRAPH  <http://mu.semte.ch/graphs/public> {
    ?s ?p ?o .
  }
} WHERE {
  GRAPH  <http://mu.semte.ch/application> {
    ?s a ?type ; ?p ?o .
    VALUES ?type {
        <http://www.w3.org/ns/dcat#Catalog>
        <http://www.w3.org/ns/dcat#Dataset>
        <http://www.w3.org/ns/dcat#Distribution>
    }
  }
}
```

Otherwise, you can execute the SPARQL query above directly on the SPARQL endpoint of your triplestore (e.g. http://localhost:8890/sparql).

Now that the data has been moved in the triplestore, we just need to make sure that anonymous users landing in our application are associated with the `public` group. The default groups for a user are configured through an environment variable on [mu-identifier](https://github.com/mu-semtech/mu-identifier).

Open `docker-compose.yml` and add the following environment variable to the `identifier` service:
```yml
services:
  identifier:
    image: semtech/mu-identifier
    environment:
      DEFAULT_MU_AUTH_ALLOWED_GROUPS_HEADER: "[{\"variables\":[],\"name\":\"public\"}]"
```

Restart your stack using `docker-compose up -d`.

You should now be able to retrieve resources of the specified resource types in your application.

## Reference
### Mounted configuration files
mu-authorization can receive a configuration file for the [user groups](#user-groups-configuration) as well as for the [delta system](#delta-system).

A standard mu-semtech stack ensures the configuration files are stored in `./config/authorization/`.  They can be mounted in the mu-authorization service by adding the following volume in your `docker-compose.yml`:

```yml
services:
  database:
    image: semtech/mu-authorization
    volumes:
      - ./config/authorization:/config
```

The contents of the configuration files is explained in depth in the sections on [authorization configuration](#user-groups-configuration) and [delta system](#delta-system).

### User groups configuration
Authorization in SEAS is based on group access rules. Groups have read and/or write access to one or multiple graphs based on constraints applied on the data. The group(s) access rules that are applicable for a user are determined based on his session information.

The user groups should be accessible either on `/config/user_groups.ex` or in `/config/config.ex`.  In your standard mu-semtech stack you'll probably save this in `./config/authorization/user_groups.ex`.

The most import function in the configuration file for SEAS is the `user_groups` function. This function returns the entire configuration regarding groups known to SEAS. The structure of its return type is explained in detail below.

#### Aliases
To make the configuration more concise and readable, the following aliases can be configured on top of the configuration file:

```elixir
alias Acl.Accessibility.Always, as: AlwaysAccessible
alias Acl.Accessibility.ByQuery, as: AccessByQuery
alias Acl.GraphSpec.Constraint.Resource.AllPredicates, as: AllPredicates
alias Acl.GraphSpec.Constraint.Resource.NoPredicates, as: NoPredicates
alias Acl.GraphSpec.Constraint.ResourceFormat, as: ResourceFormatConstraint
alias Acl.GraphSpec.Constraint.Resource, as: ResourceConstraint
alias Acl.GraphSpec, as: GraphSpec
alias Acl.GroupSpec, as: GroupSpec
alias Acl.GroupSpec.GraphCleanup, as: GraphCleanup
```
#### GroupSpec
The result of the `user_groups` function is a list of GroupSpec objects. Every such object specifies a group access rule.

The properties of a `GroupSpec` are:

- **name:** the name of the group specification rule. Must be unique.
- **useage:** a list of usage restrictions, from the set `:read`, `:write`, `:read_for_write`. `:read` and `:write` are obvious, `:read_for_write` means the data can be read while doing update queries only.
- **access:** defines which users belong to the group. See [Access rules](#access-rules).
- **graphs:** array of [graph specifications](#graphspec) describing the graph(s) in which the data of the group is stored.

It's worth noting that a group access rules doesn't map one-on-one with traditional user groups. On the contrary, a group access rule may be applicable for multiple users groups. For example, a group access rule may specify the access rule for administrators of a company, but there is an administrator user group for each company (e.g. a user group "administrators of company X", a user group "administrators of company Y", etc.).

#### Access rules
An access rule determines whether a user complies with a group specification and to which exact user group(s) he belongs.

There are two kinds of access rules: `AlwaysAccessible` and `AccessByQuery`.

##### AlwaysAccessible
A rule that simply gives access to all users regardless of their session information.

##### AccessByQuery
A rule that gives access according to a certain SPARQL query.

An `AccessByQuery` object has two properties:

- **query:** a SPARQL query string that computes the access for the current user. This query is typically based on the information attached to the user's session. `<SESSION_ID>` can be used as a placeholder in the SPARQL query and is replaced with the URI of the current session at runtime.
- **vars:** array of strings specifying the relevant variables exported/returned by the SPARQL query. The names should exactly match the variable names as returned in the `SELECT` block of the query. The variables will be consumed by the corresponding [`GraphSpecs`](#graphspec) of the group access rule.

An access rule granting access to all users with the role `SuperMegaAdmin` looks as follows:
```elixir
%AccessByQuery{
  vars: ["session_group_id","session_role"],
  query: "PREFIX ext: <http://mu.semte.ch/vocabularies/ext/>
    PREFIX mu: <http://mu.semte.ch/vocabularies/core/>

    SELECT ?session_group ?session_role WHERE {
      <SESSION_ID> ext:sessionGroup/mu:uuid ?session_group_id;
                   ext:sessionRole ?session_role.
      FILTER( ?session_role = \"SuperMegaAdmin\" )
    }
" }
```

Make sure to correctly escape special characters in the query.

If the query returns any results, the user has access. For every set of returned variables, a graph URI is resolved to use in the [`GraphSpecs`](#graphspec) part of the group access rule.

#### GraphSpec
A `GraphSpec` object defines which graph is created and which triples are added to this graph based on constraints on the data.

Each of these `GraphSpec` object holds the following properties:

- **graph:** the (base) URI of the graph that should be created. The URI is appended with the results of the `vars` property of the `GroupSpec`'s [access rule](#access-rule). For instance, if the base graph URI is `http://myorganization.org/group/` and the `vars` array of the access rule is `['group_id', 'group_name']`, the graph being created will be something like `http://myorganization.org/group/9b2a5053-0967-425c-a1ee-c9b9bfe38b81/awesome_admins`.
- **constraint:** the [constraint](#constraints) that determines which triples should be sent to/read from the graph.

The `graphs` property of a `GroupSpec` object contains an array of `GraphSpec` objects. I.e. data accessible for a group may be spread across multiple graphs. The `constraint` property defines in which graph a triple is stored.

#### Constraints
A constraint defines which triples will be sent to or read from a graph. This section makes abstraction of whether triples are read from or written to the graph as the principle is the same. Both actions will be described as 'sent to the graph'.

There are two kinds of constraints, a `ResourceFormatConstraint` and a `ResourceConstraint`.

##### ResourceFormatConstraint
A `ResourceFormatConstraint` defines a constraint on the format of the subject URI of a triple. It has just one property `resource_prefix` which contains a URI. All triples having a subject URI starting with this prefix will be sent to the graph.

In the example below all triples having a subject that starts with `http://data.myorganization.org/` will be sent to the graph `http://mu.semte.ch/graphs/public`.
```elixir
%GraphSpec{
  graph: "http://mu.semte.ch/graphs/public",
  constraint: %ResourceFormatConstraint{
    resource_prefix: "http://data.myorganization.org/"
  } }
```

##### ResourceConstraint
A `ResourceConstraint` allows to put a constraint on the type (rdf:Class) of a resource and/or the predicate of a triple.

A `ResourceConstraint` has the following properties:
- **resource_types**: a list of type URIs. Resources with this type will be sent to the graph.
- **predicates**: an additional constraint put on the predicates of such resources that will be sent to the graph. This property is optional. This constraint is either an `AllPredicates` (default) or a `NoPredicates` object with an optional `except` array of predicate URIs.

In the first example below no properties of a `foaf:Person` will be written to the graph `http://mu.semte.ch/graphs/public`, expect for the person's `foaf:name` and `foaf:accountName`. In the second example all properties of a person will be written to the graph `http://mu.semte.ch/graphs/public` except for the person's `foaf:birthday`.
```elixir
%GraphSpec{
  graph: "http://mu.semte.ch/graphs/public",
  constraint: %ResourceConstraint{
    resource_types: [
      "http://xmlns.com/foaf/0.1/Person" ],
    predicates: %NoPredicates{
      except: [
        "http://xmlns.com/foaf/0.1/name",
        "http://xmlns.com/foaf/0.1/accountName" ] }
  } }
```

```elixir
%GraphSpec{
  graph: "http://mu.semte.ch/graphs/public",
  constraint: %ResourceConstraint{
    resource_types: [
      "http://xmlns.com/foaf/0.1/Person" ],
    predicates: %AllPredicates{
      except: [
        "http://xmlns.com/foaf/0.1/birthday" ] }
  } }
```

### Delta system
For each update query mu-authorization executes it calculates the delta, i.e. which triples have been added and which triples have been removed. These delta messages can be sent to interested clients.

#### Delta clients configuration
The services allows to configure which clients will receive those delta messages. This file needs to be accessible on `/config/delta.ex` inside the docker container.

The delta config file specifies a list of target services to send the delta messages to. The docker service names - as they are known to the mu-authorization service - can be used in the URLs.

```elixir
defmodule Delta.Config do
  def targets do
    [ "http://delta-notifier" ]
  end
end
```

Currently the most used client for delta messages is the [delta-notifier](https://github.com/mu-semtech/delta-notifier#delta-formats) which allows to forward delta requests to other services based on pattern matching.

#### Delta format
The format of the delta messages is explained in the [README of the delta-notifier](https://github.com/mu-semtech/delta-notifier#delta-formats).

### SPARQL endpoint and triplestore
The mu-authorization service is a layer that is placed in front of a SPARQL endpoint. The service makes some assumptions regarding the SPARQL endpoint which can be altered.  The location of the triplestore as well as alterations to support specific triplestores can be configured.

#### Location of the SPARQL endpoint
The default SPARQL endpoint mu-authorization sends SPARQL queries to can be configured with the `MU_SPARQL_ENDPOINT` environment variable.  The default is configured on `http://database:8890/sparql` when running inside a standard container but you can override it in the `docker-compose.yml` file.  In case this variable is not set (as would be the case in a standard development setup), `http://localhost:8890/sparql` will be used as a default setting.

#### Database compatibility
Compatibility layers can rewrite SPARQL queries to be in line with the expectations of a triplestore.  Use the `DATABASE_COMPATIBILITY` environment variable.

Sometimes triplestores can be a bit cranky.  mu-authorization tries to create sensible and valid SPARQL queries that express what it intends to achieve.  Although it's still a work in progress, it's the goal to generate clean SPARQL queries.  A triplestore could barf on a query but work with a rewritten version.  The compatibility layer solves that.

Supported values for `DATABASE_COMPATIBILITY` are:
- `Raw` : (default) Don't alter queries.
- `Virtuoso` : Support for Virtuoso.  Currently rewrites DELETE DATA to DELETE WHERE.

#### SPARQL support
When writing SPARQL queries, you should not query graphs directly (except when in 'sudo'-mode). Mu-authorization will rewrite the query and handle which graphs the user has access to, regardless of the graphs specified in the query.

Mu-authorization implements most of the [SPARQL 1.1 specification](https://www.w3.org/TR/sparql11-query/) but there are some limitations. The following items are not supported by mu-authorization at the moment:
- [inline comments](https://www.w3.org/TR/sparql11-query/#grammarComments) (ex. `# this is a comment`)
- [`DESCRIBE` queries](https://www.w3.org/TR/sparql11-query/#describe) (ex. `DESCRIBE <http://example.org/>`)
- [Graph operations](https://www.w3.org/TR/sparql11-update/#graphManagement) (ex. `DROP GRAPH <http://my.graph>`)

Further in "sudo" mode (with direct access to graphs) the following is not supported:
- [`WITH` in `INSERT/DELETE` queries](https://www.w3.org/TR/2013/REC-sparql11-update-20130321/#deleteInsert)
- `USING` in `INSERT/DELETE` queries

### Logging
Logging can be configured using environment variables. These properties can be set in the environment block in the `docker-compose.yml`.

Flags which can be either on or off translate the environment variable string to an understood configuration.  Following are considered true: [`"true"`, `"yes"`, `"1"`, `"on"`], all other strings are considered to be false.

- `LOG_ERRORS` : Logs the errors, turned on by default
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
- `LOG_OUTGOING_SPARQL_QUERY_RESPONSES` : Logs the responses coming back from the backing triplestore
- `INSPECT_OUTGOING_SPARQL_QUERY_RESPONSES` : Inspects the responses coming back from the backing triplestore
- `LOG_OUTGOING_SPARQL_QUERY_ROUNDTRIP` : Logs both the request and the response to/from the backing triplestore closely together in the logs
- `LOG_WORKLOAD_INFO_REQUESTS` : Logs workload information to the console when it is requested through an http call

### Query timeout configuration
Complex SPARQL queries can take a long time to process and execute. The time mu-authorization is allowed to spend on this processing and execution before timing out can be configured through the following environment variables:

- `QUERY_MAX_PROCESSING_TIME` : Maximum amount of time in milliseconds in which the query should have been processed.  Beyond this time, a 503 response may be sent.  Take into account that, in practice, the actual consumed time might be substantially larger than the configured time.
- `QUERY_MAX_EXECUTION_TIME` : Maximum amount of time in milliseconds in which a single query to the triplestore should have been processed.  If the query takes longer the connection will be closed and the query failure mechanism will be executed potentially executing the same query again.  In case of Virtuoso, a similar setting exists in the virtuoso.ini.

### Database overload recovery
It is possible too many queries are sent to mu-authorization, making it go in overload.  An experimental system exists to limit this overload.

- `DATABASE_OVERLOAD_RECOVERY` : Enables the overload recovery system.  Note that this has not been tested and may not yet help in case of failure.
- `LOG_DATABASE_OVERLOAD_TICK` : Logs a message whenever the database overload system executes a recalculation.  Helps to see if it's still alive.

The service also provides a `/recovery-status` endpoint to get some info on the status of the recovery system.

### Other configuration
Some configuration doesn't fit in previous topics.  These settings are described in this section.

- `ERROR_ON_UNWRITTEN_DATA` : It may be that you request to write manipulations which will not be written to the triplestore because you do not have the necessary rights.  Turning this flag on will make the full manipulation fail in that case.
- `TESTING_AUTH_QUERY_ERROR_RATE`: Chance a query should fail to execute when trying to test fault-tolerance of consuming services, float ranging [0,1]


### Gotchas
-   Authorization examines the graphs the user has access to when writing triples and only writes to graphs a triple belongs to. If no such graph exists, nothing is written to the endpoint. A 201 status code is returned nonetheless.
-   Services should always strive to use SEAS to access the database. If session information is not necessary or should not be applied because the service validates access rights in its own way, the header `mu-auth-sudo` should be set to `true` in the SPARQL request sent to the service.
-   not all services can always use the SEAS because some triple patterns may not be understood by the service's rewrite rules. Note that a service should strive to be compliant with the SEAS service and I have yet to see a case where this is not possible. In a case where it is not possible to use SEAS, the service needs to write it's data to all graphs SEAS would normally write to. This is tough, hence the advice to always use SEAS.
  

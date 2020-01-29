[![Hex version badge](https://img.shields.io/hexpm/v/sparqlex.svg)](https://hex.pm/packages/sparqlex)
[![License badge](https://img.shields.io/hexpm/l/sparqlex.svg)](https://github.com/langens-jonathan/sparql/blob/master/LICENSE)

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
-   **query:** a query string that computes the access for the current user. `<SESSION_ID>` is replaced with the URI of the current session.

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
 - `LOG_OUTGOING_SPARQL_QUERY_RESPONSES` : Logs the responses coming back from the backing triplestore
 - `INSPECT_OUTGOING_SPARQL_QUERY_RESPONSES` : Inspects the responses coming back from the backing triplestore
 - `LOG_OUTGOING_SPARQL_QUERY_ROUNDTRIP` : Logs both the request and the response to/from the backing triplestore closely together in the logs.

## Timeout configuration

A query processing timeout can be configured.  Configuration is documented below:

- `QUERY_MAX_PROCESSING_TIME` : Maximum amount of time in milliseconds in which the query should have been processed.  Beyond this time, a 503 response may be sent.  Take into account that, in practice, the actual consumed time might be substantially larger than the configured time.
- `QUERY_MAX_EXECUTION_TIME`: Maximum amount of time in milliseconds in which a single query to the database should have been processed.  If the query takes longer the connection will be closed and the query failure mechanism will be executed potentially executing the same query again.  In case of Virtuoso, a similar setting exists in the virtuoso.ini.

## Database overload recovery

It is possible too many queries are sent to the database, making it go in overload.  An experimental system exists to limit this overload.

- `DATABASE_OVERLOAD_RECOVERY` : Enables the overload recovery system.  Note that this has not been tested and may not yet help in case of failure
- `LOG_DATABASE_OVERLOAD_TICK` : Logs a message whenever the database overload system executes a recalculation.  Helps to see if it's still alive.

Also see `/recovery-status` for some info on the status of the recovery system.

## Working around database issues

mu-authorization makes some assumptions regarding the SPARQL endpoint which can be altered.  The location of the triplestore as well as alterations to support specific triplestores can be configured.

### Location of the SPARQL endpoint

The default sparql endpoint can be configured with the `MU_SPARQL_ENDPOINT` environment variable.  This is configured to be `http://database:8890/sparql` when running inside a standard container but you can override it in the docker-compose file.  In case this variable is not set (as would be the case in a standard development setup), `http://localhost:8890/sparql` will be used as a default setting.

### Database compatibility

Compatibility layers can rewrite SPARQL queries to be in line with the expectations of a triplestore.  Use the `DATABASE_COMPATIBILITY` environment variable.

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

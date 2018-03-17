Definitions.

ANON           = [\[][\]]
BLANK_NODE     = [_][:][a-zA-Z0-9_\-]+
INT            = (\+|-)?[0-9]+
FLOAT          = (\+|-)?[0-9]+\.[0-9]+((E|e)(\+|-)?[0-9]+)?
ATOM           = :[a-z_]+
NAME           = [a-zA-Z0-9]+
VARIABLE       = [?$][a-zA-Z][a-zA-Z0-9\-_]*
DQSTRING       = [\"](.|[\n\r])+[\"]
SSTRING        = [\'](.|[\n\r])+[\']
REAL_URI       = [a-zA-Z0-9.:]+[:][/][/][.a-zA-Z0-9\/\-]+
                      %% REAL_URI = ^(https?:\/\/)?([\da-z\.-]+)\.([a-z\.]{2,6})([\/\w \.-]*)*\/?
WHITESPACE     = [\s\t\r\n]
STAR           = [*]
SELECT         = [sS][eE][lL][eE][cC][tT]
DISTINCT       = [dD][iI][sS][tT][iI][nN][cC][tT]
REDUCED        = [rR][eE][dD][uU][cC][eE][dD]
AS             = [aA][sS]
BASE           = [bB][aA][sS][eE]
PREFIX         = [pP][rR][eE][fF][iI][xX]
CONSTRUCT      = [cC][oO][nN][sS][tT][rR][uU][cC][Tt]
DESCRIBE       = [dD][eE][sS][cC][rR][iI][bB][eE]
ASK            = [aA][sS][kK]
FROM           = [fF][rR][oO][mM]
NAMED          = [nN][aA][Mm][eE][dD]
WHERE          = [wW][hH][eE][rR][eE]
GROUP          = [gG][rR][oO][uU][pP]
HAVING         = [hH][aA][vV][iI][nN][gG]
ORDER          = [oO][rR][dD][eE][rR]
ASC            = [aA][sS][cC]
DESC           = [dD][eE][sS][cC]
LIMIT          = [lL][iI][mM][iI][tT]
OFFSET         = [oO][fF][fF][sS][eE][tT]
VALUES         = [vV][aA][lL][uU][eE][sS]
LOAD           = [lL][oO][aA][dD]
SILENT         = [sS][iI][lL][eE][nN][tT]
INTO           = [iI][nN][tT][oO]
CLEAR          = [cC][lL][eE][aA][rR]
DROP           = [dD][rR][oO][pP]
CREATE         = [cC][rR][eE][aA][tT][eE]
ADD            = [aA][dD][dD]
TO             = [tT][oO]
MOVE           = [mM][oO][vV][eE]
COPY           = [cC][oO][pP][yY]
INSERT_DATA    = [iI][nN][sS][eE][rR][tT][\s\t\n\r][dD][aA][tT][aA]
DELETE_DATA    = [dD][eE][lL][eE][tT][eE][\s\t\n\r][dD][aA][tT][aA]
DELETE_WHERE   = [dD][eE][lL][eE][tT][eE][\s\t\n\r][wW][hH][eE][rR][eE]
WITH           = [wW][iI][tT][hH]
DELETE         = [dD][eE][lL][eE][tT][eE]
INSERT         = [iI][nN][sS][eE][rR][tT]
USING          = [uU][sS][iI][nN][gG]
DEFAULT        = [dD][eE][fF][aA][uU][lL][tT]
GRAPH          = [gG][rR][aA][pP][hH]
ALL            = [aA][lL][lL]
OPTIONAL       = [oO][pP][tT][iI][oO][nN][aA][lL]
SERVICE        = [sS][eE][rR][vV][iI][cC][eE]
BIND           = [bB][iI][nN][dD]
NIL            = ([nN][iI][lL])||([\(][\)])
%% NIL            = [nN][iI][lL]
UNDEF          = [uU][nN][dD][eE][fF]
MINUS          = [mM][iI][nN][uU][sS]
UNION          = [uU][nN][iI][oO][nN]
FILTER         = [fF][iI][lL][tT][eE][rR]
A              = [a]
LOR            = [|][|]
LAND           = [&][&]
LNOT           = [!][=]
LESS_THAN      = [<][=]
GREATER_THAN   = [>][=]
NOT            = [nN][oO][tT]
IN             = [iI][nN]
STR            = [sS][tT][rR]
LANG           = [lL][aA][nN][gG]
LANGMATCHES    = [lL][aA][nN][gG][mM][aA][tT][cC][hH][eE][sS]
DATATYPE       = [dD][aA][tT][aA][tT][yY][pP][eE]
BOUND          = [bB][oO][uU][nN][dD]
IRI            = [iI][rR][iI]
URI            = [uU][rR][iI]
BNODE          = [bB][nN][oO][dD][eE]
RAND           = [rR][aA][nN][dD]
ABS            = [aA][bB][sS]
CEIL           = [cC][eE][iI][lL]
FLOOR          = [fF][lL][oO][oO][rR]
ROUND          = [rR][oO][uU][nN][dD]
CONCAT         = [cC][oO][nN][cC][aA][tT]
STRLEN         = [sS][tT][rR][lL][eE][nN]
UCASE          = [uU][cC][aA][sS][eE]
LCASE          = [lL][cC][aA][sS][eE]
ENCODE_FOR_URI = [eE][nN][cC][oO][dD][eE][_][fF][oO][rR][_][uU][rR][iI]
CONTAINS       = [cC][oO][nN][tT][aA][iI][nN][sS]
STRSTARTS      = [sS][tT][rR][sS][tT][aA][rR][tT][sS]
STRENDS        = [sS][tT][rR][eE][nN][dD][sS]
STRBEFORE      = [sS][tT][rR][bB][eE][fF][oO][rR][eE]
STRAFTER       = [sS][tT][rR][aA][fF][tT][eE][rR]
YEAR           = [yY][eE][aA][rR]
MONTH          = [mM][oO][nN][tT][hH]
DAY            = [dD][aA][yY]
HOURS          = [hH][oO][uU][rR][sS]
MINUTES        = [mM][iI][nN][uU][tT][eE][sS]
SECONDS        = [sS][eE][cC][oO][nN][dD][sS]
TIMEZONE       = [tT][iI][mM][eE][zZ][oO][nN][eE]
TZ             = [tT][zZ]
NOW            = [nN][oO][wW]
UUID           = [uU][uU][iI][dD]
STRUUID        = [sS][tT][rR][uU][uU][iI][dD]
MD5            = [mM][dD][55]
SHA1           = [sS][hH][aA][11]
SHA256         = [sS][hH][aA][2][5][6]
SHA384         = [sS][hH][aA][3][8][4]
SHA512         = [sS][hH][aA][5][1][2]
COALESCE       = [cC][oO][aA][lL][eE][sS][cC][eE]
IF             = [iI][fF]
STRLANG        = [sS][tT][rR][lL][aA][nN][gG]
STRDT          = [sS][tT][rR][dD][tT]
SAMETERM       = [sS][aA][mM][eE][tT][eE][rR][mM]
ISIRI          = [iI][sS][iI][rR][iI]
ISURI          = [iI][sS][uU][rR][iI]
ISBLANK        = [iI][sS][bB][lL][aA][nN][kK]
ISLITERAL      = [iI][sS][lL][iI][tT][eE][rR][aA][lL]
ISNUMERIC      = [iI][sS][nN][uU][mM][eE][rR][iI][cC]
REGEX          = [rR][eE][gG][eE][xX]
SUBSTR         = [sS][uU][bB][sS][tT][rR]
REPLACE        = [rR][eE][pP][lL][aA][cC][eE]
EXISTS         = [eE][xX][iI][sS][tT][sS]
COUNT          = [cC][oO][uU][nN][tT]
SUM            = [sS][uU][mM]
MIN            = [mM][iI][nN]
MAX            = [mM][aA][xX]
AVG            = [aA][vV][gG]
SAMPLE         = [sS][aA][mM][pP][lL][eE]
GROUP_CONCAT   = [gG][rR][oO][uU][pP][_][cC][oO][nN][cC][aA][tT]
SEPARATOR      = [sS][eE][pP][aA][rR][aA][tT][oO][rR]
RDFTYPE        = [\^][\^]
BOOLEAN_TRUE   = [tT][rR][uU][eE]
BOOLEAN_FALSE  = [fF][aA][lL][sS][eE]

Rules.

{BLANK_NODE}     : { token , {'blank-node', TokenLine , blank_node_to_atom(TokenChars) } } .
{INT}            : { token , { int , TokenLine, TokenChars } } .
{FLOAT}          : { token , { float, TokenLine, TokenChars } } .
{DQSTRING}       : { token , { 'double-quoted-string', TokenLine, TokenChars } } .
{SQSTRING}       : { token , { 'single-quoted-string', TokenLine, TokenChars } } .
{REAL_URI}       : { token , { uri, TokenLine, TokenChars } } .
{BOOLEAN_TRUE}   : { token , { 'true', TokenLine } } .
{BOOLEAN_FALSE}  : { token , { 'false', TokenLine } } .
{RDFTYPE}        : { token , { 'rdf-type', TokenLine } } .
{COUNT}          : { token , { count, TokenLine } } .
{SUM}            : { token , { sum, TokenLine } } .
{MIN}            : { token , { min, TokenLine } } .
{MAX}            : { token , { max, TokenLine } } .
{AVG}            : { token , { avg, TokenLine } } .
{SAMPLE}         : { token , { sample, TokenLine } } .
{GROUP_CONCAT}   : { token , { 'group-concat', TokenLine } } .
{SEPARATOR}      : { token , { separator, TokenLine } } .
{STR}            : { token , { 'str', TokenLine } } .
{LANG}           : { token , { 'lang', TokenLine } } .
{LANGMATCHES}    : { token , { 'langmatches', TokenLine } } .
{DATATYPE}       : { token , { 'datatype', TokenLine } } .
{BOUND}          : { token , { 'bound', TokenLine } } .
{IRI}            : { token , { 'iri', TokenLine } } .
{URI}            : { token , { 'uri', TokenLine } } .
{BNODE}          : { token , { 'bnode', TokenLine } } .
{RAND}           : { token , { 'rand', TokenLine } } .
{ABS}            : { token , { 'abs', TokenLine } } .
{CEIL}           : { token , { 'ceil', TokenLine } } .
{FLOOR}          : { token , { 'floor', TokenLine } } .
{ROUND}          : { token , { 'round', TokenLine } } .
{CONCAT}         : { token , { 'concat', TokenLine } } .
{STRLEN}         : { token , { 'strlen', TokenLine } } .
{UCASE}          : { token , { 'ucase', TokenLine } } .
{LCASE}          : { token , { 'lcase', TokenLine } } .
{ENCODE_FOR_URI} : { token , { 'encode-for-uri', TokenLine } } .
{CONTAINS}       : { token , { 'contains', TokenLine } } .
{STRSTARTS}      : { token , { 'strstarts', TokenLine } } .
{STRENDS}        : { token , { 'strends', TokenLine } } .
{STRBEFORE}      : { token , { 'strbefore', TokenLine } } .
{STRAFTER}       : { token , { 'strafter', TokenLine } } .
{YEAR}           : { token , { 'year', TokenLine } } .
{MONTH}          : { token , { 'month', TokenLine } } .
{DAY}            : { token , { 'day', TokenLine } } .
{HOURS}          : { token , { 'hours', TokenLine } } .
{MINUTES}        : { token , { 'minutes', TokenLine } } .
{SECONDS}        : { token , { 'seconds', TokenLine } } .
{TIMEZONE}       : { token , { 'timezone', TokenLine } } .
{TZ}             : { token , { 'tz', TokenLine } } .
{NOW}            : { token , { 'now', TokenLine } } .
{UUID}           : { token , { 'uuid', TokenLine } } .
{STRUUID}        : { token , { 'struuid', TokenLine } } .
{MD5}            : { token , { 'md5', TokenLine } } .
{SHA1}           : { token , { 'sha1', TokenLine } } .
{SHA256}         : { token , { 'sha256', TokenLine } } .
{SHA384}         : { token , { 'sha384', TokenLine } } .
{SHA512}         : { token , { 'sha512', TokenLine } } .
{COALESCE}       : { token , { 'coalesce', TokenLine } } .
{IF}             : { token , { 'if', TokenLine } } .
{STRLANG}        : { token , { 'strlang', TokenLine } } .
{STRDT}          : { token , { 'strdt', TokenLine } } .
{SAMETERM}       : { token , { 'sameTerm', TokenLine } } .
{ISIRI}          : { token , { 'isIri', TokenLine } } .
{ISURI}          : { token , { 'isUri', TokenLine } } .
{ISBLANK}        : { token , { 'isBlank', TokenLine } } .
{ISLITERAL}      : { token , { 'isLiteral', TokenLine } } .
{ISNUMERIC}      : { token , { 'isNumeric', TokenLine } } .
{REGEX}          : { token , { 'regex', TokenLine } } .
{SUBSTR}         : { token , { 'substr', TokenLine } } .
{REPLACE}        : { token , { 'replace', TokenLine } } .
{EXISTS}         : { token , { 'exists', TokenLine } } .
{LESS_THAN}      : { token, { 'less-than', TokenLine } } .
{GREATER_THAN}   : { token, { 'greater-than', TokenLine } } .
{NOT}            : { token, { 'not', TokenLine } } .
{IN}             : { token, { in, TokenLine } } .
{OPTIONAL}       : { token, { optional, TokenLine } } .
{SERVICE}        : { token, { service, TokenLine } } .
{BIND}           : { token, { bind, TokenLine } } .
{NIL}            : { token, { nil, TokenLine } } .
{ANON}           : { token, { anon, TokenLine } } .
{UNDEF}          : { token, { undef, TokenLine } } .
{MINUS}          : { token, { minus, TokenLine } } .
{UNION}          : { token, { union, TokenLine } } .
{FILTER}         : { token, { filter, TokenLine } } .
{WITH}           : { token, { with, TokenLine } } .
{DELETE}         : { token, { delete, TokenLine } } .
{INSERT}         : { token, { insert, TokenLine } } .
{USING}          : { token, { using, TokenLine } } .
{DEFAULT}        : { token, { default, TokenLine } } .
{GRAPH}          : { token, { graph, TokenLine } } .
{ALL}            : { token, { all, TokenLine } } .
{INSERT_DATA}    : { token, { 'insert-data', TokenLine } } .
{DELETE_DATA}    : { token, { 'delete-data', TokenLine } } .
{DELETE_WHERE}   : { token, { 'delete-where', TokenLine } } .
{DROP}           : { token, { drop, TokenLine } } .
{CREATE}         : { token, { create, TokenLine } } .
{ADD}            : { token, { add, TokenLine } } .
{TO}             : { token, { to, TokenLine } } .
{MOVE}           : { token, { move, TokenLine } } .
{COPY}           : { token, { copy, TokenLine } } .
{SELECT}         : { token, { select, TokenLine } } .
{DISTINCT}       : { token, { distinct, TokenLine } } .
{REDUCED}        : { token, { reduced, TokenLine } } .
{AS}             : { token, { as, TokenLine } } .
{ASK}            : { token, { ask, TokenLine } } .
{BASE}           : { token, { base, TokenLine } } .
{FROM}           : { token, { from, TokenLine } } .
{NAMED}          : { token, { named, TokenLine } } .
{WHERE}          : { token, { where, TokenLine } } .
{GROUP}          : { token, { group, TokenLine } } .
{HAVING}         : { token, { having, TokenLine } } .
{ORDER}          : { token, { order, TokenLine } } .
{ASC}            : { token, { asc, TokenLine } } .
{DESC}           : { token, { desc, TokenLine } } .
{LIMIT}          : { token, { limit, TokenLine } } .
{OFFSET}         : { token, { offset, TokenLine } } .
{VALUES}         : { token, { values, TokenLine } } .
{LOAD}           : { token, { load, TokenLine } } .
{SILENT}         : { token, { silent, TokenLine } } .
{INTO}           : { token, { into, TokenLine } } .
{CLEAR}          : { token, { clear, TokenLine } } .
{PREFIX}         : { token, { prefix, TokenLine } } .
{DESCRIBE}       : { token, { describe, TokenLine } } .
{CONSTRUCT}      : { token, { construct, TokenLine } } .
{STAR}           : { token, { asterisk, TokenLine } } .
{WHITESPACE}+    : skip_token .
{VARIABLE}       : { token, { variable, TokenLine, variable_to_atom(TokenChars) } } .
\(               : { token, { '(', TokenLine } } .
\)               : { token, { ')', TokenLine } } .
\{               : { token, { '{', TokenLine } } .
\}               : { token, { '}', TokenLine } } .
\,               : { token, { ',', TokenLine } } .
\|               : { token, { '|', TokenLine } } .
\^               : { token, { '^', TokenLine } } .
\/               : { token, { '/', TokenLine } } .
\+               : { token, { '+', TokenLine } } .
\?               : { token, { '?', TokenLine } } .
\!               : { token, { '!', TokenLine } } .
\[               : { token, { '[', TokenLine } } .
\]               : { token, { ']', TokenLine } } .
\=               : { token, { '=', TokenLine } } .
\>               : { token, { '>', TokenLine } } .
\<               : { token, { '<', TokenLine } } .
\:               : { token, { ':', TokenLine } } .
\.               : { token, { '.', TokenLine } } .
{A}              : { token, { a, TokenLine } } .
{LAND}           : { token, { 'logical-and', TokenLine } } .
{LOR}            : { token, { 'logical-or', TokenLine } } .
{LNOT}           : { token, { 'logical-not'}} .
{NAME}           : { token , { name, TokenLine, TokenChars } } .

Erlang code.

%% to_atom([$:|Chars]) ->
%%     list_to_atom(Chars).

tail([_H|T]) ->
    T.

variable_to_atom(FullName) ->
    list_to_atom(tail(FullName)).

blank_node_to_atom(BlackNode) ->
    list_to_atom(tail(tail(BlackNode))).

defmodule Updates.QueryAnalyzer do
  alias Updates.QueryConstructors
  alias Updates.QueryAnalyzer.P, as: QueryAnalyzerProtocol
  alias InterpreterTerms.SymbolMatch, as: Sym
  alias InterpreterTerms.WordMatch, as: Word
  alias Updates.QueryAnalyzer.Iri, as: Iri
  alias Updates.QueryAnalyzer.Variable, as: Var
  alias Updates.QueryAnalyzer.String, as: Str
  alias Updates.QueryAnalyzer.Boolean, as: Bool
  alias Updates.QueryAnalyzer.NumericLiteral, as: Number
  alias Updates.QueryAnalyzer.Types.Quad, as: Quad

  require Logger
  require ALog

  @type quad_change_key :: :insert | :delete
  @type quad_change :: {quad_change_key, [Quad.t()]}
  @type quad_changes :: [quad_change]
  @type value :: Iri.t() | Var.t() | Bool.t() | Str.t() | Number.t()
  @type options :: map

  @moduledoc """
  Performs analysis on a sparql InsertData, DeleteData, DeleteWhere,
  Modify, or Construct query and yields the triples to insert in
  quad-format.

  Our analyzer assumes no blank nodes to exist in the query.

  Our analyzer is written explicitly.  If there is something we
  do not support yet, it should fall through and yield an error.
  As such, we're matching on the SymbolMatch's symbols which we
  understand, rather than providing a fall through which loops
  over each submatch for models we haven't understood.

  The analyzer consumes the following EBNF terms.  Some forms may have
  children which are not parsed.  Check the full tree to be sure.
  EBNF forms which explicitly aren't handled have received
  double-dashes (--) in front and after the used term in the EBNF.
  When forms are not handled, an error will be thrown.  The behaviour
  is not yet supported but might be in the future.  Other forms are
  handled, but not parsed.  These forms are placed between
  double-plusses (++) in front and after the used term in the EBNF.
  This means the form is not parsed, but is stored as a whole in the
  analyzed query.  The WHERE clause is a good example of something we
  don't expect to parse for update queries.

  Terms which yield quads or quad_changes:

  - InsertData ::= 'INSERT' 'DATA' QuadData
  - QuadData ::= '{' Quads '}'
  - Quads ::= TriplesTemplate? (QuadsNotTriples '.'? TriplesTemplate ?)*
  - QuadsNotTriples ::= 'GRAPH' VarOrIri '{' TriplesTemplate? '}'
  - TriplesTemplate ::= TriplesSameSubject ( '.' TriplesTemplate? )?
  - TriplesSameSubject ::= VarOrTerm PropertyListNotEmpty | --TriplesNode-- --PropertyList--
  - PropertyListNotEmpty ::= Verb ObjectList ( ';' ( Verb ObjectList )? )*
  - ObjectList ::= Object (',' Object)*
  - Object ::= GraphNode

  Terms which yield primitive values (variables included)
  - VarOrIri ::= Var | iri
  - Var ::= VAR1 | VAR2
  - iri ::= IRIREF | PrefixedName
  - PrefixedName ::= PNAME_LN | PNAME_NS
  - VarOrTerm ::= Var | GraphTerm
  - GraphTerm ::= iri | RDFLiteral | NumericLiteral | BooleanLiteral | --BlankNode-- | --NIL--
  - RDFLiteral ::= String ( LANGTAG | ( '^^' iri ) )?
  - GraphNode ::= VarOrTerm | --TriplesNode--
  - Verb ::= VarOrIri | 'a'
  - BooleanLiteral ::= 'true' | 'false'
  - String ::= STRING_LITERAL1 | STRING_LITERAL2 | STRING_LITERAL_LONG1 | STRING_LITERAL_LONG2
  - NumericLiteralUnsigned ::= INTEGER | DECIMAL | DOUBLE
  - NumericLiteralPositive ::= INTEGER_POSITIVE | DECIMAL_POSITIVE | DOUBLE_POSITIVE
  - NumericLiteralNegative ::= INTEGER_NEGATIVE | DECIMAL_NEGATIVE | DOUBLE_NEGATIVE
  - IRIREF
  - PNAME_NS
  - INTEGER
  - DECIMAL
  - DOUBLE
  - INTEGER_POSITIVE
  - DECIMAL_POSITIVE
  - DOUBLE_POSITIVE
  - INTEGER_NEGATIVE
  - DECIMAL_NEGATIVE
  - DOUBLE_NEGATIVE

  Terms which lead us to the supported match clauses:
  - Sparql ::= --QueryUnit-- | UpdateUnit
  - UpdateUnit ::= Update
  - Update ::= Prologue ( Update1 ( ';' Update )? )?
  - Prologue ::= ( BaseDecl | PrefixDecl )*
  - BaseDecl ::= 'BASE' IRIREF
  - PrefixDecl ::= 'PREFIX' PNAME_NS IRIREF

  - Update1 ::= --Load-- | --Clear-- | --Drop-- | Add | --Move-- | --Copy-- | --Create-- | InsertData | DeleteData | DeleteWhere | Modify

  Terms which were added for DELETE DATA
  - DeleteData ::= 'DELETE' 'DATA' QuadData

  Terms which were added for INSERT WHERE
  - [ ] Modify ::= ( 'WITH' iri )? ( DeleteClause InsertClause? | InsertClause ) UsingClause* 'WHERE' ++GroupGraphPattern++
  - InsertClause ::= 'INSERT' QuadPattern
  - [ ] UsingClause* ::= 'USING' ( iri | 'NAMED' iri )
  - QuadPattern ::= '{' Quads '}'

  Terms which were added for DELETE WHERE
  - DeleteClause ::= 'DELETE' QuadPattern",
  - DeleteWhere ::= 'DELETE' 'WHERE' QuadPattern"

  Terms which were added for GRAPH operations
  - Add ::= 'ADD' 'SILENT'? GraphOrDefault 'TO' GraphOrDefault",
  - GraphOrDefault ::= --'DEFAULT'-- | 'GRAPH'? iri",
  """

  @spec quad_changes(Parser.query()) :: quad_changes
  def quad_changes(query) do
    quad_changes(query, %{})
  end

  @spec quad_changes(Parser.query(), options) :: quad_changes
  def quad_changes(%Sym{symbol: :Sparql, submatches: [match]}, options) do
    # Sparql ::= QueryUnit | UpdateUnit
    case match do
      %Sym{symbol: :UpdateUnit} -> quad_changes(match, options)
    end
  end

  def quad_changes(%Sym{symbol: :UpdateUnit, submatches: [match]}, options) do
    # UpdateUnit ::= Update
    case match do
      %Sym{symbol: :Update} -> quad_changes(match, options)
    end
  end

  def quad_changes(%Sym{symbol: :Update, submatches: matches}, options) do
    # Update ::= Prologue ( Update1 ( ';' Update )? )?
    case matches do
      [_prologue_sym] ->
        []

      [prologue_sym, update_one_sym] ->
        new_options = import_prologue(prologue_sym, options)
        quad_changes(update_one_sym, new_options)

      [prologue_sym, update_one_sym, %Word{}, update_sym] ->
        new_options = import_prologue(prologue_sym, options)

        Quad.append(
          quad_changes(update_one_sym, new_options),
          quad_changes(update_sym, new_options)
        )
    end
  end

  def quad_changes(%Sym{symbol: :Update1, submatches: [match]}, options) do
    # Update1 ::= --Load-- | --Clear-- | --Drop-- | Add | --Move-- | --Copy-- | --Create-- | InsertData | DeleteData | DeleteWhere | Modify

    case match do
      %Sym{symbol: :InsertData} -> quad_changes(match, options)
      %Sym{symbol: :DeleteData} -> quad_changes(match, options)
      %Sym{symbol: :DeleteWhere} -> quad_changes(match, options)
      %Sym{symbol: :Modify} -> quad_changes(match, options)
      %Sym{symbol: :Add} -> quad_changes(match, options)
    end
  end

  def quad_changes(%Sym{symbol: :InsertData, submatches: matches}, options) do
    # InsertData ::= 'INSERT' 'DATA' QuadData

    # scan matches to find the single QuadData element:
    quad_data =
      Enum.find(matches, fn
        %Sym{symbol: :QuadData} -> true
        %Word{} -> false
      end)

    [insert: quads(quad_data, options)]
  end

  def quad_changes(%Sym{symbol: :DeleteData, submatches: matches}, options) do
    # DeleteData ::= 'DELETE' 'DATA' QuadData

    # scan matchesto find the single QuadData element:
    quad_data =
      Enum.find(matches, fn
        %Sym{symbol: :QuadData} -> true
        %Word{} -> false
      end)

    [delete: quads(quad_data, options)]
  end

  def quad_changes(%Sym{symbol: :Add, submatches: matches}, options) do
    # Add ::= 'ADD' 'SILENT'? GraphOrDefault 'TO' GraphOrDefault",

    [from_graph, to_graph] =
      case matches do
        [%Word{word: "ADD"}, %Word{word: "SILENT"}, from, %Word{word: "TO"}, to] ->
          [from, to]

        [%Word{word: "ADD"}, from, %Word{word: "TO"}, to] ->
          [from, to]
      end
      |> Enum.map(&quads(&1, options))

    # TODO: this makes no sense for non-sudo queries.  Hence we could
    # scrapt execution for any non-sudo queries

    # TODO: based on the particular graph we select from, and the name
    # of the graph we push content to, we could intelligently detect
    # where to push the data to.  There is currently no worked out
    # concept of executing a sudo query for a particular user, but
    # such case could present us with some interesting base
    # contsructs.

    authorization_groups = Map.get(options, :authorization_groups)

    cond do
      from_graph == to_graph ->
        # Noop if from_graph is to_graph
        # TODO: should we signal all copied triples as delta in this case?
        []

      authorization_groups == :sudo ->
        # Select all quads from from_graph and convert them to to_graph
        quads =
          from_graph
          |> QueryConstructors.make_select_triples_from_graph_query()
          |> SparqlServer.Router.HandlerSupport.manipulate_select_query(
            authorization_groups,
            :read_for_write
          )
          # TODO: add connection info
          |> SparqlClient.execute_parsed(query_type: :read_for_write)
          |> SparqlClient.response()
          |> SparqlClient.extract_results()
          |> convert_spo_results_to_quads(to_graph)

        [{:insert, quads}]

      true ->
        # There is currently no solution for non sudo queries.
        []
    end
  end

  def quad_changes(%Sym{symbol: :Modify, submatches: matches}, options) do
    # [ ] Modify ::= ( 'WITH' iri )? ( DeleteClause InsertClause? | InsertClause ) UsingClause* 'WHERE' ++GroupGraphPattern++

    group_graph_pattern_sym =
      %Sym{} =
      Enum.find(matches, fn
        %Sym{symbol: :GroupGraphPattern} -> true
        _ -> false
      end)

    # We disallow the explicit use of USING in the construct queries.
    # Users should never specify them, they should be calculated.
    _using_clause_syms =
      [] =
      Enum.filter(matches, fn
        %Sym{symbol: :UsingClause} -> true
        _ -> false
      end)

    # we may have either or both of delete_clause_sym and
    # insert_clause_sym.
    delete_clause_sym =
      Enum.find(matches, fn
        %Sym{symbol: :DeleteClause} -> true
        _ -> false
      end)

    insert_clause_sym =
      Enum.find(matches, fn
        %Sym{symbol: :InsertClause} -> true
        _ -> false
      end)

    # The WITH clause provides a default for both the INSERT and the
    # SELECT portion of our Modify.
    {_, options} =
      case matches do
        [%Word{word: "WITH"}, iri_sym | rest] ->
          {rest, update_options_for_with(iri_sym, options)}

        _ ->
          {matches, options}
      end

    # Our options are set, it's time to build the model for our insert
    # templates
    delete_clause_quads =
      if delete_clause_sym do
        quads(delete_clause_sym, options)
      end

    insert_clause_quads =
      if insert_clause_sym do
        quads(insert_clause_sym, options)
      end

    # Collect all information to construct the SELECT query, by
    # converting the using clauses, adding them to our options,
    # discovering the necessary SELECT variables, and constructing a
    # new SELECT query.
    delete_quads_statement =
      if delete_clause_quads do
        [
          {:delete,
           fill_in_triples_template(delete_clause_quads, group_graph_pattern_sym, options)}
        ]
      else
        []
      end

    insert_quads_statement =
      if insert_clause_quads do
        [
          {:insert,
           fill_in_triples_template(insert_clause_quads, group_graph_pattern_sym, options)}
        ]
      else
        []
      end

    ALog.di(delete_quads_statement, "delete quads statement")
    ALog.di(insert_quads_statement, "insert quads statement")

    (delete_quads_statement ++ insert_quads_statement)
    |> ALog.di("All updated quads")
  end

  def quad_changes(%Sym{symbol: :DeleteWhere, submatches: matches}, options) do
    # DeleteWhere ::= 'DELETE' 'WHERE' QuadPattern"
    quad_pattern = Enum.find(matches, &match?(%Sym{symbol: :QuadPattern}, &1))

    # The quad_pattern is more constrained than the GroupGraphPattern.
    # However, many keys are different.  The simplest way for us to
    # convert from the less expressive variant to the more expressive
    # variant is seemingly to simply convert the QuadPattern clause to
    # GroupGraphPattern by regenerating the output and interpreting it
    # as a GroupGraphPattern

    # TODO: Verify the above reasoning is fully sound as per EBNF.  An
    # initial reading showed it to be correct, yet there may be edge
    # cases still.  This can be verified by comparing the EBNF for
    # QuadPattern with the EBNF for GroupGraphPattern

    group_graph_pattern = Manipulator.Transform.quad_pattern_to_group_graph_pattern(quad_pattern)

    template = quads(quad_pattern, options)

    [{:delete, fill_in_triples_template(template, group_graph_pattern, options)}]
  end

  @spec quads(Parser.query(), options) :: [Quad.t()]
  def quads(%Sym{symbol: :DeleteClause, submatches: matches}, options) do
    # DeleteClause ::= 'DELETE' QuadPattern",

    [%Word{}, %Sym{symbol: :QuadPattern} = subsym] = matches
    quads(subsym, options)
  end

  def quads(%Sym{symbol: :InsertClause, submatches: matches}, options) do
    # InsertClause ::= 'INSERT' QuadPattern

    [%Word{}, %Sym{symbol: :QuadPattern} = subsym] = matches
    quads(subsym, options)
  end

  def quads(%Sym{symbol: :QuadPattern, submatches: matches}, options) do
    #  QuadPattern ::= '{' Quads '}'

    # Find the Quads symbol and dispatch to it
    Enum.find(matches, fn
      %Sym{symbol: :Quads} -> true
      %Word{} -> false
    end)
    |> quads(options)
  end

  def quads(%Sym{symbol: :GraphOrDefault, submatches: submatches}, options) do
    # GraphOrDefault ::= --'DEFAULT'-- | 'GRAPH'? iri
    case submatches do
      [%Word{word: "GRAPH"}, iri] -> iri
      [%Sym{symbol: :iri} = iri] -> iri
    end
    |> primitive_value(options)
    |> QueryAnalyzerProtocol.to_solution_sym()
  end

  def quads(%Sym{symbol: :QuadData, submatches: matches}, options) do
    # QuadData ::= '{' Quads '}'

    # scan matches to find the single Quads element:
    quads =
      Enum.find(matches, fn
        %Sym{symbol: :Quads} -> true
        %Word{} -> false
      end)

    quads(quads, options)
  end

  def quads(%Sym{symbol: :Quads, submatches: matches}, options) do
    # Quads ::= TriplesTemplate? (QuadsNotTriples '.'? TriplesTemplate ?)*

    # dispatch anything which is a TriplesTemplate or QuadsNotTriples
    matches
    |> Enum.filter(fn
      %Sym{symbol: :TriplesTemplate} -> true
      %Sym{symbol: :QuadsNotTriples} -> true
      %Word{} -> false
    end)
    |> Enum.map(fn x -> quads(x, options) end)
    |> Enum.reduce(&Quad.append/2)
  end

  def quads(%Sym{symbol: :QuadsNotTriples, submatches: matches}, options) do
    # QuadsNotTriples ::= 'GRAPH' VarOrIri '{' TriplesTemplate? '}'

    # Get the VarOrIri URI (which must be a URI-like symbol) and the
    # TriplesTemplate.  Dispatch to the TriplesTemplate if that
    # exists.
    graph_sym =
      Enum.find(matches, fn
        %Sym{symbol: :VarOrIri} -> true
        %Sym{symbol: :TriplesTemplate} -> false
        %Word{} -> false
      end)

    triples_template_sym =
      Enum.find(matches, false, fn
        %Sym{symbol: :TriplesTemplate} -> true
        %Sym{symbol: :VarOrIri} -> false
        %Word{} -> false
      end)

    # triplesTemplateSym may be false.  In that case, we don't need to
    # push anything special.  Otherwise, we need to analyze the
    # VarOrIri for it's primitive_value (which should yield a URI-like
    # object), and push that as the default context to our options.
    if triples_template_sym do
      graph_uri =
        graph_sym
        |> primitive_value(options)

      # |> is_uri_like!  # <<-- we have started supporting
      # variables, the EBNF is not sufficiently expressive

      quads(triples_template_sym, %{options | default_graph: graph_uri})
    end
  end

  def quads(%Sym{symbol: :TriplesTemplate, submatches: matches}, options) do
    # TriplesTemplate ::= TriplesSameSubject ( '.' TriplesTemplate? )?

    same_subject_sym =
      Enum.find(matches, fn
        %Sym{symbol: :TriplesSameSubject} -> true
        %Sym{symbol: :TriplesTemplate} -> false
        %Word{} -> false
      end)

    triples_template_sym =
      Enum.find(matches, false, fn
        %Sym{symbol: :TriplesTemplate} -> true
        %Sym{symbol: :TriplesSameSubject} -> false
        %Word{} -> false
      end)

    # first execute TriplesSameSubject, then execute TriplesTemplate
    if triples_template_sym do
      Quad.append(
        quads(same_subject_sym, options),
        quads(triples_template_sym, options)
      )
    else
      quads(same_subject_sym, options)
    end
  end

  def quads(%Sym{symbol: :TriplesSameSubject, submatches: matches}, options) do
    # TriplesSameSubject ::= VarOrTerm PropertyListNotEmpty | --TriplesNode-- --PropertyList--

    # We assume the right side of this will not be received.  We don't
    # handle blank nodes.

    var_or_term_sym =
      Enum.find(matches, fn
        %Sym{symbol: :VarOrTerm} -> true
        %Sym{symbol: :PropertyListNotEmpty} -> false
      end)

    property_list_not_empty_sym =
      Enum.find(matches, fn
        %Sym{symbol: :PropertyListNotEmpty} -> true
        %Sym{symbol: :VarOrTerm} -> false
      end)

    # We should get the URI for VarOrTerm (of which we know it should
    # not yield a variable), push it into our options as the current
    # subject, and further calculate the quads.
    subject_uri =
      var_or_term_sym
      |> primitive_value(options)

    # |> is_uri_like! # <-- we now support Variables and the EBNF is
    # not sufficiently expressive to block this.

    new_options = Map.put(options, :subject, subject_uri)

    quads(property_list_not_empty_sym, new_options)
  end

  def quads(%Sym{symbol: :PropertyListNotEmpty, submatches: matches}, options) do
    # PropertyListNotEmpty ::= Verb ObjectList ( ';' ( Verb ObjectList )? )*

    # Search for any combination of Verb ObjectList, and yield these as tuples
    verb_object_sym_combinations =
      Enum.reduce(matches, [], fn
        %Sym{symbol: :Verb} = elt, list ->
          [{elt} | list]

        %Sym{symbol: :ObjectList} = object_list, [{%Sym{symbol: :Verb} = verb} | rest] ->
          [{verb, object_list} | rest]

        %Word{}, acc ->
          acc
      end)

    # Walk over each combination
    # -> calculate the new predicate
    # -> get quads for objectlist, assuming the new predicate
    Enum.reduce(verb_object_sym_combinations, [], fn
      {%Sym{symbol: :Verb} = verb, %Sym{symbol: :ObjectList} = object_list}, acc ->
        predicate =
          verb
          |> primitive_value(options)

        new_options = Map.put(options, :predicate, predicate)
        new_quads = quads(object_list, new_options)

        Quad.append(acc, new_quads)
    end)
  end

  def quads(%Sym{symbol: :ObjectList, submatches: matches}, options) do
    # ObjectList ::= Object ( ',' Object )*

    # Filter out every Object
    Enum.filter(matches, fn
      %Sym{symbol: :Object} -> true
      %Word{} -> false
    end)
    |> Enum.map(fn sym -> quads(sym, options) end)
    |> Enum.reduce(&Quad.append/2)
  end

  def quads(%Sym{symbol: :Object, submatches: [%Sym{symbol: :GraphNode} = graph_node]}, options) do
    # Object ::= GraphNode

    # Get the primitive value for the graphNode and emit a triple containing it
    object =
      graph_node
      |> primitive_value(options)

    quad =
      options
      |> Map.put(:object, object)
      |> Quad.from_options()

    [quad]
  end

  @spec primitive_value(Parser.query(), options) :: value
  def primitive_value(%Sym{symbol: :Verb, submatches: [%Word{}]}, _) do
    # Verb ::= VarOrIri | 'a'
    Iri.make_a()
  end

  def primitive_value(%Sym{symbol: :Verb, submatches: [submatch]}, options) do
    # Verb ::= VarOrIri | 'a'
    primitive_value(submatch, options)
  end

  def primitive_value(%Sym{symbol: :VarOrIri, submatches: [submatch]}, options) do
    # VarOrIri ::= Var | iri

    case submatch do
      %Sym{symbol: :iri} -> submatch
      %Sym{symbol: :Var} -> submatch
    end
    |> primitive_value(options)
  end

  def primitive_value(%Sym{symbol: :iri, submatches: [submatch]}, options) do
    # iri ::= IRIREF | PrefixedName
    case submatch do
      %Sym{symbol: :IRIREF} ->
        primitive_value(submatch, options)

      %Sym{symbol: :PrefixedName} ->
        primitive_value(submatch, options)
    end
  end

  def primitive_value(%Sym{symbol: :IRIREF, string: string}, options) do
    Iri.from_iri_string(string, options)
  end

  def primitive_value(%Sym{symbol: :PrefixedName, submatches: [prefix_sym]}, options) do
    # PrefixedName ::= PNAME_LN | PNAME_NS

    # Dispatch further down
    primitive_value(prefix_sym, options)
  end

  def primitive_value(%Sym{symbol: :PNAME_LN, string: str}, options) do
    # PNAME_LN
    Iri.from_prefix_string(str, options)
  end

  def primitive_value(%Sym{symbol: :PNAME_NS, string: str}, options) do
    # PNAME_NS
    str
    |> String.trim(" ")
    |> Iri.from_prefix_string(options)
  end

  def primitive_value(%Sym{symbol: :Var, submatches: [submatch]}, options) do
    # Var ::= VAR1 | VAR2

    primitive_value(submatch, options)
  end

  def primitive_value(%Sym{symbol: var_sym, string: string, submatches: :none}, _options)
      when var_sym in [:VAR1, :VAR2] do
    # VAR1
    # VAR2

    string
    |> Var.from_string()
  end

  def primitive_value(%Sym{symbol: :VarOrTerm, submatches: [submatch]}, options) do
    # VarOrTerm ::= Var | GraphTerm
    case submatch do
      %Sym{symbol: :GraphTerm} -> submatch
      %Sym{symbol: :Var} -> submatch
    end
    |> primitive_value(options)
  end

  def primitive_value(%Sym{symbol: :GraphTerm, submatches: [submatch]}, options) do
    # GraphTerm ::= iri | RDFLiteral | NumericLiteral | BooleanLiteral | --BlankNode-- | --NIL--

    case submatch do
      %{symbol: :iri} -> primitive_value(submatch, options)
      %{symbol: :RDFLiteral} -> primitive_value(submatch, options)
      %{symbol: :NumericLiteral} -> primitive_value(submatch, options)
      %{symbol: :BooleanLiteral} -> primitive_value(submatch, options)
    end
  end

  def primitive_value(%Sym{symbol: :RDFLiteral, submatches: submatches}, options) do
    # RDFLiteral ::= String ( LANGTAG | ( '^^' iri ) )?

    # We can use the primitives for String and iri, but we have to combine it ourselves
    %Str{str: simple_string} =
      string_primitive =
      submatches
      |> List.first()
      |> primitive_value(options)

    case submatches do
      [_, %Sym{symbol: :LANGTAG, string: str}] ->
        lang = String.slice(str, 1, String.length(str) - 1)
        Str.from_langstring(simple_string, lang)

      [_, %Word{}, %Sym{symbol: :iri} = type_sym] ->
        type = primitive_value(type_sym, options)
        Str.from_typestring(simple_string, type)

      [_] ->
        string_primitive
    end
  end

  def primitive_value(%Sym{symbol: :GraphNode, submatches: [submatch]}, options) do
    # GraphNode ::= VarOrTerm | --TriplesNode--

    # Dispatch to VarOrTerm, we don't support blank nodes
    case submatch do
      %Sym{symbol: :VarOrTerm} -> primitive_value(submatch, options)
    end
  end

  def primitive_value(%Sym{symbol: :Verb, submatches: [submatch]}, options) do
    # Verb ::= VarOrIri | 'a'

    # Dispatch to VarOrIri, or construct the 'a' IRI

    case submatch do
      %Sym{symbol: :VarOrIri} -> primitive_value(submatch, options)
      %Word{} -> Iri.make_a()
    end
  end

  def primitive_value(%Sym{symbol: :BooleanLiteral, submatches: [%Word{word: word}]}, _options) do
    # BooleanLiteral ::= 'true' | 'false'

    # Dispatch directly to bool
    Bool.from_string(word)
  end

  def primitive_value(%Sym{symbol: :String, submatches: [submatch]}, options) do
    # String ::= STRING_LITERAL1 | STRING_LITERAL2 | STRING_LITERAL_LONG1 | STRING_LITERAL_LONG2

    primitive_value(submatch, options)
  end

  def primitive_value(%Sym{symbol: string_literal_sym, string: str}, _options)
      when string_literal_sym in [
             :STRING_LITERAL1,
             :STRING_LITERAL2,
             :STRING_LITERAL_LONG1,
             :STRING_LITERAL_LONG2
           ] do
    # TODO: by outputting this primitive value, we lack information on
    # how to render it in the future.  Each of these should be
    # rendered in a different way.  The enclosed content ",',""",'''
    # is quite relevant to ensure valid output.
    Str.from_string(str)
  end

  def primitive_value(%Sym{symbol: :NumericLiteral, submatches: [subsymbol]}, options) do
    # NumericLiteral ::= NumericLiteralUnsigned | NumericLiteralPositive | NumericLiteralNegative

    case subsymbol do
      %Sym{symbol: :NumericLiteralUnsigned} -> primitive_value(subsymbol, options)
      %Sym{symbol: :NumericLiteralPositive} -> primitive_value(subsymbol, options)
      %Sym{symbol: :NumericLiteralNegative} -> primitive_value(subsymbol, options)
    end
  end

  def primitive_value(%Sym{symbol: :NumericLiteralUnsigned, submatches: [sub]}, options) do
    # NumericLiteralUnsigned ::= INTEGER | DECIMAL | DOUBLE

    # We will dispatch to the primitive type

    primitive_value(sub, options)
  end

  def primitive_value(%Sym{symbol: :NumericLiteralPositive, submatches: [subsymbol]}, options) do
    # NumericLiteralPositive ::= INTEGER_POSITIVE | DECIMAL_POSITIVE | DOUBLE_POSITIVE
    primitive_value(subsymbol, options)
  end

  def primitive_value(%Sym{symbol: :NumericLiteralNegative, submatches: [subsymbol]}, options) do
    # NumericLiteralNegative ::= INTEGER_NEGATIVE | DECIMAL_NEGATIVE | DOUBLE_NEGATIVE
    primitive_value(subsymbol, options)
  end

  def primitive_value(%Sym{symbol: sym, string: str}, _options)
      when sym in [
             :INTEGER,
             :DECIMAL,
             :DOUBLE,
             :INTEGER_POSITIVE,
             :DECIMAL_POSITIVE,
             :DOUBLE_POSITIVE,
             :INTEGER_NEGATIVE,
             :DECIMAL_NEGATIVE,
             :DOUBLE_NEGATIVE
           ] do
    # We can dispatch to the Number type, as we don't parse further
    Number.from_string(str)
  end

  ## Primitive values for queries
  def primitive_value(%Sym{symbol: :PathPrimary, submatches: [%Word{word: "a"}]}, _options) do
    Iri.make_a()
  end

  def import_prologue(%Sym{symbol: :Prologue, submatches: matches}, options) do
    # Prologue ::= ( BaseDecl | PrefixDecl )*
    matches
    |> Enum.map(fn
      %Sym{symbol: :BaseDecl} = match -> match
      %Sym{symbol: :PrefixDecl} = match -> match
    end)
    |> Enum.reduce(options, &import_prologue/2)
  end

  def import_prologue(%Sym{symbol: :BaseDecl, submatches: matches}, options) do
    # BaseDecl ::= 'BASE' IRIREF
    [%Word{}, iriref_sym] = matches

    base_iri =
      iriref_sym
      |> primitive_value(options)
      |> is_uri_like!

    # TODO is BaseDecl the default graph, or only for creating IRIs?
    options
    |> Map.put(:default_graph, base_iri)
  end

  def import_prologue(%Sym{symbol: :PrefixDecl, submatches: matches}, options) do
    # PrefixDecl ::= 'PREFIX' PNAME_NS IRIREF

    # we must fetch PNAME_NS, but drop the spaces in front and the
    # colon (:) at the end.

    # PNAME_NS is primitive -> get the value from the returned IRI

    [%Word{}, %Sym{symbol: :PNAME_NS, string: namespace_str}, %Sym{symbol: :IRIREF} = iriref_sym] =
      matches

    # TODO don't drop spaces in front once terminal symbols don't
    # contain whitespace any longer
    namespace_string =
      namespace_str
      |> String.trim(" ")
      |> remove_last_string_char

    iriref_iri = primitive_value(iriref_sym, options)

    prefixes =
      Map.get(options, :prefixes, %{})
      |> Map.put(namespace_string, iriref_iri)

    Map.put(options, :prefixes, prefixes)
  end

  @doc """
  Yields a list of all variables which are containted in the query,
  with duplicates removed.
  """
  @spec find_variables_in_quads([Quad.t()]) :: [Var.t()]
  def find_variables_in_quads(quads) do
    quads
    |> Enum.flat_map(&Quad.as_list/1)
    |> Enum.filter(&Var.is_var/1)
    |> Enum.uniq()
  end


  @spec update_options_for_with(Sym.t(), options) :: options
  def update_options_for_with(%Sym{symbol: :iri} = sym, options) do
    # TODO double_check the use of :default_graph.  The may be used
    # incorrectly as the basis for empty predicates.
    iri = primitive_value(sym, options)

    options
    |> Map.put(:default_graph, iri)
  end

  def construct_select_distinct_matching_quads(quads) do
    graph = QueryConstructors.make_var_symbol("?g")
    subject = QueryConstructors.make_var_symbol("?s")
    predicate = QueryConstructors.make_var_symbol("?p")
    object = QueryConstructors.make_var_symbol("?o")
    where_clause = QueryConstructors.make_quad_match_values(graph, subject, predicate, object, quads)

    QueryConstructors.make_select_distinct_query([graph, subject, predicate, object], where_clause)
  end

  def construct_asks_query(quads) do
    QueryConstructors.make_asks_query(quads)
  end

  def construct_ask_query(quad) do
    QueryConstructors.make_ask_query(quad)
  end

  @spec construct_select_query([Var.t()], Sym.t(), options) ::
          {Parser.query(), Acl.allowed_groups()}
  def construct_select_query(variables, group_graph_pattern_sym, options) do
    # In order to build the select query, we need to walk the right tree.
    # At this stage, we have our options (which we can use to set the default graph)

    # TODO add default to calculate authorization_groups for no user
    authorization_groups = Map.get(options, :authorization_groups)

    ALog.di(authorization_groups, "Authorization groups")
    ALog.di(options, "Received options")

    # TODO: remove graph statements in group_graph_pattern_sym
    # TODO: move this method to a better module

    select_variables =
      variables
      |> Enum.map(&Var.to_solution_sym/1)

    QueryConstructors.make_select_distinct_query(
      select_variables,
      group_graph_pattern_sym
    )
    |> Manipulators.Recipes.add_prefixes(prefix_list_from_options(options))
    |> ALog.di("Generated partial query")
    |> Acl.process_query(Acl.UserGroups.for_use(:read_for_write), authorization_groups)

    # |> Manipulators.Recipes.set_from_graph # This should be replaced by the previous rule in the future
  end

  @spec construct_insert_query_from_quads([Quad.t()], options) :: Parser.query()
  def construct_insert_query_from_quads(quads, options) do
    # TODO: this should be clearing when the query is executed
    clear_cache_for_typed_quads(quads, options)

    quads
    |> Enum.map(&QueryConstructors.make_quad_match_from_quad/1)
    |> QueryConstructors.make_insert_query()


    # |> TODO add prefixes
  end

  @spec construct_delete_query_from_quads([Quad.t()], options) :: Parser.query()
  def construct_delete_query_from_quads(quads, options) do
    # TODO: this should be clearing when the query is executed
    clear_cache_for_typed_quads(quads, options)
    quads
    |> Enum.map(&QueryConstructors.make_quad_match_from_quad/1)
    |> QueryConstructors.make_delete_query()

    # |> TODO add prefixes
  end

  defp clear_cache_for_typed_quads(quads, options) do
    authorization_groups = Map.get(options, :authorization_groups)

    quads
    |> Enum.filter(fn %Quad{predicate: pred} -> Iri.is_a?(pred) end)
    |> Enum.map(fn %Quad{subject: %Iri{iri: subj}} ->
      Cache.Types.clear(subj, authorization_groups)
    end)
  end

  def prefix_list_from_options(options) do
    options
    # TODO: remove this prefix when it is not required anymore
    |> Map.get(:prefixes, [])
    |> Enum.into([])
    |> Enum.map(fn {name, %Updates.QueryAnalyzer.Iri{iri: iri}} -> {name, iri} end)
  end

  def fill_quad_template(quads, single_query_result) do
    quads
    |> Enum.map(fn quad -> instantiate_quad(quad, single_query_result) end)
    |> Enum.reject(&Quad.has_var?/1)
  end

  @doc """
  Fills in the variables of a single quad, for the supplied variable binding.
  """
  def instantiate_quad(%Quad{} = quad, %{} = binding) do
    quad
    |> Quad.as_list()
    |> Enum.map(fn elt ->
      if Var.is_var(elt) && Map.has_key?(binding, Var.pure_name(elt)) do
        Map.get(binding, Var.pure_name(elt))
        |> primitive_value_from_binding
      else
        elt
      end
    end)
    |> Quad.from_list()
  end

  def primitive_value_from_binding(binding_value) do
    # TODO convert binding_value to local value

    # TODO: we should verify that the strings which are returned as a
    # value, can always be dropped into a triple-quoted string, or
    # whether some escaping may be necssary.  We should compare the
    # SPARQL1.1 protocol, with the query syntax.

    perform_string_escaping = fn str ->
      # Characters which are \uXXXX are returned in their UTF-8 form
      # and it seems we're allowed to send them that way too.  The \
      # character is returned "raw" as well, hence we have to escape
      # it.  Since we don't have other escapings occuring with the \,
      # we can just escape it first.

      # TODO: check if UTF-8 characters must be escaped upon sending.
      # Such a thing might make this logic move to the regenerator
      # instead, depending on how we choose to interpret INSERT DATA.
      str
      |> String.replace("\\", "\\\\")
      |> String.replace("\"", "\\\"")
    end

    wrap_in_triple_quotes = fn str ->
      "\"\"\"" <> str <> "\"\"\""
    end

    case binding_value do
      %{"type" => "uri", "value" => value} ->
        # We supply an empty options object, it will not be used
        Iri.from_iri_string("<" <> value <> ">", %{})

      %{"type" => "literal", "xml:lang" => lang, value: value} ->
        value
        |> perform_string_escaping.()
        |> wrap_in_triple_quotes.()
        |> Str.from_langstring(lang)

      # It seems Virtuoso emits typed-literal rather than literal
      %{"type" => type_name, "datatype" => datatype, "value" => value}
      when type_name in ["literal", "typed-literal"] ->
        # We supply an empty options object, it will not be used
        type_iri = Iri.from_iri_string("<" <> datatype <> ">", %{})

        value
        |> perform_string_escaping.()
        |> wrap_in_triple_quotes.()
        |> Str.from_typestring(type_iri)

      # TODO it seems only URIs are allowed here, but we should be
      # certain stores don't break this assumption
      %{"type" => "literal", "value" => value} ->
        value
        |> perform_string_escaping.()
        |> wrap_in_triple_quotes.()
        |> Str.from_string()

        # %{ "type" => "bnode", "value": value } -> # <-- we don't do
        # blank nodes, we will crash when blank nodes arrive
    end
  end

  def is_uri_like!(%Iri{} = iri) do
    iri
  end

  def remove_last_string_char(string) do
    String.slice(string, 0, String.length(string) - 1)
  end

  @spec fill_in_triples_template(any, any, any) :: [Quad.t()]
  defp fill_in_triples_template(quads_with_vars, group_graph_pattern_sym, options) do
    # TODO the query sent to the database should take the current
    # user's access rights into account.  The query should not be
    # blindly sent to the application graph.
    case find_variables_in_quads(quads_with_vars) do
      [] ->
        quads_with_vars

      variables ->
        variables
        |> ALog.di("Detected variables")
        |> construct_select_query(group_graph_pattern_sym, options)
        |> elem(0)
        |> ALog.di("Constructed SELECT query")
        # the SELECT query to execute
        |> Regen.result()
        |> ALog.di("Construct query")
        |> SparqlClient.query(query_type: :read_for_write)
        # Array of solutions
        |> SparqlClient.extract_results()
        |> ALog.di("Results from SELECT query")
        |> Enum.flat_map(fn res -> fill_quad_template(quads_with_vars, res) end)
        # remove duplicate solutions
        |> Enum.uniq()
        |> ALog.di("Resulting filled in quads")
    end
  end

  def insert_quads(quads, options) do
    quads
    # |> consolidate_insert_quads
    # |> dispatch_insert_quads_to_desired_graphs
    |> construct_insert_query_from_quads(options)
    |> SparqlClient.execute_parsed(query_type: :write)
  end

  @spec convert_spo_results_to_quads(SparqlClient.QueryResponse.bindings(), String.t()) ::
          [Quad.t()]
  def convert_spo_results_to_quads(spo_results, graph) do
    spo_results
    |> Enum.map(fn %{"s" => subject, "p" => predicate, "o" => object} ->
      graph = primitive_value(graph, %{})

      [subject, predicate, object] =
        Enum.map([subject, predicate, object], &SparqlClient.QueryResponse.primitive_value/1)

      Quad.make(graph, subject, predicate, object)
    end)
  end
end

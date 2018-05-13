alias InterpreterTerms.SymbolMatch, as: Sym
alias InterpreterTerms.WordMatch, as: Word
alias Updates.QueryAnalyzer.Iri, as: Iri
alias Updates.QueryAnalyzer.String, as: Str
alias Updates.QueryAnalyzer.Boolean, as: Bool
alias Updates.QueryAnalyzer.NumericLiteral, as: Number
alias Updates.QueryAnalyzer.Types.Quad, as: Quad

defmodule Updates.QueryAnalyzer do
  @moduledoc """
  Performs analysis on a sparql InsertData query and yields the
  triples to insert in quad-format.

  Our analyzer assumes no blank nodes to exist in the query.

  Our analyzer is written explicitly.  If there is something we
  do not support yet, it should fall through and yield an error.
  As such, we're matching on the SymbolMatch's symbols which we
  understand, rather than providing a fall through which loops
  over each submatch for models we haven't understood.

  The analyzer consumes the following EBNF terms.  Some forms may
  have children which are not parsed.  Check the full tree to be
  sure.  EBNF forms which explicitly aren't handled have received
  double-dashes in front and after the used term in the EBNF.

  Terms which yield quads:

  - InsertData ::= 'INSERT DATA' QuadData
  - QuadData ::= '{' Quads '}'
  - Quads ::= TriplesTemplate? (QuadsNotTriples '.'? TriplesTemplate ?)*
  - QuadsNotTriples ::= 'GRAPH' VarOrIri '{' TriplesTemplate? '}'
  - TriplesTemplate ::= TriplesSameSubject ( '.' TriplesTemplate? )?
  - TriplesSameSubject ::= VarOrTerm PropertyListNotEmpty | --TriplesNode-- --PropertyList--
  - PropertyListNotEmpty ::= Verb ObjectList ( ';' ( Verb ObjectList )? )*
  - ObjectList ::= Object (',' Object)*
  - Object ::= GraphNode

  Terms which yield primitive values (variables included)
  - VarOrIri ::= --Var-- | iri
  - iri ::= IRIREF | PrefixedName
  - PrefixedName ::= PNAME_LN | PNAME_NS
  - VarOrTerm ::= --Var-- | GraphTerm
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
  - Update1 ::= --Load-- | --Clear-- | --Drop-- | --Add-- | --Move-- | --Copy-- | --Create-- | InsertData | DeleteData | --DeleteWhere-- | --Modify--

  Terms which were added for DELETE DATA
  - DeleteData ::= 'DELETE DATA' QuadData
  """

  def extract_quads( query ) do
    quads( query, %{} )
  end

  def quads( %Sym{ symbol: :Sparql, submatches: [match] }, options ) do
    # Sparql ::= QueryUnit | UpdateUnit
    case match do
      %Sym{ symbol: :UpdateUnit } -> quads( match, options )
    end
  end

  def quads( %Sym{ symbol: :UpdateUnit, submatches: [match] }, options ) do
    # UpdateUnit ::= Update
    case match do
      %Sym{ symbol: :Update } -> quads( match, options )
    end
  end

  def quads( %Sym{ symbol: :Update, submatches: matches }, options ) do
    # Update ::= Prologue ( Update1 ( ';' Update )? )?
    case matches do
      [ _prologue_sym ] -> []
      [ prologue_sym, update_one_sym ] ->
        new_options = import_prologue( prologue_sym, options )
        quads( update_one_sym, new_options )
      [ prologue_sym, update_one_sym, %Word{}, update_sym ] ->
        new_options = import_prologue( prologue_sym, options )
        Quad.append(
          quads( update_one_sym, new_options ),
          quads( update_sym, new_options ) )
    end
  end

  def quads( %Sym{ symbol: :Update1, submatches: [match] }, options ) do
    # Update1 ::= --Load-- | --Clear-- | --Drop-- | --Add-- | --Move-- | --Copy-- | --Create-- | InsertData | DeleteData | --DeleteWhere-- | --Modify--

    case match do
      %Sym{ symbol: :InsertData } -> quads( match, options )
      %Sym{ symbol: :DeleteData } -> quads( match, options )
    end
  end

  def quads( %Sym{ symbol: :InsertData, submatches: matches }, options ) do
    # InsertData ::= 'INSERT DATA' QuadData

    # scan matches to find the single QuadData element:
    quad_data = Enum.find matches, fn
      %Sym{ symbol: :QuadData } -> true
      %Word{} -> false
    end

    [ insert: quads( quad_data, options ) ]
  end

  def quads( %Sym{ symbol: :DeleteData, submatches: matches }, options ) do
    # DeleteData ::= 'DELETE DATA' QuadData

    # scan matchesto find the single QuadData element:
    quad_data = Enum.find matches, fn
      %Sym{ symbol: :QuadData } -> true
      %Word{} -> false
    end

    [ delete: quads( quad_data, options ) ]
  end


  def quads( %Sym{ symbol: :QuadData, submatches: matches }, options ) do
    # QuadData ::= '{' Quads '}'

    # scan matches to find the single Quads element:
    quads = Enum.find matches, fn
      %Sym{ symbol: :Quads } -> true
      %Word{} -> false
    end

    quads( quads, options )
  end

  def quads( %Sym{ symbol: :Quads, submatches: matches }, options ) do
    # Quads ::= TriplesTemplate? (QuadsNotTriples '.'? TriplesTemplate ?)*

    # dispatch anything which is a TriplesTemplate or QuadsNotTriples
    matches
    |> Enum.filter( fn
      %Sym{ symbol: :TriplesTemplate } -> true
      %Sym{ symbol: :QuadsNotTriples } -> true
      %Word{} -> false
    end )
    |> Enum.map( fn (x) -> quads( x, options ) end )
    |> Enum.reduce( &Quad.append/2 )
  end

  def quads( %Sym{ symbol: :QuadsNotTriples, submatches: matches }, options ) do
    # QuadsNotTriples ::= 'GRAPH' VarOrIri '{' TriplesTemplate? '}'

    # Get the VarOrIri URI (which must be a URI-like symbol) and the
    # TriplesTemplate.  Dispatch to the TriplesTemplate if that
    # exists.
    graph_sym = Enum.find matches, fn
      %Sym{ symbol: :VarOrIri } -> true
      %Sym{ symbol: :TriplesTemplate } -> false
      %Word{} -> false
    end

    triples_template_sym = Enum.find matches, false, fn
      %Sym{ symbol: :TriplesTemplate } -> true
      %Sym{ symbol: :VarOrIri } -> false
      %Word{} -> false
    end

    # triplesTemplateSym may be false.  In that case, we don't need to
    # push anything special.  Otherwise, we need to analyze the
    # VarOrIri for it's primitive_value (which should yield a URI-like
    # object), and push that as the default context to our options.
    if triples_template_sym do
      graph_uri =
        graph_sym
        |> primitive_value( options )
        |> is_uri_like!

      quads( triples_template_sym, %{ options | default_graph: graph_uri } )
    end
  end

  def quads( %Sym{ symbol: :TriplesTemplate, submatches: matches }, options ) do
    # TriplesTemplate ::= TriplesSameSubject ( '.' TriplesTemplate? )?

    same_subject_sym = Enum.find matches, fn
      %Sym{ symbol: :TriplesSameSubject } -> true
      %Sym{ symbol: :TriplesTemplate } -> false
      %Word{} -> false
    end

    triples_template_sym = Enum.find matches, false, fn
      %Sym{ symbol: :TriplesTemplate } -> true
      %Sym{ symbol: :TriplesSameSubject } -> false
      %Word{} -> false
    end

    # first execute TriplesSameSubject, then execute TriplesTemplate
    if triples_template_sym do
      Quad.append(
        quads( same_subject_sym, options ),
        quads( triples_template_sym, options ) )
    else
      quads( same_subject_sym, options )
    end

  end

  def quads( %Sym{ symbol: :TriplesSameSubject, submatches: matches }, options ) do
    # TriplesSameSubject ::= VarOrTerm PropertyListNotEmpty | --TriplesNode-- --PropertyList--

    # We assume the right side of this will not be received.  We don't
    # handle blank nodes.

    var_or_term_sym = Enum.find matches, fn
      %Sym{ symbol: :VarOrTerm } -> true
      %Sym{ symbol: :PropertyListNotEmpty } -> false
    end

    property_list_not_empty_sym = Enum.find matches, fn
      %Sym{ symbol: :PropertyListNotEmpty } -> true
      %Sym{ symbol: :VarOrTerm } -> false
    end

    # We should get the URI for VarOrTerm (of which we know it should
    # not yield a variable), push it into our options as the current
    # subject, and further calculate the quads.
    subject_uri =
      var_or_term_sym
      |> primitive_value( options )
      |> is_uri_like!

    new_options = Map.put( options, :subject, subject_uri )

    quads( property_list_not_empty_sym, new_options )
  end

  def quads( %Sym{ symbol: :PropertyListNotEmpty, submatches: matches  }, options ) do
    # PropertyListNotEmpty ::= Verb ObjectList ( ';' ( Verb ObjectList )? )*

    # Search for any combination of Verb ObjectList, and yield these as tuples
    verb_object_sym_combinations = Enum.reduce matches, [], fn
      (%Sym{ symbol: :Verb } = elt, list) ->
        [{elt} | list]
      (%Sym{ symbol: :ObjectList } = object_list, [{%Sym{ symbol: :Verb } = verb } | rest]) ->
        [{verb,object_list} | rest]
      (%Word{}, acc) -> acc
    end

    # Walk over each combination
    # -> calculate the new predicate
    # -> get quads for objectlist, assuming the new predicate
    Enum.reduce verb_object_sym_combinations, [], fn
      ({%Sym{ symbol: :Verb } = verb,
        %Sym{ symbol: :ObjectList } = object_list},
        acc)  ->
        predicate_uri = verb |> primitive_value( options ) |> is_uri_like!
        new_options = Map.put( options, :predicate, predicate_uri )
        new_quads = quads( object_list, new_options )

        Quad.append( acc, new_quads )
    end
  end

  def quads( %Sym{ symbol: :ObjectList, submatches: matches }, options ) do
    # ObjectList ::= Object ( ',' Object )*

    # Filter out every Object
    Enum.filter( matches, fn
      %Sym{ symbol: :Object } -> true
      %Word{} -> false
    end)
    |> Enum.map( fn (sym) -> quads( sym, options ) end )
    |> Enum.reduce( &Quad.append/2 )
  end

  def quads( %Sym{ symbol: :Object, submatches: [%Sym{ symbol: :GraphNode } = graph_node] }, options ) do
    # Object ::= GraphNode

    # Get the primitive value for the graphNode and emit a triple containing it
    object =
      graph_node
      |> primitive_value( options )

    quad = options
    |> Map.put( :object, object )
    |> Quad.from_options

    [ quad ]
  end

  def primitive_value( %Sym{ symbol: :VarOrIri, submatches: [%Sym{ symbol: :iri } = iri_sym] }, options ) do
    # VarOrIri ::= --Var-- | iri
    primitive_value( iri_sym, options )
  end

  def primitive_value( %Sym{ symbol: :iri, submatches: [submatch]}, options ) do
    # iri ::= IRIREF | PrefixedName
    case submatch do
      %Sym{ symbol: :IRIREF } ->
        primitive_value( submatch, options )
      %Sym{ symbol: :PrefixedName } ->
        primitive_value submatch, options
    end
  end

  def primitive_value( %Sym{ symbol: :IRIREF, string: string }, options ) do
    Iri.from_iri_string( string, options )
  end


  def primitive_value( %Sym{ symbol: :PrefixedName, submatches: [prefix_sym] }, options ) do
    # PrefixedName ::= PNAME_LN | PNAME_NS

    # Dispatch further down
    primitive_value( prefix_sym, options )
  end

  def primitive_value( %Sym{ symbol: :PNAME_LN, string: str }, options ) do
    # PNAME_LN
    Iri.from_prefix_string( str, options )
  end
  def primitive_value( %Sym{ symbol: :PNAME_NS, string: str }, options ) do
    # PNAME_NS
    str
    |> String.trim( " " )
    |> Iri.from_prefix_string( options )
  end

  def primitive_value( %Sym{ symbol: :VarOrTerm, submatches: [submatch] }, options ) do
    # VarOrTerm ::= --Var-- | GraphTerm
    case submatch do
      %Sym{ symbol: :GraphTerm } -> primitive_value( submatch, options )
    end
  end

  def primitive_value( %Sym{ symbol: :GraphTerm, submatches: [submatch] }, options ) do
    # GraphTerm ::= iri | RDFLiteral | NumericLiteral | BooleanLiteral | --BlankNode-- | --NIL--

    case submatch do
      %{ symbol: :iri } -> primitive_value( submatch, options )
      %{ symbol: :RDFLiteral } -> primitive_value( submatch, options )
      %{ symbol: :NumericLiteral } -> primitive_value( submatch, options )
      %{ symbol: :BooleanLiteral } -> primitive_value( submatch, options )
    end
  end

  def primitive_value( %Sym{ symbol: :RDFLiteral, submatches: submatches }, options ) do
    # RDFLiteral ::= String ( LANGTAG | ( '^^' iri ) )?

    # We can use the primitives for String and iri, but we have to combine it ourselves
    %Str{ str: simple_string } = string_primitive =
      submatches
      |> List.first
      |> primitive_value( options )

    case submatches do
      [_,%Sym{ symbol: :LANGTAG, string: str }] ->
        lang = String.slice( 1, String.length( str ) - 1 )
        Str.from_langstring( simple_string, lang )
      [_,%Word{},%Sym{ symbol: :iri } = type_sym] ->
        type = primitive_value( type_sym, options )
        Str.from_typestring( simple_string, type )
      [_] -> string_primitive
    end
  end

  def primitive_value( %Sym{ symbol: :GraphNode, submatches: [submatch] }, options ) do
    # GraphNode ::= VarOrTerm | --TriplesNode--

    # Dispatch to VarOrTerm, we don't support blank nodes
    case submatch do
      %Sym{ symbol: :VarOrTerm } -> primitive_value( submatch, options )
    end
  end

  def primitive_value( %Sym{ symbol: :Verb, submatches: [submatch] }, options ) do
    # Verb ::= VarOrIri | 'a'

    # Dispatch to VarOrIri, or construct the 'a' IRI

    case submatch do
      %Sym{ symbol: :VarOrIri } -> primitive_value( submatch, options )
      %Word{} -> Iri.make_a
    end
  end

  def primitive_value( %Sym{ symbol: :BooleanLiteral, submatches: [%Word{ word: word }]}, _options ) do
    # BooleanLiteral ::= 'true' | 'false'

    # Dispatch directly to bool
    Bool.from_string( word )
  end

  def primitive_value( %Sym{ symbol: :String, submatches: [ submatch ] }, options ) do
    # String ::= STRING_LITERAL1 | STRING_LITERAL2 | STRING_LITERAL_LONG1 | STRING_LITERAL_LONG2

    primitive_value submatch, options
  end

  def primitive_value( %Sym{ symbol: string_literal_sym, string: str }, _options ) when string_literal_sym in [:STRING_LITERAL1, :STRING_LITERAL2, :STRING_LITERAL_LONG1, :STRING_LITERAL_LONG2] do
    Str.from_string( str )
  end

  def primitive_value( %Sym{ symbol: :NumericLiteral, submatches: [subsymbol] }, options ) do
    # NumericLiteral ::= NumericLiteralUnsigned | NumericLiteralPositive | NumericLiteralNegative

    case subsymbol do
      %Sym{ symbol: :NumericLiteralUnsigned } -> primitive_value( subsymbol, options )
      %Sym{ symbol: :NumericLiteralPositive } -> primitive_value( subsymbol, options )
      %Sym{ symbol: :NumericLiteralNegative } -> primitive_value( subsymbol, options )
    end
  end

  def primitive_value( %Sym{ symbol: :NumericLiteralUnsigned, submatches: [sub] }, options ) do
    # NumericLiteralUnsigned ::= INTEGER | DECIMAL | DOUBLE

    # We will dispatch to the primitive type

    primitive_value( sub, options )
  end

  def primitive_value( %Sym{ symbol: :NumericLiteralPositive, submatches: [subsymbol] }, options ) do
    # NumericLiteralPositive ::= INTEGER_POSITIVE | DECIMAL_POSITIVE | DOUBLE_POSITIVE
    primitive_value( subsymbol, options )
  end

  def primitive_value( %Sym{ symbol: :NumericLiteralNegative, submatches: [subsymbol] }, options ) do
    # NumericLiteralNegative ::= INTEGER_NEGATIVE | DECIMAL_NEGATIVE | DOUBLE_NEGATIVE
    primitive_value( subsymbol, options )
  end

  def primitive_value( %Sym{ symbol: sym, string: str }, _options ) when sym in [:INTEGER, :DECIMAL, :DOUBLE, :INTEGER_POSITIVE, :DECIMAL_POSITIVE, :DOUBLE_POSITIVE, :INTEGER_NEGATIVE, :DECIMAL_NEGATIVE, :DOUBLE_NEGATIVE] do
    # We can dispatch to the Number type, as we don't parse further
    Number.from_string( str )
  end



  def import_prologue( %Sym{ symbol: :Prologue, submatches: matches }, options ) do
    # Prologue ::= ( BaseDecl | PrefixDecl )*
    matches
    |> Enum.map( fn
      %Sym{ symbol: :BaseDecl } = match -> match
      %Sym{ symbol: :PrefixDecl } = match -> match
    end )
    |> Enum.reduce( options, &import_prologue/2 )
  end

  def import_prologue( %Sym{ symbol: :BaseDecl, submatches: matches }, options ) do
    # BaseDecl ::= 'BASE' IRIREF
    [ %Word{}, iriref_sym ] = matches

    base_iri =
      iriref_sym
      |> primitive_value( options )
      |> is_uri_like!

    # TODO is BaseDecl the default graph, or only for creating IRIs?
    options
    |> Map.put( :default_graph, base_iri )
  end

  def import_prologue(%Sym{ symbol: :PrefixDecl, submatches: matches }, options ) do
    # PrefixDecl ::= 'PREFIX' PNAME_NS IRIREF

    # we must fetch PNAME_NS, but drop the spaces in front and the
    # colon (:) at the end.

    # PNAME_NS is primitive -> get the value from the returned IRI

    [ %Word{},
      %Sym{ symbol: :PNAME_NS, string: namespace_str },
      %Sym{ symbol: :IRIREF } = iriref_sym
    ] = matches

    # TODO don't drop spaces in front once terminal symbols don't
    # contain whitespace any longer
    namespace_string =
      namespace_str
      |> String.trim( " " )
      |> remove_last_string_char

    iriref_iri = primitive_value( iriref_sym, options )

    prefixes =
      Map.get( options, :prefixes, %{} )
      |> Map.put( namespace_string, iriref_iri )

    Map.put( options, :prefixes, prefixes )
  end


  @doc """
  Appends two sets of quads to each other.
  """
  def is_uri_like!(%Iri{} = iri) do
    iri
  end

  def remove_last_string_char( string ) do
    String.slice( string, 0, String.length( string ) - 1 )
  end

end

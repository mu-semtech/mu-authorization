defmodule InterpreterTerms.Choice.Impl do
  alias Generator.State, as: State
  defstruct [:parsers]

  defimpl EbnfParser.ParseProtocol do
    def parse(%InterpreterTerms.Choice.Impl{parsers: options}, parsers, chars) do
      options
      |> Enum.map(&EbnfParser.ParseProtocol.parse(&1, parsers, chars))
      |> post
    end

    defp post(results) do
      {[x | xs], _} =
        results
        |> Enum.reduce({[], -1_000_000}, &max_and_sim_reduce/2)

      if Generator.Result.is_error?(x) do
        errors = Enum.flat_map([x | xs], fn x -> x.errors end)
        %{x | errors: errors}
      else
        if length(xs) > 0 do
          IO.puts("HELP HELP HELP")
        end
        IO.puts("----------------------------------------")
        IO.inspect(results)
        IO.inspect(results |> Enum.map(& Generator.Result.length/1))
        x
      end
    end

    defp max_and_sim_reduce(el, {acc, value}) do
      new_value = Generator.Result.length(el)

      cond do
        new_value > value -> {[el], new_value}
        new_value == value -> {[el | acc], value}
        true -> {acc, value}
      end
    end
  end
end

defmodule InterpreterTerms.Choice do
  alias Generator.State, as: State
  # import EbnfParser.GeneratorConstructor, only: [ {:dispatch_generation, 2} ]

  defstruct [:options, {:state, %State{}}]

  defimpl EbnfParser.GeneratorProtocol do
    def make_generator(%InterpreterTerms.Choice{state: state, options: options}) do
      %InterpreterTerms.Choice.Interpreter{
        option_generators: Enum.map(options, &dispatch_generation(&1, state))
      }
    end

    defp dispatch_generation(alpha, beta) do
      EbnfParser.GeneratorConstructor.dispatch_generation(alpha, beta)
    end
  end

  defimpl EbnfParser.ParserProtocol do
    def make_parser(%InterpreterTerms.Choice{options: options}) do
      parser_options =
        options
        |> Enum.map(&EbnfParser.GeneratorConstructor.to_term/1)
        |> Enum.map(&EbnfParser.ParserProtocol.make_parser/1)

      %InterpreterTerms.Choice.Impl{
        parsers: parser_options
      }
    end
  end
end

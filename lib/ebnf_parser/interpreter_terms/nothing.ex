alias Generator.State, as: State

# defmodule InterpreterTerms.Nothing.Interpreter do
# end

defmodule InterpreterTerms.Nothing do
  defstruct [:spec, {:state, %State{}}, {:external, %{}}]
end

defimpl EbnfParser.GeneratorProtocol, for: InterpeterTerms.Nothing do
  def make_generator(nothing) do
    nothing
  end
end

defimpl EbnfParser.Generator, for: InterpreterTerms.Nothing do
  def emit(_) do
    {:fail}
  end
end

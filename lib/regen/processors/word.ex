defmodule Regen.Processors.Word do
  defstruct [:word, :state]

  @type t :: %Regen.Processors.Word{}

  defimpl Regen.Protocol do
    def emit(%Regen.Processors.Word{} = word) do
      Regen.Processors.Word.emit(word)
    end
  end

  def emit(%Regen.Processors.Word{
        word: word,
        state:
          %Regen.Status{
            elements: [%InterpreterTerms.WordMatch{word: word} | other_elements],
            produced_content: other_content
          } = status
      }) do
    {:ok, %Regen.Processors.None{},
     %{status | produced_content: [word | other_content], elements: other_elements}}
  end

  def emit(_) do
    {:fail}
  end
end

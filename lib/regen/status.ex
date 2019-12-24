defmodule Regen.Status do
  defstruct [{:elements, []}, {:produced_content, []}, {:syntax, :none}]

  @type t :: %Regen.Status{}

  defimpl Inspect do
    def inspect(%Regen.Status{elements: elts, produced_content: content, syntax: syntax}, opts) do
      syntax_display =
        case syntax do
          :none ->
            syntax

          _ ->
            syntax_key_count = Map.keys(syntax) |> Enum.count()

            if syntax_key_count > 10 do
              [syntax_key_count: syntax_key_count]
            else
              syntax
            end
        end

      {:doc_group,
       {:doc_cons,
        {:doc_nest,
         {:doc_cons, "%Regen.Status{",
          {:doc_cons, {:doc_break, "", :strict},
           {:doc_cons,
            {:doc_cons, {:doc_cons, "elements:", {:doc_cons, " ", Inspect.inspect(elts, opts)}},
             ","},
            {:doc_cons, {:doc_break, " ", :strict},
             {:doc_cons,
              {:doc_cons,
               {:doc_cons, "produced_content:", {:doc_cons, " ", Inspect.inspect(content, opts)}},
               ","},
              {:doc_cons, {:doc_break, " ", :strict},
               {:doc_cons, "syntax:", {:doc_cons, " ", Inspect.inspect(syntax_display, opts)}}}}}}}},
         2, :always}, {:doc_cons, {:doc_break, "", :strict}, "}"}}, :self}
    end
  end
end

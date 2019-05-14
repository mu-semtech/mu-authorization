alias InterpreterTerms.WordMatch, as: Word
alias InterpreterTerms.SymbolMatch, as: Sym

require Manipulators.Basics

defmodule Compat.Modifiers.UpdateDataToUpdateWhere do
  @behaviour Compat.QueryManipulator

  @impl Compat.QueryManipulator
  def manipulate(query) do
    Manipulators.Basics.do_map query, match do
      %Sym{
        symbol: :Update1,
        submatches: [
          %Sym{
            symbol: :DeleteData,
            submatches: [
              %Word{},
              %Word{},
              %Sym{symbol: :QuadData} = quad_data
            ]
          }
        ]
      } = update_symbol ->
        {:replace_by,
         %{
           update_symbol
           | submatches: [
               %Sym{
                 symbol: :DeleteWhere,
                 submatches: [
                   %Word{word: "DELETE"},
                   %Word{word: "WHERE"},
                   %{quad_data | symbol: :QuadPattern}
                 ]
               }
             ]
         }}
    end
  end
end

defmodule Acl do
  @moduledoc """
  Acl allows you to define and verify Access Control Lists.  It is
  used to specify who can see what, and where it should be updated.

  Acl may provide multiple strategies for shielding data.  In order to
  do so, we identified multiple issues to tackle:

  - When can you access a group?
  - What are the graphs of a group?
  - How do we identify a group for future caching?
  - How do we apply constraints?
  - ...

  A current example of applicable access rights can be found in
  Acl.Config.UserGroups
  """
  def process_quads_for_update( quads, user_groups, request ) do
    # The active_group_names should not consist of an array of strings.
    { active_groups, active_group_specs } =
      user_groups
      |> Enum.map( &({&1,Acl.GroupSpec.Protocol.accessible?(&1, request)}) )
      |> Enum.filter( fn
        ({_, {:ok, _}}) -> true
        ({_, {:fail}}) -> false
      end )
      |> Enum.map( fn ({user_group,{_,group_names}}) -> { user_group, group_names } end )
      |> Enum.unzip

    all_group_specs =
        active_group_specs
        |> List.flatten
        |> IO.inspect
        |> Enum.uniq
        |> IO.inspect

    IO.puts "^ all group specs"

    resulting_quads =
      active_groups
      |> Enum.reduce( quads, fn (item, acc) -> Acl.GroupSpec.Protocol.process( item, acc ) end )
      |> IO.inspect

    IO.puts "^ new quads"

    {all_group_specs, resulting_quads}
  end


end

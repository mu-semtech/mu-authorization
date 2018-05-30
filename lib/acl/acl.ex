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
    active_groups_info = active_user_groups_info( user_groups, request )

    all_group_specs =
        active_groups_info
        |> Enum.unzip
        |> elem(1)
        |> List.flatten
        |> Enum.uniq

    IO.puts "^ all group specs"

    resulting_quads =
      active_groups_info
      |> Enum.reduce( quads, fn ({active_group, active_group_specs} , acc) ->
        # active_group_spec should be an array of specs
        Enum.reduce( active_group_specs, acc,
          &Acl.GroupSpec.Protocol.process( active_group, &1, &2 ) )
      end )
      |> IO.inspect

    IO.puts "^ new quads"

    { all_group_specs, resulting_quads }
  end

  @doc """
  Yields the new query, and all the accessibility groups from which
  this query was constructed.
  """
  def process_query( query, user_groups, request ) do
    active_user_groups_info( user_groups, request )
    |> Enum.reduce( { query, [] }, fn ({user_group, ug_access_infos}, { query, access_infos } ) ->
      { new_query, new_access_info } =
        Enum.reduce( ug_access_infos, { query, access_infos },
          fn ( access_info, { query, access_infos } ) ->
            { new_query, new_access_info } = Acl.GroupSpec.Protocol.process_query( user_group, access_info, query )
            { new_query, new_access_info ++ access_infos }
          end )

      { new_query, new_access_info ++ access_infos }
    end)
  end

  defp active_user_groups_info( user_groups, request ) do
    user_groups
    |> Enum.map( &({&1,Acl.GroupSpec.Protocol.accessible?(&1, request)}) )
    |> Enum.filter( fn
      ({_, {:ok, _}}) -> true
      ({_, {:fail}}) -> false
    end )
    |> Enum.map( fn ({user_group,{_,group_names}}) -> { user_group, group_names } end )
  end

end

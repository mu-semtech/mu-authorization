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
  Acl.UserGroups.Config
  """
  def process_quads_for_update( quads, user_groups, authorization_groups ) do
    # The active_group_names should not consist of an array of strings.
    active_groups_info = active_user_groups_info( user_groups, authorization_groups )

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
  def process_query( query, user_groups, authorization_groups ) do
    active_user_groups_info( user_groups, authorization_groups )
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

  defp active_user_groups_info( user_groups, authorization_groups ) do
    authorization_groups_by_name =
      authorization_groups
      |> Enum.group_by( &elem( &1, 0 ) )

    user_groups
    |> Enum.flat_map( fn (user_group) ->
      if Map.has_key?( authorization_groups_by_name, user_group.name ) do
        [ { user_group, Map.get( authorization_groups_by_name, user_group.name ) } ]
      else
        []
      end

      # Map.get( authorization_groups_by_name, user_group.name, [] )
      # |> Enum.map( fn ({_user_group,_arguments} = user_group_info) -> { user_group, user_group_info } end )
    end )
  end

  @doc """
  Yields the authorization groups to which the current user would have
  access.  This content may be cached.
  """
  def user_authorization_groups( user_groups, request ) do
    user_groups
    |> Enum.map( &({&1,Acl.GroupSpec.Protocol.accessible?(&1, request)}) )
    |> Enum.filter( fn
      ({_, {:ok, _}}) -> true
      ({_, {:fail}}) -> false
    end )
    |> Enum.flat_map( fn ({_,{_,group_infos}}) -> group_infos end )
  end

end
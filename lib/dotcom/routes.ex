defmodule Dotcom.Routes do
  @moduledoc """
  A collection of functions that help to work with routes in a unified way.
  """

  @subway_route_ids ["Blue", "Green", "Orange", "Red"]

  @doc """
  Returns a list of route ids for all subway routes.
  """
  @spec subway_route_ids() :: [String.t()]
  def subway_route_ids(), do: @subway_route_ids
end

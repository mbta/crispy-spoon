defmodule Routes.RepoApi do
  @moduledoc """
  Behavior for an API client for fetching route data.
  """

  alias Routes.{Route, Shape}

  @optional_callbacks by_stop_with_route_pattern: 1, by_stop_and_direction: 3

  @doc """
  Returns a list of all the routes
  """
  @callback all() :: [Route.t()]

  @doc """
  Returns a single route by ID
  """
  @callback get(String.t()) :: Route.t() | nil

  @doc """
  Returns a list of shapes
  """
  @callback get_shapes(String.t(), Keyword.t()) :: [Shape.t()]
  @callback get_shapes(String.t(), Keyword.t(), boolean) :: [Shape.t()]

  @doc """
  Given a shape ID, returns a list of shapes matching it
  """
  @callback get_shape(String.t()) :: [Shape.t()]

  @doc """
  Given a route_type (or list of route types), returns the list of routes matching that type.
  """
  @callback by_type([0..4] | 0..4) :: [Route.t()]

  @doc """
  Given a stop ID, returns the list of routes which stop there.
  """
  @callback by_stop(String.t()) :: [Route.t()]
  @callback by_stop(String.t(), Keyword.t()) :: [Route.t()]

  @doc """
  Given a stop ID and direction ID, returns the list of routes which stop there in that direction.
  """
  @callback by_stop_and_direction(String.t(), 0 | 1) :: [Route.t()]
  @callback by_stop_and_direction(String.t(), 0 | 1, Keyword.t()) :: [Route.t()]

  @doc """
  Given a route pattern, returns the list of routes matching it.
  """
  @callback by_stop_with_route_pattern(String.t()) :: [Route.t()]

  @doc """
  The Green Line.
  """
  @callback green_line :: Route.t()
end

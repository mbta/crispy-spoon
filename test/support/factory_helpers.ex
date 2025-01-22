defmodule Test.Support.FactoryHelpers do
  @moduledoc """
  Functions used across many factories.

  Functions suffixed by _factory are themselves factories, which can invoked via
  the ExMachina callbacks, e.g.:

  ```
  [first_id | _] = FactoryHelpers.build_list(20, :id)
  direction_id = FactoryHelpers.build(:direction_id)
  ```
  """

  use ExMachina

  @doc """
  Randomly chooses between the given item, or nil
  """
  @spec nullable_item(any()) :: any() | nil
  def nullable_item(item) do
    Faker.Util.pick([nil, item])
  end

  @doc """
  Creates an autogenerated string to be used as unique identifiers
  """
  @spec id_factory :: String.t()
  def id_factory(_attrs \\ %{}) do
    sequence(:id, fn _ -> Faker.Internet.slug() end)
  end

  @doc """
  Randomly chooses a valid direction_id value
  """
  @spec direction_id_factory :: 0 | 1
  def direction_id_factory(_attrs \\ %{}) do
    Faker.Util.pick([0, 1])
  end

  @doc """
  Randomly chooses between an autogenerated identifier, or nil
  """
  @spec nullable_id_factory :: String.t() | nil
  def nullable_id_factory(_attrs \\ %{}) do
    :id
    |> build()
    |> nullable_item()
  end
end

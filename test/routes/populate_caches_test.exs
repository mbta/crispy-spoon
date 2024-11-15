defmodule Routes.PopulateCachesTest do
  @moduledoc false
  use ExUnit.Case, async: true

  import Routes.PopulateCaches

  alias __MODULE__.FakeRepo
  alias Routes.Route

  defmodule FakeRepo do
    @moduledoc """
    Fake Routes.Repo for testing without making external calls.

    Stores the calls in a MapSet for later retrieval.
    """
    def all do
      [%Route{id: "1"}]
    end

    def get_shapes(id, direction_id) do
      Agent.update(
        __MODULE__,
        fn set -> MapSet.put(set, {:get_shapes, id, direction_id}) end
      )
    end
  end

  setup do
    _ = Agent.start_link(&MapSet.new/0, name: FakeRepo)
    :ok
  end

  describe "init/1" do
    test "sends :populate_all message" do
      _ = init(FakeRepo)
      assert_received :populate_all
    end

    test "stores the repo as its argument" do
      assert {:ok, FakeRepo} = init(FakeRepo)
    end
  end

  describe "handle_info/2" do
    test "populate_all: gets headsigns and shapes for each route" do
      assert {:noreply, FakeRepo} = handle_info(:populate_all, FakeRepo)

      fn -> :timer.sleep(50) end
      |> Task.async()
      |> Task.await()

      # get the calls that were made
      set = Agent.get(FakeRepo, & &1)
      assert MapSet.member?(set, {:get_shapes, "1", [direction_id: 0]})
      assert MapSet.member?(set, {:get_shapes, "1", [direction_id: 1]})
    end

    @tag :capture_log
    test "ignores unknown messages" do
      assert {:noreply, FakeRepo} = handle_info(:unknown, FakeRepo)
    end
  end
end

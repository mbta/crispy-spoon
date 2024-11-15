defmodule Dotcom.GreenLine.CacheSupervisorTest do
  use ExUnit.Case, async: true

  import Dotcom.GreenLine.CacheSupervisor
  import Mox

  alias Dotcom.GreenLine.DateAgent

  setup :verify_on_exit!

  setup_all do
    _ = start_supervised!({Registry, keys: :unique, name: :green_line_cache_registry})
    pid = start_link_supervised!(Dotcom.GreenLine.CacheSupervisor)
    Mox.allow(Stops.Repo.Mock, self(), pid)

    stub(Stops.Repo.Mock, :by_route, fn _, _, _ ->
      []
    end)

    :ok
  end

  test "lookup/1 can retrieve the pid by date" do
    date = Util.service_date()
    {:ok, _} = start_child(date)

    case lookup(date) do
      nil -> :ok
      pid -> DateAgent.stop(pid)
    end

    assert lookup(date) == nil
  end

  test "stops_on_routes/2 gets information for nil date" do
    Stops.Repo.Mock
    |> expect(:by_route, 4, fn route_id, direction_id, opts ->
      assert route_id in GreenLine.branch_ids()
      assert direction_id in [0, 1]
      assert opts == []

      [%Stops.Stop{}]
    end)
    |> expect(:by_route, 32, fn route_id, direction_id ->
      assert route_id in GreenLine.branch_ids()
      assert direction_id in [0, 1]

      [%Stops.Stop{}]
    end)

    assert stops_on_routes(0, nil)
  end

  test "stops_on_routes/2 gets information for service date" do
    date = Util.service_date()

    Stops.Repo.Mock
    |> expect(:by_route, 4, fn route_id, direction_id, opts ->
      assert route_id in GreenLine.branch_ids()
      assert direction_id in [0, 1]
      assert opts == [{:date, date}]

      [%Stops.Stop{}]
    end)
    |> expect(:by_route, 32, fn route_id, direction_id ->
      assert route_id in GreenLine.branch_ids()
      assert direction_id in [0, 1]

      [%Stops.Stop{}]
    end)

    assert stops_on_routes(1, date)
  end
end

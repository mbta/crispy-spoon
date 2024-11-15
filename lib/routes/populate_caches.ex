defmodule Routes.PopulateCaches do
  @moduledoc """
  Populate the Routes Repo cache out-of-band.
  """

  use GenServer

  require Logger

  alias Routes.Shape

  @repeat_after :timer.hours(24)
  @routes_repo Application.compile_env!(:dotcom, :repo_modules)[:routes]

  @spec start_link([]) :: GenServer.on_start()
  def start_link([]) do
    # no cover
    GenServer.start_link(__MODULE__, @routes_repo)
  end

  @impl GenServer
  def init(repo_mod) do
    send(self(), :populate_all)
    {:ok, repo_mod}
  end

  @impl GenServer
  def handle_info(:populate_all, repo_mod) do
    all_routes = repo_mod.all()

    for route <- all_routes do
      for direction_id <- [0, 1] do
        _ = Task.async(fn -> repo_mod.get_shapes(route.id, direction_id: direction_id) end)
      end
    end

    Process.send_after(self(), :populate_all, @repeat_after)
    {:noreply, repo_mod}
  end

  def handle_info({:DOWN, _ref, :process, _pid, :normal}, state) do
    {:noreply, state}
  end

  def handle_info({_ref, []}, state) do
    {:noreply, state}
  end

  def handle_info({_ref, [%Shape{} | _]}, state) do
    {:noreply, state}
  end

  def handle_info({_ref, %{0 => _, 1 => _}}, state) do
    {:noreply, state}
  end

  def handle_info(msg, state) do
    _ = Logger.warning("module=#{__MODULE__} error=unexpected_message msg=#{inspect(msg)}")
    {:noreply, state}
  end
end

defmodule Predictions.PredictionsPubSubTest do
  use ExUnit.Case, async: false
  import Mock
  alias Predictions.{Prediction, PredictionsPubSub, Store}
  alias Routes.Route
  alias Stops.Stop

  @stop_id "place-where"
  @prediction39 %Prediction{
    id: "prediction39",
    direction_id: 1,
    route: %Route{id: "39"},
    stop: %Stop{id: @stop_id}
  }
  @channel_args "stop:#{@stop_id}"

  setup_with_mocks([
    {RoutePatterns.Repo, [], [by_stop_id: fn _stop_id -> [%RoutePatterns.RoutePattern{}] end]}
  ]) do
    start_supervised({Registry, keys: :duplicate, name: :prediction_subscriptions_registry})
    start_supervised(Store)

    subscribe_fn = fn _, _ -> :ok end
    {:ok, pid} = PredictionsPubSub.start_link(name: :subscribe, subscribe_fn: subscribe_fn)

    {:ok, pid: pid}
  end

  defp close_active_workers(context) do
    Predictions.StreamSupervisor
    |> DynamicSupervisor.which_children()
    |> Enum.each(&DynamicSupervisor.terminate_child(Predictions.StreamSupervisor, elem(&1, 1)))

    context
  end

  setup :close_active_workers

  describe "subscribe/2" do
    test "clients get existing predictions upon subscribing", %{pid: pid} do
      with_mock(Store, [:passthrough], fetch: fn _keys -> [@prediction39] end) do
        assert PredictionsPubSub.subscribe(@channel_args, pid) == [@prediction39]
      end
    end

    test "worker starts upon subscribing", %{pid: pid} do
      with_mock(Store, [:passthrough], fetch: fn _keys -> [] end) do
        assert count_workers() == 0
        t = subscribe_task(@channel_args, pid)
        assert count_workers() == 1
        on_exit(fn -> shutdown_subscribe_task(t) end)
      end
    end

    test "additional clients don't start extra workers", %{pid: pid} do
      with_mock(Store, [:passthrough], fetch: fn _keys -> [] end) do
        assert count_workers() == 0
        t1 = subscribe_task(@channel_args, pid)
        assert count_workers() == 1
        t2 = subscribe_task(@channel_args, pid)
        assert count_workers() == 1
        t3 = subscribe_task(@channel_args, pid)
        assert count_workers() == 1
        assert count_subscribers(pid) == 3
        on_exit(fn -> shutdown_subscribe_task([t1, t2, t3]) end)
      end
    end

    test "client disconnection doesn't terminate worker until no subscribers remain", %{pid: pid} do
      with_mock(Store, [:passthrough], fetch: fn _keys -> [] end) do
        task1 = subscribe_task(@channel_args, pid)
        task2 = subscribe_task(@channel_args, pid)
        task3 = subscribe_task(@channel_args, pid)
        assert count_workers() == 1
        assert count_subscribers(pid) == 3
        assert [child1] = DynamicSupervisor.which_children(Predictions.StreamSupervisor)

        shutdown_subscribe_task(task1)
        assert count_subscribers(pid) == 2
        assert count_workers() == 1
        shutdown_subscribe_task(task2)
        assert count_subscribers(pid) == 1
        assert count_workers() == 1
        shutdown_subscribe_task(task3)
        assert count_subscribers(pid) == 0
        assert count_workers() == 0
        assert [] = DynamicSupervisor.which_children(Predictions.StreamSupervisor)
        # starts a different stream after stopping
        _ = PredictionsPubSub.subscribe(@channel_args, pid)
        assert [child2] = DynamicSupervisor.which_children(Predictions.StreamSupervisor)
        assert child1 != child2
      end
    end
  end

  describe "handle_info/2 - :DOWN" do
    test "can observe when the caller/subscribing task is exited, and remove from state" do
      {:ok, pid} =
        PredictionsPubSub.start_link(name: :subscribe_and_down, subscribe_fn: fn _, _ -> :ok end)

      # Seed the state with some subscriptions, each from a different calling
      # process. Technically these processes will be dead, and not doing
      # anything, but we're just using it to pre-populate the GenServer state.
      p1 = spawn(fn -> true end)
      p2 = spawn(fn -> true end)
      p3 = spawn(fn -> true end)

      :sys.replace_state(pid, fn %{callers_by_pid: callers} = state ->
        %{
          state
          | callers_by_pid:
              callers
              |> Map.put_new(p1, "stop=1")
              |> Map.put_new(p2, "stop=2")
              |> Map.put_new(p3, "stop=3")
        }
      end)

      # A new caller process subscribes, adds its PID and channel name to state
      {task, ref} =
        Process.spawn(
          fn ->
            PredictionsPubSub.subscribe(@channel_args, pid)
            this = self()

            assert %{
                     callers_by_pid: %{
                       ^this => _filters,
                       ^p1 => "stop=1",
                       ^p2 => "stop=2",
                       ^p3 => "stop=3"
                     }
                   } = :sys.get_state(pid)
          end,
          [:monitor]
        )

      # The caller process is exited for whatever reason.
      :erlang.trace(pid, true, [:send])
      Process.exit(task, :normal)
      assert_receive {:DOWN, ^ref, :process, ^task, :normal}

      # The exited task triggers call to terminate_child
      assert_receive {:trace, ^pid, :send, {:"$gen_call", _, {:terminate_child, _}}, _}, 2000

      # The caller process is removed from the state
      assert %{
               :callers_by_pid => %{
                 ^p1 => "stop=1",
                 ^p2 => "stop=2",
                 ^p3 => "stop=3"
               }
             } = :sys.get_state(pid)
    end
  end

  defp count_workers() do
    Supervisor.count_children(Predictions.StreamSupervisor)
    |> Map.get(:active)
  end

  defp count_subscribers(pid) do
    Registry.lookup(:prediction_subscriptions_registry, pid)
    |> Enum.count()
  end

  defp subscribe_task(channel, subscriber_server) do
    parent = self()

    {:ok, task} =
      Task.start(fn ->
        send(parent, PredictionsPubSub.subscribe(channel, subscriber_server))
        Process.sleep(:infinity)
      end)

    # depends on predictions being empty or mocked to an empty list
    assert_receive []
    # worker takes time to start, subscriber takes time to be registered
    Process.sleep(2000)
    task
  end

  defp shutdown_subscribe_task([_ | _] = tasks) do
    Enum.each(tasks, &shutdown_subscribe_task/1)
  end

  defp shutdown_subscribe_task(task) do
    ref = Process.monitor(task)
    Process.exit(task, :brutal_kill)
    assert_receive {:DOWN, ^ref, :process, ^task, :brutal_kill}, 5000
    # subscriber takes time to be unregistered
    Process.sleep(1000)
  end
end

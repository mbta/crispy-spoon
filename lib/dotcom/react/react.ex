defmodule Dotcom.React do
  @moduledoc """
  React renderer supervisor
  """
  require Logger
  use Supervisor
  alias Phoenix.HTML

  @pool_name :react_render
  @default_pool_size 4

  @doc """
  Starts the react renderer worker pool.
  """
  @spec start_link(any) :: {:ok, pid} | {:error, any()}
  def start_link(_) do
    opts = [pool_size: @default_pool_size]
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec render(String.t(), map) :: HTML.safe()
  def render(react_component_name, args) do
    case do_render(react_component_name, args) do
      {:ok, %{"markup" => body}} ->
        body
        # Replace zero-width space HTML entities with the Unicode character
        |> String.replace("&#8203;", "​")
        |> HTML.raw()

      {:error, %{"error" => %{"message" => message}}} ->
        _ =
          Logger.warning(fn -> "react_renderer component=#{react_component_name} #{message}" end)

        ""
    end
  end

  defp do_render(component, props) do
    task =
      Task.async(fn ->
        :poolboy.transaction(
          @pool_name,
          fn pid -> GenServer.call(pid, {:render, component, props}) end,
          :infinity
        )
      end)

    Task.await(task)
  end

  @doc """
  Initialize the pool supervisor
  """
  def init(opts) do
    config = Application.get_env(:dotcom, :react)

    :ok = dev_build(config[:source_path])

    pool_size = Keyword.fetch!(opts, :pool_size)

    pool_opts = [
      name: {:local, @pool_name},
      worker_module: Dotcom.React.Worker,
      size: pool_size,
      max_overflow: 0
    ]

    children = [
      :poolboy.child_spec(@pool_name, pool_opts)
    ]

    opts = [strategy: :one_for_one]
    Supervisor.init(children, opts)
  end

  def dev_build(path, cmd_fn \\ &System.cmd/3)
  def dev_build(nil, _), do: :ok

  def dev_build(path, cmd_fn) do
    case cmd_fn.(
      "npm",
      ["run", "webpack:build:react"],
      cd: path
    ) do
      {_, 0} ->
        :ok
      {output, _} ->
        _ =
          Logger.warning(fn -> "react_renderer build error #{inspect(output)}" end)

        :ok
    end
  end
end

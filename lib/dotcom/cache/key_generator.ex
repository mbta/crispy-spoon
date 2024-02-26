defmodule Dotcom.Cache.KeyGenerator do
  @moduledoc """
  Generate a readable cache key based on the module, function, and arguments.
  """

  @behaviour Nebulex.Caching.KeyGenerator

  @impl Nebulex.Caching.KeyGenerator
  def generate(mod, fun, []) do
    "#{mod}|#{fun}"
  end

  def generate(mod, fun, [arg]) do
    "#{clean_mod(mod)}|#{fun}|#{:erlang.phash2(arg)}"
  end

  def generate(mod, fun, args) do
    "#{clean_mod(mod)}|#{fun}|#{:erlang.phash2(args)}"
  end

  defp clean_mod(mod) do
    mod
    |> Kernel.to_string()
    |> String.split(".")
    |> (fn [_ | tail] -> tail end).()
    |> Enum.join(".")
    |> String.downcase()
  end
end

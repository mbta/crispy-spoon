defmodule Dotcom.Cache.Multilevel do
  @moduledoc """
  A multilevel implementation of Nebulex.

  https://hexdocs.pm/nebulex/Nebulex.Adapters.Multilevel.html

  Caches will be checked in the following order:
  - Local (L1)
  - Redis (L2)
  - Publisher (L3)

  The Publisher isn't really a caching layer.
  Because calls filter down through layers, we can publish any command that comes into the cache.
  Currently, we only care about invalidating the cache, so we only publish delete commands.
  """

  use Nebulex.Cache,
    otp_app: :dotcom,
    adapter: Nebulex.Adapters.Multilevel,
    default_key_generator: Dotcom.Cache.KeyGenerator

  defmodule Local do
    use Nebulex.Cache, otp_app: :dotcom, adapter: Nebulex.Adapters.Local
  end

  defmodule Redis do
    use Nebulex.Cache, otp_app: :dotcom, adapter: NebulexRedisAdapter
  end

  defmodule Publisher do
    use Nebulex.Cache, otp_app: :dotcom, adapter: Dotcom.Cache.Publisher
  end

  @cache Application.compile_env!(:dotcom, :cache)
  @redix Application.compile_env!(:dotcom, :redix)

  @doc """
  Delete all entries where the key matches the pattern.

  First, we make sure we can get a connection to Redis.
  Then, we get all the keys in Redis that match the pattern.
  We use a cursor to stream the keys in batches of 100 using the SCAN command.
  Finally, we delete all the keys with the default delete/1 function.
  That way we'll delete from the Local, Redis, and publish the delete on the Publisher.
  """
  def flush_keys(pattern \\ "*") do
    case Application.get_env(:dotcom, :redis_config) |> @redix.start_link() do
      {:ok, conn} -> delete_redis_keys(conn, pattern)
      {:error, _} -> :error
    end
  end

  defp delete_redis_keys(conn, pattern) do
    case stream_keys(conn, pattern) |> Enum.to_list() |> List.flatten() do
      [] -> :ok
      keys -> delete_keys(conn, keys)
    end
  end

  defp delete_keys(conn, keys) do
    results = Enum.map(keys, fn key -> @cache.delete(key) end)

    result = @redix.stop(conn)

    if all_ok?([result | results]), do: :ok, else: :error
  end

  defp all_ok?(list) do
    Enum.all?(list, fn
      :ok -> true
      _ -> false
    end)
  end

  defp stream_keys(conn, pattern) do
    Stream.unfold("0", fn
      :stop -> nil
      cursor -> scan_for_keys(conn, pattern, cursor)
    end)
  end

  defp scan_for_keys(conn, pattern, cursor) do
    case @redix.command(conn, ["SCAN", cursor, "MATCH", pattern, "COUNT", 100]) do
      {:ok, [new_cursor, keys]} -> {keys, if(new_cursor == "0", do: :stop, else: new_cursor)}
      {:error, _} -> {[], :stop}
    end
  end
end

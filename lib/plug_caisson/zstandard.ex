defmodule PlugCaisson.Zstandard do
  @behaviour PlugCaisson

  @moduledoc """
  Implementation for [Zstandard][zstd] compression.

  [zstd]: https://facebook.github.io/zstd/
  """

  if Code.ensure_loaded?(:ezstd) do
    @impl true
    def init(_opts), do: {:ok, []}

    @impl true
    def deinit(_state), do: :ok

    @impl true
    def process(_state, data, _opts) do
      case :ezstd.decompress(data) do
        {:error, _} = error -> error
        decompressed -> {:ok, decompressed}
      end
    end
  else
    @impl true
    def init(_opts), do: {:error, :not_supported}

    @impl true
    def deinit(_state), do: :ok

    @impl true
    def process(_state, _data, _opts) do
      {:error, :not_supported}
    end
  end
end

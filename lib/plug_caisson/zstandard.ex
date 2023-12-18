defmodule PlugCaisson.Zstandard do
  @behaviour PlugCaisson

  @moduledoc """
  Implementation for [Zstandard][zstd] compression.

  [zstd]: https://facebook.github.io/zstd/
  """

  @impl true
  if Code.ensure_loaded?(:ezstd) do
    def decompress(data, _opts) do
      case :ezstd.decompress(data) do
        {:error, _} = error -> error
        decompressed -> {:ok, decompressed}
      end
    end
  else
    def decompress(_data, _opts), do: {:error, :not_supported}
  end
end

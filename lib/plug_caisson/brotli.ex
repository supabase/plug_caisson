defmodule PlugCaisson.Brotli do
  @behaviour PlugCaisson

  @moduledoc """
  Implementation for [Brotli][] compression.

  [Brotli]: https://brotli.org
  """

  @impl true
  if Code.ensure_loaded?(:brotli) do
    def decompress(data, _opts) do
      :brotli.decode(data)
    end
  else
    def decompress(_data, _opts), do: {:error, :not_supported}
  end
end

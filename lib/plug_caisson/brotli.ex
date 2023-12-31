defmodule PlugCaisson.Brotli do
  @behaviour PlugCaisson

  @moduledoc """
  Implementation for [Brotli][] compression.

  [Brotli]: https://brotli.org
  """

  if Code.ensure_loaded?(:brotli_decoder) do
    @impl true
    def init(_opts) do
      {:ok, :brotli_decoder.new()}
    end

    @impl true
    def deinit(_state), do: :ok

    @impl true
    def process(decoder, data, _opts) do
      case :brotli_decoder.stream(decoder, data) do
        {result, data} when result in [:ok, :more] -> {result, data, decoder}
        :error -> {:error, :decompression_error}
      end
    end
  else
    @impl true
    def init(_opts) do
      {:error, :not_supported}
    end

    @impl true
    def deinit(_state), do: :ok

    @impl true
    def process(_state, _data, _opts) do
      {:error, :not_supported}
    end
  end
end

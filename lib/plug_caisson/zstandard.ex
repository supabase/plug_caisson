defmodule PlugCaisson.Zstandard do
  @behaviour PlugCaisson

  @moduledoc """
  Implementation for [Zstandard][zstd] compression.

  [zstd]: https://facebook.github.io/zstd/
  """

  if Code.ensure_loaded?(:ezstd) do
    # Extracted from [1] as the `ezstd` do not expose that value
    #
    # [1]: https://github.com/facebook/zstd/blob/b16d193512d3ded82fd584fa822c19ecf67b09a0/lib/zstd.h#L147-L148
    @default_context_size Bitwise.bsl(1, 17)

    @impl true
    def init(opts) do
      context_size = opts[:context_size] || @default_context_size
      ctx = :ezstd.create_decompression_context(context_size)

      {:ok, ctx}
    end

    @impl true
    def deinit(_ctx), do: :ok

    @impl true
    def process(ctx, data, _opts) do
      case :ezstd.decompress_streaming(ctx, data) do
        {:error, _} = error -> error
        decompressed -> {:ok, decompressed, ctx}
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

defmodule PlugCaisson.Zlib do
  @behaviour PlugCaisson

  @moduledoc """
  Implementation for `DEFLATE`/Zlib based compression methods:

  - `gzip`
  - `deflate`

  These two are the most common algorithms used in the Web.

  ## Options

  - `:window_bits` - size of the decompression window - `:type` - either `:gzip`
    or `:deflate` that will set proper `:window_bits` according to each algorithm

  It is preferred to use `:type` over `:window_bits`, but if both are specified,
  then `:window_bits` take precedence.
  """

  @max_wbits 15
  @max_chunk_count 25

  @impl true
  def decompress(data, opts) do
    z = :zlib.open()

    try do
      :zlib.inflateInit(z, window_bits(opts))
      result = chunked_inflate(z, data)
      :zlib.inflateEnd(z)

      result
    after
      :zlib.close(z)
    else
      {:finished, data} -> {:ok, IO.iodata_to_binary(data)}
      {:continue, data} -> {:more, IO.iodata_to_binary(data)}
      {:need_dictionary, _, _} -> {:error, :not_supported}
    end
  end

  defp window_bits(opts) do
    opts[:window_bits] ||
      case opts[:type] || :gzip do
        :gzip -> @max_wbits + 16
        :deflate -> @max_wbits
      end
  end

  defp chunked_inflate(_res, _z, curr_chunk, _acc) when curr_chunk == @max_chunk_count do
    raise RuntimeError, "max chunks reached"
  end

  defp chunked_inflate({:finished, output}, _z, _curr_chunk, acc) do
    {:finished, Enum.reverse([output | acc])}
  end

  defp chunked_inflate({:continue, output}, z, curr_chunk, acc) do
    z
    |> :zlib.safeInflate([])
    |> chunked_inflate(z, curr_chunk + 1, [output | acc])
  end

  # initial
  defp chunked_inflate(z, data) when is_binary(data) do
    z
    |> :zlib.safeInflate(data)
    |> chunked_inflate(z, 0, [])
  end
end

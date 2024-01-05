defmodule PlugCaisson.Zlib do
  @behaviour PlugCaisson

  @moduledoc """
  Implementation for `DEFLATE`/Zlib based compression methods:

  - `gzip`
  - `deflate`

  These two are the most common algorithms used in the Web.

  ## Options

  - `:window_bits` - size of the decompression window
  - `:type` - either `:gzip` or `:deflate` that will set proper `:window_bits`
    according to each algorithm

  It is preferred to use `:type` over `:window_bits`, but if both are specified,
  then `:window_bits` take precedence.
  """

  @max_wbits 15

  @impl true
  def init(opts) do
    z = :zlib.open()
    :ok = :zlib.inflateInit(z, window_bits(opts))

    {:ok, z}
  end

  @impl true
  def deinit(z) do
    try do
      :zlib.inflateEnd(z)
    after
      :zlib.close(z)
    end

    :ok
  end

  @impl true
  def process(state, data, opts) do
    length = opts[:length]

    case chunked_inflate(state, data, length) do
      {:finished, data} -> {:ok, IO.iodata_to_binary(data), state}
      {:more, data} -> {:more, IO.iodata_to_binary(data), state}
      {:need_dictionary, _, _} -> {:error, :no_dictionary}
    end
  end

  defp window_bits(opts) do
    opts[:window_bits] ||
      case opts[:type] || :gzip do
        :gzip -> @max_wbits + 16
        :deflate -> @max_wbits
      end
  end

  defp chunked_inflate({:finished, output}, _z, acc, _lenght) do
    {:finished, Enum.reverse([output | acc])}
  end

  defp chunked_inflate({:continue, output}, z, acc, length) do
    if length - IO.iodata_length(output) >= 0 do
      z
      |> :zlib.safeInflate([])
      |> chunked_inflate(z, [output | acc], length - IO.iodata_length(output))
    else
      {:more, Enum.reverse([output | acc])}
    end
  end

  # initial
  defp chunked_inflate(z, data, length) when is_binary(data) do
    z
    |> :zlib.safeInflate(data)
    |> chunked_inflate(z, [], length)
  end
end

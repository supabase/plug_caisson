defmodule PlugCaisson do
  @moduledoc """
  Body reader for supporting compressed `Plug` requests.
  """

  @default %{
    "gzip" => {PlugCaisson.Zlib, type: :gzip},
    "deflate" => {PlugCaisson.Zlib, type: :deflate},
    "br" => {PlugCaisson.Brotli, []},
    "zstd" => {PlugCaisson.Zstandard, []}
  }

  @callback decompress(data :: binary(), opts :: term()) ::
              {:ok, binary()}
              | {:more, binary()}
              | {:error, term()}

  @doc """
  Read `Plug.Conn` request body and decompress it if needed.

  ## Options

  Accepts the same set of options as `Plug.Conn.read_body/2` with one option
  extra: `:algorithms` which is map containing algorithm identifier as key and
  tuple containing module name for module that implements `#{inspect(__MODULE__)}`
  behaviour and value that will be passed as 2nd argument to the `c:decompress/2`
  callback.

  By default the value is set to:

  ```
  #{inspect(@default, pretty: true)}
  ```

  ## Supported algorithms

  - `gzip`
  - `deflate`
  - `br` (Brotli) - only if `:brotli` dependency is available
  - `zstd` (Zstandard) - only if `:ezstd` dependency is available
  """
  @spec read_body(Plug.Conn.t()) ::
          {:ok, binary(), Plug.Conn.t()} | {:more, binary(), Plug.Conn.t()} | {:error, term()}
  def read_body(conn, opts \\ []) do
    content_encoding = Plug.Conn.get_req_header(conn, "content-encoding")
    types = opts[:algorithms] || @default

    with {:ok, body, conn} <- Plug.Conn.read_body(conn, opts) do
      case try_decompress(body, content_encoding, types) do
        {:ok, data} -> {:ok, data, conn}
        {:more, data} -> {:more, data, conn}
        {:error, _} = error -> error
      end
    end
  end

  defp try_decompress(data, [], _types), do: {:ok, data}

  defp try_decompress(data, [type], types) do
    case Map.fetch(types, type) do
      {:ok, {mod, opts}} ->
        mod.decompress(data, opts)

      :error ->
        {:error, :not_supported}
    end
  end
end

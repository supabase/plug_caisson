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

  @callback init(opts :: term()) :: {:ok, state :: term()} | {:error, term()}
  @callback deinit(state :: term()) :: term()
  @callback process(state :: term(), data :: binary(), opts :: keyword()) ::
              {:ok, binary()} | {:more, binary()} | {:error, term()}

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

  ## Options

  All passed opts will be passed to `Plug.Conn.read_body/2` and to used
  decompression handlers. Decompressors by default will use `:length` to limit
  amount of returned data to prevent zipbombs. Returned data can be longer than
  `:length` if the internal decompression buffer was larger. As it is described
  in `Plug.Conn.read_body/2` docs. By default `length: 8_000_000`.
  """
  @spec read_body(Plug.Conn.t()) ::
          {:ok, binary(), Plug.Conn.t()} | {:more, binary(), Plug.Conn.t()} | {:error, term()}
  def read_body(conn, opts \\ []) do
    opts = Keyword.merge([length: 8_000_000], opts)

    with {:ok, decoder, conn} <- fetch_decompressor(conn, opts[:algorithms] || @default) do
      case Plug.Conn.read_body(conn, opts) do
        {type, body, conn} when type in [:ok, :more] ->
          case try_decompress(body, decoder, opts) do
            {:error, _} = error -> error
            {:ok, data} when type == :ok -> {:ok, data, conn}
            {_, data} -> {:more, data, conn}
          end

        {:error, _} = error ->
          error
      end
    end
  end

  defp fetch_decompressor(%Plug.Conn{private: %{__MODULE__ => {mod, state}}} = conn, _types) do
    {:ok, {mod, state}, conn}
  end

  defp fetch_decompressor(conn, types) do
    case Plug.Conn.get_req_header(conn, "content-encoding") do
      [] ->
        {:ok, :raw, conn}

      ["identity"] ->
        {:ok, :raw, conn}

      [content_encoding] ->
        case Map.fetch(types, content_encoding) do
          {:ok, {mod, opts}} ->
            with {:ok, state} <- mod.init(opts) do
              {:ok, {mod, state}, set_state(conn, mod, state)}
            end

          _ ->
            {:error, :not_supported}
        end
    end
  end

  defp try_decompress(data, :raw, _), do: {:ok, data}

  defp try_decompress(data, {mod, state}, opts), do: mod.process(state, data, opts)

  defp set_state(conn, mod, state) do
    conn
    |> Plug.Conn.put_private(__MODULE__, {mod, state})
    |> Plug.Conn.register_before_send(fn conn ->
      {mod, state} = conn.private[__MODULE__]
      mod.deinit(state)
    end)
  end
end

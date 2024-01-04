defmodule PlugCaisson do
  @moduledoc """
  Body reader for supporting compressed `Plug` requests.

  ## Implementing algorithm

  In addition to the built in algorithms (see `read_body/2`) it is possible to
  implement custom algorithms by implementing behaviour defined in this module.

  ### Example

  ```elixir
  defmodule BobbyCompression do
    @behaviour #{inspect(__MODULE__)}

    # Initialise decompression state with whatever is needed
    @impl true
    def init(opts), do: {:ok, Bobby.open()}

    # Gracefully close the state
    @impl true
    def deinit(state), do: Bobby.finish(state)

    # Process read data to decompress them
    @impl true
    def process(state, data, _opts) do
      case Bobby.decompress(state, data) do
        {:finished, decompressed, new_state} ->
          # All data was decompressed and there is no more data to be
          # decompressed in stream
          {:ok, decompressed, new_state}

        {:more, decompressed, new_state} ->
          # It can happen that `decompressed == ""` and this is perfectly fine
          # as long as there is possibility that there will be more data in
          # future
          {:more, decompressed, new_state}

        {:error, _} = error -> error
      end
    end
  end
  ```
  """

  @default %{
    "gzip" => {PlugCaisson.Zlib, type: :gzip},
    "deflate" => {PlugCaisson.Zlib, type: :deflate},
    "br" => {PlugCaisson.Brotli, []},
    "zstd" => {PlugCaisson.Zstandard, []}
  }

  @doc """
  Initialise state for the decompression algorithm.

  This callback will be called if and only if given algorithm was picked as a
  suitable option for decompression. The returned state will be stored in the
  `Plug.Conn.t()`. It is guaranteed that it will be called only on first call to
  `read_body/2` and all subsequent calls will not call this function again.

  It will receive data passed as a second value in tuple declared in the
  algorithm map.
  """
  @callback init(opts :: term()) :: {:ok, state :: term()} | {:error, term()}

  @doc """
  Cleanup for the state. This will be called in
  `Plug.Conn.register_before_send/2` callback, so the same conditions as with
  these apply. It is guaranteed that it will be called only once for each
  connection.
  """
  @callback deinit(state :: term()) :: term()

  @doc """
  Process chunk of data.

  It receives current state, binary read from the request and list of options
  passed to the `read_body/2` as a 2nd argument.

  ## Return value

  In case of success it should return 3-ary tuple:

  - `{:ok, binary(), new_state :: term()}` - wich mean that all data was read
    and there is no more data left in the internal buffer.
  - `{:more, binary(), new_state :: term()}` - which mean that data was
    processed, but there is more data left to be read in future calls.

  If error occured during processing `{:error, term()}` tuple should be returned.
  """
  @callback process(state :: term(), data :: binary(), opts :: keyword()) ::
              {:ok, binary(), new_state :: term()}
              | {:more, binary(), new_state :: term()}
              | {:error, term()}

  @doc """
  Read `Plug.Conn` request body and decompress it if needed.

  ## Options

  Accepts the same set of options as `Plug.Conn.read_body/2` with one option
  extra: `:algorithms` which is map containing algorithm identifier as key and
  tuple containing module name for module that implements `#{inspect(__MODULE__)}`
  behaviour and value that will be passed as 2nd argument to the `c:init/1`
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

    with {:ok, decoder, conn} <- fetch_decompressor(conn, opts[:algorithms] || @default),
         {read_return, body, conn} <- Plug.Conn.read_body(conn, opts),
         {return, data, new_state} <- try_decompress(body, decoder, opts) do
      {return(return, read_return), data, Plug.Conn.put_private(conn, __MODULE__, new_state)}
    end
  end

  # If there is no more data in body and no more data in decompression stream,
  # then return `:ok`
  defp return(:ok, :ok), do: :ok
  defp return(_, _), do: :more

  # If the decompressor is already initialised, then return current
  # implementation and its state
  defp fetch_decompressor(%Plug.Conn{private: %{__MODULE__ => {mod, state}}} = conn, _types) do
    {:ok, {mod, state}, conn}
  end

  defp fetch_decompressor(conn, types) do
    # XXX: Theoretically we should parse `content-encoding` header to split the
    # algorithms by comma, as `gzip, br` is correct value there, but as double
    # compression makes almost sense and spec explicitly disallows values
    # like `identity, gzip` or `gzip, idenity`, then we simply can ignore
    # parsing and use value as is
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

      [_ | _] ->
        {:error, :not_supported}
    end
  end

  # Special case for `identity` case as well case when there is no compression
  # algorithm defined at all
  defp try_decompress(data, :raw, _), do: {:ok, data, :raw}

  defp try_decompress(data, {mod, state}, opts) do
    with {result, data, new_state} when result in [:ok, :more] <- mod.process(state, data, opts) do
      # Add `mod` to the returned state to simplify `read_body/2`
      {result, data, {mod, new_state}}
    end
  end

  # Setup `Plug.Conn.t()` to contain call to `mod.deinit/1` and set the
  # decompressor state in the private section of `Plug.Conn.t()` for future
  # reference
  defp set_state(conn, mod, state) do
    conn
    |> Plug.Conn.put_private(__MODULE__, {mod, state})
    |> Plug.Conn.register_before_send(fn conn ->
      case conn.private[__MODULE__] do
        {mod, state} ->
          mod.deinit(state)
          Plug.Conn.put_private(conn, __MODULE__, nil)

        nil ->
          conn
      end
    end)
  end
end

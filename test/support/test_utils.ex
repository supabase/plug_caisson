defmodule TestUtils do
  @moduledoc false

  use Plug.Test

  def pipeline(plugs) do
    fn conn -> Enum.reduce(plugs, conn, &call_plug/2) end
  end

  defp call_plug({mod, opts}, conn) when is_atom(mod) do
    opts = mod.init(opts)
    mod.call(conn, opts)
  end

  defp call_plug({fun, opts}, conn) when is_function(fun, 2) do
    fun.(conn, opts)
  end

  def echo_plug(conn, opts) do
    encoder =
      opts[:encoder] ||
        fn _ ->
          {:ok, data, _} = Plug.Conn.read_body(conn)
          data
        end

    code = opts[:code] || 200

    send_resp(conn, code, encoder.(conn.body_params))
  end

  def post({type, body}, content_encoding) do
    conn(:post, "/", body)
    |> put_req_header("content-type", type)
    |> do_post(content_encoding)
  end

  def post(body, content_encoding) do
    conn(:post, "/", body)
    |> do_post(content_encoding)
  end

  defp do_post(conn, nil), do: conn
  defp do_post(conn, ce), do: put_req_header(conn, "content-encoding", ce)

  def body_stream(conn, opts \\ []) do
    Stream.unfold(conn, fn conn ->
      case PlugCaisson.read_body(conn, opts) do
        {:ok, "", _conn} -> nil
        {:error, _} -> nil
        {:ok, body, conn} -> {body, conn}
        {:more, body, conn} -> {body, conn}
      end
    end)
  end

  def corpus do
    Path.wildcard("test/corpus/*")
    |> Map.new(&{Path.basename(&1), File.read!(&1)})
  end

  def corpus(name) do
    Map.fetch!(corpus(), name)
  end
end

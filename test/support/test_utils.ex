defmodule TestUtils do
  use Plug.Test

  def post(body, content_encoding \\ nil) do
    conn = conn(:post, "/", body)

    if content_encoding do
      put_req_header(conn, "content-encoding", content_encoding)
    else
      conn
    end
  end

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

  def binary_chunks(bin, width) do
    case bin do
      <<chunk::binary-size(width)>> <> rest ->
        [chunk | binary_chunks(rest, width)]

      last ->
        [last]
    end
  end
end

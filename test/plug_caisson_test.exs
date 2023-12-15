defmodule PlugCaissonTest do
  use ExUnit.Case, async: true
  use Plug.Test

  @subject PlugCaisson

  doctest @subject

  describe "plaintext" do
    test "is read as is" do
      data = :crypto.strong_rand_bytes(1024)
      conn = post(data)

      assert {:ok, body, _} = @subject.read_body(conn, [])
      assert body == data
    end
  end

  describe "deflate" do
    test "is read as is" do
      raw = :crypto.strong_rand_bytes(1024)
      data = :zlib.compress(raw)
      conn = post(data, "deflate")

      assert {:ok, body, _} = @subject.read_body(conn, [])
      assert body == raw
    end
  end

  describe "gzip" do
    test "is read as is" do
      raw = :crypto.strong_rand_bytes(1024)
      data = :zlib.gzip(raw)
      conn = post(data, "gzip")

      assert {:ok, body, _} = @subject.read_body(conn, [])
      assert body == raw
    end
  end

  describe "brotli" do
    test "is read as is" do
      raw = :crypto.strong_rand_bytes(1024)
      {:ok, data} = :brotli.encode(raw)
      conn = post(data, "br")

      assert {:ok, body, _} = @subject.read_body(conn, [])
      assert body == raw
    end
  end

  describe "zstandard" do
    test "is read as is" do
      raw = :crypto.strong_rand_bytes(1024)
      data = :ezstd.compress(raw)
      conn = post(data, "zstd")

      assert {:ok, body, _} = @subject.read_body(conn, [])
      assert body == raw
    end
  end

  def post(body, content_encoding \\ nil) do
    conn = conn(:post, "/", body)

    if content_encoding do
      put_req_header(conn, "content-encoding", content_encoding)
    else
      conn
    end
  end
end

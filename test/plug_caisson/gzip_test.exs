defmodule PlugCaisson.GzipTest do
  use ExUnit.Case, async: true

  import TestUtils

  @content_type "gzip"

  defp compress(data), do: :zlib.gzip(data)

  test "simple test" do
    raw = "Chrzęszczyrzewoszyckie chrząszcze chrobotliwie chrzeszczą w haszczach"
    data = compress(raw)
    conn = post(data, @content_type)

    assert raw == Enum.join(body_stream(conn))
  end

  test "partial inflation" do
    raw = "Chrzęszczyrzewoszyckie chrząszcze chrobotliwie chrzeszczą w haszczach"

    data = compress(raw)
    conn = post(data, @content_type)

    assert raw == Enum.join(body_stream(conn, length: 10))
  end

  describe "corpus tests" do
    for {path, content} <- corpus() do
      test "#{path}" do
        raw = unquote(content)
        data = compress(raw)
        conn = post(data, @content_type)

        assert raw == Enum.join(body_stream(conn))
      end
    end
  end
end

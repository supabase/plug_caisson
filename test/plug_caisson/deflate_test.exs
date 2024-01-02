defmodule PlugCaisson.DeflateTest do
  use ExUnit.Case, async: true
  use Plug.Test
  use ExUnitProperties

  import TestUtils

  @content_type "deflate"

  defp compress(data), do: :zlib.compress(data)

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

  property "data is returned as is" do
    check all raw <- binary() do
      data = compress(raw)
      conn = post(data, @content_type)

      assert raw == Enum.join(body_stream(conn))
    end
  end

  property "length can be set to custom value" do
    check all raw <- binary(),
              length <- positive_integer() do
      data = compress(raw)
      conn = post(data, @content_type)

      assert raw == Enum.join(body_stream(conn, length: length))
    end
  end

  test "Plug.Parser" do
    pipeline =
      pipeline([
        {Plug.Parsers,
         parsers: [:json], json_decoder: Jason, body_reader: {PlugCaisson, :read_body, []}},
        {&echo_plug/2, encoder: &Jason.encode!/1}
      ])

    value = for _i <- 1..2000, do: %{"hello" => "world"}
    payload = compress(Jason.encode!(value))

    assert {200, _, body} =
             post({"application/json", payload}, @content_type)
             |> pipeline.()
             |> sent_resp()

    assert {:ok, %{"_json" => [%{"hello" => "world"} | _]}} = Jason.decode(body)
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

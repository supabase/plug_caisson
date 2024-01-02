defmodule PlugCaissonTest do
  use ExUnit.Case, async: true
  use Plug.Test

  @subject PlugCaisson

  doctest @subject

  defmodule DumbAlgo do
    @moduledoc false
    @behaviour PlugCaisson

    @impl true
    def init(opts), do: {:ok, opts[:pid] || self()}

    @impl true
    def deinit(pid), do: send(pid, :deinit)

    @impl true
    def process(_, data, _opts), do: {:ok, data}
  end

  defmodule SimplePipeline do
    use Plug.Builder

    plug(Plug.Parsers,
      parsers: [:urlencoded, :json],
      json_decoder: Jason,
      body_reader: {PlugCaisson, :read_body, []},
      algorithms: %{
        "dumb" => {PlugCaissonTest.DumbAlgo, []}
      }
    )

    plug(:handle)

    defp handle(conn, []) do
      send_resp(conn, 200, Jason.encode!(conn.body_params))
    end
  end

  defmodule DefaultPipeline do
    @moduledoc false
    use Plug.Builder

    plug(Plug.Parsers,
      parsers: [:urlencoded, :json],
      json_decoder: Jason,
      body_reader: {PlugCaisson, :read_body, []}
    )

    plug(:handle)

    defp handle(conn, []) do
      send_resp(conn, 200, Jason.encode!(conn.body_params))
    end
  end

  test "deinit callback is called" do
    assert {200, _, body} =
             conn(:post, "/", Jason.encode!(%{"hello" => "world"}))
             |> put_req_header("content-type", "application/json")
             |> put_req_header("content-encoding", "dumb")
             |> SimplePipeline.call([])
             |> sent_resp()

    assert {:ok, %{"hello" => "world"}} == Jason.decode(body)
    assert_received :deinit
  end

  test "gzip" do
    value = for _i <- 1..2000, do: %{"hello" => "world"}
    payload = :zlib.gzip(Jason.encode!(value))

    assert {200, _, body} =
             conn(:post, "/", payload)
             |> put_req_header("content-type", "application/json")
             |> put_req_header("content-encoding", "gzip")
             |> DefaultPipeline.call([])
             |> sent_resp()

    assert {:ok, %{"_json" => [%{"hello" => "world"} | _]}} = Jason.decode(body)
  end
end

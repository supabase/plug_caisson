defmodule PlugCaissonTest do
  use ExUnit.Case, async: true
  use Plug.Test

  import TestUtils

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
    def process(_state, data, _opts), do: {:ok, data}
  end

  test "deinit callback is called" do
    pipeline =
      pipeline([
        {Plug.Parsers,
         parsers: [:urlencoded, :json],
         json_decoder: Jason,
         body_reader: {PlugCaisson, :read_body, []},
         algorithms: %{
           "dumb" => {PlugCaissonTest.DumbAlgo, []}
         }},
        {&echo_plug/2, encoder: &Jason.encode!/1}
      ])

    assert {200, _, body} =
             conn(:post, "/", Jason.encode!(%{"hello" => "world"}))
             |> put_req_header("content-type", "application/json")
             |> put_req_header("content-encoding", "dumb")
             |> pipeline.()
             |> sent_resp()

    assert {:ok, %{"hello" => "world"}} == Jason.decode(body)
    assert_received :deinit
  end

  test "ignores unknown encoding " do
    pipeline =
      pipeline([
        {Plug.Parsers,
         parsers: [:urlencoded, :json],
         json_decoder: Jason,
         body_reader: {PlugCaisson, :read_body, []}},
        {&echo_plug/2, []}
      ])

    assert_raise Plug.BadRequestError, fn ->
      conn(:post, "/", "{}")
      |> put_req_header("content-type", "application/json")
      |> put_req_header("content-encoding", "non-existent-algorithm")
      |> pipeline.()
      |> sent_resp()
    end
  end

  test "ignores unknown multiple encodings" do
    pipeline =
      pipeline([
        {Plug.Parsers,
         parsers: [:urlencoded, :json],
         json_decoder: Jason,
         body_reader: {PlugCaisson, :read_body, []}},
        {&echo_plug/2, []}
      ])

    assert_raise Plug.BadRequestError, fn ->
      conn(:post, "/", "{}")
      |> put_req_header("content-type", "application/json")
      |> prepend_req_headers([
        {"content-encoding", "gzip"},
        {"content-encoding", "br"}
      ])
      |> pipeline.()
      |> sent_resp()
    end
  end
end

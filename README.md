# PlugCaisson

An Elixir `Plug.Parsers` body reader that supports compressed payloads. Supports gzip, brotli, and [more](#supported-algorithms).

> A [caisson][caisson] is an geoengineering structure used to work on foundations of
> bridges and piers. Due to pressurised environment in the caisson (required to
> keep water out of it (as it has no bottom) people can get [decompression
> sickness][sick], also known as _caisson disease_.

[sick]: https://en.wikipedia.org/wiki/Decompression_sickness
[caisson]: https://en.wikipedia.org/wiki/Caisson_(engineering)

## Installation

Add `:plug_caisson` to dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:plug_caisson, "~> 0.2.0"},
    # optional, for brotli support
    {:brotli, "~> 0.3.2"},
    # optional, for zstd support
    {:ezstd, "~> 1.0"},
  ]
end
```

And then add `{PlugCaisson, :read_body, []}` as a `:body_reader` to your `Plug.Parsers`:

```elixir
plug Plug.Parsers,
  parsers: [:urlencoded, :json],
  body_reader: {PlugCaisson, :read_body, []},
  length: 8_000_000
```

All options passed to the plug are forwarded to [`Plug.Conn.read_body/2`](https://hexdocs.pm/plug/Plug.Conn.html#read_body/2).

### Supported algorithms

- `gzip` - GNU zip - most common compression algorithm used in HTTP - [RFC 1952][]
- `deflate` - DEFLATE compressed data ([RFC 1951][]) wrapped in Zlib data format
  ([RFC 1950][])
- `br` (requires optional `:brotli` dependency) - Brotli algorithm developed by
  Google and supported by most browsers nowadays - [RFC 7932][]
- `zstd` (requires optional `:ezstd` dependency) - Zstandard algorithm developed
  by Meta (Facebook) which provides faster compression/decompression times than
  Brotli, but worse compression ratio - [RFC 8478][]

[RFC 1950]: https://datatracker.ietf.org/doc/html/rfc1950
[RFC 1951]: https://datatracker.ietf.org/doc/html/rfc1951
[RFC 1952]: https://datatracker.ietf.org/doc/html/rfc1952
[RFC 7932]: https://datatracker.ietf.org/doc/html/rfc7932
[RFC 8478]: https://datatracker.ietf.org/doc/html/rfc8478

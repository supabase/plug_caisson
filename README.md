# PlugCaisson

Body reader that supports compressed payloads.

## Installation

Add `:plug_caisson` to dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:plug_caisson, "~> 0.1.0"}
  ]
end
```

And then add `{PlugCaisson, :read_body, []}` as a `:body_reader` to your
`Plug.Parsers`:

```elixir
plug Plug.Parsers,
  parsers: [:urlencoded, :json],
  body_reader: {PlugCaisson, :read_body, []}
```

## FAQ

- **Why it is called `PlugCaisson`?**

  [Caisson][caisson] is an geoengineering structure used to work on foundations
  of bridges and piers. Due to pressurised environment in the caisson (required
  to keep water out of it (as it has no bottom) people can get [decompression
  sickness][sick], also known as *caisson disease*.

## TODO

- [ ] - better support for partial Brotli and Zstd decoding
- [ ] - support nested algorithms, i.e. `Content-Encoding: br, gzip` (pointless
  in real life, but technically allowed by the HTTP)

[sick]: https://en.wikipedia.org/wiki/Decompression_sickness
[caisson]: https://en.wikipedia.org/wiki/Caisson_(engineering)

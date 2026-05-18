defmodule PlausibleWeb.CacheBodyReader do
  @moduledoc """
  Caches the raw request body on `conn.assigns[:raw_body]` for routes that
  need to verify a payload signature against the unparsed JSON (Stripe
  webhooks). For all other routes this is a no-op pass-through so we don't
  hold large bodies in memory unnecessarily.
  """

  @cache_paths ["/api/stripe/webhook"]

  def read_body(conn, opts) do
    {:ok, body, conn} = Plug.Conn.read_body(conn, opts)

    conn =
      if conn.request_path in @cache_paths do
        Plug.Conn.assign(conn, :raw_body, body)
      else
        conn
      end

    {:ok, body, conn}
  end
end

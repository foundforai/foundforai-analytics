defmodule PlausibleWeb.Plugs.NoRobots do
  @moduledoc """
  Controls per-page robots indexing.

  - Public marketing pages (root, /welcome, /docs) get
    "index, follow" so search engines and AI crawlers can discover
    and describe the product.
  - All other paths get "noindex, nofollow" because they expose
    customer dashboards, auth flows, or API endpoints.

  The plug annotates the conn with `private.robots` (read by the
  layout to render `<meta name="robots">`) and sets an
  `x-robots-tag` response header for non-HTML responses.
  """
  @behaviour Plug
  import Plug.Conn

  # Paths that should be indexable by Google, ChatGPT, Claude, etc.
  @public_paths [
    [],
    ["welcome"],
    ["docs"]
  ]

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts \\ nil) do
    robots =
      if conn.path_info in @public_paths do
        "index, follow"
      else
        "noindex, nofollow"
      end

    conn
    |> put_private(:robots, robots)
    |> put_resp_header("x-robots-tag", robots)
  end
end

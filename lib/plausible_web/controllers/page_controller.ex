defmodule PlausibleWeb.PageController do
  use PlausibleWeb, :controller
  use Plausible.Repo

  plug PlausibleWeb.RequireLoggedOutPlug

  @doc """
  The root path is never accessible in Plausible.Cloud because it is handled by the upstream reverse proxy.

  This controller action is only ever triggered in self-hosted Plausible.
  """
  def index(conn, _params) do
    render(conn, "index.html")
  end

  @doc """
  Post-Stripe-checkout landing page. Users land here right after paying via a
  Stripe Payment Link. The webhook handler creates their account asynchronously
  and emails them a one-time login link, so this page just tells them what to
  expect next.
  """
  def welcome(conn, _params) do
    render(conn, "welcome.html")
  end
end

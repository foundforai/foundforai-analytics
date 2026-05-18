defmodule PlausibleWeb.Api.StripeController do
  @moduledoc """
  Handles Stripe webhooks for auto-provisioning Found For AI Analytics
  subscriptions purchased via Stripe Payment Links.

  Flow:
    1. Stripe fires `checkout.session.completed` after a successful payment
       (or after a trial-with-card is started).
    2. We verify the HMAC-SHA256 signature on the raw request body.
    3. If the customer doesn't have an account yet, we create one
       (no password, email_verified=true) and a personal team.
    4. We sign a one-time login link (password-reset token) and email it
       to them so they can set a password and log in.

  The handler is idempotent on email: if the user already exists we just
  re-send the welcome/login email rather than creating a duplicate.
  """
  use PlausibleWeb, :controller
  use Plausible.Repo

  require Logger

  alias Plausible.Auth
  alias Plausible.Teams

  plug :verify_signature when action in [:webhook]

  def webhook(conn, %{"type" => "checkout.session.completed"} = params) do
    case handle_checkout_completed(params["data"]["object"]) do
      :ok ->
        json(conn, %{received: true})

      {:error, reason} ->
        Logger.error("Stripe webhook: checkout.session.completed failed: #{inspect(reason)}")
        # Return 200 anyway so Stripe doesn't retry forever on a permanent
        # error; we've already logged for triage. (If you want retries on
        # transient failures, return 500 instead.)
        json(conn, %{received: true, error: inspect(reason)})
    end
  end

  def webhook(conn, %{"type" => type}) do
    Logger.debug("Stripe webhook: ignoring event type #{type}")
    json(conn, %{received: true})
  end

  def webhook(conn, _params) do
    send_resp(conn, 400, "missing event type") |> halt()
  end

  defp handle_checkout_completed(session) when is_map(session) do
    with email when is_binary(email) <- get_in(session, ["customer_details", "email"]),
         email = String.downcase(email),
         name = get_in(session, ["customer_details", "name"]) || derive_name(email) do
      provision_and_notify(email, name)
    else
      _ ->
        {:error, :missing_customer_email}
    end
  end

  defp handle_checkout_completed(_), do: {:error, :invalid_session}

  defp provision_and_notify(email, name) do
    case provision_user(email, name) do
      {:ok, user, status} ->
        Logger.info("Stripe webhook: provisioned user #{user.email} (#{status})")
        send_welcome_email(user)
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp provision_user(email, name) do
    case Repo.get_by(Auth.User, email: email) do
      nil ->
        Repo.transaction(fn ->
          {:ok, user} =
            %Auth.User{}
            |> Auth.User.changeset(%{email: email, name: name, email_verified: true})
            |> Repo.insert()

          _team = Teams.force_create_my_team(user)

          {user, :created}
        end)
        |> case do
          {:ok, {user, status}} -> {:ok, user, status}
          {:error, reason} -> {:error, reason}
        end

      existing ->
        {:ok, existing, :existing}
    end
  end

  defp send_welcome_email(user) do
    token = Auth.Token.sign_password_reset(user.email)

    login_link =
      PlausibleWeb.Router.Helpers.auth_url(
        PlausibleWeb.Endpoint,
        :password_reset_form,
        token: token
      )

    PlausibleWeb.Email.foundforai_subscription_welcome(user, login_link)
    |> Plausible.Mailer.deliver_later()
  end

  defp derive_name(email) do
    email
    |> String.split("@", parts: 2)
    |> hd()
    |> String.replace(~r/[._+-]+/, " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  # --- Signature verification ---

  defp verify_signature(conn, _opts) do
    with secret when is_binary(secret) and byte_size(secret) > 0 <-
           Application.get_env(:plausible, :stripe_webhook_secret),
         [header] <- Plug.Conn.get_req_header(conn, "stripe-signature"),
         raw_body when is_binary(raw_body) <- conn.assigns[:raw_body],
         true <- valid_signature?(header, raw_body, secret) do
      conn
    else
      _ ->
        Logger.warning("Stripe webhook: signature verification failed")
        conn |> send_resp(400, "invalid signature") |> halt()
    end
  end

  defp valid_signature?(header, body, secret) do
    parts =
      header
      |> String.split(",")
      |> Enum.map(&String.trim/1)

    timestamp = find_part(parts, "t")
    sig_v1 = find_part(parts, "v1")

    cond do
      is_nil(timestamp) or is_nil(sig_v1) ->
        false

      stale_timestamp?(timestamp) ->
        false

      true ->
        payload = "#{timestamp}.#{body}"

        expected =
          :crypto.mac(:hmac, :sha256, secret, payload)
          |> Base.encode16(case: :lower)

        Plug.Crypto.secure_compare(expected, sig_v1)
    end
  end

  defp find_part(parts, key) do
    Enum.find_value(parts, fn part ->
      case String.split(part, "=", parts: 2) do
        [^key, value] -> value
        _ -> nil
      end
    end)
  end

  # Reject events older than 5 minutes to prevent replay attacks.
  defp stale_timestamp?(timestamp_str) do
    case Integer.parse(timestamp_str) do
      {ts, ""} ->
        abs(System.system_time(:second) - ts) > 300

      _ ->
        true
    end
  end
end

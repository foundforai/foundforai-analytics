defmodule PlausibleWeb.FoundforaiAdminController do
  @moduledoc """
  Minimal admin panel for Found For AI super-admins.

  Lists every user with their owned-team status (locked / not locked),
  plus quick stats. Gated by SuperAdminOnlyPlug — only users whose
  IDs are in the ADMIN_USER_IDS env var can access these routes.

  Intentionally small — three actions:
    * lock a team (block their dashboard immediately)
    * unlock a team (e.g. accidental cancellation reversed)
    * delete a user (refund + tear down)
  """
  use PlausibleWeb, :controller
  use Plausible.Repo

  import Ecto.Query

  alias Plausible.Auth
  alias Plausible.Teams

  def index(conn, _params) do
    render(conn, "index.html",
      title: "Admin · Found For AI Analytics",
      users: list_users_with_team_status(),
      stats: collect_stats(),
      hide_footer?: true
    )
  end

  def lock_team(conn, %{"team_id" => team_id}) do
    team = Repo.get!(Teams.Team, team_id)

    team
    |> Ecto.Changeset.change(locked: true)
    |> Repo.update!()

    conn
    |> put_flash(:success, "Locked team #{team.name}")
    |> redirect(to: "/admin")
  end

  def unlock_team(conn, %{"team_id" => team_id}) do
    team = Repo.get!(Teams.Team, team_id)

    team
    |> Ecto.Changeset.change(locked: false)
    |> Repo.update!()

    conn
    |> put_flash(:success, "Unlocked team #{team.name}")
    |> redirect(to: "/admin")
  end

  def delete_user(conn, %{"user_id" => user_id}) do
    user = Repo.get!(Auth.User, user_id)
    Repo.delete!(user)

    conn
    |> put_flash(:success, "Deleted user #{user.email}")
    |> redirect(to: "/admin")
  end

  defp list_users_with_team_status do
    from(u in Auth.User,
      left_join: tm in "team_memberships",
      on: tm.user_id == u.id and tm.role == "owner",
      left_join: t in Teams.Team,
      on: t.id == tm.team_id,
      order_by: [desc: u.inserted_at],
      select: %{
        user_id: u.id,
        email: u.email,
        name: u.name,
        inserted_at: u.inserted_at,
        team_id: t.id,
        team_name: t.name,
        locked: t.locked
      }
    )
    |> Repo.all()
  end

  defp collect_stats do
    %{
      total_users: Repo.aggregate(Auth.User, :count),
      total_teams: Repo.aggregate(Teams.Team, :count),
      locked_teams: Repo.aggregate(from(t in Teams.Team, where: t.locked == true), :count),
      total_sites: Repo.aggregate(Plausible.Site, :count)
    }
  end
end

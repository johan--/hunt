defmodule Hunt.Activity do
  import Ecto.Query

  alias Hunt.Repo
  alias Hunt.Activity.Schema.CompletedActivity

  @system_uuid "00000000-0000-0000-0000-000000000000"

  @activity_modules [
    Hunt.Activity.Lounge,
    Hunt.Activity.Attend,
    Hunt.Activity.Social,
    Hunt.Activity.Selfie1,
    Hunt.Activity.Selfie2,
    Hunt.Activity.Selfie3,
    Hunt.Activity.Fun,
    Hunt.Activity.Hubolution,
    Hunt.Activity.Supered
  ]

  @activities Enum.flat_map(@activity_modules, fn mod ->
    Enum.map(mod.activities(), & Map.put(&1, :module, mod))
  end)

  def activity_modules, do: @activity_modules
  def activities, do: @activities

  def completion_summary(user: user) do
    activities = completed_activities(user: user) |> Enum.group_by(& &1.activity_module)

    Enum.map(activity_modules(), fn mod ->
      mod_activities = Map.get(activities, mod, [])
      mod_activity_count = length(mod.activities())

      pointed_activities = Enum.filter(mod_activities, & &1.approval_state in [:pending, :approved])
      pointed_activities_count = length(pointed_activities)

      achievement? = mod_activity_count == pointed_activities_count
      points = Enum.map(pointed_activities, & &1.activity_points) |> Enum.sum()
      points = if achievement?, do: mod.achievement().points + points, else: points

      completion = %{
        ids: Enum.map(mod_activities, & &1.activity_id),
        achievement: achievement?,
        count: (if achievement?, do: pointed_activities_count + 1, else: pointed_activities_count),
        activity_count: pointed_activities_count,
        points: points
      }

      {mod, completion}
    end)
    |> Map.new()
  end

  def completed_activities(user: nil), do: []

  def completed_activities(user: user) do
    from(
      c in CompletedActivity,
      where: c.user_id == ^user.id
    )
    |> Repo.all()
    |> Enum.map(fn completion ->
      case find_activity(completion.activity_id) do
        nil -> nil
        act -> %{completion | activity_module: act.module, activity_points: act.points}
      end
    end)
    |> Enum.reject(& is_nil/1)
  end

  def submit_answer(_params, user: nil) do
    {:error, "Must log in first"}
  end

  def submit_answer(params, user: user) do
    id = params["activity_id"]

    case find_activity(id) do
      nil ->
        {:error, "Error submitting hunt: missing #{id}"}

      act = %{completion: completion = %{__struct__: mod}} ->
        case mod.verify(completion, params) do
          true ->
            create_activity_completion(act, user, :approved, params)

          false ->
            {:error, "Wrong answer, give it another try"}
        end
    end
  end

  def find_activity(id) do
    Enum.find(activities(), &(&1.id == id))
  end

  defp create_activity_completion(activity, user, state, metadata) when state in [:pending, :approved] do
    params = maybe_merge_state_params(%{
      activity_id: activity.id,
      user_id: user.id,
      approval_state: state,
      metadata: metadata
    }, state)

    params
    |> CompletedActivity.changeset()
    |> Repo.insert(
      returning: true,
      stale_error_field: :activity_id,
      stale_error_message: "has already been approved",
      conflict_target: [:user_id, :activity_id],
      on_conflict: (
        from c in CompletedActivity,
        where: c.approval_state in [:pending, :rejected],
        update: [
          set: ^Enum.into(params, [])
        ]
      )
    )
  end

  def reject_answer(completed_activity, by_user: user) do
    completed_activity
    |> Ecto.Changeset.change(approval_state: :rejected, approval_updated_at: DateTime.utc_now(), approval_by_id: user.id)
    |> Repo.update()
  end

  defp maybe_merge_state_params(params, state) do
    case state do
      :approved -> Map.merge(params, %{approval_updated_at: DateTime.utc_now(), approval_by_id: @system_uuid})
      _ -> params
    end
  end
end

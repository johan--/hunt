defmodule Hunt.Activity.Schema.CompletedActivity do
  use Ecto.Schema
  import Ecto.Changeset

  @timestamps_opts [type: :utc_datetime_usec]
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type Ecto.UUID
  schema "completed_activities" do
    belongs_to :user, Hunt.User.Schema.User
    field :activity_id, Ecto.UUID

    field :approval_state, Ecto.Enum, values: [:pending, :approved, :rejected, :cancelled]
    field :approval_updated_at, :utc_datetime_usec
    belongs_to :approval_by, Hunt.User.Schema.User

    timestamps()
  end

  def changeset(attrs) do
    fields = [
      :user_id,
      :activity_id,
      :approval_state,
      :approval_updated_at,
      :approval_by_id
    ]

    %__MODULE__{}
    |> cast(attrs, fields)
    |> validate_required(fields -- [:approval_by_id, :approval_updated_at])
    |> unique_constraint([:user_id, :activity_id])
  end
end

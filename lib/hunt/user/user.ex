defmodule Hunt.User do
  alias Hunt.Repo
  alias Hunt.User.Schema

  def find_or_create_user(auth: %{info: %{email: email, first_name: fname, last_name: lname}}) when is_binary(email) do
    case Repo.get_by(Schema.User, email: email) do
      nil -> create_user(email, fname, lname)
      ret -> {:ok, ret}
    end
  end

  def find_or_create_user(auth: _), do: {:error, "Invalid authentication"}

  def get_user(id) do
    Repo.get(Schema.User, id)
  end

  def create_user(email, first_name, last_name) do
    %{email: email, first_name: first_name, last_name: last_name}
    |> Schema.User.changeset()
    |> Repo.insert()
  end
end

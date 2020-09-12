defmodule Isuumo.Estate do
  use Ecto.Schema

  @derive {Poison.Encoder, except: [:__meta__]}
  schema "estate" do
    field(:name, :string)
    field(:description, :string)
    field(:thumbnail, :string)
    field(:address, :string)
    field(:latitude, :float)
    field(:longitude, :float)
    field(:rent, :integer)
    field(:door_height, :integer)
    field(:door_width, :integer)
    field(:features, :string)
    field(:popularity, :integer)
  end
end

defmodule Isuumo.Chair do
  use Ecto.Schema

  schema "chair" do
    field(:name, :string)
    field(:description, :string)
    field(:thumbnail, :string)
    field(:price, :integer)
    field(:height, :integer)
    field(:width, :integer)
    field(:depth, :integer)
    field(:color, :string)
    field(:features, :string)
    field(:kind, :string)
    field(:popularity, :integer)
    field(:stock, :integer)
  end
end

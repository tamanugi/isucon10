defmodule Isuumo.Repo do
  use Ecto.Repo,
    otp_app: :isuumo,
    adapter: Ecto.Adapters.MyXQL
end

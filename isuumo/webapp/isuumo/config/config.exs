import Config

config :isuumo, Isuumo.Repo,
  database: "isuumo",
  username: "isucon",
  password: "isucon",
  hostname: "localhost"

config :isuumo,
  ecto_repos: [Isuumo.Repo]

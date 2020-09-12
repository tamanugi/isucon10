import Config

config :isuumo, Isuumo.Repo,
  database: "isuumo",
  username: "isucon",
  password: "isucon",
  hostname: "localhost",
  pool_size: 100

config :isuumo,
  ecto_repos: [Isuumo.Repo]

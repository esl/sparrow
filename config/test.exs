import Config

config :sparrow, Sparrow.H2ClientAdapter, %{
  adapter: Sparrow.H2ClientAdapter.Mock
}

config :sparrow, Sparrow.PoolsWarden, %{enabled: false}

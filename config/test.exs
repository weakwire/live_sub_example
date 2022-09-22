import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :live_sub_example, LiveSubExampleWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "d258DLx/MH4eQ/evWCO3DkoUo5wz8aOlNJnc7C7dPPRVotFlzdcOzaL0YEjsOzXg",
  server: false

# In test we don't send emails.
config :live_sub_example, LiveSubExample.Mailer, adapter: Swoosh.Adapters.Test

# Print only warnings and errors during test
config :logger, level: :warn

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

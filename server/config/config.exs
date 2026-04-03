# This file is responsible for configuring your umbrella
# and **all applications** and their dependencies with the
# help of the Config module.
#
# Note that all applications in your umbrella share the
# same configuration and dependencies, which is why they
# all use the same configuration file. If you want different
# configurations or dependencies per app, it is best to
# move said applications out of the umbrella.
# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :dot_prompt,
  prompts_dir: "prompts"

config :dot_prompt_server,
  generators: [timestamp_type: :utc_datetime]

# Configure the endpoint
config :dot_prompt_server, DotPromptServerWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: DotPromptServerWeb.ErrorJSON, html: DotPromptServerWeb.ErrorHTML],
    layout: false
  ],
  pubsub_server: DotPromptServer.PubSub,
  live_view: [signing_salt: "d52DGzoR"]

config :dot_prompt_server, DotPromptServer.PubSub, adapter: Phoenix.PubSub.PG2

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"

# Sample configuration:
#
#     config :logger, :console,
#       level: :info,
#       format: "$date $time [$level] $metadata$message\n",
#       metadata: [:user_id]
#

import Config

if config_env() == :prod do
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise "ENVIRONMENT VARIABLE SECRET_KEY_BASE IS MISSING"

  signing_salt =
    System.get_env("LIVE_VIEW_SIGNING_SALT") ||
      raise "ENVIRONMENT VARIABLE LIVE_VIEW_SIGNING_SALT IS MISSING"

  config :dot_prompt,
    prompts_dir: System.get_env("PROMPTS_DIR") || "/app/prompts"

  # Use HTTP instead of HTTPS for easier container testing
  config :dot_prompt_server, DotPromptServerWeb.Endpoint,
    url: [host: System.get_env("PHX_HOST") || "localhost", port: 4000, scheme: "http"],
    http: [
      ip: {0, 0, 0, 0},
      port: String.to_integer(System.get_env("PORT") || "4000")
    ],
    secret_key_base: secret_key_base,
    live_view: [signing_salt: signing_salt],
    server: true
end

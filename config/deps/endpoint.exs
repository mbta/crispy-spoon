import Config

# Configures the endpoint
config :dotcom, DotcomWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "yK6hUINZWlq04EPu3SJjAHNDYgka8MZqgXZykF+AQ2PvWs4Ua4IELdFl198aMvw0",
  render_errors: [accepts: ~w(html), layout: {DotcomWeb.LayoutView, "root.html"}],
  pubsub_server: Dotcom.PubSub,
  live_view: [
    signing_salt: "gsQiz0LdGqVmqDOR4snAgelIAAphhdfm"
  ]

if config_env() == :prod do
  # For producton, we configure the host to read the PORT
  # from the system environment. Therefore, you will need
  # to set PORT=80 before running your server.
  #
  # You should also configure the url host to something
  # meaningful, we use this information when generating URLs.
  #
  # Finally, we also include the path to a manifest
  # containing the digested version of static files. This
  # manifest is generated by the mix phx.digest task
  # which you typically run after static files are built.
  config :dotcom, DotcomWeb.Endpoint, cache_static_manifest: "priv/static/cache_manifest.json"
end

if config_env() == :dev do
  # Watch static and templates for browser reloading.
  config :dotcom, DotcomWeb.Endpoint,
    debug_errors: true,
    code_reloader: true,
    check_origin: false,
    watchers: [npm: ["run", "webpack:watch", cd: Path.expand("../../assets/", __DIR__)]],
    live_reload: [
      patterns: [
        ~r{priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$},
        ~r{priv/gettext/.*(po)$},
        ~r{lib/dotcom_web/components/.*(ex)$},
        ~r{lib/dotcom_web/views/.*(ex)$},
        ~r{lib/dotcom_web/templates/.*(heex|eex)$},
        ~r{lib/dotcom_web/live/.*(heex|ex)$},
        ~r"storybook/.*(exs)$"
      ]
    ]
end

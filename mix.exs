defmodule DotCom.Mixfile do
  @moduledoc false
  use Mix.Project

  def project do
    [
      # app and version expected by `mix compile.app`
      app: :dotcom,
      version: "0.0.1",
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: Mix.compilers(),
      # configures `mix compile` to embed all code and priv content in the _build directory instead of using symlinks
      build_embedded: Mix.env() == :prod,
      # used by `mix app.start` to start the application and children in permanent mode, which guarantees the node will shut down if the application terminates (typically because its root supervisor has terminated).
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.html": :test
      ],
      dialyzer: [
        plt_add_apps: [:mix, :phoenix_live_reload],
        flags: [:unmatched_returns],
        ignore_warnings: ".dialyzer.ignore-warnings"
      ],
      deps: deps(),

      # docs
      name: "MBTA Website",
      source_url: "https://github.com/mbta/dotcom",
      homepage_url: "https://www.mbta.com/",
      # The main page in the docs
      docs: [logo: "priv/static/images/mbta-logo-t.png"]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:dev),
    do: ["lib", "test/support/factories", "test/support/factory_helpers.ex"]

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Configuration for the OTP application generated by `mix compile.app`
  def application do
    extra_apps = [
      :logger,
      :runtime_tools,
      :os_mon
    ]

    extra_apps =
      if Mix.env() == :prod do
        [:sasl | extra_apps]
      else
        extra_apps
      end

    [
      # the module to invoke when the application is started
      mod: {Dotcom.Application, []},
      # a list of OTP applications your application depends on which are not included in :deps
      extra_applications: extra_apps
    ]
  end

  # You can check the status of each dependency by running `mix hex.outdated`.
  # Dependencies that cannot be updated are noted in comments.
  # Note that you should also update `.github/dependabot.yml` and remove ignore overrides for any dependencies you update.
  defp deps do
    [
      {:absinthe_client, "0.1.1"},
      {:address_us, "0.4.3"},
      {:aws, "1.0.4"},
      {:aws_credentials, "0.3.2", optional: true},
      {:castore, "1.0.11"},
      {:crc, "0.10.5"},
      {:credo, "1.7.11", only: [:dev, :test]},
      {:csv, "3.2.2"},
      {:cva, "0.2.2"},
      {:decorator, "1.4.0"},
      {:dialyxir, "1.4.5", [only: [:dev, :test], runtime: false]},
      {:diskusage_logger, "0.2.0"},
      {:ecto, "3.12.5"},
      {:eflame, "1.0.1", only: :dev},
      {:ehmon, [github: "mbta/ehmon", only: :prod]},
      {:ex_doc, "0.36.1", only: :dev},
      {:ex_machina, "2.8.0", only: [:dev, :test]},
      {:ex_unit_summary, "0.1.0", only: [:dev, :test]},
      {:excoveralls, "0.18.5", only: :test},
      {:faker,
       git: "https://github.com/elixirs/faker.git",
       override: true,
       branch: "master",
       only: [:dev, :test]},
      {:floki, "0.37.0"},
      {:gen_stage, "1.2.1"},
      {:gettext, "0.26.2"},
      {:hackney, "1.20.1"},
      {:hammer, "6.2.1"},
      {:html_sanitize_ex, "1.4.3"},
      {:httpoison, "2.2.1"},
      {:inflex, "2.1.0"},
      {:jason, "1.4.4", override: true},
      {:logster, "1.1.1"},
      {:mail, "0.3.1"},
      {:mbta_metro, "0.1.21"},
      {:mock, "0.3.9", [only: :test]},
      {:mox, "1.2.0", [only: :test]},
      {:msgpack, "0.8.1"},
      {:nebulex, "2.6.4"},
      {:nebulex_redis_adapter, "2.4.2"},
      {
        :open_trip_planner_client,
        [github: "mbta/open_trip_planner_client", tag: "v0.11.3"]
      },
      {:parallel_stream, "1.1.0"},
      {:phoenix, "1.7.18"},
      {:phoenix_ecto, "4.6.3"},
      {:phoenix_html_helpers, "1.0.1"},
      {:phoenix_live_dashboard, "0.8.6"},
      {:phoenix_live_reload, "1.5.3", only: [:dev, :test]},
      {:phoenix_live_view, "1.0.2", override: true},
      {:phoenix_pubsub, "2.1.3"},
      {:phoenix_view, "~> 2.0"},
      {:plug, "1.16.1"},
      {:plug_cowboy, "2.7.2"},
      {:poison, "6.0.0"},
      {:polyline, "1.5.0"},
      {:poolboy, "1.5.2"},
      # Needed for rstar; workaround for mix local.hex bug
      {:proper, "1.4.0"},
      {:quixir, "0.9.3", [only: :test]},
      {:recaptcha, "3.1.0"},
      {:recase, "0.8.1"},
      {:recon, "2.5.6", [only: :prod]},
      {:redix, "1.5.2"},
      {:req, "0.5.8"},
      {:rstar, github: "armon/erl-rstar"},
      {:sentry, "10.8.1"},
      {:server_sent_event_stage, "1.2.1"},
      {:sizeable, "1.0.2"},
      {:sweet_xml, "0.7.5", only: [:dev, :prod]},
      {:telemetry, "1.3.0", override: true},
      {:telemetry_metrics, "1.1.0", override: true},
      {:telemetry_metrics_splunk, "0.0.6-alpha"},
      {:telemetry_poller, "1.1.0"},
      {:telemetry_test, "0.1.2", only: [:test]},
      {:timex, "3.7.11"},
      {:typed_ecto_schema, "0.4.1"},
      {:unrooted_polytree, "0.1.1"},
      {:uuid, "1.1.8"},
      {:wallaby, "0.30.10", [runtime: false, only: [:dev, :test]]},
      {:yaml_elixir, "2.11.0", only: [:dev]},
      {:ymlr, "5.1.3", only: [:dev]}
    ]
  end
end

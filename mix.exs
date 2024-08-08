defmodule DotCom.Mixfile do
  use Mix.Project

  def project do
    [
      # app and version expected by `mix compile.app`
      app: :dotcom,
      version: "0.0.1",
      elixir: "~> 1.12",
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
        plt_add_apps: [:mix, :phoenix_live_reload, :ex_aws, :ex_aws_ses],
        flags: [:unmatched_returns],
        ignore_warnings: ".dialyzer.ignore-warnings"
      ],
      deps: deps(),

      # docs
      name: "MBTA Website",
      source_url: "https://github.com/mbta/dotcom",
      homepage_url: "https://www.mbta.com/",
      # The main page in the docs
      docs: [logo: "assets/static/images/mbta-logo-t.png"]
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
      {:castore, "1.0.8"},
      {:crc, "0.10.5"},
      {:credo, "1.7.7", only: [:dev, :test]},
      {:csv, "3.2.1"},
      {:decorator, "1.4.0"},
      {:dialyxir, "1.4.3", [only: [:test, :dev], runtime: false]},
      {:diskusage_logger, "0.2.0"},
      {:eflame, "1.0.1", only: :dev},
      {:ehmon, [github: "mbta/ehmon", only: :prod]},
      {:ex_aws, "2.5.4"},
      {:ex_aws_s3, "2.5.3"},
      {:ex_aws_ses, "2.4.1"},
      {:ex_doc, "0.34.2", only: :dev},
      {:ex_machina, "2.8.0", only: [:dev, :test]},
      {:ex_unit_summary, "0.1.0", only: [:dev, :test]},
      {:excoveralls, "0.18.2", only: :test},
      {:faker, "0.18.0", only: [:dev, :test]},
      {:floki, "0.36.2"},
      {:gen_stage, "1.2.1"},
      {:gettext, "0.25.0"},
      {:hackney, "1.20.1"},
      {:hammer, "6.2.1"},
      {:html_sanitize_ex, "1.4.3"},
      {:httpoison, "2.2.1"},
      {:inflex, "2.1.0"},
      {:jason, "1.4.4", override: true},
      {:logster, "1.1.1"},
      {:mail, "0.3.1"},
      {:mock, "0.3.8", [only: :test]},
      {:mox, "1.1.0", [only: :test]},
      {:nebulex, "2.6.3"},
      {:nebulex_redis_adapter, "2.4.0"},
      {:open_trip_planner_client, [github: "thecristen/open_trip_planner_client", tag: "v0.9.3"]},
      {:parallel_stream, "1.1.0"},
      # latest version 1.7.14
      {:phoenix, "~> 1.7"},
      # latest version 4.1.1; cannot upgrade because we use Phoenix.HTML
      {:phoenix_html, "3.3.3"},
      {:phoenix_live_dashboard, "0.8.4"},
      {:phoenix_live_reload, "1.5.3", [only: :dev]},
      {:phoenix_live_view, "0.20.17"},
      {:phoenix_pubsub, "2.1.3"},
      {:phoenix_view, "~> 2.0"},
      {:plug, "1.16.1"},
      {:plug_cowboy, "2.7.1"},
      {:poison, "6.0.0"},
      {:polyline, "1.4.0"},
      {:poolboy, "1.5.2"},
      # Needed for rstar; workaround for mix local.hex bug
      {:proper, "1.4.0"},
      {:quixir, "0.9.3", [only: :test]},
      # Required to mock challenge failures. Upgrade once a version > 3.0.0 is released.
      {:recaptcha,
       [
         github: "samueljseay/recaptcha",
         ref: "8ea13f63990ca18725ac006d30e55d42c3a58457"
       ]},
      {:recase, "0.8.1"},
      {:recon, "2.5.5", [only: :prod]},
      {:redix, "1.5.1"},
      {:req, "0.5.6"},
      {:rstar, github: "armon/erl-rstar"},
      # latest version 10.1.0; cannot upgrade because setup appears to have changed
      {:sentry, "7.2.5"},
      {:server_sent_event_stage, "1.2.1"},
      {:sizeable, "1.0.2"},
      {:sweet_xml, "0.7.4", only: [:prod, :dev]},
      {:telemetry, "1.2.1", override: true},
      {:telemetry_metrics, "1.0.0", override: true},
      {:telemetry_metrics_splunk, "0.0.6-alpha"},
      {:telemetry_poller, "1.1.0"},
      {:telemetry_test, "0.1.2", only: [:test]},
      {:timex, "3.7.11"},
      {:unrooted_polytree, "0.1.1"},
      {:uuid, "1.1.8"},
      {:wallaby, "0.30.9", [runtime: false, only: [:test, :dev]]},
      {:yaml_elixir, "2.11.0", only: [:dev]},
      {:ymlr, "5.1.3", only: [:dev]}
    ]
  end
end

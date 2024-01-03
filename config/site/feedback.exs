import Config

config :site,
  test_mail_file: "/tmp/test_support_email.json",
  time_fetcher: DateTime

if config_env() == :test do
  config :site,
    time_fetcher: Feedback.FakeDateTime,
    exaws_config_fn: &Feedback.Test.mock_config/1,
    exaws_perform_fn: &Feedback.Test.mock_perform/2,
    feedback_rate_limit: 1_000
end

if config_env() == :dev do
  config :site,
    exaws_config_fn: &Feedback.MockAws.config/1,
    exaws_perform_fn: &Feedback.MockAws.perform/2
end

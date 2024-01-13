import Config

config :laboratory,
  features: [
    {:force_otp1, "Force OpenTripPlanner v1",
     "Override randomized assignment between OTP instances and force OTP1."},
    {:force_otp2, "Force OpenTripPlanner v2",
     "Override randomized assignment between OTP instances and force OTP2 (this takes precedent if both flags are enabled)."}
  ],
  cookie: [
    # one month,
    max_age: 3600 * 24 * 30,
    http_only: true
  ]

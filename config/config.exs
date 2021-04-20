import Config

config(:elevator_project,
  num_floors: 4,
  door_open_duration_ms: 3_000,
  floor_poll_rate_ms: 50,
  obs_poll_rate_ms: 50,
  buttons_poll_rate_ms: 25,
  button_map: %{:btn_hall_up => 0, :btn_hall_down => 1, :btn_cab => 2},
  button_types: [:btn_hall_up, :btn_hall_down, :btn_cab],
  broadcast_ms: 100,
  master_timeout_ms: 5000,
  move_timeout_ms: 7000,
  watchdog_timeout_ms: 20_000,
  port_driver: 17779,

  # dev
  local_nodes: 3,
  env: Mix.env()
  # to enable :test or :dev specific behaviour of functions
)

config :logger, :console,
  format: "[$level] $message $metadata\n",
  metadata: [:mfa]

# import_config "#{config_env()}.exs"

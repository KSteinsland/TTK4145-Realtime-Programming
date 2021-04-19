import Config

config(:elevator_project,
  num_floors: 4,
  door_open_duration_ms: 3_000,
  # 25,
  input_poll_rate_ms: 15,
  button_map: %{:btn_hall_up => 0, :btn_hall_down => 1, :btn_cab => 2},
  button_types: [:btn_hall_up, :btn_hall_down, :btn_cab],
  broadcast_ms: 100,
  master_timeout_ms: 7000,
  watchdog_timeout_ms: 20_000,

  # dev
  # local nodes is primary node + # of slaves
  # when testing on a single computer
  local_nodes: 3,
  port_driver: 17779,
  env: Mix.env()
  # to enable :test or :dev specific behaviour of functions
)

# config_env()
if Mix.env() == :test do
  IO.puts("Test config loaded!")

  config(:elevator_project,
    # broadcast_ms: 450,
    # master_timeout_ms: 2000,
    # TODO make sleep times in test depent on master_timeout!

    # Normal speed divided by ca. 2
    # input_poll_rate_ms is lower because of all IO
    input_poll_rate_ms: 8,
    door_open_duration_ms: 750,
    sim_opts: [
      travelTimeBetweenFloors_ms: 1000,
      travelTimePassingFloor_ms: 350,
      btnDepressedTime_ms: 100
    ]
  )
end

config :logger, :console,
  format: "[$level] $message $metadata\n",
  metadata: [:mfa]

# import_config "#{config_env()}.exs"

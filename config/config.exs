import Config

config(:elevator_project,
  num_floors: 4,
  num_buttons: 3,
  door_open_duration_ms: 3_000,
  # 25,
  input_poll_rate_ms: 15,
  directions: [:dir_up, :dir_down, :dir_stop],
  behaviours: [:be_idle, :be_door_open, :be_moving],
  button_map: %{:btn_hall_up => 0, :btn_hall_down => 1, :btn_cab => 2},
  button_types: [:btn_hall_up, :btn_hall_down, :btn_cab],

  # dev
  # local nodes is primary node + # of slaves
  # when testing on a single computer
  local_nodes: 2,
  port_driver: 17777
)

if config_env() == :test do
  IO.puts("Test config loaded!")

  config(:elevator_project,
    # Normal speed divided by four
    # input_poll_rate_ms is lower because of all IO
    input_poll_rate_ms: 3,
    door_open_duration_ms: 750,
    sim_opts: [
      travelTimeBetweenFloors_ms: 500,
      travelTimePassingFloor_ms: 125,
      btnDepressedTime_ms: 40
    ]
  )
end

# import_config "#{config_env()}.exs"

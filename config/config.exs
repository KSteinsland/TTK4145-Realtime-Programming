import Config

config :elevator_project,
  num_floors: 4,
  num_buttons: 3,
  directions: [:dir_up, :dir_down, :dir_stop],
  behaviours: [:be_idle, :be_door_open, :be_moving],
  button_map: %{:btn_hall_up => 0, :btn_hall_down => 1, :btn_cab => 2},
  hall_button_map: %{:btn_hall_up => 0, :btn_hall_down => 1},
  # dev
  # local nodes is primary node + # of slaves
  # when testing on a single computer
  local_nodes: 2,
  port_driver: 17777

# import_config "#{config_env()}.exs"

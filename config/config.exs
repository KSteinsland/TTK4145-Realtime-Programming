import Config

config :elevator_project,
  num_floors: 4,
  num_buttons: 3,
  directions: [:dir_up, :dir_down, :dir_stop],
  behaviours: [:be_idle, :be_door_open, :be_moving],
  button_types: [:btn_hall_up, :btn_hall_down, :btn_cab],
  button_map: %{:btn_hall_up => 0, :btn_hall_down => 1, :btn_cab => 2}

# import_config "#{config_env()}.exs"

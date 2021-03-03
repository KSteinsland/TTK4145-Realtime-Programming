
import Config 

config :elevator_project, 
    num_floors: 4, 
    num_buttons: 3,
    directions: {:Dir_up, :Dir_down, :Dir_stop},
    behaviours: {:Be_idle, :Be_door_open, :Be_moving},
    button_types: {:Btn_hall_up, :Btn_hall_down, :Btn_cab},
    button_map: %{:Btn_hall_up => 0, :Btn_hall_down => 1, :Btn_cab => 2}

#import_config "#{config_env()}.exs"
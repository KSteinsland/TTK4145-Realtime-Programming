defmodule LightHandler do
  @moduledoc """
  Puts on/off the light when a change in hall request occurs in state_server.
  """

  @num_floors Application.fetch_env!(:elevator_project, :num_floors)
  @num_buttons Application.fetch_env!(:elevator_project, :num_buttons)
  @btn_types Application.fetch_env!(:elevator_project, :button_types)
  @hall_btn_types List.delete(@btn_types, :btn_cab)

  alias StateInterface, as: SI
  alias StateServer, as: SS


  def get_hall_requests do
    hall_requests = SS.get_state.hall_requests    # Get the hall_requests struct from the StateServer.
    i = 0
    for hall_order <- hall_requests.hall_orders do
      lightController(hall_order, i)
      i = i + 1
    end
  end

  def light_controller(hall_order, floor) do
    btn_state_Up = Enum.at(hall_order, 0)
    btn_state_Down = Enum.at(hall_order, 1)

    case btn_state_Up do
      :done ->
        Driver.set_order_button_light(Enum.at(hall_btn_types, 0), floor, :off)
      :new ->
        Driver.set_order_button_light(Enum.at(hall_btn_types, 0), floor, :on)
    end


    case btn_state_Down do
      :done ->
        Driver.set_order_button_light(Enum.at(hall_btn_types, 1), floor, :off)
      :new ->
        Driver.set_order_button_light(Enum.at(hall_btn_types, 1), floor, :on)
    end

  end

  def light_check do
    #Check if lights are already turned on/off before running light_controller.

  end

end

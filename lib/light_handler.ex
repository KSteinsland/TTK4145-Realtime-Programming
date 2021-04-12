defmodule LightHandler do
  @moduledoc """
  Puts on/off the light on the hall buttons when a change in hall request occurs in state_server.
  """


  @btn_types Application.fetch_env!(:elevator_project, :button_types)
  @hall_btn_types List.delete(@btn_types, :btn_cab)
  @doc """
  hall_btn_types = {:btn_hall_up, :btn_hall_down}
  """


  alias StateServer, as: SS

  @doc """
  1: Checks if there is a state change in hall_orders.
  2: If state change -> turn light on or off.
  3: If no state change -> loop back to 1.
  """
  def light_controller(hall_orders) do
    # hall_orders = light_check(nil)    # Checks if hall_orders have changed, returns hall_orders

    for {hall_order, i} <- Enum.with_index(hall_orders) do  # Iterates through hall_orders, [[:done, :done][:done, :done][:done, :done]], and returns hall_order [:done, :done].
      light_logic(hall_order, i)      # Turns the light on or off

    end
  end

  @doc """
  Takes in  hall_order, ex.: [:new, :done],
    where hall_order[0] = :btn_hall_up,
          hall_order[1] = :btn_hall_down.
  If hall_order[0] = :done, turn off light.
  If hall_order[0] = :new, turn on light.
  Same logic for hall_order[1].
  """
  def light_logic(hall_order, floor) do
    btn_state_Up = Enum.at(hall_order, 0)
    btn_state_Down = Enum.at(hall_order, 1)

    case btn_state_Up do
      :done ->
        Driver.set_order_button_light(Enum.at(@hall_btn_types, 0), floor, :off)
      :new ->
        Driver.set_order_button_light(Enum.at(@hall_btn_types, 0), floor, :on)
    end


    case btn_state_Down do
      :done ->
        Driver.set_order_button_light(Enum.at(@hall_btn_types, 1), floor, :off)
      :new ->
        Driver.set_order_button_light(Enum.at(@hall_btn_types, 1), floor, :on)
    end

  end


  @doc """
  Checks if hall_orders have changed by comparing prevoius and current hall_orders state.
  If no state change -> do nothing (by running in an ifinite loop).
  If state change -> continue and return hall_orders (the new state).
  """
  def light_check(current_state, previous_state) do
    # currentState = SS.get_state.hall_requests.hall_orders
    if previous_state != current_state || previous_state == nil do
      light_controller(current_state.hall_orders)
    end
  end

end

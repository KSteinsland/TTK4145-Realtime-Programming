defmodule LightHandler do
  @moduledoc """
  Puts on/off the light on the hall buttons when a change in hall request occurs in state_server.
  """

  @btn_types Application.fetch_env!(:elevator_project, :button_types)
  @hall_btn_types List.delete(@btn_types, :btn_cab)

  @doc """
  Checks if hall_requests have changed by comparing prevoius and current hall_requests state.
  If no state change -> do nothing.
  If state change -> continue and call light_controller.
  """
  def light_check(current_state, previous_state) do
    if previous_state != current_state || previous_state == nil do
      light_controller(current_state)
    end
  end

  @doc """
  If state change -> turn light on or off.
  """
  def light_controller(hall_requests) do
    # Iterates through hall_requests, [[:done, :done][:done, :done][:done, :done]], and returns hall_order [:done, :done].
    for {hall_order, i} <- Enum.with_index(hall_requests) do
      # Turns the light on or off
      light_logic(hall_order, i)
    end
  end

  @doc """
  Takes in  hall_order, ex.: [:new, :done],
    where hall_order[0] = :btn_hall_up,
          hall_order[1] = :btn_hall_down.
  If hall_order[0] = :done, turn off light.
  If hall_order[0] = :new, or :assigned turn on light.
  Same logic for hall_order[1].
  """
  def light_logic(hall_order, floor) do
    btn_state_Up = Enum.at(hall_order, 0)
    btn_state_Down = Enum.at(hall_order, 1)

    case btn_state_Up do
      :done ->
        Driver.set_order_button_light_on_nodes(Enum.at(@hall_btn_types, 0), floor, :off)

      _ ->
        # catches :new and :assigned
        Driver.set_order_button_light_on_nodes(Enum.at(@hall_btn_types, 0), floor, :on)
    end

    case btn_state_Down do
      :done ->
        Driver.set_order_button_light_on_nodes(Enum.at(@hall_btn_types, 1), floor, :off)

      _ ->
        # catches :new and :assigned
        Driver.set_order_button_light_on_nodes(Enum.at(@hall_btn_types, 1), floor, :on)
    end
  end
end

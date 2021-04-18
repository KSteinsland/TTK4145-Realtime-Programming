defmodule LightHandlerTest do
  use ExUnit.Case, async: false
  doctest LightHandler

  defmodule Test_hall_requests do
    defstruct off: [
      [:done, :done],
      [:done, :done],
      [:done, :done],
      [:done, :done]
      ],

      on: [
        [:new, :new],
        [:new, :new],
        [:new, :new],
        [:new, :new]
        ],

      variations: [
        [:new, :done],
        [:new, :new],
        [:done, :done],
        [:done, :new]
        ]
    end

  test "light_check" do
    test_hall_requests = %Test_hall_requests{}

    # Turns all lights on from state=nil
    assert LightHandler.light_check(test_hall_requests.on, nil) == nil
    # Checks nothing happens when current_state = previous_state.
    assert LightHandler.light_check(test_hall_requests.off, test_hall_requests.off) == nil
    # Turns all lights off from state = on
    assert LightHandler.light_check(test_hall_requests.off, test_hall_requests.on) == [:abcast, :abcast, :abcast, :abcast]
    # Turns all lights on from state = off
    assert LightHandler.light_check(test_hall_requests.on, test_hall_requests.off) == [:abcast, :abcast, :abcast, :abcast]
    # Turns lights to "variations" from state = off
    assert LightHandler.light_check(test_hall_requests.variations, test_hall_requests.off) == [:abcast, :abcast, :abcast, :abcast]
    # Turns lights to "variations" from state = on
    assert LightHandler.light_check(test_hall_requests.variations, test_hall_requests.on) == [:abcast, :abcast, :abcast, :abcast]
  end

end

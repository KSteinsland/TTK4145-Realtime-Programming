# ElevatorProject ![](https://github.com/KSteinsland/TTK4145/workflows/Elixir%20CI/badge.svg) [![Coverage Status](https://coveralls.io/repos/github/KSteinsland/TTK4145/badge.svg?branch=main&t=jZrpDf)](https://coveralls.io/github/KSteinsland/TTK4145?branch=main)

## Start
To start the program run the command
`iex --name nodename@nodeip --vm-args ./vm.args -S mix` in the repository.
Make sure to run `mix deps.get` first.

## Documentation

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc),
Run `mix deps.get && mix docs` to generate.

## Dependencies

The dependencies (libraries) used can be found in 'mix.exs':

```elixir
def deps do
  [
    {:ex_doc, "~> 0.21", only: :dev, runtime: false},
    {:excoveralls, "~> 0.10", only: :test},
    {:json, "~> 1.4"}
  ]
 end
 '''

Ex_doc and excoveralls are used in documentation and testing respectively and are therefore
not directly used in the program.
The JSON dependency is used in 'assignment.ex' where it's main function is to convert elixir
code into JSON-format and vice versa.
More documentation on JSON can be found at "https://hexdocs.pm/json/readme.html".
(The dependencies used are not including Elang functions since it's build upon Elixir)

## Credits

The design for one elevator found in the "Elevator" folder is based upon the single elevator code
for found at "https://github.com/TTK4145/Project-resources/tree/master/elev_algo".

The "driver" module (found under "hardware") is based upon the Elixir driver given at "https://github.com/TTK4145/driver-elixir".

Additionally, the "assignment" module, which is responsible for the calculations over which elevator that should do a given hall request, is dependent on the "Hall_Request_Assigner" found at "https://github.com/TTK4145/Project-resources/tree/master/cost_fns/hall_request_assigner".

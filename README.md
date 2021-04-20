# ElevatorProject ![](https://github.com/KSteinsland/TTK4145/workflows/Elixir%20CI/badge.svg) [![Coverage Status](https://coveralls.io/repos/github/KSteinsland/TTK4145/badge.svg?branch=main&t=jZrpDf)](https://coveralls.io/github/KSteinsland/TTK4145?branch=main)
**TODO: Add description**


## Testing

For å kjøre tester har vi tre aliaser (shortcuts):

### mix test_unit
  Denne kommandoen kjører alle "vanlige" tester uten å starte applikasjonen.
  Alle unit tester bør ikke være avhengige av noen andre moduler eller prosesser enn modulen man tester.
  
### mix test_integration
  Denne kommandoen kjører alle tester markert med `@tag:external`, men her starter man heller ikke applikasjonen, 
  så man må selv starte prosessene man trenger i setup av testen.

### mix test_distributed
  Kjører alle tester markert med `@tag:distributed` og starter applikasjonen før testene kjøres.
  I tillegg vil man starte opp et antall noder som også starter applikasjonen, samt et antall heissimualutorer.
  Dette er for å teste ting som krever flere noder.

---

I tillegg har vi et par shortcuts:

### mix start_sim
  Starter et antall simulatorer.

### mix open_sim
  NB! Fungerer kun på mac dessverre
  Starter et antall simulatorer og åpner vinduet 

### Koble seg til simulatorene

  Etter at man har enten startet simulatoren eller kjørt en test kommando som har startet et antall simulatorer kan man koble seg til simulatorene
  med kommandoen `tmux attach-session -t SimTest`

### mix start_cluster
  Starter et antall noder. En mindre enn antall simulatorer 

### mix open_cluster
  NB! Fungerer kun på mac dessverre
  Starter et antall noder og åpnet vinduet. En mindre enn antall simulatorer 

### Koble seg til cluster-nodene

  Etter at man har enten startet cluster kan man koble seg til med
  med kommandoen `tmux attach-session -t ClusterTest`

### Test support
  
  Vi har to moduler for å hjelpe til med testing:
  
  * Simulator
    
    her er funksjonen `send_key(key, elevator \\ 0)` nyttig for å samhandle med simulatoren til heisene.


  * Cluster
    
    her er funksjonen `rpc(node, module, function, args)` nytting for å kalle på en funksjon på en vilkårlig node
    se dokumentasjon for `:rpc.block_call` for mer info.
 


## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `elevator_project` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:elevator_project, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/elevator_project](https://hexdocs.pm/elevator_project).

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
More documentation on JSON can be found at [https://hexdocs.pm/json/readme.html].
(The dependencies used are not including Elang functions since it's build upon Elixir)

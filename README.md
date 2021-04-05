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
  Når denne kommandoen blir kjørt vil heissimulatoren startes med en konfigurasjon som gjør at heisen vil bevege seg kjapt.

### mix test_distributed
  Kjører alle tester markert med `@tag:distributed` og starter applikasjonen før testene kjøres.
  I tillegg vil man starte opp et antall noder som også starter applikasjonen, samt et antall heissimualutorer.
  Dette er for å teste ting som krever flere noder.

---

I tillegg har vi en shortcut for å kun starte simulatoren som normalt

### mix start_sim
  her skal heisen bruke normal tid på å åpne dører og bevege seg mellom etasjer

### Koble seg til simulatorene

  Etter at man har enten startet simulatoren eller kjørt en test kommando som har startet et antall simulatorer kan man koble seg til simulatorene
  med kommandoen `tmux attach-session -t SimTest`

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


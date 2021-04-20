# Loads support modules
{:ok, files} = File.ls("./test/support")

Enum.each(files, fn file ->
  Code.require_file("support/#{file}", __DIR__)
end)

# Setup cleanup function, runs after all tests
ExUnit.after_suite(fn _ ->
  # Stops the cluster unless someone is attached
  Cluster.cleanup()
end)

ExUnit.start()

# Exclude all external and distributed tests from running
ExUnit.configure(exclude: [external: true, distributed: true])

conf = ExUnit.configuration()

# check what tests we want to run
cond do
  conf[:include][:distributed] == "true" ->
    IO.puts("Running distributed tests")
    # Get config
    port = Application.fetch_env!(:elevator_project, :port_driver)
    num_local_nodes = Application.fetch_env!(:elevator_project, :local_nodes)

    System.cmd("epmd", ["-daemon"])

    # Is this bad and needs fixing?
    ElevatorProject.Application.start(nil, nil)

    Cluster.spawn(port + 1, num_local_nodes - 1)
    IO.puts("Started cluster")

  conf[:include][:external] == "true" ->
    IO.puts("Running integration tests")

  true ->
    IO.puts("Running unit tests")
end

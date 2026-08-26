defmodule Hologram.Test do
  @doc """
  Starts Hologram for feature/browser tests.

  Runs the Hologram compiler and restarts the application with the full
  supervisor tree. Call this in your `test_helper.exs` before running
  tests that need Hologram pages served in the browser.

      # test_helper.exs
      Hologram.Test.setup()
  """
  @spec setup() :: {:ok, [atom()]} | {:error, {atom(), term()}}
  def setup do
    System.put_env("HOLOGRAM_START", "1")

    # credo:disable-for-next-line Credo.Check.Design.AliasUsage
    Mix.Tasks.Compile.Hologram.run(force?: true)

    supervisor = Process.whereis(Hologram.Supervisor)
    monitor_ref = if supervisor, do: Process.monitor(supervisor)

    Application.stop(:hologram)
    await_supervisor_shutdown(supervisor, monitor_ref)
    Application.ensure_all_started(:hologram)
  end

  defp await_supervisor_shutdown(nil, nil), do: :ok

  defp await_supervisor_shutdown(supervisor, monitor_ref) do
    receive do
      {:DOWN, ^monitor_ref, :process, ^supervisor, _reason} -> :ok
    after
      5_000 -> raise "Hologram supervisor did not stop within 5 seconds"
    end
  end
end

defmodule Mix.Tasks.Holo.Test.UpdateVoltManifest do
  @shortdoc "Updates the canonical JavaScript test parity manifest"
  @moduledoc false

  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    Hologram.Reflection.root_dir()
    |> Path.join("dev/update_volt_js_test_manifest.exs")
    |> Code.eval_file()
  end
end

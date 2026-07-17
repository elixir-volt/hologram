alias Hologram.Assets.NPMDeps
alias Hologram.Test.NPMDeps, as: TestNPMDeps

root = Path.expand("..", __DIR__)

update_lock = fn packages, destination ->
  %{install_dir: install_dir} = Volt.NPM.install!(packages, force: true)
  source = Path.join(install_dir, "npm.lock")
  File.cp!(source, destination)
  Mix.shell().info("Updated #{Path.relative_to(destination, root)}")
end

update_lock.(NPMDeps.packages(), Path.join(root, "priv/npm.lock"))
update_lock.(TestNPMDeps.packages(), Path.join(root, "test/npm.lock"))

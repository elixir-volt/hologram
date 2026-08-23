defmodule Hologram.Volt.FunctionSourceTest do
  use Hologram.Test.BasicCase, async: true

  alias Hologram.Volt.FunctionSource

  test "moves outermost function expressions into eval strings" do
    source = "const outer = () => { const inner = () => 1; return inner; };"

    assert {:ok, transformed} = FunctionSource.preserve(source, "source.mjs")

    assert transformed ==
             ~S|const outer = eval("() => { const inner = () => 1; return inner; }");|
  end

  test "preserves separate outermost function expressions" do
    source = "const a = () => 1; const b = function () { return 2; };"

    assert {:ok, transformed} = FunctionSource.preserve(source, "source.mjs")

    assert transformed ==
             ~S|const a = eval("() => 1"); const b = eval("function () { return 2; }");|
  end

  test "returns source unchanged when it has no function expressions" do
    source = "const value = 1;"
    assert FunctionSource.preserve(source, "source.mjs") == {:ok, source}
  end

  test "returns parse errors" do
    assert {:error, [_error | _errors]} = FunctionSource.preserve("const =", "source.mjs")
  end
end

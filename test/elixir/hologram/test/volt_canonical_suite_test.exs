defmodule Hologram.Test.VoltCanonicalSuiteTest do
  use Hologram.Test.BasicCase, async: true

  alias Hologram.Test.VoltCanonicalSuite
  alias Volt.Test.Result

  test "accepts matching test count and names hash" do
    result = result_fixture(["Suite › first", "Suite › second"])

    assert VoltCanonicalSuite.assert_parity!(result, parity_fixture(result.tests)) == :ok
  end

  test "raises when test count or names differ" do
    result = result_fixture(["Suite › first", "Suite › second"])
    parity = parity_fixture([%Result.Test{full_name: "Suite › different"}])

    assert_raise ExUnit.AssertionError, ~r/canonical JavaScript parity mismatch/, fn ->
      VoltCanonicalSuite.assert_parity!(result, parity)
    end
  end

  test "does nothing without parity metadata" do
    result = result_fixture([])

    assert VoltCanonicalSuite.assert_parity!(result, nil) == :ok
  end

  defp parity_fixture(tests) do
    names =
      tests
      |> Enum.map(& &1.full_name)
      |> Enum.sort()

    hash =
      names
      |> Jason.encode!()
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)

    %{"count" => length(tests), "namesSha256" => hash}
  end

  defp result_fixture(names) do
    tests = Enum.map(names, &%Result.Test{full_name: &1})
    %Result{file: "test/javascript/example_test.mjs", total: length(tests), tests: tests}
  end
end

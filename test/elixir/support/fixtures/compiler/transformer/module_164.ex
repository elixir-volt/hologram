# credo:disable-for-this-file Credo.Check.Readability.Specs
# credo:disable-for-this-file Credo.Check.Refactor.RedundantWithClauseResult
# credo:disable-for-this-file ExSlop.Check.Refactor.WithIdentityDo
defmodule Hologram.Test.Fixtures.Compiler.Transformer.Module164 do
  def test(y) do
    with :ok <- y do
      :ok
    end
  end
end

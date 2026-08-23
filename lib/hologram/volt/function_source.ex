defmodule Hologram.Volt.FunctionSource do
  @moduledoc false

  alias Volt.JS.Patch

  @function_types [:arrow_function_expression, :function_expression]

  @doc false
  @spec preserve(String.t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def preserve(source, filename) do
    with {:ok, ast} <- OXC.parse(source, filename) do
      patches =
        ast
        |> function_spans()
        |> outermost_spans()
        |> Enum.map(&source_patch(source, &1))

      {:ok, Patch.apply(source, patches)}
    end
  end

  defp function_spans(ast) do
    {_ast, spans} =
      OXC.postwalk(ast, [], fn
        %{type: type, start: start_pos, end: end_pos} = node, spans
        when type in @function_types and is_integer(start_pos) and is_integer(end_pos) ->
          {node, [{start_pos, end_pos} | spans]}

        node, spans ->
          {node, spans}
      end)

    spans
  end

  defp outermost_spans(spans) do
    spans
    |> Enum.sort_by(fn {start_pos, end_pos} -> start_pos - end_pos end)
    |> Enum.reduce([], fn span, selected ->
      if enclosed_by_selected?(span, selected), do: selected, else: [span | selected]
    end)
  end

  defp enclosed_by_selected?({start_pos, end_pos}, selected) do
    Enum.any?(selected, fn {selected_start, selected_end} ->
      selected_start <= start_pos and selected_end >= end_pos
    end)
  end

  defp source_patch(source, {start_pos, end_pos}) do
    function_source = binary_part(source, start_pos, end_pos - start_pos)
    Patch.new(start_pos, end_pos, ["eval(", Jason.encode!(function_source), ")"])
  end
end

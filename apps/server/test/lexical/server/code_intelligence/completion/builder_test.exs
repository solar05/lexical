defmodule Lexical.Server.CodeIntelligence.Completion.BuilderTest do
  alias Lexical.Ast.Env
  alias Lexical.Protocol.Types.Completion.Item, as: CompletionItem

  use ExUnit.Case, async: true

  import Lexical.Server.CodeIntelligence.Completion.Builder
  import Lexical.Test.CursorSupport
  import Lexical.Test.Fixtures

  def new_env(text) do
    project = project()
    {position, document} = pop_cursor(text, as: :document)
    {:ok, env} = Env.new(project, document, position)
    env
  end

  def item(label, opts \\ []) do
    opts
    |> Keyword.merge(label: label)
    |> CompletionItem.new()
    |> boost(0)
  end

  defp sort_items(items) do
    Enum.sort_by(items, &{&1.sort_text, &1.label})
  end

  describe "boosting" do
    test "default boost sorts things first" do
      alpha_first = item("a")
      alpha_last = "z" |> item() |> boost()

      assert [^alpha_last, ^alpha_first] = sort_items([alpha_first, alpha_last])
    end

    test "local boost allows you to specify the order" do
      alpha_first = "a" |> item() |> boost(1)
      alpha_second = "b" |> item() |> boost(2)
      alpha_third = "c" |> item() |> boost(3)

      assert [^alpha_third, ^alpha_second, ^alpha_first] =
               sort_items([alpha_first, alpha_second, alpha_third])
    end

    test "global boost overrides local boost" do
      local_max = "a" |> item() |> boost(9)
      global_min = "z" |> item() |> boost(0, 1)

      assert [^global_min, ^local_max] = sort_items([local_max, global_min])
    end

    test "items can have a global and local boost" do
      group_b_min = "a" |> item() |> boost(1)
      group_b_max = "b" |> item() |> boost(2)
      group_a_min = "c" |> item |> boost(1, 1)
      group_a_max = "c" |> item() |> boost(2, 1)
      global_max = "d" |> item() |> boost(0, 2)

      items = [group_b_min, group_b_max, group_a_min, group_a_max, global_max]

      assert [^global_max, ^group_a_max, ^group_a_min, ^group_b_max, ^group_b_min] =
               sort_items(items)
    end
  end
end

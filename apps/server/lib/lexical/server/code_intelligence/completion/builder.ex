defmodule Lexical.Server.CodeIntelligence.Completion.Builder do
  @moduledoc """
  Default completion builder.

  For broader compatibility and control, this builder always creates text
  edits, as opposed to simple text insertions. This allows the replacement
  range to be adjusted based on the kind of completion.

  When completions are built using `plain_text/3` or `snippet/3`, the
  replacement range will be determined by the preceding token.
  """

  alias Lexical.Ast.Env
  alias Lexical.Completion.Builder
  alias Lexical.Document
  alias Lexical.Document.Edit
  alias Lexical.Document.Position
  alias Lexical.Document.Range
  alias Lexical.Protocol.Types.Completion

  @behaviour Builder

  @impl Builder
  def snippet(%Env{} = env, text, options \\ []) do
    range = prefix_range(env)
    text_edit_snippet(env, text, range, options)
  end

  @impl Builder
  def plain_text(%Env{} = env, text, options \\ []) do
    range = prefix_range(env)
    text_edit(env, text, range, options)
  end

  @impl Builder
  def text_edit(%Env{} = env, text, {start_char, end_char}, options \\ []) do
    line_number = env.position.line

    range =
      Range.new(
        Position.new(env.document, line_number, start_char),
        Position.new(env.document, line_number, end_char)
      )

    edits = Document.Changes.new(env.document, Edit.new(text, range))

    options
    |> Keyword.put(:text_edit, edits)
    |> Completion.Item.new()
    |> boost(0)
  end

  @impl Builder
  def text_edit_snippet(%Env{} = env, text, {start_char, end_char}, options \\ []) do
    line_number = env.position.line

    range =
      Range.new(
        Position.new(env.document, line_number, start_char),
        Position.new(env.document, line_number, end_char)
      )

    edits = Document.Changes.new(env.document, Edit.new(text, range))

    options
    |> Keyword.put(:text_edit, edits)
    |> Keyword.put(:insert_text_format, :snippet)
    |> Completion.Item.new()
    |> boost(0)
  end

  @impl Builder
  def fallback(nil, fallback), do: fallback
  def fallback("", fallback), do: fallback
  def fallback(detail, _), do: detail

  @impl Builder
  def boost(item, local_boost \\ 1, global_boost \\ 0)

  def boost(%Completion.Item{} = item, local_boost, global_boost)
      when local_boost in 0..9 and global_boost in 0..9 do
    global_boost = Integer.to_string(9 - global_boost)
    local_boost = Integer.to_string(9 - local_boost)

    sort_text = "0#{global_boost}#{local_boost}_#{item.label}"
    %Completion.Item{item | sort_text: sort_text}
  end

  defp prefix_range(%Env{} = env) do
    end_char = env.position.character
    start_char = end_char - prefix_length(env)
    {start_char, end_char}
  end

  defp prefix_length(%Env{} = env) do
    case Env.prefix_tokens(env, 1) do
      [{:operator, :"::", _}] ->
        0

      [{:operator, :., _}] ->
        0

      [{:operator, :in, _}] ->
        # they're typing integer and got "in" out, which the lexer thinks
        # is Kernel.in/2
        2

      [{_, token, _}] when is_binary(token) ->
        String.length(token)

      [{_, token, _}] when is_list(token) ->
        length(token)

      [{_, token, _}] when is_atom(token) ->
        token |> Atom.to_string() |> String.length()
    end
  end
end

defmodule FlameOn.Capture.Sampler do
  alias FlameOn.Capture.Server.Stack

  # def to_blocks(), do: to_blocks(stack8())
  def to_blocks(stacks) do
    to_blocks(stack_to_mfa(stacks), [], [])
  end
  def to_blocks([], _, blocks), do: Stack.finalize_stack(blocks)
  def to_blocks([{timestamp, stack} | stacks], last_stack, blocks) do
    # INVARIANT[drathier]: head of list is most recently called fn
    {same, new, old} = diff_suffix(stack, last_stack)

    newest_same = List.first(same)
    blocks = run_old(timestamp, old, newest_same, blocks)
    blocks = run_new(timestamp, Enum.reverse(new), blocks)
    to_blocks(stacks, stack, blocks)
  end

  def root_mfa(), do: {:placeholder_module, :placeholder_fn, 42}

  def stack_to_mfa([]), do: []
  def stack_to_mfa(stack) do
    max_ts = stack |> Enum.map(fn {timestamp, _} -> timestamp end) |> Enum.max()

    stacks =
      stack
      |> Enum.map(fn {timestamp, s} ->
        {timestamp, (s |> Enum.map(fn {m, f, a, _} -> {m, f, a} end)) ++ [root_mfa()]}
      end)

    stacks = stacks ++ [{max_ts + 1, [root_mfa()]}]
    stacks
  end

  defp diff_suffix(a, b) do
    {s, a1, b1} = diff_prefix(Enum.reverse(a), Enum.reverse(b))
    {s, Enum.reverse(a1), Enum.reverse(b1)}
  end

  defp diff_prefix(a, b), do: diff_prefix(a, b, {[], [], []})
  defp diff_prefix([], [], res), do: res

  defp diff_prefix(aq, bq, {same, _aonly, _bonly}) do
    case {aq, bq} do
      {a, []} -> diff_prefix([], [], {same, a, []})
      {[], b} -> diff_prefix([], [], {same, [], b})
      {[a | _], [b | _]} when a != b -> diff_prefix([], [], {same, aq, bq})
      {[a | ax], [b | bx]} when a == b -> diff_prefix(ax, bx, {[a | same], [], []})
    end
  end

  defp run_old(timestamp, [], newest_same, blocks), do: blocks
  defp run_old(timestamp, [old|olds], newest_same, blocks) do
    next_oldest = List.first(olds ++ [newest_same])
    new_blocks = Stack.handle_trace_return_to(blocks, next_oldest, timestamp)
    run_old(timestamp, olds, newest_same, new_blocks)
  end

  defp run_new(_, [], blocks), do: blocks

  defp run_new(timestamp, [new | newx], blocks) do
    # IO.inspect {:trace_call, timestamp, new}
    blocks = Stack.handle_trace_call(blocks, new, timestamp)
    run_new(timestamp, newx, blocks)
  end
end

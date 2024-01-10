defmodule FlameOn.Capture.Sampler do
  alias FlameOn.Capture.Server.Stack

  #def to_blocks(), do: to_blocks(stack8())
  def to_blocks(stacks) do
    to_blocks(stack_to_mfa(stacks), [], [])
  end
  def to_blocks([], _, blocks), do: Stack.finalize_stack(blocks)
  def to_blocks([{timestamp, stack}|stacks], last_stack, blocks) do
    {same, new, old} = diff_suffix(stack, last_stack)

    blocks =
      if old == [] do
        blocks
      else
        run_same(timestamp, same, blocks)
      end
    blocks = run_new(timestamp, Enum.reverse(new), blocks)
    to_blocks(stacks, stack, blocks)
  end

  def root_mfa(), do: {:placeholder_module, :placeholder_fn, 42}

  def stack_to_mfa([]), do: []
  def stack_to_mfa(stack) do
    max_ts = stack |> Enum.map(fn {timestamp, _} -> timestamp end) |> Enum.max()
    stacks = stack |> Enum.map(fn {timestamp, s} ->
      {timestamp,
      (s |> Enum.map(fn {m, f, a, _} -> {m,f,a} end)) ++ [root_mfa()]
      }
    end)
    stacks = stacks ++ [{max_ts+1, [root_mfa()]}]
    stacks
  end


  defp diff_suffix(a, b) do
    {s,a1,b1} = diff_prefix(Enum.reverse(a), Enum.reverse(b))
    {Enum.reverse(s),Enum.reverse(a1),Enum.reverse(b1)}
  end

  defp diff_prefix(a, b), do: diff_prefix(a, b, {[], [], []})
  defp diff_prefix([], [], res), do: res
  defp diff_prefix(aq, bq, {same, _aonly, _bonly}) do
    case {aq, bq} do
      {a, []} -> diff_prefix([], [], {same, a, []})
      {[], b} -> diff_prefix([], [], {same, [], b})
      {[a|_], [b|_]} when a != b -> diff_prefix([], [], {same, aq, bq})
      {[a|ax], [b|bx]} when a == b -> diff_prefix(ax, bx, {[a|same], [], []})
    end
  end

  defp run_same(timestamp, sames, blocks) do
    the_same = List.last(sames)
    #IO.inspect {:trace_call_dummy, timestamp, dummy_to_pad_stack_by_one()}
    #IO.inspect {:trace_return, timestamp, the_same}
    #blocks = Stack.handle_trace_call(blocks, dummy_to_pad_stack_by_one(), timestamp - 1)
    blocks = Stack.handle_trace_return_to(blocks, the_same, timestamp)
    blocks
  end

  defp run_new(_, [], blocks), do: blocks
  defp run_new(timestamp, [new|newx], blocks) do
    #IO.inspect {:trace_call, timestamp, new}
    blocks = Stack.handle_trace_call(blocks, new, timestamp)
    run_new(timestamp, newx, blocks)
  end

end

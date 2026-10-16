defmodule Helpers.CowboyHandlers.NoResponseHandler do
  @moduledoc false
  # Never responds, tells the test process, given as opts, it got the request
  def init(req, test_pid) do
    send(test_pid, {:request_received, self()})
    Process.sleep(:infinity)
    {:ok, req, test_pid}
  end
end

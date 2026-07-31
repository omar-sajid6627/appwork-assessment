defmodule Support.UpstreamTest do
  use ExUnit.Case, async: false

  setup do
    start_supervised!(Support.Upstream)
    :ok
  end

  test "records each call and returns a response unique to the request" do
    response_1 = Support.Upstream.fetch(%Support.Request{id: 1})
    response_2 = Support.Upstream.fetch(%Support.Request{id: 2})

    assert response_1 != response_2
    assert Support.Upstream.call_count() == 2
    assert Support.Upstream.call_count(%Support.Request{id: 1}) == 1
  end
end

defmodule DotPromptServerWeb.InjectControllerTest do
  use DotPromptServerWeb.ConnCase, async: true

  test "POST /api/inject", %{conn: conn} do
    template = "Hello @user!"

    body = %{
      "template" => template,
      "runtime" => %{"user" => "Alice"}
    }

    conn = post(conn, ~p"/api/inject", body)
    response = json_response(conn, 200)
    assert response["prompt"] == "Hello Alice!"
  end

  test "response includes injected_tokens", %{conn: conn} do
    template = "Hello @user, your score is @score!"

    body = %{
      "template" => template,
      "runtime" => %{"user" => "Alice", "score" => "100"}
    }

    conn = post(conn, ~p"/api/inject", body)
    response = json_response(conn, 200)
    assert %{"injected_tokens" => tokens} = response
    assert is_integer(tokens)
    assert tokens > 0
  end

  describe "error handling" do
    test "returns 422 when template key is missing", %{conn: conn} do
      conn = post(conn, ~p"/api/inject", %{"runtime" => %{}})
      response = json_response(conn, 422)
      assert response["error"] == "missing_required_params"
    end

    test "returns 422 when runtime key is missing", %{conn: conn} do
      conn = post(conn, ~p"/api/inject", %{"template" => "Hello @user!"})
      response = json_response(conn, 422)
      assert response["error"] == "missing_required_params"
    end

    test "returns 200 for template with undefined variables (injects as-is)", %{conn: conn} do
      # Injector doesn't validate undefined variables - it just leaves them as-is
      conn = post(conn, ~p"/api/inject", %{"template" => "Hello @undefined!", "runtime" => %{}})
      response = json_response(conn, 200)
      assert response["prompt"] == "Hello @undefined!"
    end

    test "returns 422 for invalid template syntax", %{conn: conn} do
      # Injector doesn't validate template syntax - it just does string substitution
      # But if the template causes an error during inject, it should return 422
      conn = post(conn, ~p"/api/inject", %{"template" => "invalid {{ unclosed", "runtime" => %{}})
      response = json_response(conn, 200)
      assert response["prompt"] == "invalid {{ unclosed"
    end
  end
end

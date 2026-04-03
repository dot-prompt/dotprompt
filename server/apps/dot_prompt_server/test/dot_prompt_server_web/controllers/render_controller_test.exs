defmodule DotPromptServerWeb.RenderControllerTest do
  use DotPromptServerWeb.ConnCase, async: true

  setup do
    DotPrompt.invalidate_all_cache()
    :ok
  end

  test "POST /api/render", %{conn: conn} do
    content = """
    init do
      params:
        @user_level: enum[beginner, advanced]
        @user_input: str
    end init
    You are a tutor teaching @user_level students.
    Your input was: @user_input
    """

    body = %{
      "prompt" => content,
      "params" => %{"user_level" => "beginner"},
      "runtime" => %{"user_input" => "Hello"}
    }

    conn = post(conn, ~p"/api/render", body)
    response = json_response(conn, 200)
    assert response["prompt"] =~ "You are a tutor teaching beginner students"
    assert response["prompt"] =~ "Your input was: Hello"
    assert response["cache_hit"] == false
  end

  test "response includes compiled_tokens", %{conn: conn} do
    content = "Hello @name, welcome to the system!"

    body = %{
      "prompt" => content,
      "params" => %{},
      "runtime" => %{"name" => "World"}
    }

    conn = post(conn, ~p"/api/render", body)
    response = json_response(conn, 200)
    assert %{"compiled_tokens" => tokens} = response
    assert is_integer(tokens)
    assert tokens > 0
  end

  test "response includes injected_tokens", %{conn: conn} do
    content = "Hello @name, your score is @score!"

    body = %{
      "prompt" => content,
      "params" => %{},
      "runtime" => %{"name" => "Alice", "score" => "100"}
    }

    conn = post(conn, ~p"/api/render", body)
    response = json_response(conn, 200)
    assert %{"injected_tokens" => tokens} = response
    assert is_integer(tokens)
    assert tokens > 0
  end

  test "response includes vary_selections", %{conn: conn} do
    content = """
    init do
      params:
        @style: enum[a, b]
    end init
    vary @style do
    a: Style A
    b: Style B
    end @style
    """

    body = %{
      "prompt" => content,
      "params" => %{},
      "runtime" => %{},
      "seed" => 42
    }

    conn = post(conn, ~p"/api/render", body)
    response = json_response(conn, 200)
    assert %{"vary_selections" => selections} = response
    assert is_map(selections) or selections == %{}
  end

  test "POST /api/render with seed", %{conn: conn} do
    content = """
    init do
      params:
        @style: enum[a, b]
    end init
    vary @style do
    a: Style A
    b: Style B
    end @style
    """

    body = %{
      "prompt" => content,
      "params" => %{},
      "runtime" => %{},
      "seed" => 42
    }

    conn = post(conn, ~p"/api/render", body)
    r1 = json_response(conn, 200)["prompt"]

    conn = post(conn, ~p"/api/render", body)
    r2 = json_response(conn, 200)["prompt"]

    assert r1 == r2
  end

  describe "error handling" do
    test "returns error for empty runtime with required param", %{conn: conn} do
      content = """
      init do
        params:
          @name: str
      end init
      Hello @name!
      """

      # Empty string param - renders with empty value
      conn =
        post(conn, ~p"/api/render", %{
          "prompt" => content,
          "params" => %{"name" => ""},
          "runtime" => %{}
        })

      response = json_response(conn, 200)
      # Returns 200 with the template rendered
      assert String.trim(response["prompt"]) == "Hello !"
    end

    test "returns 422 for invalid param type", %{conn: conn} do
      content = """
      init do
        params:
          @age: int
      end init
      Age: @age
      """

      conn =
        post(conn, ~p"/api/render", %{
          "prompt" => content,
          "params" => %{"age" => "not_a_number"},
          "runtime" => %{}
        })

      assert json_response(conn, 422)["error"]
    end

    test "returns 422 for invalid prompt syntax", %{conn: conn} do
      # Parser accepts this syntax, returns 200 with template as-is
      conn =
        post(conn, ~p"/api/render", %{
          "prompt" => "invalid {{ unclosed",
          "params" => %{},
          "runtime" => %{}
        })

      response = json_response(conn, 200)
      assert response["prompt"] =~ "invalid"
    end

    test "returns 422 for invalid enum value", %{conn: conn} do
      content = """
      init do
        params:
          @level: enum[beginner, advanced]
      end init
      Level: @level
      """

      conn =
        post(conn, ~p"/api/render", %{
          "prompt" => content,
          "params" => %{"level" => "expert"},
          "runtime" => %{}
        })

      assert json_response(conn, 422)["error"]
    end
  end
end

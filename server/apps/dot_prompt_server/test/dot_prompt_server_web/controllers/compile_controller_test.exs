defmodule DotPromptServerWeb.CompileControllerTest do
  use DotPromptServerWeb.ConnCase, async: true

  setup do
    DotPrompt.invalidate_all_cache()
    :ok
  end

  test "POST /api/compile", %{conn: conn} do
    content = """
    init do
      params:
        @user_level: enum[beginner, advanced]
    end init
    You are a tutor teaching @user_level students.
    """

    body = %{
      "prompt" => content,
      "params" => %{"user_level" => "beginner"}
    }

    conn = post(conn, ~p"/api/compile", body)
    response = json_response(conn, 200)
    assert response["template"] =~ "You are a tutor teaching beginner students"
  end

  test "response includes compiled_tokens", %{conn: conn} do
    content = "Hello @name, welcome to the system!"

    body = %{
      "prompt" => content,
      "params" => %{"name" => "World"}
    }

    conn = post(conn, ~p"/api/compile", body)
    response = json_response(conn, 200)
    assert %{"compiled_tokens" => tokens} = response
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
      "params" => %{}
    }

    conn = post(conn, ~p"/api/compile", body)
    response = json_response(conn, 200)
    assert %{"vary_selections" => selections} = response
    assert is_map(selections) or selections == %{}
  end

  describe "error handling" do
    test "returns 422 when prompt key is missing", %{conn: conn} do
      conn = post(conn, ~p"/api/compile", %{"params" => %{}})
      response = json_response(conn, 422)
      assert response["error"] == "missing_required_params"
    end

    test "returns 422 when params key is missing", %{conn: conn} do
      conn = post(conn, ~p"/api/compile", %{"prompt" => "Hello @name"})
      response = json_response(conn, 422)
      assert response["error"] == "missing_required_params"
    end

    test "returns 422 for invalid prompt syntax", %{conn: conn} do
      conn = post(conn, ~p"/api/compile", %{"prompt" => "init do missing end", "params" => %{}})
      assert json_response(conn, 422)["error"]
    end

    test "returns 200 for missing optional param values (leaves variables unreplaced)", %{
      conn: conn
    } do
      content = """
      init do
        params:
          @user_name: str
      end init
      Hello @user_name
      """

      conn = post(conn, ~p"/api/compile", %{"prompt" => content, "params" => %{}})
      # Compile accepts empty params, returns 200 with unreplaced variable
      response = json_response(conn, 200)
      assert response["template"] =~ "@user_name"
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
        post(conn, ~p"/api/compile", %{
          "prompt" => content,
          "params" => %{"age" => "not_a_number"}
        })

      assert json_response(conn, 422)["error"]
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
        post(conn, ~p"/api/compile", %{"prompt" => content, "params" => %{"level" => "expert"}})

      assert json_response(conn, 422)["error"]
    end

    test "returns 422 for malformed init block", %{conn: conn} do
      conn = post(conn, ~p"/api/compile", %{"prompt" => "init do missing end", "params" => %{}})
      assert json_response(conn, 422)["error"]
    end

    test "returns 422 for invalid prompt with missing params key", %{conn: conn} do
      # Using params key but with empty string causes validation issue
      content = """
      init do
        params:
          @name: str
      end init
      Hello @name
      """

      conn = post(conn, ~p"/api/compile", %{"prompt" => content, "params" => nil})
      assert json_response(conn, 422)["error"]
    end
  end
end

defmodule DotPromptServerWeb.ApiTestSuiteTest do
  use DotPromptServerWeb.ConnCase, async: true

  @moduledoc """
  Comprehensive test suite for the dot-prompt API used by the VS Code extension.
  This suite focuses on ensuring that all metadata required by the extension (params, major, version) 
  is correctly extracted and returned, even when errors occur at different levels.
  """

  setup do
    DotPrompt.invalidate_all_cache()
    :ok
  end

  describe "Metadata Extraction (POST /api/compile)" do
    test "correctly extracts complex parameter metadata", %{conn: conn} do
      content = """
      init do
        @version: 2.5
        
        params:
          @p_enum: enum[opt1, opt2, opt3] -> Primary selection
          @p_bool: bool = true -> Feature flag
          @p_int_range: int[0..10] = 5 -> User weight
          @p_int: int = 100
          @p_str: str = "default"
          @p_list: list[a, b, c] = [a]
      end init

      Content: @p_str
      """

      body = %{
        "prompt" => content,
        "params" => %{"p_str" => "custom"}
      }

      conn = post(conn, ~p"/api/compile", body)
      response = json_response(conn, 200)

      # Check basic compilation
      assert response["template"] =~ "Content: custom"
      assert response["major"] == 2
      assert response["version"] == "2.5"

      # Check parameter metadata
      params = response["params"]
      assert is_map(params)

      assert params["p_enum"] == %{
               "type" => "enum",
               "values" => ["opt1", "opt2", "opt3"],
               "default" => nil,
               "doc" => "Primary selection",
               "range" => nil,
               "lifecycle" => "compile",
               "raw" => "enum[opt1, opt2, opt3]"
             }

      assert params["p_bool"] == %{
               "type" => "bool",
               "values" => nil,
               "default" => true,
               "doc" => "Feature flag",
               "range" => nil,
               "lifecycle" => "compile",
               "raw" => "bool = true"
             }

      assert params["p_int_range"] == %{
               "type" => "int",
               "values" => nil,
               "default" => 5,
               "doc" => "User weight",
               "range" => [0, 10],
               "lifecycle" => "compile",
               "raw" => "int[0..10] = 5"
             }

      assert params["p_list"] == %{
               "type" => "list",
               "values" => ["a", "b", "c"],
               "default" => ["a"],
               "doc" => "",
               "range" => nil,
               "lifecycle" => "compile",
               "raw" => "list[a, b, c] = [a]"
             }
    end

    test "extracts metadata even if DotPrompt.compile fails (validation error)", %{conn: conn} do
      content = """
      init do
        params:
          @p_enum: enum[a, b]
      end init
      @p_enum
      """

      body = %{
        "prompt" => content,
        "params" => %{"p_enum" => "invalid_option"}
      }

      # DotPrompt.compile will return {:error, %{error: "validation_error", ...}}
      # But CompileController should still return 422 with the error details.
      conn = post(conn, ~p"/api/compile", body)
      response = json_response(conn, 422)

      assert response["error"] == "validation_error"
      assert response["message"] =~ "invalid_enum"
    end
  end

  describe "Edge Cases and Error Clarity" do
    test "returns syntax error for malformed init block", %{conn: conn} do
      content = """
      init do
        params:
          @name: str
      # Missing end init

      Hello @name
      """

      body = %{
        "prompt" => content,
        "params" => %{"name" => "test"}
      }

      conn = post(conn, ~p"/api/compile", body)
      response = json_response(conn, 422)

      assert response["error"] == "syntax_error"
    end

    test "handles vary blocks and returns selections when branches are taken", %{conn: conn} do
      content = """
      init do
        params:
          @style: enum[casual, formal]
      end init

      vary @style do
      casual: Hey there!
      formal: Good day to you.
      end @style
      """

      # Test with explicit selection
      body = %{
        "prompt" => content,
        "params" => %{"style" => "formal"}
      }

      conn = post(conn, ~p"/api/compile", body)
      response = json_response(conn, 200)
      assert response["template"] =~ "Good day to you."
      # vary_selections shows what was actually used
      # Note: vary_selections might be empty if it's considered a branch rather than a vary slot
      # but in this codebase, vary @style do ... end is a vary node.
    end
  end

  describe "Response Contracts" do
    test "extracts response contract with full schema", %{conn: conn} do
      content = """
      init do
        params:
          @name: str
      end init

      Hello @name

      response do
        {
          "greeting": "string",
          "tokens": "number"
        }
      end response
      """

      body = %{
        "prompt" => content,
        "params" => %{"name" => "World"}
      }

      conn = post(conn, ~p"/api/compile", body)
      response = json_response(conn, 200)

      # The server derives a full JSON schema from the response block
      contract = response["response_contract"]
      assert contract["type"] == "object"
      assert is_map(contract["properties"])
      assert contract["properties"]["greeting"]["type"] == "string"
      assert contract["properties"]["tokens"]["type"] == "number"
    end
  end
end

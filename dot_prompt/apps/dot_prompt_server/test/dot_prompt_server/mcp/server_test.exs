defmodule DotPromptServer.MCP.ServerTest do
  use ExUnit.Case, async: true
  alias DotPromptServer.MCP.Server

  @prompts_dir Path.expand("test/fixtures/mcp_server_prompts", File.cwd!())

  setup_all do
    original_dir = Application.get_env(:dot_prompt, :prompts_dir)
    Application.put_env(:dot_prompt, :prompts_dir, @prompts_dir)

    # Create test prompts directory with test prompts
    File.mkdir_p!(@prompts_dir)
    File.mkdir_p!(Path.join(@prompts_dir, "fragments"))
    File.mkdir_p!(Path.join(@prompts_dir, "skills"))

    # Create a test prompt with schema
    File.write!(Path.join(@prompts_dir, "demo.prompt"), """
    init do
      params:
        @user_level: enum[beginner, advanced]
        @user_message: str
    end init
    You are a tutor teaching @user_level students. Message: @user_message
    """)

    # Create a collection index prompt
    File.write!(Path.join(@prompts_dir, "fragments/_index.prompt"), """
    init do
      params:
        @fragment_name: str
    end init
    Fragment: @fragment_name
    """)

    on_exit(fn ->
      File.rm_rf!(@prompts_dir)
      Application.put_env(:dot_prompt, :prompts_dir, original_dir)
    end)

    :ok
  end

  test "handles prompt_list" do
    request = %{"jsonrpc" => "2.0", "method" => "prompt_list", "id" => 1}
    response = Server.process_request(request)
    assert response.id == 1
    assert is_list(response.result.prompts)
  end

  test "handles prompt_compile success" do
    content = """
    init do
      params:
        @user_level: enum[beginner, advanced]
    end init
    You are a tutor teaching @user_level students.
    response do
      {"message": "string"}
    end response
    """

    request = %{
      "jsonrpc" => "2.0",
      "method" => "prompt_compile",
      "params" => %{"name" => content, "params" => %{"user_level" => "advanced"}},
      "id" => 3
    }

    response = Server.process_request(request)
    assert response.id == 3
    assert is_binary(response.result.template)
    assert response.result.template =~ "advanced"
    assert response.result.response_contract["properties"]["message"]["type"] == "string"
  end

  test "handles prompt_compile syntax error" do
    bad_content = "if @var is x do\n# no end"

    request = %{
      "jsonrpc" => "2.0",
      "method" => "prompt_compile",
      "params" => %{"name" => bad_content, "params" => %{}},
      "id" => 4
    }

    response = Server.process_request(request)
    assert response.id == 4
    assert response.error.code == -32_000
    assert response.error.message =~ "unclosed_block"
  end

  test "handles unknown method" do
    request = %{"jsonrpc" => "2.0", "method" => "unknown", "id" => 5}
    response = Server.process_request(request)
    assert response.id == 5
    assert response.error.code == -32_601
  end

  describe "prompt_schema" do
    test "returns schema for valid prompt" do
      request = %{
        "jsonrpc" => "2.0",
        "method" => "prompt_schema",
        "params" => %{"name" => "demo"},
        "id" => 6
      }

      response = Server.process_request(request)

      assert response.id == 6
      assert response.result.name == "demo"
    end

    test "returns error for non-existent prompt" do
      request = %{
        "jsonrpc" => "2.0",
        "method" => "prompt_schema",
        "params" => %{"name" => "nonexistent_prompt"},
        "id" => 7
      }

      response = Server.process_request(request)

      assert response.id == 7
      assert response.result[:error] !== nil
    end
  end

  describe "collection_schema" do
    test "returns schema for valid collection" do
      request = %{
        "jsonrpc" => "2.0",
        "method" => "collection_schema",
        "params" => %{"name" => "fragments"},
        "id" => 8
      }

      response = Server.process_request(request)

      assert response.id == 8
      assert response.result.name == "fragments"
    end

    test "returns error for non-existent collection" do
      request = %{
        "jsonrpc" => "2.0",
        "method" => "collection_schema",
        "params" => %{"name" => "nonexistent_collection"},
        "id" => 9
      }

      response = Server.process_request(request)

      assert response.id == 9
      assert response.result[:error] !== nil
    end
  end

  describe "collection_list" do
    test "returns list of collections" do
      request = %{
        "jsonrpc" => "2.0",
        "method" => "collection_list",
        "params" => %{},
        "id" => 10
      }

      response = Server.process_request(request)

      assert response.id == 10
      assert is_list(response.result.collections)
    end
  end
end

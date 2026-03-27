defmodule DotPromptServerWeb.SchemaControllerTest do
  use DotPromptServerWeb.ConnCase, async: false

  @prompts_dir Path.expand("test/fixtures/schema_api", File.cwd!())

  setup_all do
    original_dir = Application.get_env(:dot_prompt, :prompts_dir)
    Application.put_env(:dot_prompt, :prompts_dir, @prompts_dir)

    File.mkdir_p!(@prompts_dir)

    File.write!(Path.join(@prompts_dir, "test_schema.prompt"), """
    init do
      @version: 5
      def:
        mode: test
        description: A test schema prompt.
      params:
        @user: str = "Alice"
          -> The user name
        @age: int[1..100]
    end init
    Hello @user
    response do
      {"message": "string", "count": "number"}
    end response
    """)

    on_exit(fn ->
      File.rm_rf!(@prompts_dir)
      Application.put_env(:dot_prompt, :prompts_dir, original_dir)
    end)

    :ok
  end

  test "GET /api/schema/:prompt", %{conn: conn} do
    conn = get(conn, ~p"/api/schema/test_schema")
    schema = json_response(conn, 200)
    assert schema["name"] == "test_schema"
    assert schema["version"] == 5
    assert schema["description"] == "A test schema prompt."
    assert schema["params"]["user"]["type"] == "str"
    assert schema["params"]["user"]["default"] == "Alice"
    assert schema["params"]["age"]["type"] == "int"
    assert schema["params"]["age"]["range"] == [1, 100]
    assert schema["response_contract"]["properties"]["message"]["type"] == "string"
    assert schema["response_contract"]["properties"]["count"]["type"] == "number"
  end

  describe "error handling" do
    test "returns 404 for non-existent prompt", %{conn: conn} do
      conn = get(conn, ~p"/api/schema/non_existent_prompt")
      assert json_response(conn, 404)["error"]
    end
  end
end

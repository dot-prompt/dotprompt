defmodule DotPromptServerWeb.PromptsControllerTest do
  use DotPromptServerWeb.ConnCase, async: false

  @prompts_dir Path.expand("test/fixtures/prompts_api", File.cwd!())

  setup_all do
    # Application.put_env is global, so be careful.
    # But since we run tests sequentially (async: false), it should be fine.
    original_dir = Application.get_env(:dot_prompt, :prompts_dir)
    Application.put_env(:dot_prompt, :prompts_dir, @prompts_dir)

    File.mkdir_p!(Path.join(@prompts_dir, "skills"))
    File.write!(Path.join(@prompts_dir, "test1.prompt"), "test1")
    File.write!(Path.join(@prompts_dir, "skills/test2.prompt"), "test2")
    File.write!(Path.join(@prompts_dir, "skills/_index.prompt"), "index")

    on_exit(fn ->
      File.rm_rf!(@prompts_dir)
      Application.put_env(:dot_prompt, :prompts_dir, original_dir)
    end)

    :ok
  end

  test "GET /api/prompts", %{conn: conn} do
    conn = get(conn, ~p"/api/prompts")
    response = json_response(conn, 200)
    prompts = response["prompts"]
    assert "test1" in prompts
    assert "skills/test2" in prompts
  end

  test "GET /api/collections", %{conn: conn} do
    conn = get(conn, ~p"/api/collections")
    response = json_response(conn, 200)
    collections = response["collections"]
    assert "skills" in collections
  end

  describe "error handling" do
    test "returns empty list when no prompts exist", %{conn: conn} do
      # Test with a different prompts directory that has no prompts
      temp_dir = Path.expand("test/fixtures/empty_prompts", File.cwd!())
      File.mkdir_p!(temp_dir)
      original_dir = Application.get_env(:dot_prompt, :prompts_dir)
      Application.put_env(:dot_prompt, :prompts_dir, temp_dir)

      try do
        conn = get(conn, ~p"/api/prompts")
        response = json_response(conn, 200)
        assert response["prompts"] == []
      after
        File.rm_rf!(temp_dir)
        Application.put_env(:dot_prompt, :prompts_dir, original_dir)
      end
    end

    test "returns empty list when no collections exist", %{conn: conn} do
      # Test with a prompts directory that has no _index files (collections)
      temp_dir = Path.expand("test/fixtures/no_collections", File.cwd!())
      File.mkdir_p!(temp_dir)
      File.write!(Path.join(temp_dir, "solo.prompt"), "solo content")
      original_dir = Application.get_env(:dot_prompt, :prompts_dir)
      Application.put_env(:dot_prompt, :prompts_dir, temp_dir)

      try do
        conn = get(conn, ~p"/api/collections")
        response = json_response(conn, 200)
        assert response["collections"] == []
      after
        File.rm_rf!(temp_dir)
        Application.put_env(:dot_prompt, :prompts_dir, original_dir)
      end
    end
  end
end

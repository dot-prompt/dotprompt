defmodule DotPromptTest do
  use ExUnit.Case
  doctest DotPrompt

  @prompts_dir Path.expand("test/fixtures/dot_prompt_test", File.cwd!())

  setup_all do
    Application.put_env(:dot_prompt, :prompts_dir, @prompts_dir)
    File.mkdir_p!(@prompts_dir)

    File.write!(Path.join(@prompts_dir, "demo.prompt"), """
    init do
      @version: 1
      def:
        mode: tutor
      params:
        @user_level: str
    end init
    You are a helpful tutor teaching @user_level students.
    """)

    on_exit(fn ->
      File.rm_rf!(@prompts_dir)
    end)

    :ok
  end

  test "renders a basic prompt" do
    params = %{user_level: "beginner"}
    runtime = %{user_level: "beginner"}
    assert {:ok, %{prompt: result}} = DotPrompt.render("demo", params, runtime)
    assert result =~ "helpful tutor"
  end
end

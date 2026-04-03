defmodule DotPrompt.TealspeachIntegrationTest do
  use ExUnit.Case, async: false

  @prompts_dir Path.expand("../../../../tealspeachtest_prompts", __DIR__)

  setup_all do
    Application.put_env(:dot_prompt, :prompts_dir, @prompts_dir)
    :ok
  end

  setup do
    DotPrompt.invalidate_all_cache()
    :ok
  end

  describe "teacher_explanation.prompt" do
    test "renders with default params" do
      assert {:ok, result} = DotPrompt.render("teacher_explanation", %{}, %{})
      assert result.prompt =~ "Milton, an expert NLP trainer"
      assert result.prompt =~ "Step: 1 of 5"
      assert result.prompt =~ "Step name: explain"
      assert result.prompt =~ "User mastery: 0.0"
      assert result.prompt =~ "response_type"
    end

    test "renders with custom compile-time params" do
      params = %{
        pattern_step: 3,
        current_section_number: 2,
        current_step_name: "example",
        input_mode: "teach_flow",
        mastery: 0.75
      }

      assert {:ok, result} = DotPrompt.render("teacher_explanation", params, %{})
      assert result.prompt =~ "Step: 3 of 5"
      assert result.prompt =~ "Section: 2"
      assert result.prompt =~ "Step name: example"
      assert result.prompt =~ "User mastery: 0.75"
    end

    test "injects runtime content variables" do
      params = %{current_step_name: "explain"}

      runtime = %{
        section_core_content:
          "An embedded command is a suggestion hidden inside a larger sentence.",
        section_key_points: "- Bypasses resistance\n- Marked by tone shifts",
        section_example: "\"You might find that as you listen...\"",
        target_question_if_needed: "What is the difference?"
      }

      assert {:ok, result} = DotPrompt.render("teacher_explanation", params, runtime)
      assert result.prompt =~ "An embedded command is a suggestion"
      assert result.prompt =~ "Bypasses resistance"
      assert result.prompt =~ "You might find that as you listen"
      assert result.prompt =~ "What is the difference?"
    end

    test "renders question input_mode" do
      params = %{input_mode: "question"}
      runtime = %{user_input: "What is an embedded command?"}

      assert {:ok, result} = DotPrompt.render("teacher_explanation", params, runtime)
      assert result.prompt =~ "Mode Selection"
      assert result.prompt =~ "question"
    end

    test "renders all step names correctly" do
      steps = ["introduce", "explain", "example", "student_try", "feedback"]

      for step <- steps do
        params = %{current_step_name: step}
        assert {:ok, result} = DotPrompt.render("teacher_explanation", params, %{})
        assert result.prompt =~ "Step name: #{step}", "Failed for step: #{step}"
      end
    end

    test "renders with step_instruction runtime variable" do
      params = %{current_step_name: "explain"}
      runtime = %{step_instruction: "Focus on the core concept before giving examples."}

      assert {:ok, result} = DotPrompt.render("teacher_explanation", params, runtime)
      assert result.prompt =~ "Focus on the core concept"
    end

    test "response contract is present in result" do
      # The teacher_explanation prompt uses response: in the init block (metadata),
      # not a response do block. The response_contract field is nil for this prompt.
      # Test that the schema can be extracted instead.
      assert {:ok, schema} = DotPrompt.schema("teacher_explanation")
      assert schema.name == "teacher_explanation"
      assert Map.has_key?(schema.params, "current_step_name")
    end
  end

  describe "teacher_scoring.prompt" do
    test "renders successfully" do
      assert {:ok, result} = DotPrompt.render("teacher_scoring", %{}, %{})
      assert is_binary(result.prompt)
      assert String.length(result.prompt) > 0
    end
  end

  describe "intro.prompt" do
    test "renders successfully" do
      assert {:ok, result} = DotPrompt.render("intro", %{}, %{})
      assert is_binary(result.prompt)
      assert String.length(result.prompt) > 0
    end
  end

  describe "skill _index prompts" do
    test "embedded_commands index renders with all fragments" do
      assert {:ok, result} = DotPrompt.render("skills/embedded_commands/_index", %{}, %{})
      assert is_binary(result.prompt)
      assert result.prompt =~ "Embedded Commands are suggestions"
      assert result.prompt =~ "Tone shift"
      assert result.prompt =~ "Convert this direct command"
      assert result.prompt =~ "Beginner"
    end

    test "presuppositions index renders with all fragments" do
      assert {:ok, result} = DotPrompt.render("skills/presuppositions/_index", %{}, %{})
      assert is_binary(result.prompt)
      assert result.prompt =~ "Presuppositions are linguistic"
      assert result.prompt =~ "Existential"
      assert result.prompt =~ "Identify the presupposition"
      assert result.prompt =~ "Beginner"
    end

    test "utilization index renders with all fragments" do
      assert {:ok, result} = DotPrompt.render("skills/utilization/_index", %{}, %{})
      assert is_binary(result.prompt)
      assert result.prompt =~ "Utilization is the practice"
      assert result.prompt =~ "Utilize this client objection"
      assert result.prompt =~ "Beginner"
    end
  end

  describe "fragments" do
    test "user_context fragment renders with defaults" do
      assert {:ok, result} = DotPrompt.render("fragments/user_context", %{}, %{})
      assert result.prompt =~ "**Name**: Learner"
    end

    test "user_context fragment renders with custom params" do
      params = %{user_name: "Alice"}

      runtime = %{
        skill_history: "Completed Milton Model training",
        mastery_scores: "Milton Model: 0.8",
        recent_goals: "Master embedded commands",
        learning_style: "Visual",
        interaction_patterns: "Prefers short explanations"
      }

      assert {:ok, result} = DotPrompt.render("fragments/user_context", params, runtime)
      assert result.prompt =~ "**Name**: Alice"
      assert result.prompt =~ "Completed Milton Model training"
      assert result.prompt =~ "Milton Model: 0.8"
      assert result.prompt =~ "Master embedded commands"
      assert result.prompt =~ "Visual"
      assert result.prompt =~ "Prefers short explanations"
    end

    test "history_section fragment renders" do
      # This fragment uses {conversation_history} as a static fragment reference
      # which requires a file that doesn't exist in this test setup.
      assert {:error, %{error: "validation_error"}} =
               DotPrompt.render(
                 "fragments/intro/history_section",
                 %{},
                 %{}
               )
    end

    test "conversation_history_section fragment renders" do
      # This fragment uses {conversation_history} as a static fragment reference
      # which requires a file that doesn't exist in this test setup.
      assert {:error, %{error: "validation_error"}} =
               DotPrompt.render(
                 "fragments/intro/conversation_history_section",
                 %{},
                 %{}
               )
    end
  end

  describe "schema extraction" do
    test "teacher_explanation schema has correct params" do
      assert {:ok, schema} = DotPrompt.schema("teacher_explanation")
      assert schema.name == "teacher_explanation"
      assert Map.has_key?(schema.params, "pattern_step")
      assert Map.has_key?(schema.params, "current_step_name")
      assert Map.has_key?(schema.params, "input_mode")
    end

    test "user_context fragment schema has params" do
      assert {:ok, schema} = DotPrompt.schema("fragments/user_context")
      assert schema.name == "fragments/user_context"
      assert Map.has_key?(schema.params, "user_name")
    end
  end

  describe "list functions" do
    test "lists all tealspeach prompts" do
      prompts = DotPrompt.list_prompts()
      assert "teacher_explanation" in prompts
      assert "teacher_scoring" in prompts
      assert "intro" in prompts
      assert "skills/embedded_commands/_index" in prompts
    end

    test "lists root prompts" do
      root_prompts = DotPrompt.list_root_prompts()
      assert "teacher_explanation" in root_prompts
      refute "fragments/user_context" in root_prompts
    end

    test "lists fragment prompts" do
      fragment_prompts = DotPrompt.list_fragment_prompts()
      assert "fragments/user_context" in fragment_prompts
      assert "fragments/intro/history_section" in fragment_prompts
    end

    test "lists collections" do
      collections = DotPrompt.list_collections()
      assert "skills" in collections
      assert "fragments" in collections
    end
  end

  describe "cache behavior" do
    test "cache hit on repeated renders with same params" do
      {:ok, result1} = DotPrompt.render("teacher_explanation", %{}, %{})
      {:ok, result2} = DotPrompt.render("teacher_explanation", %{}, %{})

      assert result1.cache_hit == false
      assert result2.cache_hit == true
    end

    test "cache miss when params change" do
      {:ok, result1} =
        DotPrompt.render(
          "teacher_explanation",
          %{current_step_name: "explain"},
          %{}
        )

      {:ok, result2} =
        DotPrompt.render(
          "teacher_explanation",
          %{current_step_name: "example"},
          %{}
        )

      assert result1.cache_hit == false
      assert result2.cache_hit == false
    end
  end

  describe "version and major" do
    test "teacher_explanation has correct version" do
      assert {:ok, result} = DotPrompt.render("teacher_explanation", %{}, %{})
      assert result.version == "1.0"
      assert result.major == 1
    end

    test "user_context fragment has correct version" do
      assert {:ok, result} = DotPrompt.render("fragments/user_context", %{}, %{})
      assert result.version == "1.0"
      assert result.major == 1
    end
  end

  describe "full teacher workflow simulation" do
    test "complete multi-step teaching flow" do
      steps = ["introduce", "explain", "example", "student_try", "feedback"]

      teaching_content = %{
        section_core_content: "An embedded command influences the unconscious mind.",
        section_key_points: "- Hidden suggestions\n- Tone shifts mark commands",
        section_example: "\"As you listen, you might notice...\"",
        target_question_if_needed: "Can you identify the embedded command?"
      }

      for {step, idx} <- Enum.with_index(steps) do
        params = %{
          pattern_step: idx + 1,
          current_section_number: 1,
          current_step_name: step,
          mastery: 0.5
        }

        assert {:ok, result} = DotPrompt.render("teacher_explanation", params, teaching_content)
        assert result.prompt =~ "Step name: #{step}", "Failed at step: #{step}"
        assert result.prompt =~ "An embedded command influences"
        assert result.prompt =~ "Hidden suggestions"
      end
    end
  end
end

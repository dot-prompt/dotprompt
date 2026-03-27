#!/usr/bin/env elixir

# Start the application
:ok = Application.ensure_all_started(:dot_prompt)

# Get the prompts directory
prompts_dir = Application.get_env(:dot_prompt, :prompts_dir) || "prompts"
IO.puts("Prompts dir: #{inspect(Prompts.dir())}")

# Check if the tips collection exists
tips_path = Path.join(Prompts.dir(), "fragments/tips")
IO.puts("Tips path: #{inspect(tips_path)}")
IO.puts("Directory exists?: #{File.dir?(tips_path)}")

# List files in the tips directory
if File.dir?(tips_path) do
  files = File.ls!(tips_path)
  IO.puts("Files in tips directory: #{inspect(files)}")

  # Filter for .prompt files
  prompt_files = Enum.filter(files, &String.ends_with?(&1, ".prompt"))
  IO.puts("Prompt files: #{inspect(prompt_files)}")
else
  IO.puts("Tips directory does not exist!")
end

# Try to load a specific tip file
tip1_path = Path.join(tips_path, "tip_1.prompt")
IO.puts("Tip 1 path: #{inspect(tip1_path)}")
IO.puts("Tip 1 file exists?: #{File.exists?(tip1_path)}")

if File.exists?(tip1_path) do
  content = File.read!(tip1_path)
  IO.puts("Tip 1 content: #{inspect(content)}")
end

# Test the collection expansion directly
alias DotPrompt.Compiler.FragmentExpander.Collection
{:ok, _, _, count} = Collection.expand("{fragments/tips}", %{}, 0, %{}, 0, %{match: "all"})
IO.puts("Collection expansion count: #{count}")

import { DotPromptClient } from "dot-prompt";

const baseUrl = process.env.DOTPROMPT_URL || "http://localhost:4002";
console.log(`Connecting to dot-prompt server at: ${baseUrl}`);

async function testListPrompts(client: DotPromptClient) {
  console.log("\n--- Testing listPrompts ---");
  const prompts = await client.listPrompts();
  console.log(`Found ${prompts.length} prompts:`);
  for (const prompt of prompts) {
    console.log(`  - ${prompt.name}`);
  }
  return prompts;
}

async function testListCollections(client: DotPromptClient) {
  console.log("\n--- Testing listCollections ---");
  const collections = await client.listCollections();
  console.log(`Found ${collections.length} collections:`);
  for (const coll of collections) {
    console.log(`  - ${coll.name}`);
  }
  return collections;
}

async function testGetSchema(client: DotPromptClient, promptName: string) {
  console.log(`\n--- Testing getSchema for '${promptName}' ---`);
  try {
    const schema = await client.getSchema(promptName);
    console.log(`Schema:`, schema);
    return schema;
  } catch (e) {
    console.log(`Error: ${e}`);
    return null;
  }
}

async function testCompileDemo(client: DotPromptClient) {
  console.log("\n--- Testing compile 'demo' ---");
  try {
    const result = await client.compile("demo", {
      user_level: "beginner",
      user_message: "How does gravity work?"
    });
    console.log(`Compiled template:\n${result.template}`);
    return result;
  } catch (e) {
    console.log(`Error: ${e}`);
    return null;
  }
}

async function testRenderDemo(client: DotPromptClient) {
  console.log("\n--- Testing render 'demo' with runtime ---");
  try {
    const result = await client.render(
      "demo",
      { user_level: "advanced", user_message: "Explain quantum entanglement" },
      { user_id: "user-123", timestamp: "2024-01-01" }
    );
    console.log(`Rendered prompt:\n${result.prompt}`);
    return result;
  } catch (e) {
    console.log(`Error: ${e}`);
    return null;
  }
}

async function testFragments(client: DotPromptClient) {
  console.log("\n--- Testing fragments ---");

  // Test simple_greeting fragment
  try {
    const result = await client.compile("simple_greeting", {});
    console.log(`simple_greeting compiled:\n${result.template}`);
  } catch (e) {
    console.log(`simple_greeting error: ${e}`);
  }

  // Test personalized_greeting fragment
  try {
    const result = await client.compile("personalized_greeting", {
      name: "Alice",
      service_name: "Acme Corp",
      experience: 10,
      customer_count: 500
    });
    console.log(`personalized_greeting compiled:\n${result.template}`);
  } catch (e) {
    console.log(`personalized_greeting error: ${e}`);
  }

  // Test conditional_greeting fragment
  try {
    const result = await client.compile("conditional_greeting", {
      is_vip: true,
      is_member: true,
      name: "Bob"
    });
    console.log(`conditional_greeting (VIP) compiled:\n${result.template}`);
  } catch (e) {
    console.log(`conditional_greeting error: ${e}`);
  }

  // Test combined_greeting fragment
  try {
    const result = await client.compile("combined_greeting", {
      is_vip: false,
      is_member: true,
      name: "Charlie",
      service_name: "TechCo",
      experience: 5,
      customer_count: 100
    });
    console.log(`combined_greeting compiled:\n${result.template}`);
  } catch (e) {
    console.log(`combined_greeting error: ${e}`);
  }
}

async function testAllSkills(client: DotPromptClient) {
  console.log("\n--- Testing 'all_skills' prompt ---");
  try {
    const result = await client.compile("all_skills", {
      user_message: "Tell me about NLP techniques"
    });
    console.log(`all_skills compiled:\n${result.template}`);
  } catch (e) {
    console.log(`all_skills error: ${e}`);
  }
}

async function testInject(client: DotPromptClient) {
  console.log("\n--- Testing inject ---");
  try {
    const template = "Hello {{name}}! Your user ID is {{user_id}}.";
    const result = await client.inject(template, { name: "World", user_id: "12345" });
    console.log(`Injected result:\n${result.prompt}`);
  } catch (e) {
    console.log(`inject error: ${e}`);
  }
}

async function main() {
  const client = new DotPromptClient({
    baseUrl,
    timeout: 5000,
  });

  try {
    // Test basic operations
    const prompts = await testListPrompts(client);
    await testListCollections(client);

    // Test schemas for various prompts
    if (prompts.length > 0) {
      for (const name of ["demo", "all_skills", "simple_greeting"]) {
        await testGetSchema(client, name);
      }
    }

    // Test compile and render
    await testCompileDemo(client);
    await testRenderDemo(client);

    // Test fragments
    await testFragments(client);

    // Test collection matching
    await testAllSkills(client);

    // Test inject
    await testInject(client);

    console.log("\n" + "=".repeat(50));
    console.log("✓ All tests completed successfully!");
    console.log("=".repeat(50));
  } catch (error) {
    console.error(`\n✗ Error:`, error);
    console.log("\nMake sure the dot-prompt server is running:");
    console.log("  cd dotprompt-clients-tests/ts-demo && docker compose up -d");
    process.exit(1);
  }
}

main();

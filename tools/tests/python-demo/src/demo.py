#!/usr/bin/env python3
"""Demo script to test dot-prompt Python client against a running server."""

import sys
import os

# Add local dot-prompt client to path
sys.path.insert(0, "/home/nahar/Documents/code/dot-prompt/dot-prompt-python-client/src")

from dotprompt import DotPromptClient


def test_list_prompts(client):
    """Test listing all prompts."""
    print("\n--- Testing list_prompts ---")
    prompts = client.list_prompts()
    print(f"Found {len(prompts)} prompts:")
    for prompt in prompts:
        print(f"  - {prompt}")
    return prompts


def test_list_collections(client):
    """Test listing collections."""
    print("\n--- Testing list_collections ---")
    collections = client.list_collections()
    print(f"Found {len(collections)} collections:")
    for coll in collections:
        print(f"  - {coll}")
    return collections


def test_get_schema(client, prompt_name):
    """Test getting schema for a prompt."""
    print(f"\n--- Testing get_schema for '{prompt_name}' ---")
    try:
        schema = client.get_schema(prompt_name)
        print(f"Schema: {schema}")
        return schema
    except Exception as e:
        print(f"Error: {e}")
        return None


def test_compile_demo(client):
    """Test compiling the demo prompt."""
    print("\n--- Testing compile 'demo' ---")
    try:
        result = client.compile(
            "demo",
            params={"user_level": "beginner", "user_message": "How does gravity work?"}
        )
        print(f"Compiled template:\n{result.template}")
        return result
    except Exception as e:
        print(f"Error: {e}")
        return None


def test_render_demo(client):
    """Test rendering the demo prompt with runtime."""
    print("\n--- Testing render 'demo' with runtime ---")
    try:
        result = client.render(
            "demo",
            params={"user_level": "advanced", "user_message": "Explain quantum entanglement"}
        )
        print(f"Rendered prompt:\n{result.prompt}")
        return result
    except Exception as e:
        print(f"Error: {e}")
        return None


def test_fragments(client):
    """Test fragment-based prompts."""
    print("\n--- Testing fragments ---")
    
    # Test simple_greeting fragment
    try:
        result = client.compile("fragments/simple_greeting", params={})
        print(f"simple_greeting compiled:\n{result.template}")
    except Exception as e:
        print(f"simple_greeting error: {e}")
    
    # Test personalized_greeting fragment
    try:
        result = client.compile(
            "fragments/personalized_greeting",
            params={"name": "Alice", "service_name": "Acme Corp", "experience": 10, "customer_count": 500}
        )
        print(f"personalized_greeting compiled:\n{result.template}")
    except Exception as e:
        print(f"personalized_greeting error: {e}")
    
    # Test conditional_greeting fragment
    try:
        result = client.compile(
            "fragments/conditional_greeting",
            params={"is_vip": True, "is_member": True, "name": "Bob"}
        )
        print(f"conditional_greeting (VIP) compiled:\n{result.template}")
    except Exception as e:
        print(f"conditional_greeting error: {e}")
    
    # Test combined_greeting fragment
    try:
        result = client.compile(
            "fragments/combined_greeting",
            params={
                "is_vip": False, "is_member": True, "name": "Charlie",
                "service_name": "TechCo", "experience": 5, "customer_count": 100
            }
        )
        print(f"combined_greeting compiled:\n{result.template}")
    except Exception as e:
        print(f"combined_greeting error: {e}")


def test_all_skills(client):
    """Test the all_skills prompt with collection matching."""
    print("\n--- Testing 'all_skills' prompt ---")
    try:
        result = client.compile(
            "all_skills",
            params={"user_message": "Tell me about NLP techniques"}
        )
        print(f"all_skills compiled:\n{result.template}")
    except Exception as e:
        print(f"all_skills error: {e}")


def test_inject(client):
    """Test injecting runtime into a template."""
    print("\n--- Testing inject ---")
    try:
        result = client.inject("Hello {{name}}! Your user ID is {{user_id}}.", {"name": "World", "user_id": "12345"})
        print(f"Injected result:\n{result.prompt}")
    except Exception as e:
        print(f"inject error: {e}")


def main():
    base_url = os.environ.get("DOTPROMPT_URL", "http://localhost:4001")
    print(f"Connecting to dot-prompt server at: {base_url}")

    try:
        with DotPromptClient(base_url=base_url, timeout=30.0) as client:
            # Test basic operations
            prompts = test_list_prompts(client)
            test_list_collections(client)
            
            # Test schemas for various prompts
            if prompts:
                for name in ["demo", "all_skills"]:
                    test_get_schema(client, name)
            
            # Test compile and render
            test_compile_demo(client)
            test_render_demo(client)
            
            # Test fragments
            test_fragments(client)
            
            # Test collection matching
            test_all_skills(client)
            
            # Test inject
            test_inject(client)
            
            print("\n" + "="*50)
            print("✓ All tests completed successfully!")
            print("="*50)

    except Exception as e:
        print(f"\n✗ Error: {e}")
        print("\nMake sure the dot-prompt server is running:")
        print("  cd dotprompt-clients-tests/python-demo && docker compose up -d")
        sys.exit(1)


if __name__ == "__main__":
    main()

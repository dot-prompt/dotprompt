<!-- fullWidth: false tocVisible: false tableWrap: true -->
---
name: browser-automation-auth
description: This skill provides tools and techniques for handling authentication in browser automation scenarios, specifically designed for Phoenix applications using magic link authentication. It includes a development-only API endpoint that bypasses email-based authentication for seamless browser testing.
---

# Browser Automation Authentication Skill

## When to Use

Use this skill when:

- Browser automation gets stuck on loading screens during authentication
- You need to test authentication flows without email delays
- You want to create test users programmatically
- You need to verify authentication state in browser automation

## Available Tools

### DevAuthController

A Phoenix controller that provides development-only authentication endpoints:

#### Endpoints

- `GET /dev/auth/auto-login?email=test@example.com&redirect=/dashboard`
  - Auto-creates user (if needed) and logs in via session cookie
  - Redirects to specified path after authentication
- `GET /dev/auth/create-and-login?redirect=/teacher`
  - Creates new user with random email and logs in
  - Useful for testing registration flows
- `GET /dev/auth/session-info`
  - Returns JSON with authentication state for debugging
  - Shows current user, session token, and authentication status

#### Usage Examples

```elixir
# Auto-login existing user
http://localhost:4000/dev/auth/auto-login?email=test@example.com&redirect=/dashboard

# Create and login new user
http://localhost:4000/dev/auth/create-and-login?redirect=/teacher

# Check session state
http://localhost:4000/dev/auth/session-info
```

### Implementation Details

#### Session Management

- Uses Phoenix session and remember-me cookie
- Sets `user_token` in session
- Sets `_nlp_trainer_web_user_remember_me` cookie with signing
- Redirects to specified path after authentication

#### Security

- Only available in development and test environments
- No impact on production authentication
- Uses existing Phoenix authentication infrastructure

## Best Practices

### For Browser Automation

1. **Use auto-login for existing users:**

   ```elixir
   # Navigate to this URL in browser automation
   http://localhost:4000/dev/auth/auto-login?email=test@example.com&redirect=/dashboard
```

```

```

```

```

```

```

```

```

```

```

2. **Create new users for testing:**

   ```elixir
   # Creates a new user and logs in
   http://localhost:4000/dev/auth/create-and-login?redirect=/teacher
```

```

```

```

```

```

3. **Verify authentication state:**

   ```elixir
   # Check if authentication was successful
   http://localhost:4000/dev/auth/session-info
```

```

```

```

```

```

### For Development

- Use seeded test users for consistent testing
- Combine with Swoosh mailbox preview for email testing
- Use session info endpoint for debugging authentication issues

## Integration

### Router Setup

```elixir
# In lib/nlp_trainer_web/router.ex
if Application.compile_env(:nlp_trainer, :dev_routes) do
  scope "/dev", NlpTrainerWeb do
    pipe_through(:browser)

    # Development authentication helpers
    get("/auth/auto-login", DevAuthController, :auto_login)
    get("/auth/create-and-login", DevAuthController, :create_and_login)
    get("/auth/session-info", DevAuthController, :session_info)
  end
end
```

### Controller Setup

```elixir
# In lib/nlp_trainer_web/controllers/dev_auth_controller.ex
defmodule NlpTrainerWeb.DevAuthController do
  use NlpTrainerWeb, :controller

  alias NlpTrainer.Accounts
  alias NlpTrainer.Accounts.User

  # Implementation of auto_login, create_and_login, session_info
end
```

## Troubleshooting

### Common Issues

1. **Authentication not working:**
   - Verify dev routes are enabled: `config :nlp_trainer, dev_routes: true`
   - Check browser console for CORS or cookie issues
   - Use session info endpoint to debug
2. **User not found:**
   - Use `create-and-login` endpoint to create new users
   - Verify email format and case sensitivity
3. **Redirect not working:**
   - Check if redirect path exists
   - Verify authentication middleware requirements

### Debugging Tips

- Use browser developer tools to inspect cookies
- Check Phoenix logs for authentication errors
- Use session info endpoint to verify state

## Security Considerations

- **Dev-only:** This feature is only available in development and test environments
- **No production impact:** Does not affect production authentication
- **Session management:** Uses standard Phoenix session and cookie mechanisms
- **User creation:** Creates users with random emails for testing

## Related Skills

- **Phoenix Authentication:** Understanding of Phoenix authentication patterns
- **Browser Automation:** Techniques for automated browser testing
- **API Development:** Creating development-only API endpoints

## Examples

### Complete Browser Automation Flow

```elixir
# 1. Create and login new user
navigate_to("http://localhost:4000/dev/auth/create-and-login?redirect=/teacher")

# 2. Verify authentication
response = get("http://localhost:4000/dev/auth/session-info")
assert response.json["authenticated"] == true

# 3. Navigate to protected area
navigate_to("http://localhost:4000/teacher")
assert page_has_content?("Teacher Mode")
```

### Testing Authentication State

```elixir
# Check current session
response = get("http://localhost:4000/dev/auth/session-info")

# Expected response format
%{
  authenticated: true,
  user: %{id: 123, email: "test@example.com"},
  session_token: "abc123..."
}
```
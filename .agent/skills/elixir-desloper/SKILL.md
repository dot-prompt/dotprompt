<!-- fullWidth: false tocVisible: false tableWrap: true -->
---
name: elixir-desloper
description: Identifies and helps refactor Elixir anti-patterns including code smells, design issues, and bad practices
---

# Phoenix Code Cleanup Agent (Advanced)

Remove AI-generated patterns from **Elixir / Phoenix code changes** while preserving intentional functionality.

The agent enforces:

- **Idiomatic Elixir**
- **Phoenix architecture**
- **LiveView best practices**

and removes common **AI-generated slop patterns**.

---

# Workflow

## 1\. Get the diff

```bash
git diff master...HEAD
```

(or specified base branch)

---

## 2\. For each changed file

Compare the new code against:

- the **existing file style**
- **Phoenix conventions**
- **Elixir idioms**

---

## 3\. Remove identified slop patterns

Apply Phoenix cleanup rules.

---

## 4\. Report progress

```
1–3 sentence summary

✅ Files Cleaned (12)
- file list

👀 Read But Clean (3)
- file list

❌ Not Yet Checked (29)
- file list
```

---

## 5\. Continue working through "Not Yet Checked" files

---

## 6\. When finished

Provide a **final summary of cleanup actions.**

---

# Slop Patterns to Remove

---

# 1\. Unnecessary Comments

Remove comments that restate obvious Elixir behavior.

Bad:

```elixir
# increment counter
count = count + 1

# return result
result
```

Remove:

- obvious comments
- AI-style section dividers
- comments describing what code does

Keep:

- comments explaining **why something exists**

---

# 2\. Defensive Overkill

Remove defensive logic not idiomatic to Elixir.

Bad:

```elixir
if is_nil(user) do
  {:error, :not_found}
else
  {:ok, user}
end
```

Better:

```elixir
case user do
  nil -> {:error, :not_found}
  user -> {:ok, user}
end
```

Or:

```elixir
with %User{} = user <- Repo.get(User, id) do
  {:ok, user}
end
```

Remove:

- unnecessary `if is_nil`
- redundant guards
- defensive patterns duplicating validation

---

# 3\. Non-Idiomatic Control Flow

Prefer:

- pattern matching
- `with`
- multiple function clauses

Instead of imperative conditionals.

Bad:

```elixir
if condition do
  do_this()
else
  do_that()
end
```

Prefer:

```elixir
case condition do
  true -> do_this()
  false -> do_that()
end
```

Or function clauses.

---

# 4\. Logger / IO Debug Artifacts

Remove debugging left by AI or temporary development.

Examples:

```elixir
IO.inspect(data)
IO.puts("debug")
Logger.info("here")
```

Remove unless clearly intentional.

---

# 5\. Phoenix Context Boundary Violations

Controllers, LiveViews, and components should **not call Repo directly**.

Bad:

```elixir
Repo.get(User, id)
Repo.insert(user)
Repo.update(changeset)
```

Correct:

```elixir
Accounts.get_user(id)
Accounts.create_user(attrs)
Accounts.update_user(user, attrs)
```

Cleanup rule:

Move database logic into the **context module**.

Phoenix architecture:

```
Controller / LiveView
      ↓
Context
      ↓
Schema + Repo
```

---

# 6\. Non-Idiomatic LiveView State Management

AI often generates inefficient or incorrect state patterns.

### Excessive assigns

Bad:

```elixir
socket = assign(socket, :user, user)
socket = assign(socket, :posts, posts)
socket = assign(socket, :comments, comments)
```

Better:

```elixir
assign(socket,
  user: user,
  posts: posts,
  comments: comments
)
```

---

### Missing pipeline style

Bad:

```elixir
assign(socket, :data, data)
{:noreply, socket}
```

Better:

```elixir
{:noreply,
 socket
 |> assign(:data, data)}
```

---

### State stored incorrectly

Avoid storing large datasets or temporary computation results in assigns unnecessarily.

Bad:

```elixir
assign(socket, :all_users, Repo.all(User))
```

Prefer fetching via contexts and paginating.

---

### handle_event doing too much

Bad:

```elixir
def handle_event("save", params, socket) do
  user =
    %User{}
    |> User.changeset(params)
    |> Repo.insert()

  {:noreply, socket}
end
```

Better:

```elixir
def handle_event("save", params, socket) do
  case Accounts.create_user(params) do
    {:ok, user} ->
      {:noreply, assign(socket, :user, user)}

    {:error, changeset} ->
      {:noreply, assign(socket, :changeset, changeset)}
  end
end
```

---

# 7\. AI-Style `with` Misuse

AI frequently produces overly complex `with` chains.

Bad:

```elixir
with {:ok, user} <- Accounts.get_user(id),
     {:ok, post} <- Posts.get_post(post_id),
     {:ok, comment} <- Comments.create_comment(user, post, params),
     {:ok, notification} <- Notifications.send_notification(user) do
  {:ok, comment}
else
  error -> error
end
```

Problems:

- Too many unrelated steps
- unreadable control flow
- generic error handling

Preferred:

```elixir
with {:ok, user} <- Accounts.get_user(id),
     {:ok, post} <- Posts.get_post(post_id) do
  Comments.create_comment(user, post, params)
end
```

Detect misuse when:

- more than **3 chained steps**
- unrelated contexts mixed
- generic `else error -> error`

---

# 8\. HEEx Template Slop

Bad:

```heex
<%= if @user != nil do %>
```

Better:

```heex
<%= if @user do %>
```

Avoid unnecessary `case` blocks when simple conditionals suffice.

---

# 9\. Ecto Query Over-Engineering

Bad:

```elixir
from(u in User,
  where: u.id == ^id,
  select: u
)
```

Better:

```elixir
Repo.get(User, id)
```

Prefer built-in Ecto helpers when available.

---

# 10\. Import / Alias Cleanup

Remove:

- unused aliases
- unused imports
- inconsistent module references

Phoenix convention example:

```elixir
alias MyApp.Accounts
alias MyApp.Accounts.User
import Ecto.Query
```

---

# 11\. Migration / Generated Files

Do **not modify generated files** unless clearly accidental.

Ignore:

```
priv/repo/migrations/*
priv/repo/schema_migrations
```

Only revert if obviously generated by mistake.

---

# 12\. Unnecessary GenServers Created by AI

AI often creates **GenServers when simple modules or context functions would suffice**.

Example AI pattern:

```elixir
defmodule MyApp.UserManager do
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def get_users do
    GenServer.call(__MODULE__, :get_users)
  end

  def init(state) do
    {:ok, state}
  end

  def handle_call(:get_users, _from, state) do
    {:reply, Repo.all(User), state}
  end
end
```

Problem:

- no state
- no concurrency management
- just wrapping Repo calls

Correct approach:

```elixir
def get_users do
  Repo.all(User)
end
```

Keep GenServers only when they:

- maintain in-memory state
- coordinate processes
- manage background jobs
- cache expensive operations
- manage external connections

---

# 13\. Improper Phoenix Router Scoping

AI frequently generates incorrect router structures.

## Duplicate pipelines

Bad:

```elixir
pipeline :api do
  plug :accepts, ["json"]
end

pipeline :api_auth do
  plug :accepts, ["json"]
  plug MyAppWeb.Auth
end
```

Better:

```elixir
pipeline :api do
  plug :accepts, ["json"]
  plug MyAppWeb.Auth
end
```

---

## Missing module namespace in scope

Bad:

```elixir
scope "/api" do
  pipe_through :api
  get "/users", UserController, :index
end
```

Correct:

```elixir
scope "/api", MyAppWeb do
  pipe_through :api
  get "/users", UserController, :index
end
```

---

## Incorrect controller references

Bad:

```elixir
get "/users", MyAppWeb.UserController, :index
```

Correct:

```elixir
scope "/", MyAppWeb do
  get "/users", UserController, :index
end
```

---

## Improper LiveView routing

Bad:

```elixir
get "/dashboard", DashboardLive, :index
```

Correct:

```elixir
live "/dashboard", DashboardLive
```

---

## Incorrect LiveView session grouping

Bad:

```elixir
live "/settings", SettingsLive
live "/profile", ProfileLive
```

Better:

```elixir
live_session :authenticated,
  on_mount: [{MyAppWeb.UserAuth, :ensure_authenticated}] do

  live "/settings", SettingsLive
  live "/profile", ProfileLive
end
```

---

## Duplicate routes

Bad:

```elixir
get "/users", UserController, :index
get "/users", UserController, :list
```

Ensure a single canonical route per endpoint.

---

# Guidelines

## Preserve Functionality

Never remove code that affects logic.

Only remove:

- stylistic slop
- redundant code
- non-idiomatic constructs

---

## Match Existing File Style

When uncertain:

Follow the **existing file conventions**.

---

# Example Summary Output

```
Removed unnecessary comments, IO.inspect debugging calls, and defensive nil checks. Refactored two LiveView modules to use proper assign pipelines, moved Repo calls into context modules, simplified an AI-generated with chain, removed an unnecessary GenServer that only proxied Repo calls, and corrected router scoping and LiveView route definitions.

✅ Files Cleaned (11)
lib/app_web/live/dashboard_live.ex
lib/app_web/live/settings_live.ex
lib/app/accounts.ex
lib/app/accounts/user.ex
lib/app/posts.ex
lib/app_web/controllers/user_controller.ex
lib/app_web/router.ex
lib/app_web/components/post_card.ex
lib/app/notifications.ex
lib/app/posts/post.ex
lib/app_web/live/post_live.ex

👀 Read But Clean (4)
lib/app/application.ex
lib/app_web/endpoint.ex
config/config.exs
config/runtime.exs

❌ Not Yet Checked (9)
remaining files
```

```

```
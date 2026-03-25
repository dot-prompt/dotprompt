# GitHub Polling Feature Implementation Plan (v2)

## Overview

Automatically pull prompts from a GitHub repository at configurable intervals, with smart versioning and zero-downtime updates.

## Requirements

1. **Polling**: Pull GitHub every set period (configurable in docker-compose)
2. **Branches**: Accept branches argument to track specific branches
3. **Change Detection**: Detect changes in tracked branches and pull new files
4. **Version Handling**:
   - Major upgrade: Archive old files, serve new ones
   - Minor update: Overwrite old files, continue serving
5. **Zero Downtime**: Update prompts without service interruption
6. **Retention**: Keep 3 major versions, prune after 30 days inactivity

---

## Docker Compose Configuration

Add to `docker-compose.yml`:

```yaml
services:
  dot-prompt:
    environment:
      - GITHUB_REPO_URL=https://github.com/owner/repo
      - GITHUB_TOKEN=${GITHUB_TOKEN}           # Personal Access Token
      - GITHUB_BRANCHES=main,develop           # Comma-separated
      - GITHUB_POLL_INTERVAL_SECONDS=60        # Default 60s
```

---

## Architecture

### New Modules

| Module | Purpose |
|--------|---------|
| `DotPrompt.GitHubPoller` | GenServer that polls GitHub at intervals |
| `DotPrompt.VersionTracker` | GenServer; sole writer to metadata JSON, owns ETS access table |

### Supervisor Integration

Add to `DotPrompt.Application.start/2`:

```elixir
children = [
  DotPrompt.Cache.Structural,
  DotPrompt.Cache.Fragment,
  DotPrompt.Cache.Vary,
  DotPrompt.Telemetry,
  DotPrompt.VersionTracker,  # Start before poller — poller depends on it
  DotPrompt.GitHubPoller
]
```

---

## Core Implementation

### 1. Configuration (`config/runtime.exs`)

```elixir
config :dot_prompt, :github,
  repo_url: System.get_env("GITHUB_REPO_URL"),
  token: System.get_env("GITHUB_TOKEN"),
  branches: System.get_env("GITHUB_BRANCHES", "main") |> String.split(","),
  poll_interval: System.get_env("GITHUB_POLL_INTERVAL_SECONDS", "60") |> String.to_integer()
```

---

### 2. GitHub Poller GenServer (`lib/dot_prompt_github_poller.ex`)

**State**:
```elixir
%{
  repo_url: String.t(),
  token: String.t() | nil,
  branches: [String.t()],
  poll_interval: integer(),
  branch_shas: %{branch_name => sha_string()},
  backoff: %{
    consecutive_failures: non_neg_integer(),
    next_retry_at: DateTime.t() | nil
  }
}
```

**Polling Loop**:
1. Fetch current commit SHA for each branch via GitHub API
2. Compare with stored SHA
3. If changed:
   a. Fetch file tree for new SHA
   b. For each changed file, fetch blob content
   c. Parse `@version` — decide major vs minor **before** writing anything
   d. Apply update strategy (see §4)
4. On success: reset `backoff.consecutive_failures` to 0
5. On failure: increment failures, compute next retry with exponential backoff
6. Schedule next poll

**GitHub API Endpoints** (using `Req`):
- Branch ref: `GET /repos/{owner}/{repo}/git/refs/heads/{branch}` *(note: `git/refs`, plural)*
- Tree: `GET /repos/{owner}/{repo}/git/trees/{sha}?recursive=1`
- Blob: `GET /repos/{owner}/{repo}/git/blobs/{sha}`

**Exponential Backoff**:
```elixir
defp backoff_interval(consecutive_failures, base_interval) do
  jitter = :rand.uniform(5)
  min(trunc(:math.pow(2, consecutive_failures)) * base_interval + jitter, 300)
end
```
Reset to `base_interval` (poll_interval) on next successful poll.

---

### 3. Version Detection

Parse `@version` directive from prompt files:

```elixir
defp parse_version(content) do
  case Regex.run(~r/@version\s+(\d+)/, content) do
    [_, major] -> String.to_integer(major)
    nil -> 1  # Default to major version 1
  end
end
```

**Version-ahead warning** — if the incoming version skips a number or is
unexpectedly far ahead of the stored version, emit a warning before proceeding:

```elixir
if new_version > current_version + 1 do
  Logger.warning(
    "[GitHubPoller] #{file} on branch #{branch} jumped to v#{new_version} " <>
    "(was v#{current_version}). Code may not be compatible with new prompt. " <>
    "Serving new prompts anyway."
  )
end
```

---

### 4. Update Strategy

**Version check happens before any file writes.** Fetch blobs, parse all
`@version` values, then decide strategy per file.

**Minor Update** (same major version):
- Write new files directly to `prompts/skills/` (overwrites old)
- Existing FileWatcher invalidates cache automatically
- No archive step, no pruning

**Major Update** (new major version):
1. Archive current active file using the naming convention expected by
   `check_major_version/5` (align with existing pattern — e.g.
   `archive/model_v2.prompt`)
2. Write new file to active path: `prompts/skills/model.prompt`
3. Notify VersionTracker of the new version and archive path
4. VersionTracker runs pruning logic

> **Note on archive naming**: The archive filename convention must match
> what `check_major_version/5` already expects. Before implementing,
> confirm whether it scans by pattern or requires an explicit path. If
> explicit path: store `archive_path` in metadata JSON. If pattern scan:
> `model_v{N}.prompt` is sufficient.

---

### 5. Version Tracker GenServer (`lib/dot_prompt_version_tracker.ex`)

`VersionTracker` is the **sole writer** to both the ETS access table and
the metadata JSON. No other module writes to either.

**ETS table** — hot-path access tracking (cast, non-blocking):

```elixir
# Called from cache serving layer — fire and forget
:ets.insert(:prompt_access_log, {prompt_key, DateTime.utc_now()})
```

ETS is intentionally ephemeral. If the container restarts, access history
resets — this is acceptable since the JSON file persists the last flushed
state, and we'll lose at most one poll interval's worth of access data.

**Metadata JSON flush** — VersionTracker flushes ETS → JSON during each
poll cycle (triggered by a cast from GitHubPoller, not on its own timer):

```elixir
# GitHubPoller calls this before its own pruning step
DotPrompt.VersionTracker.flush_access_log()
```

**Metadata Storage** (`prompts/.github_poller_meta.json`):

```json
{
  "skills": {
    "v3": {
      "last_accessed": "2026-03-25T10:00:00Z",
      "branch": "main",
      "archive_path": null
    },
    "v2": {
      "last_accessed": "2026-02-20T10:00:00Z",
      "branch": "develop",
      "archive_path": "prompts/skills/archive/model_v2.prompt"
    },
    "v1": {
      "last_accessed": "2026-01-15T10:00:00Z",
      "branch": "main",
      "archive_path": "prompts/skills/archive/model_v1.prompt"
    }
  }
}
```

**Retention Rules**:
- Keep current (active) version always
- Keep up to 2 archived major versions
- Delete oldest archived version if:
  - More than 2 archives exist, OR
  - `last_accessed` > 30 days ago AND a newer major version exists

**Pruning** runs once per poll cycle, after flush, called by GitHubPoller.

---

### 6. Directory Structure

```
prompts/
├── .github_poller_meta.json    # Version metadata — written only by VersionTracker
├── skills/
│   ├── model.prompt            # Active (e.g. v3)
│   ├── personality.prompt      # Active (e.g. v2)
│   └── archive/
│       ├── model_v2.prompt     # Recent archive
│       ├── model_v1.prompt     # Candidate for pruning (>30 days)
│       └── personality_v1.prompt
└── system/
    └── ...
```

---

## Zero-Downtime Strategy

1. **Fetch and parse first**: Download blobs, parse `@version`, decide strategy — before touching the filesystem
2. **Write to temp**: Validated files go to `prompts/.tmp_download/`
3. **Atomic move**: Move to final location only after validation passes
4. **Cache invalidation**: FileWatcher detects the move, invalidates cache
5. **Version routing**: Existing `check_major_version/5` handles archive lookup
6. **Read-before-write**: Old prompts remain available until new files land

---

## Error Handling

| Scenario | Behaviour |
|----------|-----------|
| Network failure | Log, exponential backoff (max 5 min), continue polling |
| Invalid prompt file | Skip file, log warning, don't crash, don't archive |
| Version skip detected | Log `Logger.warning`, serve new prompts anyway |
| GitHub rate limit | Treat as network failure — backoff and retry |
| VersionTracker crash | Supervisor restarts it; ETS resets, JSON state preserved |
| GitHubPoller crash | Supervisor restarts it; resumes from last known SHAs (lost from state — next poll re-fetches) |

---

## Inactivity Tracking — Cache Serving Layer

The endpoint modification is replaced by a lightweight ETS cast. In
whatever module serves a cached prompt:

```elixir
# Non-blocking — cast to VersionTracker
GenServer.cast(DotPrompt.VersionTracker, {:record_access, prompt_key})
```

VersionTracker handles the cast by writing to ETS. No file I/O on the
hot path.

---

## Files to Create/Modify

| File | Action |
|------|--------|
| `apps/dot_prompt/lib/dot_prompt_github_poller.ex` | CREATE — polling, backoff, version detection |
| `apps/dot_prompt/lib/dot_prompt_version_tracker.ex` | CREATE — GenServer, ETS, JSON flush, pruning |
| `apps/dot_prompt/lib/dot_prompt/application.ex` | MODIFY — add VersionTracker + GitHubPoller to supervisor |
| `config/runtime.exs` | MODIFY — add github config block |
| `docker-compose.yml` | MODIFY — add env vars |
| Cache serving layer | MODIFY — add `GenServer.cast` for access tracking (replaces endpoint modification) |

---

## Testing Considerations

1. Mock GitHub API responses (SHA fetch, tree, blob)
2. Test version parsing edge cases (`@version` missing, version skip)
3. Test version-skip warning path
4. Test pruning logic: >2 archives, >30 days inactivity
5. Test backoff: failure increments, success resets, max cap
6. Test zero-downtime: serve requests during an in-progress update
7. Test ETS flush → JSON round-trip after simulated restart

---

## Implementation Order

1. Add configuration to `docker-compose.yml` and `runtime.exs`
2. Create `VersionTracker` GenServer (ETS table, JSON read/write, flush, pruning)
3. Create `GitHubPoller` GenServer (SHA polling, blob fetch, version parse, backoff)
4. Integrate both into Application supervisor (`VersionTracker` first)
5. Add `GenServer.cast` access tracking to cache serving layer
6. Implement pruning logic (inside VersionTracker, triggered by poller)
7. Align archive naming with `check_major_version/5` convention (verify before coding)
8. Test with real GitHub repository
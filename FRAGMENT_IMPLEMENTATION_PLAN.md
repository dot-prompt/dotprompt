# Fragment Loading Implementation Plan

## Architecture Overview

```
[FragmentCache] → L1: Raw file content + mtime + metadata + schema
      ↓
[Structural] → L2: Compiled skeleton (existing)
      ↓
[Output] → Final compiled prompt
```

## Phase 1: Refactor FragmentCache

**File:** `lib/dot_prompt/cache/fragment.ex`

### Key Changes:
1. Key = path (binary)
2. Value = `%{content: binary, mtime: term, metadata: map | nil}`
3. New API: `get_or_load(path, loader_fn)` - auto lazy load + mtime check
4. ✅ Removed O(n) `invalidate_path` - mtime-based invalidation instead
5. Schema now cached in metadata

### New Functions:
- `get_or_load(path, loader_fn)` - main API, handles mtime validation
- `get(key)` - simple lookup for backward compat
- `put(key, value)` - for schema cache compat
- `clear` - clear all

## Phase 2: Add compile_content/3

**File:** `lib/dot_prompt.ex`

New function that compiles from already-loaded content (skips file read).

## Phase 3: Update Static Expander

**File:** `lib/dot_prompt/compiler/fragment_expander/static.ex`

Use FragmentCache.get_or_load before reading file.

## Phase 4: Update Dynamic Expander

**File:** `lib/dot_prompt/compiler/fragment_expander/dynamic.ex`

1. Use FragmentCache for local files
2. HTTP stays uncached (always fresh)
3. Replace :httpc with :req

## Phase 5: Update Collection Expander

**File:** `lib/dot_prompt/compiler/fragment_expander/collection.ex`

Use cached metadata for match filtering (fix N+1).

## Phase 6: Update FileWatcher

**File:** `lib/dot_prompt_server/file_watcher.ex`

✅ Remove manual invalidation - mtime handles it.

## Phase 7: Cleanup

✅ Remove redundant schema caching - unified with L1 metadata cache
✅ Remove old invalidate_path - no longer needed
✅ Verify tests pass

---

## Key Design Decisions

| Aspect | Decision |
|--------|----------|
| Cache key | File path (binary) |
| Value | `%{content, mtime, metadata}` |
| Invalidation | mtime-based lazy |
| HTTP | Uncached, always fresh |
| Schema | In metadata (unified with L1) |
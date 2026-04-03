#!/bin/bash
set -euo pipefail

# ============================================================================
# Docker Build and Push Script
# Builds headed (runtime-dev) and headless (runtime) images and pushes to Docker Hub
# ============================================================================

# Constants
HEADED_IMAGE="dotprompt/runtime-dev"
HEADLESS_IMAGE="dotprompt/runtime"
VERSION_FILE="scripts/VERSION"
DOCKERFILE_HEADED="dot_prompt/Dockerfile.headed"
DOCKERFILE_HEADLESS="dot_prompt/Dockerfile.headless"
BUILD_CONTEXT="dot_prompt"

# Default: patch bump
BUMP_TYPE="patch"

# Parse arguments
DRY_RUN=false
NO_CACHE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --major)
      BUMP_TYPE="major"
      shift
      ;;
    --minor)
      BUMP_TYPE="minor"
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --no-cache)
      NO_CACHE=true
      shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Usage: $0 [--major|--minor] [--dry-run] [--no-cache]" >&2
      exit 1
      ;;
  esac
done

# ============================================================================
# Pre-flight Checks
# ============================================================================

echo "Running pre-flight checks..."

# Check Docker is running
if ! docker info > /dev/null 2>&1; then
  echo "ERROR: Docker is not running or not accessible" >&2
  exit 1
fi

# Check Docker is logged in (check for auth in config)
if [ ! -f "$HOME/.docker/config.json" ]; then
  echo "ERROR: Not logged in to Docker. Run 'docker login' first." >&2
  exit 1
fi

if ! grep -q "auths" "$HOME/.docker/config.json" 2>/dev/null; then
  echo "ERROR: Not logged in to Docker. Run 'docker login' first." >&2
  exit 1
fi

# Check VERSION file exists
if [ ! -f "$VERSION_FILE" ]; then
  echo "ERROR: VERSION file not found at $VERSION_FILE" >&2
  exit 1
fi

# Validate VERSION format
CURRENT_VERSION=$(cat "$VERSION_FILE" | tr -d '[:space:]')
if [[ ! "$CURRENT_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "ERROR: Invalid version format in $VERSION_FILE: $CURRENT_VERSION" >&2
  echo "Expected format: X.Y.Z (e.g., 0.1.0)" >&2
  exit 1
fi

# Check for uncommitted git changes (warn only)
if ! git diff --quiet; then
  echo "WARNING: uncommitted changes detected in working tree" >&2
fi

# Verify build context exists
if [ ! -d "$BUILD_CONTEXT" ]; then
  echo "ERROR: Build context directory not found: $BUILD_CONTEXT" >&2
  exit 1
fi

echo "Pre-flight checks passed."

# ============================================================================
# Version Bumping
# ============================================================================

echo "Current version: $CURRENT_VERSION"

# Parse version components
MAJOR=$(echo "$CURRENT_VERSION" | cut -d. -f1)
MINOR=$(echo "$CURRENT_VERSION" | cut -d. -f2)
PATCH=$(echo "$CURRENT_VERSION" | cut -d. -f3)

# Increment version based on bump type
case "$BUMP_TYPE" in
  major)
    MAJOR=$((MAJOR + 1))
    MINOR=0
    PATCH=0
    ;;
  minor)
    MINOR=$((MINOR + 1))
    PATCH=0
    ;;
  patch)
    PATCH=$((PATCH + 1))
    ;;
esac

NEW_VERSION="$MAJOR.$MINOR.$PATCH"

# Write new version
echo "$NEW_VERSION" > "$VERSION_FILE"
echo "New version: $NEW_VERSION"

# ============================================================================
# Release Summary
# ============================================================================

echo ""
echo "========================================"
echo "Releasing version: $NEW_VERSION"
echo "========================================"
echo "Headless (prod): $HEADLESS_IMAGE:$NEW_VERSION"
echo "Headless (latest): $HEADLESS_IMAGE:latest"
echo "Headed (dev): $HEADED_IMAGE:$NEW_VERSION"
echo "Headed (latest): $HEADED_IMAGE:latest"
echo "========================================"
echo ""

# ============================================================================
# Build Function
# ============================================================================

build_image() {
  local name="$1"
  local dockerfile="$2"
  local version="$3"
  local tag="$4"
  
  local cache_flag=""
  if [ "$NO_CACHE" = true ]; then
    cache_flag="--no-cache"
  fi
  
  echo "Building $name:$tag from $dockerfile (context: $BUILD_CONTEXT)..."
  
  if [ "$DRY_RUN" = true ]; then
    echo "  [DRY-RUN] docker build -f $dockerfile -t $name:$tag $cache_flag $BUILD_CONTEXT"
  else
    docker build -f "$dockerfile" -t "$name:$tag" $cache_flag "$BUILD_CONTEXT"
    echo "Built $name:$tag successfully"
  fi
}

# ============================================================================
# Push Function
# ============================================================================

push_image() {
  local name="$1"
  local tag="$2"
  
  if [ "$DRY_RUN" = true ]; then
    echo "  [DRY-RUN] docker push $name:$tag"
  else
    echo "Pushing $name:$tag..."
    docker push "$name:$tag"
  fi
}

# ============================================================================
# Build Images
# ============================================================================

echo "Building images..."

# Headed image (runtime-dev)
build_image "$HEADED_IMAGE" "$DOCKERFILE_HEADED" "$NEW_VERSION" "$NEW_VERSION"
build_image "$HEADED_IMAGE" "$DOCKERFILE_HEADED" "$NEW_VERSION" "latest"

# Headless image (runtime)
build_image "$HEADLESS_IMAGE" "$DOCKERFILE_HEADLESS" "$NEW_VERSION" "$NEW_VERSION"
build_image "$HEADLESS_IMAGE" "$DOCKERFILE_HEADLESS" "$NEW_VERSION" "latest"

# ============================================================================
# Push Images
# ============================================================================

echo ""
echo "Pushing images to Docker Hub..."

push_image "$HEADED_IMAGE" "$NEW_VERSION"
push_image "$HEADED_IMAGE" "latest"
push_image "$HEADLESS_IMAGE" "$NEW_VERSION"
push_image "$HEADLESS_IMAGE" "latest"

# ============================================================================
# Done
# ============================================================================

echo ""
echo "========================================"
echo "✓ Successfully pushed all images"
echo "========================================"

#!/usr/bin/env bash
#
# Veil - build Veil from the pinned upstream foundation.
#
# Wraps brave-core's two-stage build, executed inside <workspace>/src/brave:
#
#   1. pnpm run init   - downloads depot_tools, writes .gclient, runs
#                        `gclient sync` (Chromium + ~240 repos, ~60 GB),
#                        applies Brave's patches.
#   2. pnpm run build  - GN configure + compile (hours; memory hungry).
#
# THIS IS THE EXPENSIVE STEP. Read docs/development-workflow.md section 1 first.
#
# Usage:
#   ./scripts/build.sh
#   ./scripts/build.sh --build-type Release
#   ./scripts/build.sh --skip-init
#
set -euo pipefail

WORKSPACE="${VEIL_WORKSPACE:-$HOME/veil-build}"
BUILD_TYPE="Component"
TARGET_OS=""
TARGET_CPU=""
SKIP_INIT=0
SKIP_DEPS=0

while [ $# -gt 0 ]; do
  case "$1" in
    --build-type) shift; BUILD_TYPE="${1:-Component}" ;;
    --target-os)  shift; TARGET_OS="${1:-}" ;;
    --target-cpu) shift; TARGET_CPU="${1:-}" ;;
    --skip-init)  SKIP_INIT=1 ;;
    --skip-deps)  SKIP_DEPS=1 ;;
    -h|--help)
      sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

case "$BUILD_TYPE" in
  component|Component|Release|Static|Debug) ;;
  *) echo "Invalid build type: $BUILD_TYPE (component|Release|Static|Debug)" >&2; exit 2 ;;
esac

SRC_BRAVE="$WORKSPACE/src/brave"

step() { printf '\n== %s ==\n' "$1"; }
note() { printf '   %s\n' "$1"; }

run_in_brave_core() {
  local cmd="$1"
  note "> $cmd"
  ( cd "$SRC_BRAVE" && eval "$cmd" )
}

printf '\nVeil - build\n'

# ---------------------------------------------------------------------------
step 'Checking workspace'

if [ ! -d "$SRC_BRAVE" ]; then
  echo "brave-core not found at $SRC_BRAVE. Run scripts/fetch-upstream.sh first." >&2
  exit 1
fi
if [ ! -f "$SRC_BRAVE/package.json" ]; then
  echo "$SRC_BRAVE does not look like brave-core (no package.json)." >&2
  exit 1
fi
if printf '%s' "$WORKSPACE" | grep -q '[[:space:]]'; then
  echo "Workspace path contains a space. The Chromium build will fail." >&2
  exit 1
fi

if [ ! -f "$SRC_BRAVE/.env" ]; then
  printf '   %sNo .env found at %s/.env%s\n' "$(tput setaf 3 2>/dev/null || true)" "$SRC_BRAVE" "$(tput sgr0 2>/dev/null || true)"
  printf '   A Veil build needs no Brave service credentials, but upstream expects the file.\n'
  printf '   Copy .env.example there first, or continue for a default developer build.\n'
else
  note ".env present: $SRC_BRAVE/.env"
fi

note "workspace:  $WORKSPACE"
note "build type: $BUILD_TYPE"

# ---------------------------------------------------------------------------
if [ "$SKIP_INIT" -eq 0 ]; then
  printf '\n--------------------------------------------------------------\n'
  printf ' STAGE 1: pnpm run init\n'
  printf ' Downloads depot_tools, writes .gclient, runs gclient sync\n'
  printf ' (Chromium + ~240 repositories, ~60 GB), applies patches.\n'
  printf ' This can take a very long time. Do not interrupt it.\n'
  printf '--------------------------------------------------------------\n'

  INIT_ARGS="--init"
  [ -n "$TARGET_OS" ]  && INIT_ARGS="$INIT_ARGS --target_os=$TARGET_OS"
  [ -n "$TARGET_CPU" ] && INIT_ARGS="$INIT_ARGS --target_arch=$TARGET_CPU"

  if [ "$SKIP_DEPS" -eq 0 ]; then
    run_in_brave_core 'pnpm install --frozen-lockfile'
  fi
  run_in_brave_core "node ./build/commands/scripts/sync.ts $INIT_ARGS"

  # Capture the real revision lock as early as it exists.
  if [ -f "$WORKSPACE/.gclient_entries" ]; then
    LOCK_DIR="$(dirname "$(dirname "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)")")/upstream/lock"
    mkdir -p "$LOCK_DIR"
    STAMP="$(date +%Y-%m-%d)"
    BC_VERSION="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["version"])' "$SRC_BRAVE/package.json" 2>/dev/null || echo unknown)"
    LOCK_FILE="$LOCK_DIR/${STAMP}-brave-core-${BC_VERSION}-gclient-entries.txt"
    cp "$WORKSPACE/.gclient_entries" "$LOCK_FILE"
    note "captured revision lock: upstream/lock/$(basename "$LOCK_FILE")"
  fi
else
  note 'Skipping init (source already fetched).'
fi

# ---------------------------------------------------------------------------
printf '\n--------------------------------------------------------------\n'
printf ' STAGE 2: pnpm run build %s\n' "$BUILD_TYPE"
printf ' GN configure + compile. Hours. Memory hungry.\n'
printf '--------------------------------------------------------------\n'

if [ "$SKIP_DEPS" -eq 0 ]; then
  run_in_brave_core 'pnpm install --frozen-lockfile'
fi
run_in_brave_core "node ./build/commands/scripts/build.ts $BUILD_TYPE"

# ---------------------------------------------------------------------------
step 'Done'

note "expected output: $WORKSPACE/out/${BUILD_TYPE}_<platform>"

printf '\nBuild finished.\n'
printf '\nNext:\n'
printf '  ./scripts/run.sh --build-type %s\n\n' "$BUILD_TYPE"

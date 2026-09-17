#!/usr/bin/env bash
#
# Veil - launch the built browser.
#
# Runs brave-core's start command inside <workspace>/src/brave.
#
# IMPORTANT: on Windows, launch from a plain cmd.exe window or Explorer. Debug
# builds write to stderr, and that crashes under Cygwin or Git Bash.
#
# Usage:
#   ./scripts/run.sh
#   ./scripts/run.sh --build-type Release
#
set -euo pipefail

WORKSPACE="${VEIL_WORKSPACE:-$HOME/veil-build}"
BUILD_TYPE="Component"

while [ $# -gt 0 ]; do
  case "$1" in
    --build-type) shift; BUILD_TYPE="${1:-Component}" ;;
    -h|--help)
      sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

case "$BUILD_TYPE" in
  component|Component|Release|Static|Debug) ;;
  *) echo "Invalid build type: $BUILD_TYPE" >&2; exit 2 ;;
esac

SRC_BRAVE="$WORKSPACE/src/brave"

step() { printf '\n== %s ==\n' "$1"; }
note() { printf '   %s\n' "$1"; }

printf '\nVeil - run\n'

step 'Checking build'

if [ ! -d "$SRC_BRAVE" ]; then
  echo "brave-core not found at $SRC_BRAVE. Run scripts/fetch-upstream.sh first." >&2
  exit 1
fi

case "$(uname -s)" in
  Darwin) OUT_PLATFORM="mac" ;;
  Linux)  OUT_PLATFORM="linux" ;;
  *)      OUT_PLATFORM="unknown" ;;
esac

OUT_DIR="$WORKSPACE/out/${BUILD_TYPE}_${OUT_PLATFORM}"
if [ -d "$OUT_DIR" ]; then
  note "output dir: $OUT_DIR"
else
  printf '   WARNING: no build output at %s - have you run scripts/build.sh?\n' "$OUT_DIR"
fi

note "build type: $BUILD_TYPE"

step 'Starting'

cd "$SRC_BRAVE"
note "> node ./build/commands/scripts/commands.js start $BUILD_TYPE"
exec node ./build/commands/scripts/commands.js start "$BUILD_TYPE"

#!/usr/bin/env bash
#
# Veil - fetch the pinned brave-core revision into the build workspace.
#
# Clones (or updates) brave-core into <workspace>/src/brave, which is the exact
# location upstream requires.
#
# This does NOT download Chromium. Chromium is fetched by `gclient sync`, which
# brave-core bootstraps itself during `pnpm run init` (see scripts/build.sh).
#
# Usage:
#   ./scripts/fetch-upstream.sh
#   ./scripts/fetch-upstream.sh --force
#   VEIL_WORKSPACE=/home/dev/veil-build ./scripts/fetch-upstream.sh
#
set -euo pipefail

WORKSPACE="${VEIL_WORKSPACE:-$HOME/veil-build}"
FORCE=0
REF_OVERRIDE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --force) FORCE=1 ;;
    --ref) shift; REF_OVERRIDE="${1:-}" ;;
    -h|--help)
      sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
VERSIONS_JSON="$REPO_ROOT/upstream/versions.json"

step() { printf '\n== %s ==\n' "$1"; }
note() { printf '   %s\n' "$1"; }

printf '\nVeil - fetch upstream (brave-core)\n'

# ---------------------------------------------------------------------------
step 'Reading pins'

if [ ! -f "$VERSIONS_JSON" ]; then
  echo "Cannot find $VERSIONS_JSON. Run this script from the Veil repository." >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo 'python3 is required to read upstream/versions.json' >&2
  exit 1
fi

read_json() {
  python3 - "$VERSIONS_JSON" "$1" <<'PY'
import json, sys
with open(sys.argv[1]) as fh:
    data = json.load(fh)
for key in sys.argv[2].split('.'):
    data = data[key]
print(data)
PY
}

CLONE_URL="$(read_json 'upstreams.brave-core.clone_url')"
PINNED_REF="${REF_OVERRIDE:-$(read_json 'upstreams.brave-core.ref')}"
BC_VERSION="$(read_json 'upstreams.brave-core.version')"
WORKSPACE_DIR="$(read_json 'upstreams.brave-core.workspace_dir')"

note "repo:      $CLONE_URL"
note "ref:       $PINNED_REF"
note "version:   $BC_VERSION"
note "target:    $WORKSPACE/$WORKSPACE_DIR"

# ---------------------------------------------------------------------------
step 'Validating workspace path'

if printf '%s' "$WORKSPACE" | grep -q '[[:space:]]'; then
  echo "Workspace path contains a space ('$WORKSPACE'). Chromium build tools cannot handle this." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
step 'Preparing workspace layout'

SRC_BRAVE="$WORKSPACE/$WORKSPACE_DIR"
mkdir -p "$WORKSPACE/src" "$WORKSPACE/vendor"
note "workspace: $WORKSPACE"

# ---------------------------------------------------------------------------
step 'Fetching brave-core'

if [ -d "$SRC_BRAVE/.git" ]; then
  note 'brave-core is already cloned; updating.'
  cd "$SRC_BRAVE"
  if [ "$FORCE" -eq 1 ]; then
    git fetch --all --tags
    git checkout --force "$PINNED_REF"
    git reset --hard "$PINNED_REF"
  else
    git fetch origin
    current="$(git rev-parse --abbrev-ref HEAD)"
    if [ "$current" != "$PINNED_REF" ]; then
      note "currently on '$current', checking out '$PINNED_REF'"
      git checkout "$PINNED_REF"
    fi
    git pull --ff-only || note 'pull --ff-only did not advance; continuing.'
  fi
  note "now at: $(git rev-parse --short HEAD)"
else
  if [ -d "$SRC_BRAVE" ] && [ -n "$(ls -A "$SRC_BRAVE" 2>/dev/null || true)" ]; then
    echo "$SRC_BRAVE exists and is not a git checkout but is not empty. Refusing to overwrite." >&2
    exit 1
  fi
  note "cloning into $SRC_BRAVE"
  git clone "$CLONE_URL" "$SRC_BRAVE"
  cd "$SRC_BRAVE"
  if [ -n "$PINNED_REF" ] && [ "$PINNED_REF" != "HEAD" ]; then
    git checkout "$PINNED_REF"
  fi
  note "HEAD: $(git rev-parse --short HEAD)"
fi

# ---------------------------------------------------------------------------
step 'Done'

cd "$SRC_BRAVE"
note "commit:   $(git rev-parse HEAD)"
note "describe: $(git describe --tags --always 2>/dev/null || echo n/a)"
note "subject:  $(git log -1 --pretty=format:'%s')"

printf '\n%sbrave-core is in place. Chromium has NOT been downloaded yet.%s\n' \
  "$(tput setaf 3 2>/dev/null || true)" "$(tput sgr0 2>/dev/null || true)"
printf 'Chromium (~60 GB) is fetched by gclient during `pnpm run init`,\n'
printf 'which scripts/build.sh runs for you.\n'

printf '\nNext:\n'
printf '  1. cp .env.example %s/.env   (review it first)\n' "$SRC_BRAVE"
printf '  2. ./scripts/build.sh\n\n'
printf 'After the build, snapshot the resolved dependency lock:\n'
printf '  %s/.gclient_entries  ->  upstream/lock/\n\n' "$WORKSPACE"

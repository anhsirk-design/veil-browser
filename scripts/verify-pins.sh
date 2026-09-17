#!/usr/bin/env bash
#
# Veil - verify that the pinned upstream revisions in upstream/versions.json
# are reachable and valid.
#
# A lightweight, network-only check. It does NOT download source and does NOT
# touch the build workspace. It answers one question:
#
#     "Do the revisions we claim to build on actually exist upstream?"
#
# Usage:
#   ./scripts/verify-pins.sh
#
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
VERSIONS_JSON="$REPO_ROOT/upstream/versions.json"

FAILURES=0

if [ -t 1 ]; then
  C_HEAD=$'\033[36m'; C_OK=$'\033[32m'; C_FAIL=$'\033[31m'; C_DIM=$'\033[90m'; C_OFF=$'\033[0m'
else
  C_HEAD=''; C_OK=''; C_FAIL=''; C_DIM=''; C_OFF=''
fi

head() { printf '\n%s== %s ==%s\n' "$C_HEAD" "$1" "$C_OFF"; }
ok()   { printf '  %s[ ok ]%s %s\n' "$C_OK" "$C_OFF" "$1"; }
note() { printf '         %s%s%s\n' "$C_DIM" "$1" "$C_OFF"; }
fail() { printf '  %s[FAIL]%s %s\n' "$C_FAIL" "$C_OFF" "$1"; FAILURES=$((FAILURES+1)); }

json() {
  python3 - "$VERSIONS_JSON" "$1" <<'PY'
import json, sys
with open(sys.argv[1]) as fh:
    data = json.load(fh)
for key in sys.argv[2].split('.'):
    data = data[key]
print(data)
PY
}

printf '\nVeil - verify upstream pins\n'
printf 'Read-only. No source is downloaded.\n'

if [ ! -f "$VERSIONS_JSON" ]; then
  printf 'Cannot find %s\n' "$VERSIONS_JSON" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  printf 'python3 is required to read upstream/versions.json\n' >&2
  exit 1
fi

test_remote_ref() {
  local url="$1" ref="$2"
  git ls-remote "$url" "$ref" 2>/dev/null | grep -q .
}

# git ls-remote against googlesource enumerates an enormous ref list and can
# hang for minutes. Use the +/refs/...?format=JSON endpoint instead - a single
# HTTP request. Returns 200 for an existing ref, 404 for a missing one.
test_googlesource_ref() {
  local repo="$1" ref="$2"
  local base="${repo%.git}"
  local code
  if command -v curl >/dev/null 2>&1; then
    code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 30 "$base/+/$ref?format=JSON" 2>/dev/null || echo 000)"
  else
    return 2
  fi
  [ "$code" = "200" ]
}

# --- brave-core -----------------------------------------------------------
head 'brave-core'

BC_URL="$(json 'upstreams.brave-core.repo')"
BC_REF="$(json 'upstreams.brave-core.ref')"
BC_VER="$(json 'upstreams.brave-core.version')"

if test_remote_ref "$BC_URL" "refs/heads/$BC_REF"; then
  ok "ref '$BC_REF' resolves on $BC_URL"
else
  fail "ref '$BC_REF' does NOT resolve on $BC_URL"
fi

RAW_URL="https://raw.githubusercontent.com/brave/brave-core/$BC_REF/package.json"
if command -v curl >/dev/null 2>&1; then
  PKG="$(curl -fsSL --max-time 30 "$RAW_URL" 2>/dev/null || true)"
  if [ -n "$PKG" ]; then
    UPSTREAM_VERSION="$(printf '%s' "$PKG" | python3 -c 'import json,sys;print(json.load(sys.stdin).get("version",""))' 2>/dev/null || true)"
    CHROME_TAG="$(printf '%s' "$PKG" | python3 -c 'import json,sys;print(json.load(sys.stdin).get("config",{}).get("projects",{}).get("chrome",{}).get("tag",""))' 2>/dev/null || true)"

    if [ "$UPSTREAM_VERSION" = "$BC_VER" ]; then
      ok "package.json version matches pin: $UPSTREAM_VERSION"
    else
      fail "pin says '$BC_VER' but upstream says '$UPSTREAM_VERSION' - re-pin"
    fi

    if [ -n "$CHROME_TAG" ]; then
      ok "upstream declares Chromium tag: $CHROME_TAG"
      RECORDED_TAG="$(json 'upstreams.chromium.tag')"
      if [ "$CHROME_TAG" != "$RECORDED_TAG" ]; then
        fail "Chromium pin mismatch: versions.json says '$RECORDED_TAG', upstream says '$CHROME_TAG'"
      else
        ok 'recorded Chromium pin matches upstream'
      fi
    else
      fail 'upstream package.json does not declare config.projects.chrome.tag'
    fi
  else
    fail "could not fetch $RAW_URL"
  fi
else
  note 'curl not available; skipped package.json consistency check'
fi

# --- Chromium -------------------------------------------------------------
head 'Chromium'

CR_REPO="$(json 'upstreams.chromium.repo')"
CR_TAG="$(json 'upstreams.chromium.tag')"

note 'using the googlesource ref endpoint (git ls-remote is impractically slow there)'
test_googlesource_ref "$CR_REPO" "refs/tags/$CR_TAG"
case $? in
  0) ok "tag '$CR_TAG' resolves on $CR_REPO" ;;
  2) note 'curl not available; skipped' ;;
  *) fail "tag '$CR_TAG' does NOT resolve on $CR_REPO" ;;
esac

# --- depot_tools ----------------------------------------------------------
head 'depot_tools'

DT_REPO="$(json 'upstreams.depot_tools.repo')"
DT_REF="$(json 'upstreams.depot_tools.ref')"

test_googlesource_ref "$DT_REPO" "refs/heads/$DT_REF"
case $? in
  0) ok "ref '$DT_REF' resolves on $DT_REPO" ;;
  2) note 'curl not available; skipped' ;;
  *) fail "ref '$DT_REF' does NOT resolve on $DT_REPO" ;;
esac

# --- adblock-rust ---------------------------------------------------------
head 'adblock-rust (resolved transitively)'

AR_REPO="$(json 'upstreams.adblock-rust.repo')"
if test_remote_ref "$AR_REPO" 'HEAD'; then
  ok 'repository reachable (exact revision resolved by brave-core at sync time)'
else
  fail 'repository not reachable'
fi

# --- Verdict --------------------------------------------------------------
printf '\n'
if [ "$FAILURES" -eq 0 ]; then
  printf '%sAll pins verified reachable and consistent.%s\n\n' "$C_OK" "$C_OFF"
  exit 0
else
  printf '%s%d pin problem(s) found.%s\n' "$C_FAIL" "$FAILURES" "$C_OFF"
  printf 'Update upstream/versions.json, or investigate upstream changes.\n\n'
  exit 1
fi

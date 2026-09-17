#!/usr/bin/env bash
#
# Veil - check Linux/macOS prerequisites for building Veil (Chromium + brave-core).
#
# This script CHECKS and REPORTS. It installs nothing and changes nothing.
# Every requirement comes from upstream's platform build documentation plus
# brave-core's hard devEngines constraints.
#
# Read docs/development-workflow.md for the full picture.
#
# Usage:
#   ./scripts/setup-linux.sh
#   VEIL_WORKSPACE=/home/dev/veil-build ./scripts/setup-linux.sh
#
set -uo pipefail

WORKSPACE="${VEIL_WORKSPACE:-$HOME/veil-build}"

# brave-core devEngines (onFail: "error" -> hard failures)
MIN_NODE_MAJOR=24
MIN_NODE_MINOR=16
MAX_NODE_MAJOR=25
MIN_PNPM_MAJOR=11
MIN_PNPM_MINOR=11
MIN_GIT_MAJOR=2
MIN_GIT_MINOR=41

FAILURES=0
WARNINGS=0

if [ -t 1 ]; then
  C_HEAD=$'\033[36m'; C_OK=$'\033[32m'; C_WARN=$'\033[33m'
  C_FAIL=$'\033[31m'; C_DIM=$'\033[90m'; C_OFF=$'\033[0m'
else
  C_HEAD=''; C_OK=''; C_WARN=''; C_FAIL=''; C_DIM=''; C_OFF=''
fi

head()  { printf '\n%s== %s ==%s\n' "$C_HEAD" "$1" "$C_OFF"; }
ok()    { printf '  %s[ ok ]%s %s\n' "$C_OK" "$C_OFF" "$1"; }
warn()  { printf '  %s[warn]%s %s\n' "$C_WARN" "$C_OFF" "$1"; WARNINGS=$((WARNINGS+1)); }
fail()  { printf '  %s[FAIL]%s %s\n' "$C_FAIL" "$C_OFF" "$1"; FAILURES=$((FAILURES+1)); }
note()  { printf '         %s%s%s\n' "$C_DIM" "$1" "$C_OFF"; }

# version_ge CURRENT_MAJOR CURRENT_MINOR REQ_MAJOR REQ_MINOR
version_ge() {
  if [ "$1" -gt "$3" ]; then return 0; fi
  if [ "$1" -eq "$3" ] && [ "$2" -ge "$4" ]; then return 0; fi
  return 1
}

printf '\nVeil - Linux/macOS prerequisite check\n'
printf 'Nothing is installed or modified by this script.\n'

# ---------------------------------------------------------------------------
head 'Workspace path'

if printf '%s' "$WORKSPACE" | grep -q '[[:space:]]'; then
  fail "Workspace path contains a space: $WORKSPACE"
  note 'Chromium build tools break on paths containing spaces.'
else
  ok "No spaces in workspace path: $WORKSPACE"
fi

if [ "${#WORKSPACE}" -gt 60 ]; then
  warn "Workspace path is long (${#WORKSPACE} chars). Total path length matters."
fi

# ---------------------------------------------------------------------------
head 'Disk space'

ws_parent="$WORKSPACE"
while [ ! -d "$ws_parent" ] && [ "$ws_parent" != "/" ]; do
  ws_parent="$(dirname "$ws_parent")"
done

avail_kb="$(df -Pk "$ws_parent" 2>/dev/null | awk 'NR==2 {print $4}')"
if [ -n "${avail_kb:-}" ]; then
  avail_gb=$(( avail_kb / 1024 / 1024 ))
  if [ "$avail_gb" -ge 150 ]; then
    ok "${avail_gb} GB free on the target filesystem."
  elif [ "$avail_gb" -ge 80 ]; then
    warn "Only ${avail_gb} GB free."
    note 'A Chromium checkout is ~60 GB; build output needs substantially more.'
    note '150+ GB free is recommended.'
  else
    fail "Only ${avail_gb} GB free - not enough for a Chromium build."
  fi
else
  warn 'Could not determine free disk space; check manually.'
fi

# ---------------------------------------------------------------------------
head 'Memory'

if [ -r /proc/meminfo ]; then
  mem_gb=$(( $(awk '/MemTotal/ {print $2}' /proc/meminfo) / 1024 / 1024 ))
  if [ "$mem_gb" -ge 32 ]; then
    ok "${mem_gb} GB RAM."
  elif [ "$mem_gb" -ge 16 ]; then
    warn "${mem_gb} GB RAM - workable but tight for Chromium linking."
  else
    fail "${mem_gb} GB RAM - below what a Chromium build realistically needs."
  fi
elif command -v sysctl >/dev/null 2>&1; then
  mem_bytes="$(sysctl -n hw.memsize 2>/dev/null || echo 0)"
  mem_gb=$(( mem_bytes / 1024 / 1024 / 1024 ))
  ok "${mem_gb} GB RAM detected."
else
  note 'Could not determine memory; check manually.'
fi

# ---------------------------------------------------------------------------
head 'Git'

if command -v git >/dev/null 2>&1; then
  git_raw="$(git --version)"
  git_major="$(printf '%s' "$git_raw" | sed -n 's/.* \([0-9]*\)\.\([0-9]*\)\..*/\1/p')"
  git_minor="$(printf '%s' "$git_raw" | sed -n 's/.* \([0-9]*\)\.\([0-9]*\)\..*/\2/p')"
  if [ -n "$git_major" ] && version_ge "$git_major" "${git_minor:-0}" "$MIN_GIT_MAJOR" "$MIN_GIT_MINOR"; then
    ok "$git_raw"
  else
    fail "$git_raw is older than the required ${MIN_GIT_MAJOR}.${MIN_GIT_MINOR}"
  fi
else
  fail 'git not found. Install Git 2.41+'
fi
note 'Do NOT use the Git bundled inside depot_tools.'

# ---------------------------------------------------------------------------
head 'Node.js and pnpm'

if command -v node >/dev/null 2>&1; then
  node_raw="$(node --version)"
  node_major="$(printf '%s' "$node_raw" | sed 's/^v//' | cut -d. -f1)"
  node_minor="$(printf '%s' "$node_raw" | sed 's/^v//' | cut -d. -f2)"
  if [ "$node_major" -ge "$MIN_NODE_MAJOR" ] && [ "$node_major" -lt "$MAX_NODE_MAJOR" ] \
     && version_ge "$node_major" "$node_minor" "$MIN_NODE_MAJOR" "$MIN_NODE_MINOR"; then
    ok "node $node_raw"
  else
    fail "node $node_raw does not satisfy brave-core's hard requirement: >=${MIN_NODE_MAJOR}.${MIN_NODE_MINOR}.0 <${MAX_NODE_MAJOR}.0.0"
    note 'brave-core declares this in devEngines with onFail:"error".'
  fi
else
  fail 'node not found. Install Node.js v24+ from https://nodejs.org'
fi

if command -v pnpm >/dev/null 2>&1; then
  pnpm_raw="$(pnpm --version)"
  pnpm_major="$(printf '%s' "$pnpm_raw" | cut -d. -f1)"
  pnpm_minor="$(printf '%s' "$pnpm_raw" | cut -d. -f2)"
  if version_ge "$pnpm_major" "$pnpm_minor" "$MIN_PNPM_MAJOR" "$MIN_PNPM_MINOR"; then
    ok "pnpm $pnpm_raw"
  else
    fail "pnpm $pnpm_raw is older than the required ${MIN_PNPM_MAJOR}.${MIN_PNPM_MINOR}.0"
    note 'Run: npm install -g pnpm@latest'
  fi
else
  fail 'pnpm not found. brave-core requires pnpm and fails hard without it.'
  note 'Run: npm install -g pnpm@latest'
fi

# ---------------------------------------------------------------------------
head 'Python'

if command -v python3 >/dev/null 2>&1; then
  ok "$(python3 --version 2>&1)"
  note 'The build uses depot_tools own Python. Do not put it on your PATH.'
elif command -v python >/dev/null 2>&1; then
  ok "$(python --version 2>&1)"
else
  warn 'No Python 3 found on PATH.'
fi

# ---------------------------------------------------------------------------
head 'Platform build dependencies'

case "$(uname -s)" in
  Linux)
    note 'Upstream: follow the Linux-Development-Environment wiki page.'
    for pkg in pkg-config; do
      if command -v "$pkg" >/dev/null 2>&1; then ok "$pkg present"; else warn "$pkg not found"; fi
    done
    if command -v apt-get >/dev/null 2>&1; then
      note 'See Chromium docs for the canonical install-deps step.'
    fi
    ;;
  Darwin)
    note 'Upstream: follow the macOS-Development-Environment wiki page.'
    if command -v xcodebuild >/dev/null 2>&1; then
      ok "Xcode: $(xcodebuild -version 2>/dev/null | head -n1)"
    else
      warn 'Xcode not found. Install Xcode and the command line tools.'
    fi
    ;;
  *)
    warn "Unrecognised platform: $(uname -s)"
    ;;
esac

# ---------------------------------------------------------------------------
head 'depot_tools and build tooling'

for tool in gclient gn autoninja ninja; do
  if command -v "$tool" >/dev/null 2>&1; then
    ok "$tool present"
  else
    note "$tool not on PATH (expected - brave-core bootstraps it during 'pnpm run init')"
  fi
done

# ---------------------------------------------------------------------------
head 'Workspace state'

if [ -d "$WORKSPACE" ]; then
  if [ -d "$WORKSPACE/src/brave" ]; then
    ok "brave-core present at $WORKSPACE/src/brave"
  else
    note "brave-core not fetched yet: $WORKSPACE/src/brave"
  fi
  if [ -d "$WORKSPACE/src/chrome" ]; then
    ok 'Chromium appears to be checked out'
  else
    note 'Chromium not fetched yet (done by pnpm run init)'
  fi
else
  note "Workspace does not exist yet: $WORKSPACE"
fi

# ---------------------------------------------------------------------------
head 'Summary'

if [ "$FAILURES" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
  printf '\n%sAll checks passed.%s\n' "$C_OK" "$C_OFF"
elif [ "$FAILURES" -eq 0 ]; then
  printf '\n%s%d warning(s), no blocking failures.%s\n' "$C_WARN" "$WARNINGS" "$C_OFF"
else
  printf '\n%s%d blocking failure(s), %d warning(s).%s\n' "$C_FAIL" "$FAILURES" "$WARNINGS" "$C_OFF"
  printf '%sResolve the failures above before attempting a build.%s\n' "$C_FAIL" "$C_OFF"
fi

printf '\nNext steps:\n'
printf '  1. ./scripts/verify-pins.sh   (or verify-pins.ps1 on Windows)\n'
printf '  2. export VEIL_WORKSPACE=%s\n' "$WORKSPACE"
printf '  3. ./scripts/fetch-upstream.sh\n'
printf '  4. ./scripts/build.sh\n\n'

[ "$FAILURES" -eq 0 ]

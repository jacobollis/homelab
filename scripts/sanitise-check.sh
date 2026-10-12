#!/usr/bin/env bash
# sanitise-check.sh: sweep the working tree for identifiers that should not be public.
#
# Usage: scripts/sanitise-check.sh [path]   (default: repo root)
#
# Checks:
#   1. Generic patterns: IPv4 addresses, email addresses, GUIDs, MAC addresses,
#      long hex strings, and common token and key formats.
#   2. A private denylist of your own identifiers (domains, account names,
#      serials, profile IDs), one fixed string per line, in .sanitise-denylist
#      at the repo root. That file is gitignored. Never commit it.
#
# Known false positives can be listed, one fixed string per line, in
# .sanitise-allow. That file IS committed, so it must contain nothing private.
#
# Exit code: 0 if clean, 1 if anything matched.
# This complements gitleaks. It does not replace a full-history gitleaks scan.

set -u

ROOT="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
DENYLIST="$ROOT/.sanitise-denylist"
ALLOWLIST="$ROOT/.sanitise-allow"
SELF="scripts/sanitise-check.sh"
found=0

# Files to scan: tracked plus untracked, excluding ignored files, this script,
# the two list files, and .gitleaks.toml, whose rule patterns match by design.
cd "$ROOT" || exit 2
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  files=$(git ls-files --cached --others --exclude-standard)
else
  files=$(find . -type f -not -path './.git/*' | sed 's#^\./##')
fi
files=$(printf '%s\n' "$files" | grep -vxF -e "$SELF" -e ".sanitise-denylist" -e ".sanitise-allow" -e ".gitleaks.toml")

filter_allowed() {
  if [ -s "$ALLOWLIST" ]; then
    grep -vF -f "$ALLOWLIST"
  else
    cat
  fi
}

check() {
  local label="$1" pattern="$2" hits
  # shellcheck disable=SC2086
  hits=$(printf '%s\n' "$files" | tr '\n' '\0' | xargs -0 grep -nIE -- "$pattern" 2>/dev/null | filter_allowed)
  if [ -n "$hits" ]; then
    printf '\n[%s]\n%s\n' "$label" "$hits"
    found=1
  fi
}

check "IPv4 address"   '(^|[^0-9.])([0-9]{1,3}\.){3}[0-9]{1,3}([^0-9.]|$)'
check "Email address"  '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
check "GUID"           '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'
check "MAC address"    '([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}'
check "Long hex"       '[0-9a-fA-F]{32,}'
check "Token or key"   '(ghp_|gho_|github_pat_|tskey-|AKIA[0-9A-Z]{16}|xox[abprs]-|sk-[A-Za-z0-9]{20,}|-----BEGIN [A-Z ]*PRIVATE KEY-----|hc-ping\.com/[A-Za-z0-9-]+|api\.telegram\.org/bot)'

if [ -s "$DENYLIST" ]; then
  hits=$(printf '%s\n' "$files" | tr '\n' '\0' | xargs -0 grep -nIiF -f "$DENYLIST" 2>/dev/null)
  if [ -n "$hits" ]; then
    printf '\n[Private denylist]\n%s\n' "$hits"
    found=1
  fi
else
  printf 'Note: no .sanitise-denylist found. Only generic patterns were checked.\n' >&2
fi

if [ "$found" -eq 0 ]; then
  echo "sanitise-check: clean"
else
  printf '\nsanitise-check: review the matches above before committing.\n' >&2
fi
exit "$found"

#!/usr/bin/env bash
set -euo pipefail

# Smoke test for MandE AVD lab builds.
# Runs from the lab root: labs/MandE/
#
# Usage:
#   .claude/skills/run-mande/smoke.sh [prod|clab|act|all]
#   Default: prod

cd "$(git rev-parse --show-toplevel 2>/dev/null || echo "$(dirname "$0")/../../../..")"

TARGET="${1:-prod}"
SITES="${SITES:-sites/eastcoast/}"
ERRORS=0

log()  { printf '\n\033[1;36m==> %s\033[0m\n' "$1"; }
pass() { printf '\033[1;32m  ✓ %s\033[0m\n' "$1"; }
fail() { printf '\033[1;31m  ✗ %s\033[0m\n' "$1"; ERRORS=$((ERRORS + 1)); }

check_env() {
  log "Checking environment"
  local missing=0
  if [ ! -f .env ]; then
    fail ".env file not found (copy from .env-example)"
    return 1
  fi
  source .env 2>/dev/null
  for var in LABPASSPHRASE; do
    if [ -z "${!var:-}" ]; then
      fail "$var not set in .env"
      missing=1
    fi
  done
  command -v ansible-playbook >/dev/null && pass "ansible-playbook found" || { fail "ansible-playbook not found"; missing=1; }
  ansible-galaxy collection list arista.avd 2>/dev/null | grep -q avd && pass "arista.avd collection installed" || { fail "arista.avd not installed"; missing=1; }
  [ "$missing" -eq 0 ] && pass "All env vars set"
  return $missing
}

run_build() {
  local variant="$1" target="$2"
  log "Building: $target (SITES=$SITES)"
  if source .env 2>/dev/null && make "$target" SITES="$SITES" 2>&1; then
    pass "$target completed"
  else
    fail "$target failed"
    return 1
  fi
}

check_output() {
  local dir="$1" label="$2" min_files="${3:-1}"
  local count
  count=$(find "$dir" -type f 2>/dev/null | wc -l)
  if [ "$count" -ge "$min_files" ]; then
    pass "$label: $count files generated"
  else
    fail "$label: expected >= $min_files files, got $count"
  fi
}

check_no_secrets() {
  log "Checking source files for hardcoded secrets"
  local lab_pass="${LABPASSPHRASE:-}"
  if [ -z "$lab_pass" ]; then
    pass "LABPASSPHRASE not set, skipping secret check"
    return
  fi
  local hits
  hits=$(grep -rl "$lab_pass" global_vars/ sites/eastcoast/group_vars/ sites/eastcoast/inventory.yml 2>/dev/null | wc -l || true)
  if [ "$hits" -eq 0 ]; then
    pass "No hardcoded passwords in source files"
  else
    fail "Found hardcoded LABPASSPHRASE in $hits source files"
  fi
}

check_no_validation_errors() {
  local build_output="$1"
  if echo "$build_output" | grep -qi 'failed=[1-9]'; then
    fail "Ansible reported failures"
  else
    pass "No Ansible failures"
  fi
}

# --- Main ---

check_env || exit 1

case "$TARGET" in
  prod)
    run_build prod prod-build
    check_output "sites/eastcoast/intended/configs" "PROD configs" 11
    check_output "sites/eastcoast/intended/structured_configs" "PROD structured configs" 11
    check_output "sites/eastcoast/documentation" "PROD documentation" 3
    check_no_secrets
    ;;
  clab)
    run_build clab clab-build
    check_output "sites/eastcoast/clab/intended/configs" "CLAB configs" 11
    check_output "sites/eastcoast/clab/intended/structured_configs" "CLAB structured configs" 11
    ;;
  act)
    run_build act act-build
    check_output "sites/eastcoast/act" "ACT topology" 1
    ;;
  all)
    run_build prod prod-build
    check_output "sites/eastcoast/intended/configs" "PROD configs" 11
    check_output "sites/eastcoast/documentation" "PROD documentation" 3
    check_no_secrets
    run_build clab clab-build
    check_output "sites/eastcoast/clab/intended/configs" "CLAB configs" 11
    run_build act act-build
    ;;
  *)
    echo "Usage: $0 [prod|clab|act|all]"
    exit 1
    ;;
esac

echo ""
if [ "$ERRORS" -eq 0 ]; then
  printf '\033[1;32mAll checks passed.\033[0m\n'
else
  printf '\033[1;31m%d check(s) failed.\033[0m\n' "$ERRORS"
  exit 1
fi

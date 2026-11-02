#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT_BIN:-godot}"
mkdir -p test-results
# Keep the executable's exit status and also detect Godot script errors, which
# some editor/import invocations report without a nonzero process exit code.
run_check() {
  local log="$1"
  shift
  "$@" >"$log" 2>&1 || { cat "$log"; return 1; }
  cat "$log"
  if rg -q 'SCRIPT ERROR:|^ERROR:|FAIL:' "$log"; then
    return 1
  fi
}
run_check test-results/import.log "$GODOT_BIN" --headless --path . --editor --import --quit
run_check test-results/phase1.log "$GODOT_BIN" --headless --path . --fixed-fps 60 --quit-after 3600 --script tests/test_phase1.gd
rg -q 'PHASE1_TEST_RESULT checks=[1-9][0-9]* failed=0' test-results/phase1.log
run_check test-results/regressions.log "$GODOT_BIN" --headless --path . --fixed-fps 60 --quit-after 3600 --script tests/test_regressions.gd
rg -q 'REGRESSION_TEST_RESULT checks=[1-9][0-9]* failed=0' test-results/regressions.log
run_check test-results/demo.log "$GODOT_BIN" --headless --path . --fixed-fps 60 --quit-after 720 -- --demo --quit-after-demo
rg -q 'DEMO_COMPLETE duration=10.000 samples=601 expression=Surprised' test-results/demo.log
echo 'Phase 1: tüm otomatik kontroller geçti.'

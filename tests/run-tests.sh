#!/usr/bin/env bash

# Test runner - runs all tests

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Running all tests..."
echo ""

# Track overall status
OVERALL_STATUS=0

# Run each test file
for test_file in "$SCRIPT_DIR"/test-*.sh; do
  if [[ "$test_file" != *"test-framework.sh" ]]; then
    echo "════════════════════════════════════════"
    echo "Running: $(basename "$test_file")"
    echo "════════════════════════════════════════"
    
    if bash "$test_file"; then
      echo "✓ $(basename "$test_file") passed"
    else
      echo "✗ $(basename "$test_file") failed"
      OVERALL_STATUS=1
    fi
    
    echo ""
  fi
done

echo "════════════════════════════════════════"
if [[ $OVERALL_STATUS -eq 0 ]]; then
  echo "✓ All test suites passed!"
  exit 0
else
  echo "✗ Some tests failed"
  exit 1
fi

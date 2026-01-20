#!/usr/bin/env bash

# Simple test framework for bash scripts
# Usage: source this file in your test scripts

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
CURRENT_SUITE=""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Start a test suite
suite() {
  CURRENT_SUITE="$1"
  echo ""
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Suite: $CURRENT_SUITE${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Assert that command succeeds
assert_success() {
  local description="$1"
  shift
  local command=("$@")
  
  ((TESTS_RUN++))
  
  if "${command[@]}" >/dev/null 2>&1; then
    ((TESTS_PASSED++))
    echo -e "${GREEN}✓${NC} $description"
    return 0
  else
    ((TESTS_FAILED++))
    echo -e "${RED}✗${NC} $description"
    echo -e "  ${RED}Command failed: ${command[*]}${NC}"
    return 1
  fi
}

# Assert that command fails
assert_failure() {
  local description="$1"
  shift
  local command=("$@")
  
  ((TESTS_RUN++))
  
  if "${command[@]}" >/dev/null 2>&1; then
    ((TESTS_FAILED++))
    echo -e "${RED}✗${NC} $description"
    echo -e "  ${RED}Expected failure but command succeeded${NC}"
    return 1
  else
    ((TESTS_PASSED++))
    echo -e "${GREEN}✓${NC} $description"
    return 0
  fi
}

# Assert equality
assert_equals() {
  local description="$1"
  local expected="$2"
  local actual="$3"
  
  ((TESTS_RUN++))
  
  if [[ "$expected" == "$actual" ]]; then
    ((TESTS_PASSED++))
    echo -e "${GREEN}✓${NC} $description"
    return 0
  else
    ((TESTS_FAILED++))
    echo -e "${RED}✗${NC} $description"
    echo -e "  ${RED}Expected: '$expected'${NC}"
    echo -e "  ${RED}Actual:   '$actual'${NC}"
    return 1
  fi
}

# Assert contains
assert_contains() {
  local description="$1"
  local haystack="$2"
  local needle="$3"
  
  ((TESTS_RUN++))
  
  if [[ "$haystack" == *"$needle"* ]]; then
    ((TESTS_PASSED++))
    echo -e "${GREEN}✓${NC} $description"
    return 0
  else
    ((TESTS_FAILED++))
    echo -e "${RED}✗${NC} $description"
    echo -e "  ${RED}Expected to contain: '$needle'${NC}"
    echo -e "  ${RED}Actual: '$haystack'${NC}"
    return 1
  fi
}

# Assert file exists
assert_file_exists() {
  local description="$1"
  local file="$2"
  
  ((TESTS_RUN++))
  
  if [[ -f "$file" ]]; then
    ((TESTS_PASSED++))
    echo -e "${GREEN}✓${NC} $description"
    return 0
  else
    ((TESTS_FAILED++))
    echo -e "${RED}✗${NC} $description"
    echo -e "  ${RED}File does not exist: $file${NC}"
    return 1
  fi
}

# Assert directory exists
assert_dir_exists() {
  local description="$1"
  local dir="$2"
  
  ((TESTS_RUN++))
  
  if [[ -d "$dir" ]]; then
    ((TESTS_PASSED++))
    echo -e "${GREEN}✓${NC} $description"
    return 0
  else
    ((TESTS_FAILED++))
    echo -e "${RED}✗${NC} $description"
    echo -e "  ${RED}Directory does not exist: $dir${NC}"
    return 1
  fi
}

# Setup function (override in test files)
setup() {
  :
}

# Teardown function (override in test files)
teardown() {
  :
}

# Run a test with setup/teardown
run_test() {
  local test_name="$1"
  
  setup
  "$test_name"
  local result=$?
  teardown
  
  return $result
}

# Print test summary
print_summary() {
  echo ""
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Test Summary${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "Total:  $TESTS_RUN"
  echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
  
  if [[ $TESTS_FAILED -gt 0 ]]; then
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    echo ""
    return 1
  else
    echo -e "${GREEN}All tests passed!${NC}"
    echo ""
    return 0
  fi
}

# Skip a test
skip() {
  local reason="$1"
  echo -e "${YELLOW}⊘${NC} SKIPPED: $reason"
}

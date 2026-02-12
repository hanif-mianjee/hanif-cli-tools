#!/usr/bin/env bash

# Tests for bumpversion command

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source test framework
source "$SCRIPT_DIR/test-framework.sh"

# Source the CLI (for testing)
export SCRIPT_DIR="$PROJECT_ROOT/bin"
export LIB_DIR="$PROJECT_ROOT/lib"
export COMMANDS_DIR="$LIB_DIR/commands"
export UTILS_DIR="$LIB_DIR/utils"
export FUNCTIONS_DIR="$LIB_DIR/functions"

# Source common utilities (needed by functions)
source "$UTILS_DIR/common.sh"

# Global test directory
TEST_DIR=""
ORIG_DIR="$(pwd)"

setup() {
  TEST_DIR=$(mktemp -d)
  cd "$TEST_DIR"
}

teardown() {
  cd "$ORIG_DIR"
  [[ -n "$TEST_DIR" ]] && rm -rf "$TEST_DIR"
}

# ─────────────────────────────────────────────
# File existence tests
# ─────────────────────────────────────────────

test_bumpversion_command_exists() {
  assert_file_exists "Bumpversion command file exists" "$COMMANDS_DIR/bumpversion.sh"
}

test_bumpversion_functions_exist() {
  assert_file_exists "Bumpversion functions file exists" "$FUNCTIONS_DIR/bumpversion-functions.sh"
}

# ─────────────────────────────────────────────
# Help tests
# ─────────────────────────────────────────────

test_bumpversion_help() {
  local output
  output=$("$PROJECT_ROOT/bin/hanif" bumpversion --help 2>&1)

  assert_contains "Help output contains usage" "$output" "USAGE"
  assert_contains "Help output contains subcommands" "$output" "SUBCOMMANDS"
  assert_contains "Help output contains config" "$output" "CONFIG"
  assert_contains "Help output contains workflow" "$output" "WORKFLOW"
  assert_contains "Help output contains examples" "$output" "EXAMPLES"
  assert_contains "Help output contains tips" "$output" "TIPS"
}

test_bv_alias_help() {
  local output
  output=$("$PROJECT_ROOT/bin/hanif" bv --help 2>&1)

  assert_contains "bv alias shows help" "$output" "Version Bumping Tool"
}

# ─────────────────────────────────────────────
# Config parsing tests
# ─────────────────────────────────────────────

test_config_parsing() {
  setup

  cat > .bumpversion.cfg << 'EOF'
[bumpversion]
current_version = 1.2.3-rc1
commit = True
tag = True
tag_name = v{new_version}
parse = (?P<major>\d+)\.(?P<minor>\d+)\.(?P<patch>\d+)(-(?P<release>rc)(?P<rc>\d+))?
serialize =
  {major}.{minor}.{patch}-{release}{rc}
  {major}.{minor}.{patch}
commit_message = chore: release version {new_version}

[bumpversion:part:release]
optional_value = ga
values =
  rc
  ga

[bumpversion:part:rc]
first_value = 0

[bumpversion:file:setup.py]
search = version='{current_version}'
replace = version='{new_version}'

[bumpversion:file:README.md]
EOF

  source "$FUNCTIONS_DIR/bumpversion-functions.sh"
  parse_bumpversion_config

  assert_equals "Current version parsed" "1.2.3-rc1" "$(_bv_get_config "current_version")"
  assert_equals "Commit setting parsed" "True" "$(_bv_get_config "commit")"
  assert_equals "Tag setting parsed" "True" "$(_bv_get_config "tag")"
  assert_equals "Tag name parsed" "v{new_version}" "$(_bv_get_config "tag_name")"
  assert_equals "Release optional_value parsed" "ga" "$(_bv_get_part "release" "optional_value")"
  assert_equals "RC first_value parsed" "0" "$(_bv_get_part "rc" "first_value")"
  assert_equals "File search pattern parsed" "version='{current_version}'" "$(_bv_get_file_prop "0" "search")"
  assert_equals "File count" "2" "$BV_FILE_COUNT"

  teardown
}

# ─────────────────────────────────────────────
# Version parsing tests
# ─────────────────────────────────────────────

test_version_parsing_with_rc() {
  setup

  cat > .bumpversion.cfg << 'EOF'
[bumpversion]
current_version = 1.2.3-rc1
parse = (?P<major>\d+)\.(?P<minor>\d+)\.(?P<patch>\d+)(-(?P<release>rc)(?P<rc>\d+))?
serialize =
  {major}.{minor}.{patch}-{release}{rc}
  {major}.{minor}.{patch}

[bumpversion:part:release]
optional_value = ga

[bumpversion:part:rc]
first_value = 0
EOF

  source "$FUNCTIONS_DIR/bumpversion-functions.sh"
  parse_bumpversion_config
  parse_version "1.2.3-rc1"

  assert_equals "Major parsed" "1" "$(_bv_get_vp "major")"
  assert_equals "Minor parsed" "2" "$(_bv_get_vp "minor")"
  assert_equals "Patch parsed" "3" "$(_bv_get_vp "patch")"
  assert_equals "Release parsed" "rc" "$(_bv_get_vp "release")"
  assert_equals "RC parsed" "1" "$(_bv_get_vp "rc")"

  teardown
}

test_version_parsing_without_rc() {
  setup

  cat > .bumpversion.cfg << 'EOF'
[bumpversion]
current_version = 1.2.3
parse = (?P<major>\d+)\.(?P<minor>\d+)\.(?P<patch>\d+)(-(?P<release>rc)(?P<rc>\d+))?
serialize =
  {major}.{minor}.{patch}-{release}{rc}
  {major}.{minor}.{patch}

[bumpversion:part:release]
optional_value = ga

[bumpversion:part:rc]
first_value = 0
EOF

  source "$FUNCTIONS_DIR/bumpversion-functions.sh"
  parse_bumpversion_config
  parse_version "1.2.3"

  assert_equals "Major parsed" "1" "$(_bv_get_vp "major")"
  assert_equals "Minor parsed" "2" "$(_bv_get_vp "minor")"
  assert_equals "Patch parsed" "3" "$(_bv_get_vp "patch")"
  assert_equals "Release empty" "" "$(_bv_get_vp "release")"
  assert_equals "RC empty" "" "$(_bv_get_vp "rc")"

  teardown
}

# ─────────────────────────────────────────────
# Version calculation tests
# ─────────────────────────────────────────────

_setup_version_config() {
  cat > .bumpversion.cfg << 'EOF'
[bumpversion]
current_version = 1.2.3
parse = (?P<major>\d+)\.(?P<minor>\d+)\.(?P<patch>\d+)(-(?P<release>rc)(?P<rc>\d+))?
serialize =
  {major}.{minor}.{patch}-{release}{rc}
  {major}.{minor}.{patch}

[bumpversion:part:release]
optional_value = ga
values =
  rc
  ga

[bumpversion:part:rc]
first_value = 0
EOF

  source "$FUNCTIONS_DIR/bumpversion-functions.sh"
  parse_bumpversion_config
  parse_version "1.2.3"
}

_setup_rc_version_config() {
  cat > .bumpversion.cfg << 'EOF'
[bumpversion]
current_version = 1.2.3-rc1
parse = (?P<major>\d+)\.(?P<minor>\d+)\.(?P<patch>\d+)(-(?P<release>rc)(?P<rc>\d+))?
serialize =
  {major}.{minor}.{patch}-{release}{rc}
  {major}.{minor}.{patch}

[bumpversion:part:release]
optional_value = ga
values =
  rc
  ga

[bumpversion:part:rc]
first_value = 0
EOF

  source "$FUNCTIONS_DIR/bumpversion-functions.sh"
  parse_bumpversion_config
  parse_version "1.2.3-rc1"
}

test_calculate_patch() {
  setup
  _setup_version_config

  local result
  result=$(calculate_next_version "patch")
  assert_equals "Patch bump" "1.2.4-rc0" "$result"

  teardown
}

test_calculate_minor() {
  setup
  _setup_version_config

  local result
  result=$(calculate_next_version "minor")
  assert_equals "Minor bump" "1.3.0-rc0" "$result"

  teardown
}

test_calculate_major() {
  setup
  _setup_version_config

  local result
  result=$(calculate_next_version "major")
  assert_equals "Major bump" "2.0.0-rc0" "$result"

  teardown
}

test_calculate_rc_from_rc() {
  setup
  _setup_rc_version_config

  local result
  result=$(calculate_next_version "rc")
  assert_equals "RC bump from RC" "1.2.3-rc2" "$result"

  teardown
}

test_calculate_rc_from_release() {
  setup
  _setup_version_config

  local result
  result=$(calculate_next_version "rc")
  assert_equals "RC bump from release" "1.2.3-rc0" "$result"

  teardown
}

test_calculate_release() {
  setup
  _setup_rc_version_config

  local result
  result=$(calculate_next_version "release")
  assert_equals "Release from RC" "1.2.3" "$result"

  teardown
}

# ─────────────────────────────────────────────
# Serialization tests
# ─────────────────────────────────────────────

test_serialize_with_rc() {
  setup
  _setup_rc_version_config

  # Set version parts directly using the helper
  _bv_set_vp "major" "1"
  _bv_set_vp "minor" "2"
  _bv_set_vp "patch" "3"
  _bv_set_vp "release" "rc"
  _bv_set_vp "rc" "5"

  local result
  result=$(serialize_version)
  assert_equals "Serialize with RC" "1.2.3-rc5" "$result"

  teardown
}

test_serialize_without_rc() {
  setup
  _setup_version_config

  # Set version parts to simulate a GA release
  _bv_set_vp "major" "1"
  _bv_set_vp "minor" "2"
  _bv_set_vp "patch" "3"
  _bv_set_vp "release" "ga"
  _bv_set_vp "rc" ""

  local result
  result=$(serialize_version)
  assert_equals "Serialize without RC" "1.2.3" "$result"

  teardown
}

# ─────────────────────────────────────────────
# File update tests
# ─────────────────────────────────────────────

test_file_update() {
  setup

  # Create test files
  echo "version='1.0.0'" > test_setup.py
  echo '{"version": "1.0.0"}' > test_package.json

  cat > .bumpversion.cfg << 'EOF'
[bumpversion]
current_version = 1.0.0
parse = (?P<major>\d+)\.(?P<minor>\d+)\.(?P<patch>\d+)(-(?P<release>rc)(?P<rc>\d+))?
serialize =
  {major}.{minor}.{patch}-{release}{rc}
  {major}.{minor}.{patch}

[bumpversion:part:release]
optional_value = ga

[bumpversion:part:rc]
first_value = 0

[bumpversion:file:test_setup.py]

[bumpversion:file:test_package.json]
EOF

  source "$FUNCTIONS_DIR/bumpversion-functions.sh"
  parse_bumpversion_config

  update_version_files "1.0.0" "1.0.1-rc0"

  local setup_content package_content config_content
  setup_content=$(cat test_setup.py)
  package_content=$(cat test_package.json)
  config_content=$(cat .bumpversion.cfg)

  assert_contains "setup.py updated" "$setup_content" "1.0.1-rc0"
  assert_contains "package.json updated" "$package_content" "1.0.1-rc0"
  assert_contains "Config updated" "$config_content" "current_version = 1.0.1-rc0"

  teardown
}

# ─────────────────────────────────────────────
# Init tests
# ─────────────────────────────────────────────

test_init_creates_config() {
  setup

  # Create a fake package.json
  echo '{"version": "2.5.0"}' > package.json

  source "$FUNCTIONS_DIR/bumpversion-functions.sh"

  # Run init with simulated input (use version, track files, no extra files)
  echo -e "y\ny\nn" | bumpversion_init 2>&1 >/dev/null || true

  assert_file_exists "Config file created" ".bumpversion.cfg"

  local config_content
  config_content=$(cat .bumpversion.cfg)
  assert_contains "Config has version" "$config_content" "current_version"
  assert_contains "Config has parse regex" "$config_content" "parse"
  assert_contains "Config has serialize" "$config_content" "serialize"

  teardown
}

test_init_detects_package_json() {
  setup

  echo '{"version": "3.0.0"}' > package.json

  source "$FUNCTIONS_DIR/bumpversion-functions.sh"

  # Auto-accept defaults
  echo -e "y\ny\nn" | bumpversion_init 2>&1 >/dev/null || true

  local config_content
  config_content=$(cat .bumpversion.cfg)
  assert_contains "Config tracks package.json" "$config_content" "package.json"

  teardown
}

test_init_detects_pyproject_toml() {
  setup

  cat > pyproject.toml << 'EOF'
[project]
name = "myproject"
version = "0.5.0"
EOF

  source "$FUNCTIONS_DIR/bumpversion-functions.sh"

  echo -e "y\ny\nn" | bumpversion_init 2>&1 >/dev/null || true

  local config_content
  config_content=$(cat .bumpversion.cfg)
  assert_contains "Config tracks pyproject.toml" "$config_content" "pyproject.toml"

  teardown
}

# ─────────────────────────────────────────────
# Tag conflict tests
# ─────────────────────────────────────────────

test_tag_conflict_detection() {
  setup

  git init >/dev/null 2>&1
  git config user.email "test@example.com"
  git config user.name "Test User"
  echo "test" > file.txt
  git add file.txt
  git commit -m "Initial commit" >/dev/null 2>&1
  git tag -a "v1.0.0" -m "v1.0.0"

  source "$FUNCTIONS_DIR/bumpversion-functions.sh"

  # check_tag_exists should return 0 (exists) for v1.0.0
  local result=0
  check_tag_exists "v1.0.0" || result=$?
  assert_equals "Existing tag detected" "0" "$result"

  # check_tag_exists should return 1 (not found) for v9.9.9
  result=0
  check_tag_exists "v9.9.9" || result=$?
  assert_equals "Non-existing tag not found" "1" "$result"

  teardown
}

# ─────────────────────────────────────────────
# Commit revert on tag conflict tests
# ─────────────────────────────────────────────

test_revert_bump_commit_on_tag_abort() {
  setup

  git init >/dev/null 2>&1
  git config user.email "test@example.com"
  git config user.name "Test User"

  # Create initial commit with version file
  echo "version='1.0.0'" > setup.py
  cat > .bumpversion.cfg << 'EOF'
[bumpversion]
current_version = 1.0.0
commit = True
tag = True
tag_name = v{new_version}
parse = (?P<major>\d+)\.(?P<minor>\d+)\.(?P<patch>\d+)(-(?P<release>rc)(?P<rc>\d+))?
serialize =
  {major}.{minor}.{patch}-{release}{rc}
  {major}.{minor}.{patch}
commit_message = Bump version: {current_version} → {new_version}

[bumpversion:part:release]
optional_value = ga
values =
  rc
  ga

[bumpversion:part:rc]
first_value = 0

[bumpversion:file:setup.py]
EOF

  git add .
  git commit -m "Initial commit" >/dev/null 2>&1

  # Create conflicting tag
  git tag -a "v1.0.1-rc0" -m "v1.0.1-rc0"

  local initial_sha
  initial_sha=$(git rev-parse HEAD)

  source "$FUNCTIONS_DIR/bumpversion-functions.sh"
  parse_bumpversion_config
  parse_version "1.0.0"

  local new_version
  new_version=$(calculate_next_version "patch")

  # Update files (this simulates what bump_version does)
  update_version_files "1.0.0" "$new_version"

  # Run commit and tag, selecting abort (option 3) for tag conflict
  echo "3" | bump_commit_and_tag "1.0.0" "$new_version" 2>&1 >/dev/null || true

  # After abort, HEAD should be back to initial commit
  local final_sha
  final_sha=$(git rev-parse HEAD)
  assert_equals "HEAD reverted to pre-bump commit" "$initial_sha" "$final_sha"

  # Version file should be restored
  local setup_content
  setup_content=$(cat setup.py)
  assert_contains "setup.py restored to original version" "$setup_content" "1.0.0"

  teardown
}

test_default_commit_message() {
  setup

  source "$FUNCTIONS_DIR/bumpversion-functions.sh"

  # Test that default commit_message uses the right pattern
  # (not "chore: release version" but "Bump version: X → Y")
  _bv_set_config "commit_message" ""
  # After reset, the default should kick in
  local default_msg
  default_msg=$(_bv_get_config "commit_message")
  # When commit_message is empty, bump_commit_and_tag uses the fallback
  # Test the init-generated config
  echo '{"version": "1.0.0"}' > package.json
  echo -e "y\ny\nn" | bumpversion_init 2>&1 >/dev/null || true

  local config_content
  config_content=$(cat .bumpversion.cfg)
  assert_contains "Init uses correct commit message pattern" "$config_content" "Bump version: {current_version}"

  teardown
}

# ─────────────────────────────────────────────
# Integration tests (main CLI)
# ─────────────────────────────────────────────

test_help_bumpversion_topic() {
  local output
  output=$("$PROJECT_ROOT/bin/hanif" help bumpversion 2>&1)

  assert_contains "Help shows bumpversion docs" "$output" "Version Bumping Tool"
  assert_contains "Help shows workflow" "$output" "WORKFLOW"
  assert_contains "Help shows tips" "$output" "TIPS"
}

test_help_bv_topic() {
  local output
  output=$("$PROJECT_ROOT/bin/hanif" help bv 2>&1)

  assert_contains "Help bv alias works" "$output" "Version Bumping Tool"
}

test_main_help_includes_bumpversion() {
  local output
  output=$("$PROJECT_ROOT/bin/hanif" help 2>&1)

  assert_contains "Main help includes bv command" "$output" "bv"
  assert_contains "Main help shows bv description" "$output" "Version bumping"
}

test_main_usage_includes_bumpversion() {
  local output
  output=$("$PROJECT_ROOT/bin/hanif" 2>&1)

  assert_contains "Main usage includes bv" "$output" "bv [subcommand]"
}

# ─────────────────────────────────────────────
# Run all tests
# ─────────────────────────────────────────────

echo "Running bumpversion command tests..."
echo ""

# File existence
run_test test_bumpversion_command_exists
run_test test_bumpversion_functions_exist

# Help
run_test test_bumpversion_help
run_test test_bv_alias_help

# Config parsing
run_test test_config_parsing

# Version parsing
run_test test_version_parsing_with_rc
run_test test_version_parsing_without_rc

# Version calculation
run_test test_calculate_patch
run_test test_calculate_minor
run_test test_calculate_major
run_test test_calculate_rc_from_rc
run_test test_calculate_rc_from_release
run_test test_calculate_release

# Serialization
run_test test_serialize_with_rc
run_test test_serialize_without_rc

# File updates
run_test test_file_update

# Init
run_test test_init_creates_config
run_test test_init_detects_package_json
run_test test_init_detects_pyproject_toml

# Tag conflict
run_test test_tag_conflict_detection

# Commit revert
run_test test_revert_bump_commit_on_tag_abort
run_test test_default_commit_message

# Integration
run_test test_help_bumpversion_topic
run_test test_help_bv_topic
run_test test_main_help_includes_bumpversion
run_test test_main_usage_includes_bumpversion

print_summary

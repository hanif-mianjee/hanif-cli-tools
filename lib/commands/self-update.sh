#!/usr/bin/env bash
#
# Self-update command — fetch and run the canonical install script.
#
# Living in its own command file means it self-registers and the entry-point
# script no longer needs to know about it.

register_command --name "self-update" --group "Other" \
  --handler "self_update_command" \
  --description "Update Hanif CLI to latest version"

self_update_command() {
  # shellcheck source=../functions/update-functions.sh
  source "${FUNCTIONS_DIR}/update-functions.sh"
  self_update "$@"
}

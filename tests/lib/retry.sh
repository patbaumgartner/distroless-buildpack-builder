#!/usr/bin/env bash
# tests/lib/retry.sh
#
# Retry a command with exponential backoff.
#
# Registry pulls and buildpack dependency downloads fail intermittently with
# connection resets and timeouts (Docker Hub, GitHub releases, go.dev). Without
# a retry a single reset turns the whole pipeline red.
#
# Usage:
#   bash tests/lib/retry.sh <command> [args...]
#   source tests/lib/retry.sh && retry <command> [args...]
#
# Environment:
#   RETRY_ATTEMPTS  total attempts before giving up (default 3)
#   RETRY_DELAY     seconds to wait after the first failure (default 15),
#                   doubled after every subsequent failure

retry() {
  local attempts="${RETRY_ATTEMPTS:-3}"
  local delay="${RETRY_DELAY:-15}"
  local attempt=1
  local rc

  while true; do
    rc=0
    "$@" || rc=$?

    if [[ "${rc}" -eq 0 ]]; then
      return 0
    fi

    if [[ "${attempt}" -ge "${attempts}" ]]; then
      echo "retry: giving up after ${attempts} attempt(s), last exit ${rc}: $*" >&2
      return "${rc}"
    fi

    echo "retry: attempt ${attempt}/${attempts} failed (exit ${rc}), retrying in ${delay}s: $*" >&2
    sleep "${delay}"
    attempt=$((attempt + 1))
    delay=$((delay * 2))
  done
}

# Executed directly rather than sourced: act as a command wrapper.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  set -uo pipefail

  if [[ "$#" -eq 0 ]]; then
    echo "usage: retry.sh <command> [args...]" >&2
    exit 2
  fi

  retry "$@"
fi

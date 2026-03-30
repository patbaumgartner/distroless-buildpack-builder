#!/usr/bin/env bash
# tests/integration/test_builder.sh
#
# Integration tests for the distroless buildpack builder.
# Builds each sample application using 'pack' and verifies the resulting
# container starts and responds correctly.
#
# Prerequisites:
#   - pack CLI installed and on PATH
#   - docker daemon running
#   - BUILDER image available locally or pullable
#
# Usage:
#   ./tests/integration/test_builder.sh
#   BUILDER=distroless-builder ./tests/integration/test_builder.sh

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

BUILDER="${BUILDER:-ghcr.io/patbaumgartner/distroless-buildpack-builder:latest}"
REGISTRY_PREFIX="${REGISTRY_PREFIX:-distroless-test}"
CONTAINER_NAME_PREFIX="distroless-test-"
PORT=8080
PASS=0
FAIL=0

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------
info()  { echo "ℹ  $*"; }
pass()  { echo "✔  $*"; PASS=$((PASS + 1)); }
fail()  { echo "✘  $*"; FAIL=$((FAIL + 1)); }

cleanup_container() {
  local name="$1"
  docker rm -f "${name}" 2>/dev/null || true
}

wait_for_http() {
  local url="$1"
  local max_attempts=30
  local attempt=0
  while [[ ${attempt} -lt ${max_attempts} ]]; do
    if curl -sf "${url}" >/dev/null 2>&1; then
      return 0
    fi
    attempt=$((attempt + 1))
    sleep 1
  done
  return 1
}

test_sample() {
  local lang="$1"
  local src_dir="${REPO_ROOT}/samples/${lang}"
  local image="${REGISTRY_PREFIX}/${lang}:test"
  local container="${CONTAINER_NAME_PREFIX}${lang}"

  info "Testing sample: ${lang}"
  cleanup_container "${container}"

  info "  → Building image with pack..."
  local build_log
  build_log=$(mktemp)
  if ! pack build "${image}" \
        --path "${src_dir}" \
        --builder "${BUILDER}" \
        --pull-policy if-not-present \
        --trust-builder >"${build_log}" 2>&1; then
    fail "${lang}: pack build failed"
    cat "${build_log}"
    rm -f "${build_log}"
    return
  fi
  rm -f "${build_log}"

  info "  → Starting container..."
  docker run -d --rm \
    --name "${container}" \
    -e PORT="${PORT}" \
    -p "${PORT}:${PORT}" \
    "${image}" >/dev/null

  info "  → Waiting for HTTP response on :${PORT}..."
  if wait_for_http "http://localhost:${PORT}/"; then
    local body
    body=$(curl -sf "http://localhost:${PORT}/")
    if echo "${body}" | grep -qi "hello"; then
      pass "${lang}: root endpoint returned expected response"
    else
      fail "${lang}: unexpected response body: ${body}"
    fi
  else
    fail "${lang}: container did not become ready in time"
  fi

  cleanup_container "${container}"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
info "Builder: ${BUILDER}"
info "Running integration tests against sample applications..."
echo

for lang in nodejs go python ruby dotnet-core php web-servers; do
  test_sample "${lang}"
  echo
done

# Java builds take longer; only run when INCLUDE_JAVA=1
if [[ "${INCLUDE_JAVA:-0}" == "1" ]]; then
  test_sample "java"
  echo
  test_sample "java-native-image"
  echo
fi

echo "-------------------------------"
echo "Results: ${PASS} passed, ${FAIL} failed"
echo "-------------------------------"

if [[ "${FAIL}" -gt 0 ]]; then
  exit 1
fi

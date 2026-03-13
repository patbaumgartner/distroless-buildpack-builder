#!/usr/bin/env bash
# tests/smoke/smoke_test.sh
#
# Smoke tests for the distroless buildpack builder.
# Validates the stack images have the correct CNB labels and users,
# and that the builder.toml is syntactically valid.
#
# Usage:
#   ./tests/smoke/smoke_test.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

REGISTRY="${REGISTRY:-ghcr.io/patbaumgartner/distroless-buildpack-builder}"
BUILD_IMAGE="${BUILD_IMAGE:-${REGISTRY}/build:latest}"
RUN_IMAGE="${RUN_IMAGE:-${REGISTRY}/run:latest}"
BUILDER_IMAGE="${REGISTRY}:latest"
EXPECTED_STACK_ID="io.buildpacks.stacks.jammy"

PASS=0
FAIL=0

info()  { echo "ℹ  $*"; }
pass()  { echo "✔  $*"; PASS=$((PASS + 1)); }
fail()  { echo "✘  $*" >&2; FAIL=$((FAIL + 1)); }

check_label() {
  local image="$1"
  local label="$2"
  local expected="$3"

  local actual
  actual=$(docker inspect --format "{{ index .Config.Labels \"${label}\" }}" "${image}" 2>/dev/null)

  if [[ "${actual}" == "${expected}" ]]; then
    pass "${image}: label '${label}' = '${actual}'"
  else
    fail "${image}: label '${label}' expected '${expected}', got '${actual}'"
  fi
}

check_image_user() {
  local image="$1"
  local expected_uid="$2"

  local actual
  actual=$(docker inspect --format "{{ .Config.User }}" "${image}" 2>/dev/null)

  if [[ "${actual}" == *"${expected_uid}"* ]]; then
    pass "${image}: user contains expected uid '${expected_uid}'"
  else
    fail "${image}: user expected to contain '${expected_uid}', got '${actual}'"
  fi
}

# ---------------------------------------------------------------------------
# 1. Stack images – label checks
# ---------------------------------------------------------------------------
info "Checking stack image labels..."

if docker image inspect "${BUILD_IMAGE}" >/dev/null 2>&1; then
  check_label "${BUILD_IMAGE}" "io.buildpacks.stack.id" "${EXPECTED_STACK_ID}"
else
  fail "Build image not found locally: ${BUILD_IMAGE} (run 'make build-stack' first)"
fi

if docker image inspect "${RUN_IMAGE}" >/dev/null 2>&1; then
  check_label "${RUN_IMAGE}" "io.buildpacks.stack.id" "${EXPECTED_STACK_ID}"
  check_label "${RUN_IMAGE}" "io.buildpacks.base.distro.name" "distroless"
  check_image_user "${RUN_IMAGE}" "1002"
else
  fail "Run image not found locally: ${RUN_IMAGE} (run 'make build-stack' first)"
fi

# ---------------------------------------------------------------------------
# 2. builder.toml validation (pack inspect-builder if builder is available)
# ---------------------------------------------------------------------------
info "Validating builder.toml..."

if ! grep -q '\[stack\]' "${REPO_ROOT}/builder.toml"; then
  fail "builder.toml is missing [stack] section"
else
  pass "builder.toml contains [stack] section"
fi

if ! grep -q 'build-image' "${REPO_ROOT}/builder.toml"; then
  fail "builder.toml is missing build-image"
else
  pass "builder.toml contains build-image"
fi

if ! grep -q 'run-image' "${REPO_ROOT}/builder.toml"; then
  fail "builder.toml is missing run-image"
else
  pass "builder.toml contains run-image"
fi

# ---------------------------------------------------------------------------
# 3. Builder image (if available)
# ---------------------------------------------------------------------------
if docker image inspect "${BUILDER_IMAGE}" >/dev/null 2>&1; then
  info "Inspecting builder image..."
  if pack builder inspect "${BUILDER_IMAGE}" >/dev/null 2>&1; then
    pass "${BUILDER_IMAGE}: pack builder inspect succeeded"
  else
    fail "${BUILDER_IMAGE}: pack builder inspect failed"
  fi
else
  info "Builder image not found locally – skipping builder inspect"
fi

# ---------------------------------------------------------------------------
# 4. Dockerfile syntax check
# ---------------------------------------------------------------------------
if command -v hadolint >/dev/null 2>&1; then
  info "Running hadolint on Dockerfiles..."
  for df in "${REPO_ROOT}/stack/build/Dockerfile" "${REPO_ROOT}/stack/run/Dockerfile"; do
    if hadolint "${df}" 2>&1; then
      pass "${df}: hadolint passed"
    else
      fail "${df}: hadolint reported issues"
    fi
  done
else
  info "hadolint not found – skipping Dockerfile lint"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "-------------------------------"
echo "Smoke test results: ${PASS} passed, ${FAIL} failed"
echo "-------------------------------"

[[ "${FAIL}" -eq 0 ]]

#!/usr/bin/env bash
# tests/smoke/smoke_test.sh
#
# Verifies the contract that this project promises, without needing a shell
# inside the images under test: the run image is genuinely distroless
# (no shell, no package manager), runs as a non-root CNB user, carries the
# CNB metadata that `pack` relies on, and still ships the shared libraries
# that Paketo buildpacks link their runtimes against.
#
# Filesystem assertions come from `docker export`, so they work on an image
# that cannot execute anything.
#
# Usage:
#   ./tests/smoke/smoke_test.sh
#
# Environment:
#   BUILD_IMAGE, RUN_IMAGE, BUILDER_IMAGE   images to check
#   SMOKE_ARTIFACT_DIR                      directory to write inventories to

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

REGISTRY="${REGISTRY:-ghcr.io/patbaumgartner/distroless-buildpack-builder}"
BUILD_IMAGE="${BUILD_IMAGE:-${REGISTRY}/build:latest}"
RUN_IMAGE="${RUN_IMAGE:-${REGISTRY}/run:latest}"
BUILDER_IMAGE="${BUILDER_IMAGE:-${REGISTRY}:latest}"

EXPECTED_STACK_ID="io.buildpacks.stacks.jammy"
EXPECTED_RUN_USER="1002:1000"
EXPECTED_BUILD_UID="1000"

# Shared libraries that the run stack installs on purpose. Paketo compiles
# language runtimes against these, so a missing entry breaks applications at
# start-up rather than at build time.
REQUIRED_SONAMES=(
  libargon2.so.1
  libcrypt.so.1
  libcurl.so.4
  libexpat.so.1
  libffi.so.8
  libgmp.so.10
  libonig.so.5
  libreadline.so.8
  libsodium.so.23
  libsqlite3.so.0
  libxml2.so.2
  libyaml-0.so.2
  libssl.so.3
  libcrypto.so.3
  libicuuc.so.70
  libicui18n.so.70
  libicudata.so.70
)

# Executables that must never reach a distroless runtime.
FORBIDDEN_PATHS=(
  bin/sh
  bin/bash
  bin/dash
  bin/busybox
  usr/bin/sh
  usr/bin/bash
  usr/bin/dash
  usr/bin/apt
  usr/bin/apt-get
  usr/bin/dpkg
  usr/bin/openssl
)

PASS=0
FAIL=0

info() { echo "ℹ  $*"; }
pass() { echo "✔  $*"; PASS=$((PASS + 1)); }
fail() { echo "✘  $*" >&2; FAIL=$((FAIL + 1)); }

WORK_DIR="$(mktemp -d)"
cleanup() { rm -rf "${WORK_DIR}"; }
trap cleanup EXIT

# --------------------------------------------------------------------------
# Docker helpers
# --------------------------------------------------------------------------

image_exists() { docker image inspect "$1" >/dev/null 2>&1; }

inspect_field() {
  docker inspect --format "$2" "$1" 2>/dev/null
}

# Flattens an image to a file listing plus the passwd/group databases.
# `docker create` never starts the container, so the dummy command does not
# need to exist inside the image.
snapshot_image() {
  local image="$1"
  local dest="$2"
  local container

  mkdir -p "${dest}/etc"
  if ! container=$(docker create "${image}" /cnb-smoke-test-no-op 2>/dev/null); then
    return 1
  fi

  docker export "${container}" >"${dest}/rootfs.tar"
  docker rm -f "${container}" >/dev/null 2>&1 || true

  tar -tf "${dest}/rootfs.tar" | sed 's#^\./##' >"${dest}/files.txt"
  tar -xf "${dest}/rootfs.tar" -C "${dest}" etc/passwd etc/group >/dev/null 2>&1 || true
  rm -f "${dest}/rootfs.tar"
}

path_in_image() {
  grep -qxF "$2" "$1/files.txt"
}

soname_in_image() {
  local escaped="${2//./\\.}"
  grep -qE "/${escaped}(\.[0-9]+)*$" "$1/files.txt"
}

# --------------------------------------------------------------------------
# Assertions
# --------------------------------------------------------------------------

assert_label() {
  local image="$1" label="$2" expected="$3" actual
  actual=$(inspect_field "${image}" "{{ index .Config.Labels \"${label}\" }}")
  if [[ "${actual}" == "${expected}" ]]; then
    pass "${image}: ${label} = ${actual}"
  else
    fail "${image}: ${label} expected '${expected}', got '${actual}'"
  fi
}

assert_config_user() {
  local image="$1" expected="$2" actual
  actual=$(inspect_field "${image}" "{{ .Config.User }}")
  if [[ "${actual}" == "${expected}" ]]; then
    pass "${image}: runs as ${actual}"
  else
    fail "${image}: user expected '${expected}', got '${actual}'"
  fi
}

assert_env() {
  local image="$1" name="$2" expected="$3" actual
  actual=$(inspect_field "${image}" \
    "{{ range .Config.Env }}{{ println . }}{{ end }}" | grep "^${name}=" || true)
  if [[ "${actual}" == "${name}=${expected}" ]]; then
    pass "${image}: ${name}=${expected}"
  else
    fail "${image}: ${name} expected '${expected}', got '${actual:-<unset>}'"
  fi
}

# --------------------------------------------------------------------------
# 1. Run image – the distroless runtime contract
# --------------------------------------------------------------------------
info "Checking run image: ${RUN_IMAGE}"

if ! image_exists "${RUN_IMAGE}"; then
  fail "Run image not found locally: ${RUN_IMAGE} (run 'make build-stack' first)"
elif ! snapshot_image "${RUN_IMAGE}" "${WORK_DIR}/run"; then
  fail "Could not export run image filesystem: ${RUN_IMAGE}"
else
  assert_label "${RUN_IMAGE}" "io.buildpacks.stack.id" "${EXPECTED_STACK_ID}"
  assert_label "${RUN_IMAGE}" "io.buildpacks.base.distro.name" "distroless"
  assert_config_user "${RUN_IMAGE}" "${EXPECTED_RUN_USER}"

  for path in "${FORBIDDEN_PATHS[@]}"; do
    if path_in_image "${WORK_DIR}/run" "${path}"; then
      fail "run image is not distroless: /${path} is present"
    fi
  done
  pass "run image contains no shell, package manager, or openssl binary"

  missing_sonames=()
  for soname in "${REQUIRED_SONAMES[@]}"; do
    soname_in_image "${WORK_DIR}/run" "${soname}" || missing_sonames+=("${soname}")
  done
  if [[ ${#missing_sonames[@]} -eq 0 ]]; then
    pass "run image provides all ${#REQUIRED_SONAMES[@]} required shared libraries"
  else
    fail "run image is missing shared libraries: ${missing_sonames[*]}"
  fi

  if grep -qE "^cnb:[^:]*:1002:1000" "${WORK_DIR}/run/etc/passwd" 2>/dev/null; then
    pass "run image /etc/passwd declares cnb as uid 1002, gid 1000"
  else
    fail "run image /etc/passwd has no cnb user with uid 1002 and gid 1000"
  fi

  if grep -qE "^cnb:[^:]*:1000" "${WORK_DIR}/run/etc/group" 2>/dev/null; then
    pass "run image /etc/group declares cnb as gid 1000"
  else
    fail "run image /etc/group has no cnb group with gid 1000"
  fi

  for path in etc/ssl/certs usr/share/zoneinfo etc/services; do
    if grep -qE "^${path}(/|$)" "${WORK_DIR}/run/files.txt"; then
      pass "run image ships /${path}"
    else
      fail "run image is missing /${path}"
    fi
  done
fi

# --------------------------------------------------------------------------
# 2. Build image – CNB build-time contract
# --------------------------------------------------------------------------
info "Checking build image: ${BUILD_IMAGE}"

if ! image_exists "${BUILD_IMAGE}"; then
  fail "Build image not found locally: ${BUILD_IMAGE} (run 'make build-stack' first)"
else
  assert_label "${BUILD_IMAGE}" "io.buildpacks.stack.id" "${EXPECTED_STACK_ID}"
  assert_config_user "${BUILD_IMAGE}" "cnb"
  assert_env "${BUILD_IMAGE}" "CNB_USER_ID" "${EXPECTED_BUILD_UID}"
  assert_env "${BUILD_IMAGE}" "CNB_GROUP_ID" "1000"
  assert_env "${BUILD_IMAGE}" "CNB_STACK_ID" "${EXPECTED_STACK_ID}"
fi

# --------------------------------------------------------------------------
# 3. Both images must agree on the stack id, or `pack` refuses the builder
# --------------------------------------------------------------------------
if image_exists "${BUILD_IMAGE}" && image_exists "${RUN_IMAGE}"; then
  build_stack_id=$(inspect_field "${BUILD_IMAGE}" \
    '{{ index .Config.Labels "io.buildpacks.stack.id" }}')
  run_stack_id=$(inspect_field "${RUN_IMAGE}" \
    '{{ index .Config.Labels "io.buildpacks.stack.id" }}')
  if [[ "${build_stack_id}" == "${run_stack_id}" ]]; then
    pass "build and run images agree on stack id '${build_stack_id}'"
  else
    fail "stack id mismatch: build='${build_stack_id}' run='${run_stack_id}'"
  fi
fi

# --------------------------------------------------------------------------
# 4. builder.toml
# --------------------------------------------------------------------------
info "Validating builder.toml..."

if ! command -v python3 >/dev/null 2>&1; then
  fail "python3 is required to validate builder.toml"
elif toml_errors=$(python3 "${SCRIPT_DIR}/validate_builder_toml.py" \
  "${REPO_ROOT}/builder.toml" "${EXPECTED_STACK_ID}" 2>&1); then
  pass "builder.toml structural validation passed"
else
  while IFS= read -r line; do
    fail "builder.toml: ${line}"
  done <<<"${toml_errors}"
fi

# --------------------------------------------------------------------------
# 5. Builder image (only when it has been assembled locally)
# --------------------------------------------------------------------------
if image_exists "${BUILDER_IMAGE}"; then
  info "Inspecting builder image: ${BUILDER_IMAGE}"
  if pack builder inspect "${BUILDER_IMAGE}" >/dev/null 2>&1; then
    pass "${BUILDER_IMAGE}: pack builder inspect succeeded"
  else
    fail "${BUILDER_IMAGE}: pack builder inspect failed"
  fi
else
  info "Builder image not found locally – skipping builder inspect"
fi

# --------------------------------------------------------------------------
# 6. Publish the run image inventory so slimming changes can be diffed
# --------------------------------------------------------------------------
if [[ -n "${SMOKE_ARTIFACT_DIR:-}" && -f "${WORK_DIR}/run/files.txt" ]]; then
  mkdir -p "${SMOKE_ARTIFACT_DIR}"
  cp "${WORK_DIR}/run/files.txt" "${SMOKE_ARTIFACT_DIR}/run-image-files.txt"
  grep -oE '[^/]*\.so(\.[0-9]+)*$' "${WORK_DIR}/run/files.txt" | sort -u \
    >"${SMOKE_ARTIFACT_DIR}/run-image-sonames.txt"
  info "Wrote run image inventory to ${SMOKE_ARTIFACT_DIR}"
fi

echo ""
echo "-------------------------------"
echo "Smoke test results: ${PASS} passed, ${FAIL} failed"
echo "-------------------------------"

[[ "${FAIL}" -eq 0 ]]

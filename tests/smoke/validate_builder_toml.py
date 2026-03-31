#!/usr/bin/env python3
"""Strict structural validation of builder.toml using a TOML parser.

Validates:
  - File parses as valid TOML
  - Required sections exist: [stack], [lifecycle], [[buildpacks]], [[order]]
  - [stack] contains id, build-image, run-image; stack id matches expected value
  - [lifecycle] contains a version string
  - Every [[buildpacks]] entry has a uri starting with "docker://"
  - Every [[order]] has at least one [[order.group]] with id and version
  - Each order.group id has a matching [[buildpacks]] URI
  - Each order.group version matches the corresponding [[buildpacks]] URI tag

Usage:
  python3 validate_builder_toml.py <path-to-builder.toml> <expected-stack-id>

Exit code 0 on success, 1 on validation failure (errors printed to stderr).
"""

import sys

try:
    import tomllib  # Python 3.11+
except ModuleNotFoundError:
    try:
        import tomli as tomllib  # type: ignore[no-redef]
    except ModuleNotFoundError:
        # Python < 3.11 without tomli — fall back to a minimal approach
        import json
        import subprocess

        print(
            "Neither tomllib nor tomli available; "
            "install tomli or use Python 3.11+",
            file=sys.stderr,
        )
        sys.exit(1)


def main() -> int:
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <builder.toml> <expected-stack-id>", file=sys.stderr)
        return 1

    path = sys.argv[1]
    expected_stack_id = sys.argv[2]
    errors: list[str] = []

    # Parse TOML
    try:
        with open(path, "rb") as f:
            data = tomllib.load(f)
    except Exception as exc:
        print(f"Failed to parse TOML: {exc}", file=sys.stderr)
        return 1

    # [stack]
    stack = data.get("stack")
    if not isinstance(stack, dict):
        errors.append("Missing or invalid [stack] section")
    else:
        if "id" not in stack:
            errors.append("[stack] is missing 'id'")
        elif stack["id"] != expected_stack_id:
            errors.append(
                f"[stack] id is '{stack['id']}', expected '{expected_stack_id}'"
            )
        if "build-image" not in stack:
            errors.append("[stack] is missing 'build-image'")
        if "run-image" not in stack:
            errors.append("[stack] is missing 'run-image'")

    # [lifecycle]
    lifecycle = data.get("lifecycle")
    if not isinstance(lifecycle, dict):
        errors.append("Missing or invalid [lifecycle] section")
    elif "version" not in lifecycle:
        errors.append("[lifecycle] is missing 'version'")

    # [[buildpacks]]
    buildpacks = data.get("buildpacks")
    if not isinstance(buildpacks, list) or len(buildpacks) == 0:
        errors.append("Missing or empty [[buildpacks]] list")
    else:
        # Build a map: depName -> tag from URIs
        bp_uri_map: dict[str, str] = {}
        for i, bp in enumerate(buildpacks):
            uri = bp.get("uri", "")
            if not uri.startswith("docker://"):
                errors.append(f"[[buildpacks]][{i}] uri does not start with 'docker://': {uri}")
            else:
                # Parse "docker://paketobuildpacks/java:21.4.0"
                ref = uri.removeprefix("docker://")
                # Strip optional docker.io/ prefix
                if ref.startswith("docker.io/"):
                    ref = ref.removeprefix("docker.io/")
                if ":" in ref:
                    name, tag = ref.rsplit(":", 1)
                    bp_uri_map[name] = tag
                else:
                    errors.append(f"[[buildpacks]][{i}] uri missing version tag: {uri}")

    # [[order]]
    orders = data.get("order")
    if not isinstance(orders, list) or len(orders) == 0:
        errors.append("Missing or empty [[order]] list")
    else:
        for i, order in enumerate(orders):
            group = order.get("group")
            if not isinstance(group, list) or len(group) == 0:
                errors.append(f"[[order]][{i}] has no [[order.group]] entries")
                continue
            for j, entry in enumerate(group):
                entry_id = entry.get("id", "")
                entry_version = entry.get("version", "")
                if not entry_id:
                    errors.append(f"[[order]][{i}].group[{j}] is missing 'id'")
                if not entry_version:
                    errors.append(f"[[order]][{i}].group[{j}] is missing 'version'")
                # Cross-reference: order.group id should match a buildpacks URI
                if entry_id and isinstance(buildpacks, list):
                    # Convert id "paketo-buildpacks/java" -> "paketobuildpacks/java"
                    # Only strip hyphens from the org prefix, not the buildpack name
                    parts = entry_id.split("/", 1)
                    bp_name = parts[0].replace("-", "") + "/" + parts[1] if len(parts) == 2 else entry_id.replace("-", "")
                    if bp_name not in bp_uri_map:
                        errors.append(
                            f"[[order]][{i}].group[{j}] id '{entry_id}' "
                            f"has no matching [[buildpacks]] URI"
                        )
                    elif entry_version and bp_uri_map[bp_name] != entry_version:
                        errors.append(
                            f"[[order]][{i}].group[{j}] version '{entry_version}' "
                            f"does not match [[buildpacks]] URI tag "
                            f"'{bp_uri_map[bp_name]}' for '{entry_id}'"
                        )

    if errors:
        for err in errors:
            print(err, file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Structural validation of ``builder.toml``.

``pack builder create`` only reports the *first* problem it hits, and some
mistakes (an ``[[order]]`` version that has drifted away from the matching
``[[buildpacks]]`` tag) produce a builder that fails much later, at
``pack build`` time. This validator reports every problem in one pass, before
any image is built.

Checks:
  - The file parses as TOML.
  - ``[stack]`` exists with ``id``/``build-image``/``run-image``; the id
    matches the expected value.
  - ``[lifecycle]`` exists with a version.
  - Every ``[[buildpacks]]`` entry has a ``docker://`` uri pinned to a tag.
  - Every ``[[order]]`` has at least one ``[[order.group]]`` with id/version.
  - Every ``order.group`` id resolves to a ``[[buildpacks]]`` uri, and the
    versions agree.

Usage:
  python3 validate_builder_toml.py <path-to-builder.toml> <expected-stack-id>

Exit code 0 on success, 1 on validation failure (errors printed to stderr).
"""

from __future__ import annotations

import sys
from typing import Any

try:
    import tomllib
except ModuleNotFoundError:  # pragma: no cover - Python < 3.11
    try:
        import tomli as tomllib  # type: ignore[no-redef]
    except ModuleNotFoundError:  # pragma: no cover - no TOML parser at all
        sys.exit("builder.toml validation needs Python 3.11+ or the 'tomli' package")

DOCKER_URI_PREFIX = "docker://"
MOVING_TAGS = frozenset({"latest", "edge", "main", "master"})


def _normalize_repository(repository: str) -> str:
    """Make an image repository comparable to a buildpack id.

    Paketo publishes ``paketo-buildpacks/java`` under the image repository
    ``paketobuildpacks/java``, so the organisation segment is compared with
    hyphens removed. The final segment is the buildpack name and is left
    alone, because names such as ``java-native-image`` are hyphenated.
    """
    org, separator, name = repository.rpartition("/")
    return f"{org.replace('-', '')}{separator}{name}"


def parse_image_ref(ref: str) -> tuple[str, str]:
    """Split an image reference into ``(normalized repository, tag)``.

    Handles an optional registry host and an optional ``@sha256:`` digest.
    The tag is an empty string when the reference is not tagged.
    """
    name = ref.split("@", 1)[0]
    host, separator, remainder = name.partition("/")
    if separator and ("." in host or ":" in host or host == "localhost"):
        name = remainder
    repository, separator, tag = name.rpartition(":")
    if not separator:
        repository, tag = name, ""
    return _normalize_repository(repository), tag


def _validate_stack(data: dict[str, Any], expected_stack_id: str) -> list[str]:
    stack = data.get("stack")
    if not isinstance(stack, dict):
        return ["Missing or invalid [stack] section"]

    errors: list[str] = []
    stack_id = stack.get("id")
    if stack_id is None:
        errors.append("[stack] is missing 'id'")
    elif stack_id != expected_stack_id:
        errors.append(f"[stack] id is '{stack_id}', expected '{expected_stack_id}'")

    for key in ("build-image", "run-image"):
        value = stack.get(key)
        if value is None:
            errors.append(f"[stack] is missing '{key}'")
        elif not isinstance(value, str) or not value.strip():
            errors.append(f"[stack] '{key}' must be a non-empty string")
    return errors


def _validate_lifecycle(data: dict[str, Any]) -> list[str]:
    lifecycle = data.get("lifecycle")
    if not isinstance(lifecycle, dict):
        return ["Missing or invalid [lifecycle] section"]
    version = lifecycle.get("version")
    if version is None:
        return ["[lifecycle] is missing 'version'"]
    if not isinstance(version, str) or not version.strip():
        return ["[lifecycle] 'version' must be a non-empty string"]
    return []


def _validate_buildpacks(
    data: dict[str, Any],
) -> tuple[dict[str, set[str]], list[str]]:
    """Return ``({repository: {tags}}, errors)``.

    A builder may legitimately embed several versions of the same buildpack,
    so tags are collected into a set rather than overwriting each other. The
    map is always returned, even when the section is missing, so callers can
    cross-reference ``[[order]]`` entries unconditionally.
    """
    buildpacks = data.get("buildpacks")
    if not isinstance(buildpacks, list) or not buildpacks:
        return {}, ["Missing or empty [[buildpacks]] list"]

    tags_by_repository: dict[str, set[str]] = {}
    errors: list[str] = []
    for index, buildpack in enumerate(buildpacks):
        location = f"[[buildpacks]][{index}]"
        if not isinstance(buildpack, dict):
            errors.append(f"{location} is not a table")
            continue

        uri = buildpack.get("uri")
        if not isinstance(uri, str) or not uri:
            errors.append(f"{location} is missing 'uri'")
            continue
        if not uri.startswith(DOCKER_URI_PREFIX):
            errors.append(
                f"{location} uri does not start with '{DOCKER_URI_PREFIX}': {uri}"
            )
            continue

        repository, tag = parse_image_ref(uri[len(DOCKER_URI_PREFIX) :])
        if not tag:
            errors.append(f"{location} uri missing version tag: {uri}")
            continue
        if tag in MOVING_TAGS:
            # Renovate pins these tags; a moving tag silently changes the builder.
            errors.append(f"{location} uri must pin a version, not '{tag}': {uri}")
            continue
        tags_by_repository.setdefault(repository, set()).add(tag)

    return tags_by_repository, errors


def _validate_order(
    data: dict[str, Any], tags_by_repository: dict[str, set[str]]
) -> list[str]:
    orders = data.get("order")
    if not isinstance(orders, list) or not orders:
        return ["Missing or empty [[order]] list"]

    errors: list[str] = []
    for order_index, order in enumerate(orders):
        location = f"[[order]][{order_index}]"
        if not isinstance(order, dict):
            errors.append(f"{location} is not a table")
            continue

        group = order.get("group")
        if not isinstance(group, list) or not group:
            errors.append(f"{location} has no [[order.group]] entries")
            continue

        for entry_index, entry in enumerate(group):
            entry_location = f"{location}.group[{entry_index}]"
            if not isinstance(entry, dict):
                errors.append(f"{entry_location} is not a table")
                continue

            entry_id = entry.get("id")
            entry_version = entry.get("version")
            if not isinstance(entry_id, str) or not entry_id:
                errors.append(f"{entry_location} is missing 'id'")
                entry_id = ""
            if not isinstance(entry_version, str) or not entry_version:
                errors.append(f"{entry_location} is missing 'version'")
                entry_version = ""
            if not entry_id:
                continue

            repository = _normalize_repository(entry_id)
            pinned_tags = tags_by_repository.get(repository)
            if pinned_tags is None:
                errors.append(
                    f"{entry_location} id '{entry_id}' "
                    f"has no matching [[buildpacks]] uri"
                )
            elif entry_version and entry_version not in pinned_tags:
                available = ", ".join(sorted(pinned_tags))
                errors.append(
                    f"{entry_location} version '{entry_version}' does not match "
                    f"[[buildpacks]] uri tag '{available}' for '{entry_id}'"
                )
    return errors


def validate(data: dict[str, Any], expected_stack_id: str) -> list[str]:
    """Return every structural problem found in a parsed ``builder.toml``."""
    tags_by_repository, errors = _validate_buildpacks(data)
    return [
        *_validate_stack(data, expected_stack_id),
        *_validate_lifecycle(data),
        *errors,
        *_validate_order(data, tags_by_repository),
    ]


def main(argv: list[str] | None = None) -> int:
    args = sys.argv[1:] if argv is None else argv
    if len(args) < 2:
        print(
            "Usage: validate_builder_toml.py <builder.toml> <expected-stack-id>",
            file=sys.stderr,
        )
        return 1

    path, expected_stack_id = args[0], args[1]
    try:
        with open(path, "rb") as handle:
            data = tomllib.load(handle)
    except OSError as exc:
        print(f"Failed to read {path}: {exc}", file=sys.stderr)
        return 1
    except tomllib.TOMLDecodeError as exc:
        print(f"Failed to parse TOML: {exc}", file=sys.stderr)
        return 1

    errors = validate(data, expected_stack_id)
    for error in errors:
        print(error, file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())

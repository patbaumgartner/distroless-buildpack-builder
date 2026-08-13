#!/usr/bin/env python3
"""Unit tests for :mod:`validate_builder_toml`.

Run from the repository root:

    python3 -m unittest discover --start-directory tests/smoke
"""

from __future__ import annotations

import contextlib
import copy
import io
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from typing import Any

import tomllib

SMOKE_DIR = Path(__file__).resolve().parent
REPO_ROOT = SMOKE_DIR.parents[1]
if str(SMOKE_DIR) not in sys.path:  # allow running this file directly
    sys.path.insert(0, str(SMOKE_DIR))

import validate_builder_toml as validator

STACK_ID = "io.buildpacks.stacks.jammy"

VALID_CONFIG: dict[str, Any] = {
    "stack": {
        "id": STACK_ID,
        "build-image": "example.com/build:latest",
        "run-image": "example.com/run:latest",
    },
    "lifecycle": {"version": "0.21.7"},
    "buildpacks": [{"uri": "docker://paketobuildpacks/java:21.4.0"}],
    "order": [{"group": [{"id": "paketo-buildpacks/java", "version": "21.4.0"}]}],
}


def config(**overrides: Any) -> dict[str, Any]:
    """A valid configuration with the given top-level keys replaced."""
    data = copy.deepcopy(VALID_CONFIG)
    data.update(copy.deepcopy(overrides))
    return data


def errors_for(**overrides: Any) -> list[str]:
    return validator.validate(config(**overrides), STACK_ID)


class ParseImageRefTests(unittest.TestCase):
    def test_plain_reference(self) -> None:
        self.assertEqual(
            validator.parse_image_ref("paketobuildpacks/java:21.4.0"),
            ("paketobuildpacks/java", "21.4.0"),
        )

    def test_organisation_hyphens_are_normalized(self) -> None:
        self.assertEqual(
            validator.parse_image_ref("paketo-buildpacks/java:1.0")[0],
            "paketobuildpacks/java",
        )

    def test_buildpack_name_keeps_its_hyphens(self) -> None:
        self.assertEqual(
            validator.parse_image_ref("paketo-buildpacks/java-native-image:14.3.0"),
            ("paketobuildpacks/java-native-image", "14.3.0"),
        )

    def test_registry_host_is_stripped(self) -> None:
        self.assertEqual(
            validator.parse_image_ref("ghcr.io/paketo-buildpacks/go:4.19.7"),
            ("paketobuildpacks/go", "4.19.7"),
        )

    def test_registry_host_with_port_is_stripped(self) -> None:
        self.assertEqual(
            validator.parse_image_ref("localhost:5000/acme/bp:2.0"),
            ("acme/bp", "2.0"),
        )

    def test_digest_is_ignored_and_tag_kept(self) -> None:
        self.assertEqual(
            validator.parse_image_ref("acme/bp:2.0@sha256:" + "0" * 64),
            ("acme/bp", "2.0"),
        )

    def test_untagged_reference_has_empty_tag(self) -> None:
        self.assertEqual(validator.parse_image_ref("acme/bp"), ("acme/bp", ""))


class ValidConfigTests(unittest.TestCase):
    def test_repository_builder_toml_is_valid(self) -> None:
        """The builder.toml actually shipped by this repository must pass."""
        with open(REPO_ROOT / "builder.toml", "rb") as handle:
            data = tomllib.load(handle)
        self.assertEqual(validator.validate(data, STACK_ID), [])

    def test_minimal_configuration_has_no_errors(self) -> None:
        self.assertEqual(errors_for(), [])

    def test_hyphenated_buildpack_name_resolves(self) -> None:
        self.assertEqual(
            errors_for(
                buildpacks=[
                    {"uri": "docker://paketobuildpacks/java-native-image:14.3.0"}
                ],
                order=[
                    {
                        "group": [
                            {
                                "id": "paketo-buildpacks/java-native-image",
                                "version": "14.3.0",
                            }
                        ]
                    }
                ],
            ),
            [],
        )

    def test_registry_qualified_and_digest_pinned_uri_resolves(self) -> None:
        self.assertEqual(
            errors_for(
                buildpacks=[
                    {
                        "uri": "docker://ghcr.io/paketo-buildpacks/java:21.4.0"
                        "@sha256:" + "a" * 64
                    }
                ]
            ),
            [],
        )


class StackSectionTests(unittest.TestCase):
    def test_missing_section(self) -> None:
        data = config()
        del data["stack"]
        self.assertIn(
            "Missing or invalid [stack] section", validator.validate(data, STACK_ID)
        )

    def test_section_is_not_a_table(self) -> None:
        self.assertIn(
            "Missing or invalid [stack] section", errors_for(stack="not-a-table")
        )

    def test_missing_id(self) -> None:
        stack = dict(VALID_CONFIG["stack"])
        del stack["id"]
        self.assertIn("[stack] is missing 'id'", errors_for(stack=stack))

    def test_unexpected_id(self) -> None:
        stack = dict(VALID_CONFIG["stack"], id="io.buildpacks.stacks.bionic")
        self.assertIn(
            f"[stack] id is 'io.buildpacks.stacks.bionic', expected '{STACK_ID}'",
            errors_for(stack=stack),
        )

    def test_missing_images(self) -> None:
        errors = errors_for(stack={"id": STACK_ID})
        self.assertIn("[stack] is missing 'build-image'", errors)
        self.assertIn("[stack] is missing 'run-image'", errors)

    def test_blank_image_reference(self) -> None:
        stack = dict(VALID_CONFIG["stack"], **{"run-image": "   "})
        self.assertIn(
            "[stack] 'run-image' must be a non-empty string", errors_for(stack=stack)
        )


class LifecycleSectionTests(unittest.TestCase):
    def test_missing_section(self) -> None:
        data = config()
        del data["lifecycle"]
        self.assertIn(
            "Missing or invalid [lifecycle] section", validator.validate(data, STACK_ID)
        )

    def test_missing_version(self) -> None:
        self.assertIn("[lifecycle] is missing 'version'", errors_for(lifecycle={}))

    def test_non_string_version(self) -> None:
        self.assertIn(
            "[lifecycle] 'version' must be a non-empty string",
            errors_for(lifecycle={"version": 21}),
        )


class BuildpacksSectionTests(unittest.TestCase):
    def test_missing_section_does_not_crash_order_cross_reference(self) -> None:
        data = config()
        del data["buildpacks"]
        errors = validator.validate(data, STACK_ID)
        self.assertIn("Missing or empty [[buildpacks]] list", errors)
        self.assertIn(
            "[[order]][0].group[0] id 'paketo-buildpacks/java' "
            "has no matching [[buildpacks]] uri",
            errors,
        )

    def test_empty_list_does_not_crash_order_cross_reference(self) -> None:
        """Regression: this previously raised UnboundLocalError."""
        errors = errors_for(buildpacks=[])
        self.assertIn("Missing or empty [[buildpacks]] list", errors)
        self.assertTrue(any("has no matching [[buildpacks]] uri" in e for e in errors))

    def test_entry_is_not_a_table(self) -> None:
        self.assertIn(
            "[[buildpacks]][0] is not a table", errors_for(buildpacks=["nope"])
        )

    def test_entry_missing_uri(self) -> None:
        self.assertIn("[[buildpacks]][0] is missing 'uri'", errors_for(buildpacks=[{}]))

    def test_non_docker_uri(self) -> None:
        self.assertIn(
            "[[buildpacks]][0] uri does not start with 'docker://': "
            "urn:cnb:registry:paketo-buildpacks/java",
            errors_for(buildpacks=[{"uri": "urn:cnb:registry:paketo-buildpacks/java"}]),
        )

    def test_untagged_uri_is_rejected(self) -> None:
        self.assertIn(
            "[[buildpacks]][0] uri missing version tag: docker://paketobuildpacks/java",
            errors_for(buildpacks=[{"uri": "docker://paketobuildpacks/java"}]),
        )


class OrderSectionTests(unittest.TestCase):
    def test_missing_section(self) -> None:
        data = config()
        del data["order"]
        self.assertIn(
            "Missing or empty [[order]] list", validator.validate(data, STACK_ID)
        )

    def test_entry_is_not_a_table(self) -> None:
        self.assertIn("[[order]][0] is not a table", errors_for(order=["nope"]))

    def test_missing_group(self) -> None:
        self.assertIn(
            "[[order]][0] has no [[order.group]] entries", errors_for(order=[{}])
        )

    def test_group_entry_is_not_a_table(self) -> None:
        self.assertIn(
            "[[order]][0].group[0] is not a table", errors_for(order=[{"group": ["x"]}])
        )

    def test_group_entry_missing_id_and_version(self) -> None:
        errors = errors_for(order=[{"group": [{}]}])
        self.assertIn("[[order]][0].group[0] is missing 'id'", errors)
        self.assertIn("[[order]][0].group[0] is missing 'version'", errors)

    def test_unknown_buildpack_id(self) -> None:
        self.assertIn(
            "[[order]][0].group[0] id 'paketo-buildpacks/ruby' "
            "has no matching [[buildpacks]] uri",
            errors_for(
                order=[
                    {"group": [{"id": "paketo-buildpacks/ruby", "version": "1.1.4"}]}
                ]
            ),
        )

    def test_version_drift_between_order_and_uri(self) -> None:
        self.assertIn(
            "[[order]][0].group[0] version '21.4.1' does not match "
            "[[buildpacks]] uri tag '21.4.0' for 'paketo-buildpacks/java'",
            errors_for(
                order=[
                    {"group": [{"id": "paketo-buildpacks/java", "version": "21.4.1"}]}
                ]
            ),
        )

    def test_all_problems_are_reported_together(self) -> None:
        errors = validator.validate(
            {
                "lifecycle": {},
                "buildpacks": [],
                "order": [],
            },
            STACK_ID,
        )
        self.assertEqual(len(errors), 4, errors)


class CommandLineTests(unittest.TestCase):
    def _run(self, *args: str) -> tuple[int, str]:
        stderr = io.StringIO()
        with contextlib.redirect_stderr(stderr):
            code = validator.main(list(args))
        return code, stderr.getvalue()

    def test_too_few_arguments(self) -> None:
        code, stderr = self._run("builder.toml")
        self.assertEqual(code, 1)
        self.assertIn("Usage:", stderr)

    def test_unreadable_file(self) -> None:
        code, stderr = self._run("/nonexistent/builder.toml", STACK_ID)
        self.assertEqual(code, 1)
        self.assertIn("Failed to read", stderr)

    def test_malformed_toml(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "builder.toml"
            path.write_text("this is not = = toml\n", encoding="utf-8")
            code, stderr = self._run(str(path), STACK_ID)
        self.assertEqual(code, 1)
        self.assertIn("Failed to parse TOML", stderr)

    def test_repository_builder_toml_passes_as_a_subprocess(self) -> None:
        """The exact invocation used by tests/smoke/smoke_test.sh."""
        result = subprocess.run(
            [
                sys.executable,
                str(SMOKE_DIR / "validate_builder_toml.py"),
                str(REPO_ROOT / "builder.toml"),
                STACK_ID,
            ],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stderr, "")

    def test_invalid_file_reports_every_error_on_stderr(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "builder.toml"
            path.write_text('[lifecycle]\nversion = "0.21.7"\n', encoding="utf-8")
            code, stderr = self._run(str(path), STACK_ID)
        self.assertEqual(code, 1)
        self.assertIn("Missing or invalid [stack] section", stderr)
        self.assertIn("Missing or empty [[buildpacks]] list", stderr)
        self.assertIn("Missing or empty [[order]] list", stderr)


if __name__ == "__main__":
    unittest.main()

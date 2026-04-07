#!/usr/bin/env python3
# /// script
# requires-python = ">=3.10"
# dependencies = ["pyyaml>=6.0"]
# ///
"""Tests for switch-ops.py."""

import json
import subprocess
import sys
import tempfile
from pathlib import Path

import yaml

SCRIPT = str(Path(__file__).parent.parent / "switch-ops.py")
PASS = 0
FAIL = 0


def run(args: list[str]) -> tuple[dict, int]:
    """Run the script and return (parsed JSON output, exit code)."""
    result = subprocess.run(
        [sys.executable, SCRIPT] + args,
        capture_output=True,
        text=True,
    )
    try:
        return json.loads(result.stdout), result.returncode
    except json.JSONDecodeError:
        return {"error": result.stderr, "stdout": result.stdout}, result.returncode


def assert_eq(name: str, actual: object, expected: object) -> None:
    global PASS, FAIL
    if actual == expected:
        PASS += 1
        print(f"  ✓ {name}", file=sys.stderr)
    else:
        FAIL += 1
        print(f"  ✗ {name}: expected {expected!r}, got {actual!r}", file=sys.stderr)


def assert_true(name: str, actual: object) -> None:
    assert_eq(name, bool(actual), True)


def assert_false(name: str, actual: object) -> None:
    assert_eq(name, bool(actual), False)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


def write_index(repo: str, features: list[dict]) -> None:
    """Write a feature-index.yaml to the repo root."""
    path = Path(repo) / "feature-index.yaml"
    with open(path, "w") as f:
        yaml.dump({"features": features}, f, default_flow_style=False)


def write_feature(
    repo: str,
    domain: str,
    service: str,
    feature_id: str,
    data: dict,
) -> None:
    """Write a feature.yaml to the expected path."""
    feature_dir = Path(repo) / "features" / domain / service / feature_id
    feature_dir.mkdir(parents=True, exist_ok=True)
    with open(feature_dir / "feature.yaml", "w") as f:
        yaml.dump(data, f, default_flow_style=False, sort_keys=False)


SAMPLE_INDEX_ENTRIES = [
    {
        "id": "auth-login",
        "domain": "platform",
        "service": "identity",
        "status": "active",
        "owner": "cweber",
        "summary": "User authentication flow",
    },
    {
        "id": "user-profile",
        "domain": "platform",
        "service": "identity",
        "status": "active",
        "owner": "amelia",
        "summary": "User profile management",
    },
    {
        "id": "legacy-sso",
        "domain": "platform",
        "service": "identity",
        "status": "archived",
        "owner": "cweber",
        "summary": "Old SSO integration",
    },
]

SAMPLE_FEATURE = {
    "featureId": "auth-login",
    "name": "User Authentication",
    "domain": "platform",
    "service": "identity",
    "phase": "dev",
    "track": "quickplan",
    "priority": "high",
    "updated": "2026-03-01T10:00:00Z",
    "dependencies": {
        "depends_on": [],
        "depended_by": [],
    },
}


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------


def test_list_features():
    """List features from feature-index.yaml."""
    print("test_list_features", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        write_index(tmp, SAMPLE_INDEX_ENTRIES)

        result, code = run(["list", "--governance-repo", tmp])
        assert_eq("list status", result["status"], "pass")
        assert_eq("list exit code", code, 0)
        # Default filter: active only — 2 active entries
        assert_eq("list active count", result["total"], 2)
        ids = [f["id"] for f in result["features"]]
        assert_true("contains auth-login", "auth-login" in ids)
        assert_true("contains user-profile", "user-profile" in ids)
        assert_false("excludes archived", "legacy-sso" in ids)


def test_list_active_only_excludes_archived():
    """Active filter excludes archived features."""
    print("test_list_active_only_excludes_archived", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        write_index(tmp, SAMPLE_INDEX_ENTRIES)

        result, code = run(["list", "--governance-repo", tmp, "--status-filter", "active"])
        assert_eq("active filter status", result["status"], "pass")
        assert_eq("active count", result["total"], 2)
        for f in result["features"]:
            assert_eq(f"feature {f['id']} is active", f["status"], "active")


def test_list_all_includes_archived():
    """All filter includes archived features."""
    print("test_list_all_includes_archived", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        write_index(tmp, SAMPLE_INDEX_ENTRIES)

        result, code = run(["list", "--governance-repo", tmp, "--status-filter", "all"])
        assert_eq("all filter status", result["status"], "pass")
        assert_eq("all count", result["total"], 3)
        ids = [f["id"] for f in result["features"]]
        assert_true("includes archived", "legacy-sso" in ids)


def test_list_missing_index():
    """List fails when feature-index.yaml is absent."""
    print("test_list_missing_index", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        result, code = run(["list", "--governance-repo", tmp])
        assert_eq("missing index status", result["status"], "fail")
        assert_eq("missing index exit code", code, 1)
        assert_true("error mentions file", "feature-index.yaml" in result.get("error", ""))


def test_list_empty_index():
    """List succeeds with zero features when index has empty list."""
    print("test_list_empty_index", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        write_index(tmp, [])
        result, code = run(["list", "--governance-repo", tmp])
        assert_eq("empty index status", result["status"], "pass")
        assert_eq("empty index total", result["total"], 0)


def test_list_output_fields():
    """List output includes all required fields per feature."""
    print("test_list_output_fields", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        write_index(tmp, SAMPLE_INDEX_ENTRIES)
        result, _ = run(["list", "--governance-repo", tmp])
        for feature in result["features"]:
            for key in ("id", "domain", "service", "status", "owner", "summary"):
                assert_true(f"feature has {key}", key in feature)


def test_switch_existing_feature():
    """Switch to an existing feature validates and returns full context."""
    print("test_switch_existing_feature", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        write_index(tmp, SAMPLE_INDEX_ENTRIES)
        write_feature(tmp, "platform", "identity", "auth-login", SAMPLE_FEATURE)

        result, code = run(["switch", "--governance-repo", tmp, "--feature-id", "auth-login"])
        assert_eq("switch status", result["status"], "pass")
        assert_eq("switch exit code", code, 0)

        feat = result.get("feature", {})
        assert_eq("feature id", feat.get("id"), "auth-login")
        assert_eq("feature phase", feat.get("phase"), "dev")
        assert_eq("feature domain", feat.get("domain"), "platform")
        assert_eq("feature service", feat.get("service"), "identity")
        assert_eq("feature track", feat.get("track"), "quickplan")
        assert_eq("feature priority", feat.get("priority"), "high")
        assert_eq("feature status", feat.get("status"), "active")
        assert_eq("feature owner", feat.get("owner"), "cweber")
        assert_true("stale field present", "stale" in feat)

        ctx = result.get("context_to_load", {})
        assert_true("has summaries key", "summaries" in ctx)
        assert_true("has full_docs key", "full_docs" in ctx)


def test_switch_nonexistent_feature():
    """Switch to a nonexistent featureId returns fail and exit 1."""
    print("test_switch_nonexistent_feature", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        write_index(tmp, SAMPLE_INDEX_ENTRIES)

        result, code = run(["switch", "--governance-repo", tmp, "--feature-id", "does-not-exist"])
        assert_eq("not found status", result["status"], "fail")
        assert_eq("not found exit code", code, 1)
        assert_true("error mentions feature id", "does-not-exist" in result.get("error", ""))


def test_switch_returns_context_depends_on():
    """Switch loads full_docs paths for depends_on dependencies."""
    print("test_switch_returns_context_depends_on", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        extra_entry = {
            "id": "oauth-provider",
            "domain": "platform",
            "service": "auth",
            "status": "active",
            "owner": "cweber",
            "summary": "OAuth2 provider",
        }
        write_index(tmp, SAMPLE_INDEX_ENTRIES + [extra_entry])

        feature_with_deps = {
            **SAMPLE_FEATURE,
            "dependencies": {
                "depends_on": ["oauth-provider"],
                "depended_by": [],
            },
        }
        write_feature(tmp, "platform", "identity", "auth-login", feature_with_deps)

        result, code = run(["switch", "--governance-repo", tmp, "--feature-id", "auth-login"])
        assert_eq("switch status", result["status"], "pass")
        full_docs = result.get("context_to_load", {}).get("full_docs", [])
        assert_true(
            "full_doc for oauth-provider",
            any("oauth-provider" in p for p in full_docs),
        )
        assert_true(
            "full_doc is tech-plan",
            any("tech-plan.md" in p for p in full_docs),
        )


def test_switch_returns_context_related():
    """Switch loads summary paths for related dependencies."""
    print("test_switch_returns_context_related", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        write_index(tmp, SAMPLE_INDEX_ENTRIES)

        feature_with_related = {
            **SAMPLE_FEATURE,
            "dependencies": {
                "depends_on": [],
                "depended_by": [],
                "related": ["user-profile"],
            },
        }
        write_feature(tmp, "platform", "identity", "auth-login", feature_with_related)

        result, code = run(["switch", "--governance-repo", tmp, "--feature-id", "auth-login"])
        assert_eq("switch status", result["status"], "pass")
        summaries = result.get("context_to_load", {}).get("summaries", [])
        assert_true(
            "summary for user-profile",
            any("user-profile" in p for p in summaries),
        )
        assert_true(
            "summary is summary.md",
            any("summary.md" in p for p in summaries),
        )


def test_switch_stale_detection():
    """Switch detects stale features (updated > 30 days ago)."""
    print("test_switch_stale_detection", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        write_index(tmp, SAMPLE_INDEX_ENTRIES)

        stale_feature = {**SAMPLE_FEATURE, "updated": "2020-01-01T00:00:00Z"}
        write_feature(tmp, "platform", "identity", "auth-login", stale_feature)

        result, code = run(["switch", "--governance-repo", tmp, "--feature-id", "auth-login"])
        assert_eq("switch status", result["status"], "pass")
        assert_eq("stale is true", result["feature"]["stale"], True)


def test_switch_not_stale_recent():
    """Switch marks recently-updated features as not stale."""
    print("test_switch_not_stale_recent", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        write_index(tmp, SAMPLE_INDEX_ENTRIES)
        # Use a recent timestamp — write feature with fixed recent date
        recent_feature = {**SAMPLE_FEATURE, "updated": "2099-01-01T00:00:00Z"}
        write_feature(tmp, "platform", "identity", "auth-login", recent_feature)

        result, code = run(["switch", "--governance-repo", tmp, "--feature-id", "auth-login"])
        assert_eq("switch status", result["status"], "pass")
        assert_eq("stale is false", result["feature"]["stale"], False)


def test_context_paths_with_depends_on_and_related():
    """context-paths returns full_docs for depends_on and summaries for related."""
    print("test_context_paths_with_depends_on_and_related", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        extra_entries = [
            {
                "id": "oauth-provider",
                "domain": "platform",
                "service": "auth",
                "status": "active",
                "owner": "cweber",
                "summary": "OAuth2 provider",
            },
            {
                "id": "audit-log",
                "domain": "platform",
                "service": "compliance",
                "status": "active",
                "owner": "cweber",
                "summary": "Audit logging service",
            },
        ]
        write_index(tmp, SAMPLE_INDEX_ENTRIES + extra_entries)

        feature_data = {
            **SAMPLE_FEATURE,
            "dependencies": {
                "depends_on": ["oauth-provider"],
                "depended_by": [],
                "related": ["audit-log"],
            },
        }
        write_feature(tmp, "platform", "identity", "auth-login", feature_data)

        result, code = run([
            "context-paths",
            "--governance-repo", tmp,
            "--feature-id", "auth-login",
            "--domain", "platform",
            "--service", "identity",
        ])
        assert_eq("context-paths status", result["status"], "pass")
        assert_eq("exit code", code, 0)

        full_docs = result.get("full_docs", [])
        summaries = result.get("summaries", [])

        assert_true("full_doc for oauth-provider", any("oauth-provider" in p for p in full_docs))
        assert_true("full_doc is tech-plan", any("tech-plan.md" in p for p in full_docs))
        assert_true("summary for audit-log", any("audit-log" in p for p in summaries))
        assert_true("summary is summary.md", any("summary.md" in p for p in summaries))
        assert_false("audit-log not in full_docs", any("audit-log" in p for p in full_docs))


def test_context_paths_with_blocks():
    """context-paths returns full_docs for blocks dependencies."""
    print("test_context_paths_with_blocks", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        extra_entry = {
            "id": "user-profile",
            "domain": "platform",
            "service": "identity",
            "status": "active",
            "owner": "amelia",
            "summary": "User profile management",
        }
        write_index(tmp, [extra_entry])

        feature_data = {
            **SAMPLE_FEATURE,
            "featureId": "data-migration",
            "dependencies": {
                "depends_on": [],
                "depended_by": [],
                "blocks": ["user-profile"],
            },
        }
        write_feature(tmp, "platform", "identity", "data-migration", feature_data)

        result, code = run([
            "context-paths",
            "--governance-repo", tmp,
            "--feature-id", "data-migration",
            "--domain", "platform",
            "--service", "identity",
        ])
        assert_eq("blocks context status", result["status"], "pass")
        full_docs = result.get("full_docs", [])
        assert_true("full_doc for user-profile", any("user-profile" in p for p in full_docs))
        assert_true("full_doc is tech-plan", any("tech-plan.md" in p for p in full_docs))


def test_context_paths_no_dependencies():
    """context-paths returns empty lists when feature has no dependencies."""
    print("test_context_paths_no_dependencies", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        write_index(tmp, SAMPLE_INDEX_ENTRIES)
        write_feature(tmp, "platform", "identity", "auth-login", SAMPLE_FEATURE)

        result, code = run([
            "context-paths",
            "--governance-repo", tmp,
            "--feature-id", "auth-login",
            "--domain", "platform",
            "--service", "identity",
        ])
        assert_eq("no deps status", result["status"], "pass")
        assert_eq("no deps exit code", code, 0)
        assert_eq("summaries empty", result.get("summaries"), [])
        assert_eq("full_docs empty", result.get("full_docs"), [])


def test_context_paths_not_found():
    """context-paths returns fail when feature does not exist."""
    print("test_context_paths_not_found", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        write_index(tmp, SAMPLE_INDEX_ENTRIES)

        result, code = run([
            "context-paths",
            "--governance-repo", tmp,
            "--feature-id", "ghost-feature",
            "--domain", "platform",
            "--service", "identity",
        ])
        assert_eq("not found status", result["status"], "fail")
        assert_eq("not found exit code", code, 1)


def test_path_traversal_in_feature_id():
    """Path traversal in featureId is rejected with exit 1."""
    print("test_path_traversal_in_feature_id", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        write_index(tmp, SAMPLE_INDEX_ENTRIES)

        for evil_id in ["../../etc/passwd", "../evil", "has spaces", "CamelCase"]:
            result, code = run(["switch", "--governance-repo", tmp, "--feature-id", evil_id])
            assert_eq(f"traversal rejected ({evil_id!r}) status", result["status"], "fail")
            assert_eq(f"traversal rejected ({evil_id!r}) exit", code, 1)

        # context-paths also rejects
        result, code = run([
            "context-paths",
            "--governance-repo", tmp,
            "--feature-id", "../../etc/passwd",
            "--domain", "platform",
            "--service", "identity",
        ])
        assert_eq("context-paths traversal rejected", result["status"], "fail")
        assert_eq("context-paths traversal exit", code, 1)


def test_depends_on_not_duplicated_in_summaries():
    """Features in depends_on are in full_docs, not summaries, even if also in related."""
    print("test_depends_on_not_duplicated_in_summaries", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        extra_entry = {
            "id": "oauth-provider",
            "domain": "platform",
            "service": "auth",
            "status": "active",
            "owner": "cweber",
            "summary": "OAuth2 provider",
        }
        write_index(tmp, SAMPLE_INDEX_ENTRIES + [extra_entry])

        # oauth-provider is in both depends_on AND related — should only be in full_docs
        feature_data = {
            **SAMPLE_FEATURE,
            "dependencies": {
                "depends_on": ["oauth-provider"],
                "depended_by": [],
                "related": ["oauth-provider"],
            },
        }
        write_feature(tmp, "platform", "identity", "auth-login", feature_data)

        result, code = run([
            "context-paths",
            "--governance-repo", tmp,
            "--feature-id", "auth-login",
            "--domain", "platform",
            "--service", "identity",
        ])
        assert_eq("dedup status", result["status"], "pass")
        full_docs = result.get("full_docs", [])
        summaries = result.get("summaries", [])
        assert_true("oauth-provider in full_docs", any("oauth-provider" in p for p in full_docs))
        assert_false("oauth-provider not in summaries", any("oauth-provider" in p for p in summaries))


# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------


def main() -> None:
    test_list_features()
    test_list_active_only_excludes_archived()
    test_list_all_includes_archived()
    test_list_missing_index()
    test_list_empty_index()
    test_list_output_fields()
    test_switch_existing_feature()
    test_switch_nonexistent_feature()
    test_switch_returns_context_depends_on()
    test_switch_returns_context_related()
    test_switch_stale_detection()
    test_switch_not_stale_recent()
    test_context_paths_with_depends_on_and_related()
    test_context_paths_with_blocks()
    test_context_paths_no_dependencies()
    test_context_paths_not_found()
    test_path_traversal_in_feature_id()
    test_depends_on_not_duplicated_in_summaries()

    total = PASS + FAIL
    print(f"\n{PASS}/{total} tests passed", file=sys.stderr)

    if FAIL > 0:
        print(f"{FAIL} test(s) FAILED", file=sys.stderr)
        sys.exit(1)
    sys.exit(0)


if __name__ == "__main__":
    main()

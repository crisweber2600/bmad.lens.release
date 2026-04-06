#!/usr/bin/env python3
# /// script
# requires-python = ">=3.10"
# dependencies = ["pyyaml>=6.0"]
# ///
"""Tests for migrate-ops.py."""

import json
import subprocess
import sys
import tempfile
from pathlib import Path

import yaml

SCRIPT = str(Path(__file__).parent.parent / "migrate-ops.py")
PASS = 0
FAIL = 0


def run(args: list[str]) -> tuple[dict, int]:
    """Run the script and return parsed JSON output."""
    result = subprocess.run(
        [sys.executable, SCRIPT] + args,
        capture_output=True,
        text=True,
    )
    try:
        return json.loads(result.stdout), result.returncode
    except json.JSONDecodeError:
        return {"error": result.stderr, "stdout": result.stdout}, result.returncode


def assert_eq(name: str, actual, expected):
    global PASS, FAIL
    if actual == expected:
        PASS += 1
        print(f"  ✓ {name}", file=sys.stderr)
    else:
        FAIL += 1
        print(f"  ✗ {name}: expected {expected!r}, got {actual!r}", file=sys.stderr)


def assert_true(name: str, actual):
    assert_eq(name, bool(actual), True)


def make_branch_dir(tmp: str, branch_name: str) -> Path:
    """Create a legacy branch directory in the branches/ folder."""
    d = Path(tmp) / "branches" / branch_name
    d.mkdir(parents=True, exist_ok=True)
    return d


def test_scan_detects_legacy():
    """scan detects legacy feature directories."""
    print("test_scan_detects_legacy", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        make_branch_dir(tmp, "platform-identity-auth-login")

        result, code = run(["scan", "--governance-repo", tmp])
        assert_eq("scan status", result["status"], "pass")
        assert_eq("scan exit code", code, 0)
        assert_eq("scan total", result["total"], 1)
        assert_true("has legacy_features", len(result["legacy_features"]) == 1)


def test_scan_derives_components():
    """scan derives domain/service/featureId from old naming."""
    print("test_scan_derives_components", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        make_branch_dir(tmp, "platform-identity-auth-login")
        make_branch_dir(tmp, "platform-identity-auth-login-planning")
        make_branch_dir(tmp, "platform-identity-auth-login-dev")

        result, code = run(["scan", "--governance-repo", tmp])
        assert_eq("scan status", result["status"], "pass")
        assert_eq("total features", result["total"], 1)

        feature = result["legacy_features"][0]
        assert_eq("derived_domain", feature["derived_domain"], "platform")
        assert_eq("derived_service", feature["derived_service"], "identity")
        assert_eq("feature_id", feature["feature_id"], "auth-login")
        assert_eq("old_id", feature["old_id"], "platform-identity-auth-login")
        assert_true("has planning milestone", "planning" in feature["milestones"])
        assert_true("has dev milestone", "dev" in feature["milestones"])
        assert_eq("proposed base_branch", feature["proposed"]["base_branch"], "auth-login")
        assert_eq("proposed plan_branch", feature["proposed"]["plan_branch"], "auth-login-plan")


def test_scan_empty_branches():
    """scan returns empty plan when no branches dir exists."""
    print("test_scan_empty_branches", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        result, code = run(["scan", "--governance-repo", tmp])
        assert_eq("empty scan status", result["status"], "pass")
        assert_eq("empty scan total", result["total"], 0)
        assert_eq("empty scan exit code", code, 0)


def test_scan_multiple_features():
    """scan groups multiple features correctly."""
    print("test_scan_multiple_features", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        make_branch_dir(tmp, "platform-identity-auth-login")
        make_branch_dir(tmp, "core-api-user-mgmt")
        make_branch_dir(tmp, "core-api-user-mgmt-dev")

        result, code = run(["scan", "--governance-repo", tmp])
        assert_eq("scan status", result["status"], "pass")
        assert_eq("total features", result["total"], 2)

        ids = [f["feature_id"] for f in result["legacy_features"]]
        assert_true("has auth-login", "auth-login" in ids)
        assert_true("has user-mgmt", "user-mgmt" in ids)

        user_mgmt = next(f for f in result["legacy_features"] if f["feature_id"] == "user-mgmt")
        assert_true("user-mgmt has dev milestone", "dev" in user_mgmt["milestones"])


def test_migrate_feature_creates_yaml():
    """migrate-feature creates feature.yaml."""
    print("test_migrate_feature_creates_yaml", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        result, code = run([
            "migrate-feature",
            "--governance-repo", tmp,
            "--old-id", "platform-identity-auth-login",
            "--feature-id", "auth-login",
            "--domain", "platform",
            "--service", "identity",
            "--username", "testuser",
        ])
        assert_eq("migrate status", result["status"], "pass")
        assert_eq("migrate exit code", code, 0)
        assert_eq("feature_yaml_created", result["feature_yaml_created"], True)

        feature_path = Path(tmp) / "features" / "platform" / "identity" / "auth-login" / "feature.yaml"
        assert_eq("feature.yaml exists", feature_path.exists(), True)

        with open(feature_path) as f:
            data = yaml.safe_load(f)
        assert_eq("featureId field", data["featureId"], "auth-login")
        assert_eq("domain field", data["domain"], "platform")
        assert_eq("service field", data["service"], "identity")
        assert_eq("migrated_from field", data["migrated_from"], "platform-identity-auth-login")
        assert_eq("phase field", data["phase"], "preplan")
        assert_true("has team lead", data["team"][0]["role"] == "lead")


def test_migrate_feature_creates_index_entry():
    """migrate-feature creates feature-index.yaml entry."""
    print("test_migrate_feature_creates_index_entry", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        result, code = run([
            "migrate-feature",
            "--governance-repo", tmp,
            "--old-id", "core-api-user-mgmt",
            "--feature-id", "user-mgmt",
            "--domain", "core",
            "--service", "api",
            "--username", "testuser",
        ])
        assert_eq("migrate status", result["status"], "pass")
        assert_eq("index_updated", result["index_updated"], True)

        index_path = Path(tmp) / "feature-index.yaml"
        assert_eq("feature-index.yaml exists", index_path.exists(), True)

        with open(index_path) as f:
            index = yaml.safe_load(f)

        feature_ids = [e["featureId"] for e in index.get("features", [])]
        assert_true("feature in index", "user-mgmt" in feature_ids)

        entry = next(e for e in index["features"] if e["featureId"] == "user-mgmt")
        assert_eq("index entry domain", entry["domain"], "core")
        assert_eq("index entry migrated_from", entry["migrated_from"], "core-api-user-mgmt")


def test_migrate_feature_dry_run():
    """migrate-feature dry-run makes no changes."""
    print("test_migrate_feature_dry_run", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        result, code = run([
            "migrate-feature",
            "--governance-repo", tmp,
            "--old-id", "platform-identity-auth-login",
            "--feature-id", "auth-login",
            "--domain", "platform",
            "--service", "identity",
            "--username", "testuser",
            "--dry-run",
        ])
        assert_eq("dry_run status", result["status"], "pass")
        assert_eq("dry_run flag", result["dry_run"], True)
        assert_eq("dry_run no yaml created", result["feature_yaml_created"], False)
        assert_eq("dry_run no index updated", result["index_updated"], False)
        assert_true("planned_actions present", len(result.get("planned_actions", [])) > 0)

        feature_path = Path(tmp) / "features" / "platform" / "identity" / "auth-login" / "feature.yaml"
        assert_eq("feature.yaml not created in dry run", feature_path.exists(), False)

        index_path = Path(tmp) / "feature-index.yaml"
        assert_eq("index not created in dry run", index_path.exists(), False)


def test_check_conflicts_no_conflict():
    """check-conflicts returns pass when target path is free."""
    print("test_check_conflicts_no_conflict", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        result, code = run([
            "check-conflicts",
            "--governance-repo", tmp,
            "--feature-id", "auth-login",
            "--domain", "platform",
            "--service", "identity",
        ])
        assert_eq("no conflict status", result["status"], "pass")
        assert_eq("conflict false", result["conflict"], False)
        assert_eq("exit code 0", code, 0)


def test_check_conflicts_conflict():
    """check-conflicts returns conflict when target path exists."""
    print("test_check_conflicts_conflict", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        feature_dir = Path(tmp) / "features" / "platform" / "identity" / "auth-login"
        feature_dir.mkdir(parents=True)
        with open(feature_dir / "feature.yaml", "w") as f:
            yaml.dump({"featureId": "auth-login"}, f)

        result, code = run([
            "check-conflicts",
            "--governance-repo", tmp,
            "--feature-id", "auth-login",
            "--domain", "platform",
            "--service", "identity",
        ])
        assert_eq("conflict status", result["status"], "conflict")
        assert_eq("conflict true", result["conflict"], True)
        assert_true("existing_path set", bool(result.get("existing_path")))
        assert_eq("conflict exit code", code, 0)


def test_invalid_feature_id():
    """Invalid feature-id slug is rejected with exit code 1."""
    print("test_invalid_feature_id", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        result, code = run([
            "migrate-feature",
            "--governance-repo", tmp,
            "--old-id", "platform-identity-auth-login",
            "--feature-id", "Auth_Login!",
            "--domain", "platform",
            "--service", "identity",
            "--username", "testuser",
        ])
        assert_eq("invalid id status", result["status"], "fail")
        assert_eq("invalid id exit code", code, 1)
        assert_true("error mentions Invalid", "Invalid" in result.get("error", ""))


def test_invalid_domain():
    """Invalid domain (path traversal) is rejected."""
    print("test_invalid_domain", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        result, code = run([
            "migrate-feature",
            "--governance-repo", tmp,
            "--old-id", "platform-identity-auth-login",
            "--feature-id", "auth-login",
            "--domain", "../evil",
            "--service", "identity",
            "--username", "testuser",
        ])
        assert_eq("invalid domain status", result["status"], "fail")
        assert_eq("invalid domain exit code", code, 1)


def test_governance_repo_not_found():
    """Governance repo not found causes exit code 1."""
    print("test_governance_repo_not_found", file=sys.stderr)
    result, code = run([
        "scan",
        "--governance-repo", "/nonexistent/path/to/repo/xyz123",
    ])
    assert_eq("missing repo exit code", code, 1)


def test_governance_repo_not_found_migrate():
    """Governance repo not found on migrate-feature causes exit code 1."""
    print("test_governance_repo_not_found_migrate", file=sys.stderr)
    result, code = run([
        "migrate-feature",
        "--governance-repo", "/nonexistent/path/xyz123",
        "--old-id", "platform-identity-auth",
        "--feature-id", "auth",
        "--domain", "platform",
        "--service", "identity",
        "--username", "testuser",
    ])
    assert_eq("missing repo exit code (migrate)", code, 1)


def test_scan_detects_conflict():
    """scan surfaces conflict when new-model feature.yaml already exists."""
    print("test_scan_detects_conflict", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        make_branch_dir(tmp, "platform-identity-auth-login")

        # Pre-create the target feature.yaml
        feature_dir = Path(tmp) / "features" / "platform" / "identity" / "auth-login"
        feature_dir.mkdir(parents=True)
        with open(feature_dir / "feature.yaml", "w") as f:
            yaml.dump({"featureId": "auth-login"}, f)

        result, code = run(["scan", "--governance-repo", tmp])
        assert_eq("scan with conflict status", result["status"], "pass")
        assert_eq("conflicts detected", len(result["conflicts"]), 1)
        assert_eq("conflict old_id", result["conflicts"][0]["old_id"], "platform-identity-auth-login")


if __name__ == "__main__":
    test_scan_detects_legacy()
    test_scan_derives_components()
    test_scan_empty_branches()
    test_scan_multiple_features()
    test_migrate_feature_creates_yaml()
    test_migrate_feature_creates_index_entry()
    test_migrate_feature_dry_run()
    test_check_conflicts_no_conflict()
    test_check_conflicts_conflict()
    test_invalid_feature_id()
    test_invalid_domain()
    test_governance_repo_not_found()
    test_governance_repo_not_found_migrate()
    test_scan_detects_conflict()

    print(f"\n{'='*40}", file=sys.stderr)
    print(f"Results: {PASS} passed, {FAIL} failed", file=sys.stderr)
    print(f"{'='*40}", file=sys.stderr)
    sys.exit(1 if FAIL > 0 else 0)

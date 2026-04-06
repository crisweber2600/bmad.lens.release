#!/usr/bin/env python3
# /// script
# requires-python = ">=3.10"
# dependencies = ["pyyaml>=6.0"]
# ///
"""Tests for status-ops.py."""

import json
import subprocess
import sys
import tempfile
from pathlib import Path

import yaml

SCRIPT = str(Path(__file__).parent.parent / "status-ops.py")
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


def make_feature_yaml(tmp: str, domain: str, service: str, feature_id: str, **kwargs) -> Path:
    """Create a feature.yaml for testing."""
    feature_dir = Path(tmp) / "features" / domain / service / feature_id
    feature_dir.mkdir(parents=True, exist_ok=True)
    data = {
        "featureId": feature_id,
        "name": kwargs.get("name", "Test Feature"),
        "domain": domain,
        "service": service,
        "phase": kwargs.get("phase", "dev"),
        "track": kwargs.get("track", "quickplan"),
        "priority": kwargs.get("priority", "medium"),
        "team": kwargs.get("team", [{"username": "testuser", "role": "lead"}]),
        "updated": kwargs.get("updated", "2026-04-01T10:00:00Z"),
        "context": {
            "stale": kwargs.get("stale", False),
            "last_pulled": None,
        },
    }
    path = feature_dir / "feature.yaml"
    with open(path, "w") as f:
        yaml.dump(data, f)
    return path


def make_feature_index(tmp: str, features: list[dict]) -> Path:
    """Create a feature-index.yaml at the governance repo root for testing."""
    index_path = Path(tmp) / "feature-index.yaml"
    with open(index_path, "w") as f:
        yaml.dump({"features": features}, f)
    return index_path


# ─────────────────────────────────────────────
# Tests: feature subcommand
# ─────────────────────────────────────────────

def test_feature_existing():
    print("test_feature_existing", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        make_feature_yaml(
            tmp, "platform", "identity", "auth-login",
            name="Auth Login", phase="dev", stale=True,
            team=[{"username": "alice", "role": "lead"}],
        )
        result, code = run([
            "feature",
            "--governance-repo", tmp,
            "--feature-id", "auth-login",
            "--domain", "platform",
            "--service", "identity",
        ])
        assert_eq("exit code", code, 0)
        assert_eq("status", result["status"], "pass")
        assert_eq("feature id", result["feature"]["id"], "auth-login")
        assert_eq("phase", result["feature"]["phase"], "dev")
        assert_eq("track", result["feature"]["track"], "quickplan")
        assert_eq("stale true", result["feature"]["stale"], True)
        assert_true("team present", len(result["feature"]["team"]) > 0)
        assert_eq("team lead", result["feature"]["team"][0]["role"], "lead")
        assert_eq("updated_at", result["feature"]["updated_at"], "2026-04-01T10:00:00Z")


def test_feature_not_found():
    print("test_feature_not_found", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        result, code = run([
            "feature",
            "--governance-repo", tmp,
            "--feature-id", "missing-feature",
            "--domain", "platform",
            "--service", "identity",
        ])
        assert_eq("exit code", code, 1)
        assert_eq("status fail", result["status"], "fail")
        assert_true("error message present", result.get("error"))


def test_feature_invalid_id_path_traversal():
    print("test_feature_invalid_id_path_traversal", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        result, code = run([
            "feature",
            "--governance-repo", tmp,
            "--feature-id", "../../../etc/passwd",
            "--domain", "platform",
            "--service", "identity",
        ])
        assert_eq("exit code", code, 1)
        assert_eq("status fail", result["status"], "fail")
        assert_true("error mentions Invalid", "Invalid" in result.get("error", ""))


# ─────────────────────────────────────────────
# Tests: domain subcommand
# ─────────────────────────────────────────────

def test_domain_multiple_features():
    print("test_domain_multiple_features", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        make_feature_index(tmp, [
            {
                "featureId": "auth-login", "domain": "platform", "service": "identity",
                "status": "active", "owner": "alice", "summary": "Auth feature",
                "phase": "dev", "stale": False,
            },
            {
                "featureId": "auth-mfa", "domain": "platform", "service": "identity",
                "status": "active", "owner": "bob", "summary": "MFA feature",
                "phase": "techplan", "stale": True,
            },
            {
                "featureId": "billing-v2", "domain": "payments", "service": "core",
                "status": "active", "owner": "carol", "summary": "Billing",
                "phase": "dev", "stale": False,
            },
        ])
        result, code = run([
            "domain",
            "--governance-repo", tmp,
            "--domain", "platform",
        ])
        assert_eq("exit code", code, 0)
        assert_eq("status", result["status"], "pass")
        assert_eq("domain name", result["domain"], "platform")
        assert_eq("total", result["total"], 2)
        assert_eq("feature count", len(result["features"]), 2)
        ids = {f["id"] for f in result["features"]}
        assert_eq("correct ids", ids, {"auth-login", "auth-mfa"})
        # Verify billing-v2 (different domain) is excluded
        assert_eq("billing excluded", "billing-v2" not in ids, True)


def test_domain_no_features():
    print("test_domain_no_features", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        make_feature_index(tmp, [
            {
                "featureId": "billing-v2", "domain": "payments", "service": "core",
                "status": "active", "owner": "carol", "summary": "Billing",
                "phase": "dev", "stale": False,
            },
        ])
        result, code = run([
            "domain",
            "--governance-repo", tmp,
            "--domain", "empty-domain",
        ])
        assert_eq("exit code", code, 0)
        assert_eq("status pass", result["status"], "pass")
        assert_eq("total zero", result["total"], 0)
        assert_eq("empty list", result["features"], [])


# ─────────────────────────────────────────────
# Tests: portfolio subcommand
# ─────────────────────────────────────────────

def test_portfolio_all_features():
    print("test_portfolio_all_features", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        make_feature_index(tmp, [
            {
                "featureId": "feat-a", "domain": "p", "service": "s",
                "status": "active", "owner": "alice", "summary": "A",
                "phase": "dev", "stale": False,
            },
            {
                "featureId": "feat-b", "domain": "p", "service": "s",
                "status": "archived", "owner": "bob", "summary": "B",
                "phase": "complete", "stale": False,
            },
        ])
        result, code = run([
            "portfolio",
            "--governance-repo", tmp,
            "--status-filter", "all",
        ])
        assert_eq("exit code", code, 0)
        assert_eq("status", result["status"], "pass")
        assert_eq("total all", result["total"], 2)
        ids = {f["id"] for f in result["features"]}
        assert_eq("both included", ids, {"feat-a", "feat-b"})


def test_portfolio_active_excludes_archived():
    print("test_portfolio_active_excludes_archived", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        make_feature_index(tmp, [
            {
                "featureId": "feat-active", "domain": "p", "service": "s",
                "status": "active", "owner": "alice", "summary": "Active",
                "phase": "dev", "stale": False,
            },
            {
                "featureId": "feat-paused", "domain": "p", "service": "s",
                "status": "paused", "owner": "alice", "summary": "Paused",
                "phase": "dev", "stale": False,
            },
            {
                "featureId": "feat-archived", "domain": "p", "service": "s",
                "status": "archived", "owner": "bob", "summary": "Done",
                "phase": "complete", "stale": False,
            },
        ])
        result, code = run([
            "portfolio",
            "--governance-repo", tmp,
        ])
        assert_eq("exit code", code, 0)
        assert_eq("status", result["status"], "pass")
        assert_eq("excludes archived", result["total"], 2)
        ids = {f["id"] for f in result["features"]}
        assert_eq("active and paused included", ids, {"feat-active", "feat-paused"})
        assert_eq("archived excluded", "feat-archived" not in ids, True)


def test_portfolio_stale_count():
    print("test_portfolio_stale_count", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        make_feature_index(tmp, [
            {
                "featureId": "feat-1", "domain": "p", "service": "s",
                "status": "active", "owner": "alice", "summary": "F1",
                "phase": "dev", "stale": True,
            },
            {
                "featureId": "feat-2", "domain": "p", "service": "s",
                "status": "active", "owner": "bob", "summary": "F2",
                "phase": "dev", "stale": True,
            },
            {
                "featureId": "feat-3", "domain": "p", "service": "s",
                "status": "active", "owner": "carol", "summary": "F3",
                "phase": "dev", "stale": False,
            },
        ])
        result, code = run([
            "portfolio",
            "--governance-repo", tmp,
        ])
        assert_eq("exit code", code, 0)
        assert_eq("status", result["status"], "pass")
        assert_eq("total", result["total"], 3)
        assert_eq("stale count", result["stale_count"], 2)


def test_feature_index_missing():
    print("test_feature_index_missing", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        # No feature-index.yaml — governance repo not initialized
        result, code = run([
            "portfolio",
            "--governance-repo", tmp,
        ])
        assert_eq("exit code", code, 1)
        assert_eq("status fail", result["status"], "fail")
        assert_true("error mentions feature-index.yaml", "feature-index.yaml" in result.get("error", ""))


def main():
    test_feature_existing()
    test_feature_not_found()
    test_feature_invalid_id_path_traversal()
    test_domain_multiple_features()
    test_domain_no_features()
    test_portfolio_all_features()
    test_portfolio_active_excludes_archived()
    test_portfolio_stale_count()
    test_feature_index_missing()

    print(f"\n{'=' * 40}", file=sys.stderr)
    total = PASS + FAIL
    print(f"Results: {PASS}/{total} passed", file=sys.stderr)
    if FAIL > 0:
        print(f"FAILED: {FAIL} test(s)", file=sys.stderr)
        sys.exit(1)
    else:
        print("All tests passed.", file=sys.stderr)


if __name__ == "__main__":
    main()

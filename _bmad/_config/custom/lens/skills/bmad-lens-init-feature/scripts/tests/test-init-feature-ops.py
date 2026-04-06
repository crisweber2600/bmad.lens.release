#!/usr/bin/env python3
# /// script
# requires-python = ">=3.10"
# dependencies = ["pyyaml>=6.0"]
# ///
"""Tests for init-feature-ops.py."""

import json
import subprocess
import sys
import tempfile
from pathlib import Path

import yaml

SCRIPT = str(Path(__file__).parent.parent / "init-feature-ops.py")
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


def test_create_feature():
    """Valid feature creation creates feature.yaml, updates feature-index.yaml, creates summary.md."""
    print("test_create_feature", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        result, code = run([
            "create",
            "--governance-repo", tmp,
            "--feature-id", "auth-refresh",
            "--domain", "platform",
            "--service", "identity",
            "--name", "Auth Token Refresh",
            "--track", "quickplan",
            "--username", "cweber",
        ])
        assert_eq("create status", result.get("status"), "pass")
        assert_eq("create exit code", code, 0)
        assert_eq("featureId in result", result.get("featureId"), "auth-refresh")
        assert_eq("index_updated", result.get("index_updated"), True)
        assert_true("feature_yaml_path in result", result.get("feature_yaml_path"))
        assert_true("summary_path in result", result.get("summary_path"))
        assert_true("git_commands non-empty", len(result.get("git_commands", [])) > 0)
        assert_true("gh_commands non-empty", len(result.get("gh_commands", [])) > 0)

        feature_yaml = Path(tmp) / "features" / "platform" / "identity" / "auth-refresh" / "feature.yaml"
        assert_eq("feature.yaml exists", feature_yaml.exists(), True)

        with open(feature_yaml) as f:
            data = yaml.safe_load(f)
        assert_eq("featureId in yaml", data.get("featureId"), "auth-refresh")
        assert_eq("domain in yaml", data.get("domain"), "platform")
        assert_eq("service in yaml", data.get("service"), "identity")
        assert_eq("phase in yaml", data.get("phase"), "preplan")
        assert_eq("track in yaml", data.get("track"), "quickplan")
        assert_eq("team lead", data.get("team", [{}])[0].get("role"), "lead")
        assert_eq("team username", data.get("team", [{}])[0].get("username"), "cweber")

        index_path = Path(tmp) / "feature-index.yaml"
        assert_eq("feature-index.yaml exists", index_path.exists(), True)

        with open(index_path) as f:
            idx = yaml.safe_load(f)
        ids = [e.get("id") for e in idx.get("features", [])]
        assert_true("auth-refresh in index", "auth-refresh" in ids)

        entry = next(e for e in idx["features"] if e["id"] == "auth-refresh")
        assert_eq("index entry domain", entry.get("domain"), "platform")
        assert_eq("index entry service", entry.get("service"), "identity")
        assert_eq("index entry status", entry.get("status"), "preplan")
        assert_eq("index entry owner", entry.get("owner"), "cweber")
        assert_eq("index entry plan_branch", entry.get("plan_branch"), "auth-refresh-plan")

        summary_path = Path(tmp) / "features" / "platform" / "identity" / "auth-refresh" / "summary.md"
        assert_eq("summary.md exists", summary_path.exists(), True)
        summary_text = summary_path.read_text()
        assert_true("summary contains feature name", "Auth Token Refresh" in summary_text)
        assert_true("summary contains featureId", "auth-refresh" in summary_text)


def test_index_created_when_missing():
    """feature-index.yaml is created when it does not exist."""
    print("test_index_created_when_missing", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        index_path = Path(tmp) / "feature-index.yaml"
        assert_eq("index absent before create", index_path.exists(), False)

        result, code = run([
            "create",
            "--governance-repo", tmp,
            "--feature-id", "new-feature",
            "--domain", "core",
            "--service", "api",
            "--name", "New Feature",
            "--username", "testuser",
        ])
        assert_eq("create status", result.get("status"), "pass")
        assert_eq("index now exists", index_path.exists(), True)

        with open(index_path) as f:
            idx = yaml.safe_load(f)
        assert_eq("index has one entry", len(idx.get("features", [])), 1)


def test_dry_run():
    """Dry run returns planned operations but creates no files."""
    print("test_dry_run", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        result, code = run([
            "create",
            "--governance-repo", tmp,
            "--feature-id", "dry-feature",
            "--domain", "platform",
            "--service", "identity",
            "--name", "Dry Feature",
            "--username", "cweber",
            "--dry-run",
        ])
        assert_eq("dry run status", result.get("status"), "pass")
        assert_eq("dry run flag in result", result.get("dry_run"), True)
        assert_eq("dry run exit code", code, 0)
        assert_true("git_commands present", len(result.get("git_commands", [])) > 0)
        assert_true("gh_commands present", len(result.get("gh_commands", [])) > 0)

        feature_yaml = Path(tmp) / "features" / "platform" / "identity" / "dry-feature" / "feature.yaml"
        assert_eq("feature.yaml not created", feature_yaml.exists(), False)

        index_path = Path(tmp) / "feature-index.yaml"
        assert_eq("index not created", index_path.exists(), False)


def test_invalid_feature_id():
    """Non-kebab-case and path-traversal featureIds are rejected."""
    print("test_invalid_feature_id", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        base = [
            "--governance-repo", tmp,
            "--domain", "core",
            "--service", "api",
            "--name", "Bad",
            "--username", "testuser",
        ]

        result, code = run(["create", "--feature-id", "../../etc/passwd"] + base)
        assert_eq("path traversal rejected", result.get("status"), "fail")
        assert_eq("path traversal exit code", code, 1)
        assert_true("error mentions Invalid", "Invalid" in result.get("error", ""))

        result, code = run(["create", "--feature-id", "CamelCase"] + base)
        assert_eq("uppercase rejected", result.get("status"), "fail")

        result, code = run(["create", "--feature-id", "has spaces"] + base)
        assert_eq("spaces rejected", result.get("status"), "fail")

        result, code = run(["create", "--feature-id", "auth.login_v2"] + base)
        assert_eq("dots/underscores rejected (stricter pattern)", result.get("status"), "fail")

        result, code = run(["create", "--feature-id", "valid-id-123"] + base)
        assert_eq("valid kebab accepted", result.get("status"), "pass")


def test_invalid_domain_service():
    """Path traversal in domain or service is rejected."""
    print("test_invalid_domain_service", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        result, code = run([
            "create",
            "--governance-repo", tmp,
            "--feature-id", "good-id",
            "--domain", "../evil",
            "--service", "api",
            "--name", "Bad",
            "--username", "testuser",
        ])
        assert_eq("bad domain rejected", result.get("status"), "fail")
        assert_eq("bad domain exit code", code, 1)

        result, code = run([
            "create",
            "--governance-repo", tmp,
            "--feature-id", "good-id2",
            "--domain", "core",
            "--service", "../../etc",
            "--name", "Bad",
            "--username", "testuser",
        ])
        assert_eq("bad service rejected", result.get("status"), "fail")


def test_duplicate_feature():
    """Creating a feature whose ID already exists in feature-index.yaml fails."""
    print("test_duplicate_feature", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        args = [
            "create",
            "--governance-repo", tmp,
            "--feature-id", "dup-check",
            "--domain", "platform",
            "--service", "identity",
            "--name", "Dup Check",
            "--username", "cweber",
        ]
        first, code1 = run(args)
        assert_eq("first create passes", first.get("status"), "pass")
        assert_eq("first create exit code", code1, 0)

        second, code2 = run(args)
        assert_eq("duplicate rejected", second.get("status"), "fail")
        assert_eq("duplicate exit code", code2, 1)
        assert_true("error mentions already exists", "already exists" in second.get("error", ""))


def test_missing_required_args():
    """Missing required args cause non-zero exit without valid JSON."""
    print("test_missing_required_args", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        result, code = run([
            "create",
            "--governance-repo", tmp,
            "--feature-id", "incomplete",
            # missing --domain, --service, --name, --username
        ])
        assert_true("missing args fails", code != 0)

        result, code = run([
            "create",
            "--governance-repo", tmp,
            "--domain", "platform",
            "--service", "identity",
            "--name", "No ID",
            "--username", "cweber",
            # missing --feature-id
        ])
        assert_true("missing feature-id fails", code != 0)


def test_fetch_context_with_existing_index():
    """fetch-context returns related features and depends_on paths."""
    print("test_fetch_context_with_existing_index", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        for fid, domain, service in [
            ("auth-login", "platform", "identity"),
            ("auth-refresh", "platform", "identity"),
            ("payment-api", "commerce", "payments"),
        ]:
            run([
                "create",
                "--governance-repo", tmp,
                "--feature-id", fid,
                "--domain", domain,
                "--service", service,
                "--name", fid.replace("-", " ").title(),
                "--username", "cweber",
            ])

        result, code = run([
            "fetch-context",
            "--governance-repo", tmp,
            "--feature-id", "auth-login",
        ])
        assert_eq("fetch-context status", result.get("status"), "pass")
        assert_eq("fetch-context exit code", code, 0)
        assert_true("related list present", "related" in result)
        assert_true("depends_on list present", "depends_on" in result)
        assert_true("context_paths present", "context_paths" in result)

        related = result.get("related", [])
        assert_true("auth-refresh in related (same domain)", "auth-refresh" in related)
        assert_true("payment-api not in related (diff domain)", "payment-api" not in related)
        assert_true("auth-login not in own related list", "auth-login" not in related)

        context_paths = result.get("context_paths", [])
        assert_true("context paths are summary.md (summaries depth)", all("summary.md" in p for p in context_paths))


def test_fetch_context_full_depth():
    """fetch-context --depth full returns feature.yaml paths for related features."""
    print("test_fetch_context_full_depth", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        for fid in ["feat-a", "feat-b"]:
            run([
                "create",
                "--governance-repo", tmp,
                "--feature-id", fid,
                "--domain", "core",
                "--service", "svc",
                "--name", fid.replace("-", " ").title(),
                "--username", "cweber",
            ])

        result, code = run([
            "fetch-context",
            "--governance-repo", tmp,
            "--feature-id", "feat-a",
            "--depth", "full",
        ])
        assert_eq("full depth status", result.get("status"), "pass")
        context_paths = result.get("context_paths", [])
        assert_true("full depth returns feature.yaml paths", all("feature.yaml" in p for p in context_paths))


def test_fetch_context_feature_not_found():
    """fetch-context fails when the featureId is not in the index."""
    print("test_fetch_context_feature_not_found", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        run([
            "create",
            "--governance-repo", tmp,
            "--feature-id", "some-feature",
            "--domain", "core",
            "--service", "api",
            "--name", "Some Feature",
            "--username", "cweber",
        ])

        result, code = run([
            "fetch-context",
            "--governance-repo", tmp,
            "--feature-id", "nonexistent",
        ])
        assert_eq("not found status", result.get("status"), "fail")
        assert_eq("not found exit code", code, 1)


def test_fetch_context_no_index():
    """fetch-context fails gracefully when feature-index.yaml is absent."""
    print("test_fetch_context_no_index", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        result, code = run([
            "fetch-context",
            "--governance-repo", tmp,
            "--feature-id", "any-feature",
        ])
        assert_eq("no index status", result.get("status"), "fail")
        assert_eq("no index exit code", code, 1)


def test_control_repo_git_commands():
    """When control-repo differs from governance-repo, git commands include both repos."""
    print("test_control_repo_git_commands", file=sys.stderr)
    with tempfile.TemporaryDirectory() as gov_tmp:
        with tempfile.TemporaryDirectory() as ctrl_tmp:
            result, code = run([
                "create",
                "--governance-repo", gov_tmp,
                "--control-repo", ctrl_tmp,
                "--feature-id", "ctrl-test",
                "--domain", "platform",
                "--service", "svc",
                "--name", "Control Repo Test",
                "--username", "cweber",
                "--dry-run",
            ])
            assert_eq("ctrl repo dry run status", result.get("status"), "pass")
            git_cmds = result.get("git_commands", [])
            assert_true(
                "ctrl repo checkout in git commands",
                any(ctrl_tmp in c for c in git_cmds),
            )
            assert_true(
                "gov repo checkout in git commands",
                any(gov_tmp in c for c in git_cmds),
            )
            assert_true(
                "plan branch created in ctrl repo",
                any("ctrl-test-plan" in c and ctrl_tmp in c for c in git_cmds),
            )


if __name__ == "__main__":
    test_create_feature()
    test_index_created_when_missing()
    test_dry_run()
    test_invalid_feature_id()
    test_invalid_domain_service()
    test_duplicate_feature()
    test_missing_required_args()
    test_fetch_context_with_existing_index()
    test_fetch_context_full_depth()
    test_fetch_context_feature_not_found()
    test_fetch_context_no_index()
    test_control_repo_git_commands()

    print(f"\nResults: {PASS} passed, {FAIL} failed", file=sys.stderr)
    sys.exit(1 if FAIL > 0 else 0)

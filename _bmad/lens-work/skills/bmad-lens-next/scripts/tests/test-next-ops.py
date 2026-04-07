#!/usr/bin/env python3
# /// script
# requires-python = ">=3.10"
# dependencies = ["pyyaml>=6.0"]
# ///
"""Tests for next-ops.py."""

import json
import subprocess
import sys
import tempfile
from pathlib import Path

import yaml

SCRIPT = str(Path(__file__).parent.parent / "next-ops.py")
PASS = 0
FAIL = 0


def run(args: list[str]) -> tuple[dict, int]:
    """Run the script and return (parsed JSON, exit code)."""
    result = subprocess.run(
        [sys.executable, SCRIPT] + args,
        capture_output=True,
        text=True,
    )
    try:
        return json.loads(result.stdout), result.returncode
    except json.JSONDecodeError:
        return {"error": result.stderr, "stdout": result.stdout}, result.returncode


def assert_eq(name: str, actual, expected) -> None:
    global PASS, FAIL
    if actual == expected:
        PASS += 1
        print(f"  ✓ {name}", file=sys.stderr)
    else:
        FAIL += 1
        print(f"  ✗ {name}: expected {expected!r}, got {actual!r}", file=sys.stderr)


def assert_true(name: str, actual) -> None:
    assert_eq(name, bool(actual), True)


def make_feature(
    tmp: str,
    feature_id: str,
    phase: str = "preplan",
    track: str = "quickplan",
    extra: dict | None = None,
) -> Path:
    """Write a minimal feature.yaml into the temp governance repo."""
    domain = "core"
    service = "api"
    feature_dir = Path(tmp) / "features" / domain / service / feature_id
    feature_dir.mkdir(parents=True, exist_ok=True)
    data: dict = {
        "featureId": feature_id,
        "name": f"Test {feature_id}",
        "description": "",
        "domain": domain,
        "service": service,
        "phase": phase,
        "track": track,
        "milestones": {
            "businessplan": None,
            "techplan": None,
            "sprintplan": None,
            "dev-ready": None,
            "dev-complete": None,
        },
        "team": [{"username": "testuser", "role": "lead"}],
        "dependencies": {"depends_on": [], "depended_by": []},
        "target_repos": [],
        "links": {"retrospective": None, "issues": [], "pull_request": None},
        "priority": "medium",
        "created": "2026-04-06T00:00:00Z",
        "updated": "2026-04-06T00:00:00Z",
        "phase_transitions": [{"phase": "preplan", "timestamp": "2026-04-06T00:00:00Z", "user": "testuser"}],
    }
    if extra:
        data.update(extra)
    with open(feature_dir / "feature.yaml", "w") as f:
        yaml.dump(data, f, default_flow_style=False, sort_keys=False)
    return feature_dir / "feature.yaml"


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------


def test_preplan_phase():
    """Preplan phase → recommends quickplan."""
    print("test_preplan_phase", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        make_feature(tmp, "preplan-feat", phase="preplan")
        result, code = run(["suggest", "--governance-repo", tmp, "--feature-id", "preplan-feat"])
        assert_eq("status pass", result["status"], "pass")
        assert_eq("exit code 0", code, 0)
        assert_eq("action quickplan", result["recommendation"]["action"], "quickplan")
        assert_eq("command", result["recommendation"]["command"], "/quickplan")
        assert_eq("no blockers", result["recommendation"]["blockers"], [])


def test_dev_phase():
    """Dev phase → recommends dev-next-story."""
    print("test_dev_phase", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        make_feature(
            tmp,
            "dev-feat",
            phase="dev",
            extra={
                "milestones": {
                    "businessplan": "2026-04-01T00:00:00Z",
                    "techplan": "2026-04-02T00:00:00Z",
                    "sprintplan": "2026-04-03T00:00:00Z",
                    "dev-ready": None,
                    "dev-complete": None,
                }
            },
        )
        result, code = run(["suggest", "--governance-repo", tmp, "--feature-id", "dev-feat"])
        assert_eq("status pass", result["status"], "pass")
        assert_eq("exit code 0", code, 0)
        assert_eq("action dev-next-story", result["recommendation"]["action"], "dev-next-story")
        assert_eq("command", result["recommendation"]["command"], "/dev-story")
        assert_eq("phase in output", result["phase"], "dev")


def test_complete_phase():
    """Complete phase → recommends retrospective."""
    print("test_complete_phase", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        make_feature(
            tmp,
            "done-feat",
            phase="complete",
            extra={
                "milestones": {
                    "businessplan": "2026-04-01T00:00:00Z",
                    "techplan": "2026-04-02T00:00:00Z",
                    "sprintplan": "2026-04-03T00:00:00Z",
                    "dev-ready": "2026-04-04T00:00:00Z",
                    "dev-complete": "2026-04-05T00:00:00Z",
                }
            },
        )
        result, code = run(["suggest", "--governance-repo", tmp, "--feature-id", "done-feat"])
        assert_eq("status pass", result["status"], "pass")
        assert_eq("exit code 0", code, 0)
        assert_eq("action retrospective", result["recommendation"]["action"], "retrospective")
        assert_eq("command", result["recommendation"]["command"], "/retrospective")
        assert_eq("no blockers", result["recommendation"]["blockers"], [])


def test_stale_context_warning():
    """context.stale=true → warning included in recommendation."""
    print("test_stale_context_warning", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        make_feature(tmp, "stale-feat", phase="preplan", extra={"context": {"stale": True}})
        result, code = run(["suggest", "--governance-repo", tmp, "--feature-id", "stale-feat"])
        assert_eq("status pass", result["status"], "pass")
        assert_eq("exit code 0", code, 0)
        warnings = result["recommendation"]["warnings"]
        assert_true("stale warning present", any("context.stale" in w for w in warnings))


def test_feature_not_found():
    """Feature not found → status=fail, exit code 1."""
    print("test_feature_not_found", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        result, code = run(["suggest", "--governance-repo", tmp, "--feature-id", "ghost-feat"])
        assert_eq("status fail", result["status"], "fail")
        assert_eq("exit code 1", code, 1)
        assert_true("error message", "ghost-feat" in result.get("error", ""))


def test_path_traversal_rejected():
    """Path-traversal feature-id → status=fail, exit code 1."""
    print("test_path_traversal_rejected", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        result, code = run(["suggest", "--governance-repo", tmp, "--feature-id", "../etc/passwd"])
        assert_eq("status fail", result["status"], "fail")
        assert_eq("exit code 1", code, 1)
        assert_true("error message", "Invalid feature-id" in result.get("error", ""))


def test_valid_action_command_returned():
    """Dev phase returns a valid non-empty command string."""
    print("test_valid_action_command_returned", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        make_feature(
            tmp,
            "cmd-feat",
            phase="dev",
            extra={
                "milestones": {
                    "businessplan": "2026-04-01T00:00:00Z",
                    "techplan": "2026-04-02T00:00:00Z",
                    "sprintplan": "2026-04-03T00:00:00Z",
                    "dev-ready": None,
                    "dev-complete": None,
                }
            },
        )
        result, code = run(["suggest", "--governance-repo", tmp, "--feature-id", "cmd-feat"])
        assert_eq("exit code 0", code, 0)
        command = result["recommendation"]["command"]
        assert_true("command starts with /", command.startswith("/"))
        assert_true("command non-empty", len(command) > 1)


def test_businessplan_phase():
    """Businessplan phase → action=continue-businessplan."""
    print("test_businessplan_phase", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        make_feature(tmp, "bp-feat", phase="businessplan")
        result, code = run(["suggest", "--governance-repo", tmp, "--feature-id", "bp-feat"])
        assert_eq("status pass", result["status"], "pass")
        assert_eq("action", result["recommendation"]["action"], "continue-businessplan")
        assert_eq("command", result["recommendation"]["command"], "/quickplan")


def test_techplan_phase():
    """Techplan phase → action=continue-techplan."""
    print("test_techplan_phase", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        make_feature(
            tmp,
            "tp-feat",
            phase="techplan",
            extra={
                "milestones": {
                    "businessplan": "2026-04-01T00:00:00Z",
                    "techplan": None,
                    "sprintplan": None,
                    "dev-ready": None,
                    "dev-complete": None,
                }
            },
        )
        result, code = run(["suggest", "--governance-repo", tmp, "--feature-id", "tp-feat"])
        assert_eq("status pass", result["status"], "pass")
        assert_eq("action", result["recommendation"]["action"], "continue-techplan")
        assert_eq("command", result["recommendation"]["command"], "/techplan")
        assert_eq("no blockers (businessplan milestone set)", result["recommendation"]["blockers"], [])


def test_missing_entry_milestone_blocker():
    """Techplan phase with no businessplan milestone → blocker surfaced."""
    print("test_missing_entry_milestone_blocker", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        make_feature(tmp, "block-feat", phase="techplan")
        result, code = run(["suggest", "--governance-repo", tmp, "--feature-id", "block-feat"])
        assert_eq("status pass", result["status"], "pass")
        blockers = result["recommendation"]["blockers"]
        assert_true("blocker present", len(blockers) > 0)
        assert_true("blocker message", any("business plan" in b.lower() for b in blockers))


def test_open_issues_warning():
    """More than 3 open issues → warning included."""
    print("test_open_issues_warning", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        make_feature(
            tmp,
            "issues-feat",
            phase="dev",
            extra={
                "milestones": {
                    "businessplan": "2026-04-01T00:00:00Z",
                    "techplan": "2026-04-02T00:00:00Z",
                    "sprintplan": "2026-04-03T00:00:00Z",
                    "dev-ready": None,
                    "dev-complete": None,
                },
                "links": {
                    "retrospective": None,
                    "issues": ["issue-1", "issue-2", "issue-3", "issue-4"],
                    "pull_request": None,
                },
            },
        )
        result, code = run(["suggest", "--governance-repo", tmp, "--feature-id", "issues-feat"])
        assert_eq("status pass", result["status"], "pass")
        warnings = result["recommendation"]["warnings"]
        assert_true("issues warning present", any("open issues" in w for w in warnings))


def test_domain_service_fast_path():
    """Direct lookup via --domain/--service works without scanning."""
    print("test_domain_service_fast_path", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        make_feature(tmp, "fast-feat", phase="sprintplan")
        result, code = run([
            "suggest",
            "--governance-repo", tmp,
            "--feature-id", "fast-feat",
            "--domain", "core",
            "--service", "api",
        ])
        assert_eq("status pass", result["status"], "pass")
        assert_eq("action", result["recommendation"]["action"], "continue-sprintplan")


def test_feature_index_lookup():
    """Feature lookup via feature-index.yaml works when domain/service omitted."""
    print("test_feature_index_lookup", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        make_feature(tmp, "indexed-feat", phase="preplan")
        # Write a feature-index.yaml
        index_path = Path(tmp) / "feature-index.yaml"
        with open(index_path, "w") as f:
            yaml.dump(
                {"features": [{"featureId": "indexed-feat", "domain": "core", "service": "api"}]},
                f,
            )
        result, code = run(["suggest", "--governance-repo", tmp, "--feature-id", "indexed-feat"])
        assert_eq("status pass", result["status"], "pass")
        assert_eq("action quickplan", result["recommendation"]["action"], "quickplan")


if __name__ == "__main__":
    test_preplan_phase()
    test_dev_phase()
    test_complete_phase()
    test_stale_context_warning()
    test_feature_not_found()
    test_path_traversal_rejected()
    test_valid_action_command_returned()
    test_businessplan_phase()
    test_techplan_phase()
    test_missing_entry_milestone_blocker()
    test_open_issues_warning()
    test_domain_service_fast_path()
    test_feature_index_lookup()

    print(f"\n{'='*40}", file=sys.stderr)
    print(f"Results: {PASS} passed, {FAIL} failed", file=sys.stderr)
    print(f"{'='*40}", file=sys.stderr)
    sys.exit(1 if FAIL > 0 else 0)

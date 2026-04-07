#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["PyYAML>=6.0"]
# ///
"""
git-orchestration-ops.py — Lens git write operations for the 2-branch feature model.

Subcommands:
  create-feature-branches  Create {featureId} + {featureId}-plan branches
  commit-artifacts         Stage and commit files with a structured message
  create-dev-branch        Create {featureId}-dev-{username} branch
  merge-plan               Merge {featureId}-plan into {featureId}
  push                     Push current (or named) branch to remote

Exit codes:
  0 — success
  1 — hard error (precondition failed, git error, repo not found)
  2 — partial success with warnings
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Any

import yaml


# ---------------------------------------------------------------------------
# Git helpers
# ---------------------------------------------------------------------------

def git(args: list[str], cwd: str, check: bool = True, capture: bool = True) -> subprocess.CompletedProcess:
    """Run a git command in the given directory."""
    return subprocess.run(
        ["git"] + args,
        cwd=cwd,
        check=check,
        capture_output=capture,
        text=True,
    )


def check_git_version() -> str | None:
    """Return error string if git < 2.28, else None."""
    try:
        result = subprocess.run(["git", "--version"], capture_output=True, text=True, check=True)
        version_str = result.stdout.strip()
        parts = re.findall(r"(\d+)\.(\d+)", version_str)
        if parts:
            major, minor = int(parts[0][0]), int(parts[0][1])
            if (major, minor) < (2, 28):
                return f"git >= 2.28 required, found {version_str}"
    except FileNotFoundError:
        return "git not found on PATH"
    return None


def current_branch(repo: str) -> str:
    """Return name of current checked-out branch."""
    result = git(["rev-parse", "--abbrev-ref", "HEAD"], cwd=repo)
    return result.stdout.strip()


def branch_exists(repo: str, branch: str, include_remote: bool = False) -> bool:
    """Return True if branch exists locally (or remotely when include_remote=True)."""
    result = git(["branch", "--list", branch], cwd=repo)
    if result.stdout.strip():
        return True
    if include_remote:
        result = git(["branch", "-r", "--list", f"origin/{branch}"], cwd=repo)
        return bool(result.stdout.strip())
    return False


def has_tracking_ref(repo: str) -> bool:
    """Return True if current branch has an upstream tracking ref."""
    result = git(["rev-parse", "--abbrev-ref", "@{u}"], cwd=repo, check=False)
    return result.returncode == 0


def head_sha(repo: str) -> str:
    """Return short SHA of HEAD."""
    result = git(["rev-parse", "--short", "HEAD"], cwd=repo)
    return result.stdout.strip()


def verify_clean(repo: str) -> str | None:
    """Return error string if repo has uncommitted changes, else None."""
    result = git(["status", "--porcelain"], cwd=repo)
    if result.stdout.strip():
        return "working directory is not clean — commit or stash changes first"
    return None


# ---------------------------------------------------------------------------
# feature.yaml helpers (shared with git-state-ops)
# ---------------------------------------------------------------------------

def find_feature_yaml(governance_repo: str, feature_id: str) -> Path | None:
    """Walk governance_repo looking for feature.yaml whose feature_id matches."""
    root = Path(governance_repo)
    for yaml_file in root.rglob("feature.yaml"):
        try:
            data = yaml.safe_load(yaml_file.read_text())
            if isinstance(data, dict) and data.get("feature_id") == feature_id:
                return yaml_file
        except Exception:
            continue
    return None


def load_feature_yaml(path: Path) -> dict | None:
    """Load and parse a feature.yaml file. Returns None on parse error."""
    try:
        data = yaml.safe_load(path.read_text())
        return data if isinstance(data, dict) else None
    except Exception:
        return None


# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

_SLUG_RE = re.compile(r"^[a-z0-9][a-z0-9-]*[a-z0-9]$|^[a-z0-9]$")


def validate_slug(value: str, field_name: str = "value") -> str | None:
    """Return error string if value is not a valid slug, else None."""
    if not _SLUG_RE.match(value):
        return f"invalid {field_name} '{value}' — must be lowercase alphanumeric + hyphens, no leading/trailing hyphens, no slashes"
    return None


# ---------------------------------------------------------------------------
# dry-run runner
# ---------------------------------------------------------------------------

class Runner:
    def __init__(self, dry_run: bool, repo: str):
        self.dry_run = dry_run
        self.repo = repo
        self.log: list[str] = []

    def run(self, args: list[str]) -> subprocess.CompletedProcess:
        cmd_str = "git " + " ".join(args)
        if self.dry_run:
            print(f"[dry-run] {cmd_str}", file=sys.stderr)
            self.log.append(cmd_str)
            return subprocess.CompletedProcess(args, 0, stdout="", stderr="")
        result = git(args, cwd=self.repo, check=False)
        if result.returncode != 0:
            # Include both stdout and stderr — git writes CONFLICT lines to stdout
            combined = (result.stdout.strip() + "\n" + result.stderr.strip()).strip()
            raise RuntimeError(f"git {args[0]} failed: {combined}")
        return result


# ---------------------------------------------------------------------------
# Subcommands
# ---------------------------------------------------------------------------

def cmd_create_feature_branches(args: argparse.Namespace) -> tuple[dict[str, Any], int]:
    feature_id = args.feature_id
    governance_repo = args.governance_repo
    repo = args.repo or governance_repo
    default_branch = args.default_branch

    err = validate_slug(feature_id, "feature_id")
    if err:
        return {"error": "invalid_feature_id", "detail": err}, 1

    yaml_path = find_feature_yaml(governance_repo, feature_id)
    if yaml_path is None:
        return {"error": "feature_yaml_not_found", "feature_id": feature_id}, 1

    plan_branch = f"{feature_id}-plan"

    if branch_exists(repo, feature_id, include_remote=True):
        return {"error": "branch_already_exists", "branch": feature_id}, 1
    if branch_exists(repo, plan_branch, include_remote=True):
        return {"error": "branch_already_exists", "branch": plan_branch}, 1

    runner = Runner(args.dry_run, repo)
    saved = current_branch(repo)
    try:
        runner.run(["checkout", default_branch])
        try:
            runner.run(["pull", "origin", default_branch])
        except RuntimeError as exc:
            return {"error": "pull_failed", "detail": str(exc)}, 1
        runner.run(["checkout", "-b", feature_id])
        runner.run(["push", "--set-upstream", "origin", feature_id])
        runner.run(["checkout", "-b", plan_branch])
        runner.run(["push", "--set-upstream", "origin", plan_branch])
    except RuntimeError as exc:
        return {"error": "push_failed", "detail": str(exc)}, 1
    finally:
        git(["checkout", saved], cwd=repo, check=False)

    return {
        "feature_id": feature_id,
        "base_branch": feature_id,
        "plan_branch": plan_branch,
        "base_remote": f"origin/{feature_id}",
        "plan_remote": f"origin/{plan_branch}",
        "created_from": default_branch,
        "dry_run": args.dry_run,
    }, 0


def cmd_commit_artifacts(args: argparse.Namespace) -> tuple[dict[str, Any], int]:
    repo = args.repo
    feature_id = args.feature_id
    files = args.files
    description = args.description
    push = args.push

    if not files:
        return {"error": "no_files_specified"}, 1

    root = Path(repo)
    for f in files:
        if not (root / f).exists():
            return {"error": "file_not_found", "path": f}, 1

    # Guard: must be on a branch belonging to this feature
    if not args.dry_run:
        cb = current_branch(repo)
        allowed = {feature_id, f"{feature_id}-plan"}
        if cb not in allowed and not cb.startswith(f"{feature_id}-dev-"):
            return {
                "error": "wrong_branch",
                "current": cb,
                "expected": [feature_id, f"{feature_id}-plan", f"{feature_id}-dev-<username>"],
            }, 1

    # Resolve phase from feature.yaml if not provided
    phase = args.phase
    warnings: list[str] = []
    if not phase:
        governance_repo = args.governance_repo or repo
        yaml_path = find_feature_yaml(governance_repo, feature_id)
        if yaml_path:
            data = load_feature_yaml(yaml_path)
            if data:
                phase = data.get("phase")
        if not phase:
            phase = "unknown"
            warnings.append("phase could not be resolved from feature.yaml — defaulted to 'unknown'")

    commit_msg = f"[{phase}] {feature_id} — {description}"

    runner = Runner(args.dry_run, repo)
    try:
        runner.run(["add"] + list(files))
    except RuntimeError as exc:
        return {"error": "stage_failed", "detail": str(exc)}, 1

    # Check nothing to commit
    if not args.dry_run:
        status = git(["status", "--porcelain"], cwd=repo)
        if not status.stdout.strip():
            return {"error": "nothing_to_commit"}, 1

    try:
        runner.run(["commit", "-m", commit_msg])
    except RuntimeError as exc:
        return {"error": "commit_failed", "detail": str(exc)}, 1

    sha = head_sha(repo) if not args.dry_run else "dry-run"

    if push:
        try:
            runner.run(["push"])
        except RuntimeError as exc:
            return {"error": "push_failed", "detail": str(exc)}, 1

    result: dict[str, Any] = {
        "feature_id": feature_id,
        "branch": current_branch(repo) if not args.dry_run else "(dry-run)",
        "phase": phase,
        "files_committed": list(files),
        "commit_sha": sha,
        "commit_message": commit_msg,
        "pushed": push and not args.dry_run,
        "dry_run": args.dry_run,
    }
    if warnings:
        result["warnings"] = warnings
    return result, 0


def cmd_create_dev_branch(args: argparse.Namespace) -> tuple[dict[str, Any], int]:
    feature_id = args.feature_id
    username = args.username
    repo = args.repo or args.governance_repo

    err = validate_slug(username, "username")
    if err:
        return {"error": "invalid_username", "detail": err}, 1

    if not branch_exists(repo, feature_id):
        return {"error": "base_branch_not_found", "branch": feature_id}, 1

    dev_branch = f"{feature_id}-dev-{username}"
    if branch_exists(repo, dev_branch, include_remote=True):
        return {"error": "branch_already_exists", "branch": dev_branch}, 1

    runner = Runner(args.dry_run, repo)
    saved = current_branch(repo)
    try:
        runner.run(["checkout", feature_id])
        runner.run(["checkout", "-b", dev_branch])
        runner.run(["push", "--set-upstream", "origin", dev_branch])
    except RuntimeError as exc:
        return {"error": "push_failed", "detail": str(exc)}, 1
    finally:
        git(["checkout", saved], cwd=repo, check=False)

    return {
        "feature_id": feature_id,
        "dev_branch": dev_branch,
        "parent_branch": feature_id,
        "remote": f"origin/{dev_branch}",
        "dry_run": args.dry_run,
    }, 0


def cmd_merge_plan(args: argparse.Namespace) -> tuple[dict[str, Any], int]:
    feature_id = args.feature_id
    repo = args.repo or args.governance_repo
    strategy = args.strategy
    delete_after = args.delete_after_merge

    plan_branch = f"{feature_id}-plan"

    if not branch_exists(repo, feature_id):
        return {"error": "base_branch_not_found", "branch": feature_id}, 1
    if not branch_exists(repo, plan_branch):
        return {"error": "plan_branch_not_found", "branch": plan_branch}, 1

    result_payload: dict[str, Any] = {
        "feature_id": feature_id,
        "strategy": strategy,
        "base_branch": feature_id,
        "plan_branch": plan_branch,
        "plan_branch_deleted": False,
        "dry_run": args.dry_run,
    }

    runner = Runner(args.dry_run, repo)

    if strategy == "pr":
        if args.dry_run:
            result_payload["pr_url"] = "(dry-run)"
            return result_payload, 0
        try:
            pr_result = subprocess.run(
                ["gh", "pr", "create",
                 "--base", feature_id,
                 "--head", plan_branch,
                 "--title", f"[plan] {feature_id} — merge planning artifacts",
                 "--body", "Auto-created by bmad-lens-git-orchestration"],
                cwd=repo, capture_output=True, text=True, check=False
            )
            if pr_result.returncode != 0:
                if "authentication" in pr_result.stderr.lower():
                    return {"error": "gh_not_authenticated", "detail": pr_result.stderr.strip()}, 1
                return {"error": "pr_create_failed", "detail": pr_result.stderr.strip()}, 1
            result_payload["pr_url"] = pr_result.stdout.strip()
        except FileNotFoundError:
            return {"error": "gh_not_found", "detail": "gh CLI not found on PATH"}, 1
    else:  # direct
        # Guard: clean working tree before checkout
        dirty = verify_clean(repo) if not args.dry_run else None
        if dirty:
            return {"error": "dirty_working_tree", "detail": dirty}, 1

        saved = current_branch(repo)
        merge_started = False
        try:
            runner.run(["checkout", feature_id])
            merge_started = True
            runner.run(["merge", "--no-ff", plan_branch, "-m", f"[merge] {feature_id} — merge plan into base"])
            merge_started = False
            # Push: use --set-upstream if no tracking ref exists
            if not args.dry_run and not has_tracking_ref(repo):
                runner.run(["push", "--set-upstream", "origin", feature_id])
            else:
                runner.run(["push"])
            if delete_after:
                runner.run(["branch", "-d", plan_branch])
                runner.run(["push", "origin", "--delete", plan_branch])
                result_payload["plan_branch_deleted"] = True
        except RuntimeError as exc:
            detail = str(exc)
            if merge_started:
                # Conflict — abort to restore clean state, then restore branch
                git(["merge", "--abort"], cwd=repo, check=False)
                merge_started = False
            if "CONFLICT" in detail or "conflict" in detail.lower() or "Automatic merge failed" in detail:
                git(["checkout", saved], cwd=repo, check=False)
                return {"error": "merge_conflict", "detail": detail}, 1
            return {"error": "push_failed", "detail": detail}, 1
        finally:
            restore = git(["checkout", saved], cwd=repo, check=False)
            if restore.returncode != 0 and not args.dry_run:
                result_payload["warnings"] = [f"branch restore failed — still on {feature_id}"]

    return result_payload, 0


def cmd_push(args: argparse.Namespace) -> tuple[dict[str, Any], int]:
    repo = args.repo or args.governance_repo
    branch = args.branch or current_branch(repo)

    runner = Runner(args.dry_run, repo)
    tracking = has_tracking_ref(repo) if not args.dry_run else False

    try:
        if tracking:
            runner.run(["push"])
        else:
            runner.run(["push", "--set-upstream", "origin", branch])
    except RuntimeError as exc:
        detail = str(exc)
        if "rejected" in detail:
            return {"error": "push_rejected", "detail": detail}, 1
        if "authentication" in detail.lower() or "403" in detail:
            return {"error": "auth_failed", "detail": detail}, 1
        return {"error": "push_failed", "detail": detail}, 1

    sha = head_sha(repo) if not args.dry_run else "dry-run"
    return {
        "branch": branch,
        "remote": f"origin/{branch}",
        "commit_sha": sha,
        "tracking_set": not tracking,
        "already_up_to_date": False,
        "dry_run": args.dry_run,
    }, 0


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="Lens git write operations for the 2-branch feature model"
    )
    sub = p.add_subparsers(dest="command", required=True)

    # create-feature-branches
    cfb = sub.add_parser("create-feature-branches", help="Create {featureId} + {featureId}-plan branches")
    cfb.add_argument("--governance-repo", required=True)
    cfb.add_argument("--feature-id", required=True)
    cfb.add_argument("--repo", default=None, help="Working repo path (defaults to governance-repo)")
    cfb.add_argument("--default-branch", default="main")
    cfb.add_argument("--dry-run", action="store_true")

    # commit-artifacts
    ca = sub.add_parser("commit-artifacts", help="Stage and commit files with structured message")
    ca.add_argument("--repo", required=True)
    ca.add_argument("--governance-repo", default=None)
    ca.add_argument("--feature-id", required=True)
    ca.add_argument("--files", nargs="+", required=True)
    ca.add_argument("--description", required=True)
    ca.add_argument("--phase", default=None, help="Phase token; auto-resolved from feature.yaml if omitted")
    ca.add_argument("--push", action="store_true")
    ca.add_argument("--no-confirm", action="store_true")
    ca.add_argument("--dry-run", action="store_true")

    # create-dev-branch
    cdb = sub.add_parser("create-dev-branch", help="Create {featureId}-dev-{username} branch")
    cdb.add_argument("--governance-repo", required=True)
    cdb.add_argument("--feature-id", required=True)
    cdb.add_argument("--username", required=True)
    cdb.add_argument("--repo", default=None)
    cdb.add_argument("--dry-run", action="store_true")

    # merge-plan
    mp = sub.add_parser("merge-plan", help="Merge {featureId}-plan into {featureId}")
    mp.add_argument("--governance-repo", required=True)
    mp.add_argument("--feature-id", required=True)
    mp.add_argument("--repo", default=None)
    mp.add_argument("--strategy", choices=["pr", "direct"], default="pr")
    mp.add_argument("--delete-after-merge", action="store_true")
    mp.add_argument("--dry-run", action="store_true")

    # push
    pu = sub.add_parser("push", help="Push current or named branch to remote")
    pu.add_argument("--governance-repo", required=True)
    pu.add_argument("--repo", default=None)
    pu.add_argument("--branch", default=None)
    pu.add_argument("--dry-run", action="store_true")

    return p


def main() -> int:
    version_err = check_git_version()
    if version_err:
        print(json.dumps({"error": "git_version", "detail": version_err}))
        return 1

    parser = build_parser()
    args = parser.parse_args()

    dispatch = {
        "create-feature-branches": cmd_create_feature_branches,
        "commit-artifacts": cmd_commit_artifacts,
        "create-dev-branch": cmd_create_dev_branch,
        "merge-plan": cmd_merge_plan,
        "push": cmd_push,
    }

    fn = dispatch.get(args.command)
    if fn is None:
        print(json.dumps({"error": "unknown_command", "command": args.command}))
        return 1

    try:
        result, exit_code = fn(args)
    except Exception as exc:
        print(json.dumps({"error": "internal_error", "detail": str(exc)}))
        return 1

    print(json.dumps(result, indent=2))
    return exit_code


if __name__ == "__main__":
    sys.exit(main())

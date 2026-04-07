#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["pyyaml>=6.0"]
# ///
"""Feature initialization operations — create branches, feature.yaml, PR, and feature-index entries.

The init-feature workflow creates the 2-branch topology ({featureId} and {featureId}-plan),
writes feature.yaml to the governance repo, registers the feature in feature-index.yaml on main,
and creates a summary.md stub. Git/gh commands are returned as arrays — not executed directly.
"""

import argparse
import json
import os
import re
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path

import yaml


FEATURE_ID_PATTERN = re.compile(r"^[a-z0-9][a-z0-9-]{0,63}$")
SAFE_ID_PATTERN = re.compile(r"^[a-z0-9][a-z0-9._-]{0,63}$")
VALID_TRACKS = [
    "quickplan",
    "full",
    "feature",
    "hotfix",
    "hotfix-express",
    "express",
    "spike",
    "tech-change",
]


def validate_feature_id(value: str) -> str | None:
    """Validate featureId is strict kebab-case. Returns error message or None."""
    if not FEATURE_ID_PATTERN.match(value):
        return (
            f"Invalid featureId: '{value}'. "
            f"Must match ^[a-z0-9][a-z0-9-]{{0,63}}$ (lowercase alphanumeric and hyphens only)."
        )
    return None


def validate_safe_id(value: str, field_name: str) -> str | None:
    """Validate a path-constructing identifier is safe. Returns error message or None."""
    if not SAFE_ID_PATTERN.match(value):
        return (
            f"Invalid {field_name}: '{value}'. "
            f"Must match [a-z0-9][a-z0-9._-]{{0,63}} (lowercase alphanumeric, dots, hyphens, underscores)."
        )
    return None


def now_iso() -> str:
    """Return current UTC time as ISO 8601 string."""
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def read_feature_index(governance_repo: str) -> tuple[dict, bool]:
    """Read feature-index.yaml; return (data, exists). Creates empty structure if missing."""
    index_path = Path(governance_repo) / "feature-index.yaml"
    if not index_path.exists():
        return {"features": []}, False
    try:
        with open(index_path) as f:
            data = yaml.safe_load(f) or {}
    except (yaml.YAMLError, OSError) as e:
        raise RuntimeError(f"Failed to read feature-index.yaml: {e}") from e
    if "features" not in data:
        data["features"] = []
    return data, True


def atomic_write_yaml(path: Path, data: dict) -> None:
    """Write YAML atomically via temp file + rename to prevent corruption."""
    dir_path = path.parent
    dir_path.mkdir(parents=True, exist_ok=True)
    fd, tmp_path = tempfile.mkstemp(dir=str(dir_path), suffix=".yaml.tmp")
    try:
        with os.fdopen(fd, "w") as f:
            yaml.dump(data, f, default_flow_style=False, sort_keys=False, allow_unicode=True)
        os.replace(tmp_path, str(path))
    except Exception:
        try:
            os.unlink(tmp_path)
        except OSError:
            pass
        raise


def make_feature_yaml(
    feature_id: str,
    domain: str,
    service: str,
    name: str,
    track: str,
    username: str,
    timestamp: str,
) -> dict:
    """Build the initial feature.yaml data structure."""
    return {
        "name": name,
        "description": "",
        "featureId": feature_id,
        "domain": domain,
        "service": service,
        "phase": "preplan",
        "track": track,
        "milestones": {
            "businessplan": None,
            "techplan": None,
            "sprintplan": None,
            "dev-ready": None,
            "dev-complete": None,
        },
        "team": [{"username": username, "role": "lead"}],
        "dependencies": {"depends_on": [], "depended_by": []},
        "target_repos": [],
        "links": {"retrospective": None, "issues": [], "pull_request": None},
        "priority": "medium",
        "created": timestamp,
        "updated": timestamp,
        "phase_transitions": [{"phase": "preplan", "timestamp": timestamp, "user": username}],
    }


def make_summary_md(
    feature_id: str,
    domain: str,
    service: str,
    name: str,
    username: str,
    timestamp: str,
) -> str:
    """Build the initial summary.md stub content."""
    return (
        f"# {name}\n\n"
        f"> Status: preplan | Feature ID: `{feature_id}`\n\n"
        f"Auto-generated stub. Update as planning progresses.\n\n"
        f"**Domain:** {domain}  \n"
        f"**Service:** {service}  \n"
        f"**Owner:** {username}  \n"
        f"**Initialized:** {timestamp}\n"
    )


def build_git_commands(
    governance_repo: str,
    control_repo: str | None,
    feature_id: str,
    domain: str,
    service: str,
) -> list[str]:
    """Return the ordered git commands needed to commit the initialized feature."""
    gov = governance_repo
    plan_branch = f"{feature_id}-plan"
    feature_yaml_rel = f"features/{domain}/{service}/{feature_id}/feature.yaml"
    summary_rel = f"features/{domain}/{service}/{feature_id}/summary.md"

    cmds: list[str] = []

    if control_repo:
        cmds.extend([
            f"git -C {control_repo} checkout -b {feature_id}",
            f"git -C {control_repo} checkout -b {plan_branch}",
        ])

    cmds.extend([
        f"git -C {gov} checkout -b {plan_branch}",
        f"git -C {gov} add {feature_yaml_rel}",
        f'git -C {gov} commit -m "feat({domain}/{service}): init {feature_id} planning artifacts"',
        f"git -C {gov} checkout main",
        f"git -C {gov} add feature-index.yaml {summary_rel}",
        f'git -C {gov} commit -m "feat: add {feature_id} to feature index"',
    ])

    return cmds


def build_gh_commands(control_repo: str, feature_id: str, name: str) -> list[str]:
    """Return the gh CLI commands for PR creation."""
    plan_branch = f"{feature_id}-plan"
    return [
        (
            f"gh pr create --repo {control_repo} "
            f"--head {plan_branch} --base {feature_id} "
            f'--title "Planning: {name}" '
            f'--body "Initialize planning artifacts for {name}"'
        ),
    ]


def cmd_create(args: argparse.Namespace) -> dict:
    """Create feature branches, feature.yaml, PR, feature-index entry, and summary stub."""
    err = validate_feature_id(args.feature_id)
    if err:
        return {"status": "fail", "error": err}

    for field_name, value in [("domain", args.domain), ("service", args.service)]:
        err = validate_safe_id(value, field_name)
        if err:
            return {"status": "fail", "error": err}

    governance_repo = args.governance_repo
    control_repo = args.control_repo
    feature_id = args.feature_id
    domain = args.domain
    service = args.service
    name = args.name
    track = args.track
    username = args.username

    try:
        index_data, _index_exists = read_feature_index(governance_repo)
    except RuntimeError as e:
        return {"status": "fail", "error": str(e)}

    existing_ids = [f.get("id") for f in index_data.get("features", [])]
    if feature_id in existing_ids:
        return {
            "status": "fail",
            "error": f"Feature '{feature_id}' already exists in feature-index.yaml",
        }

    timestamp = now_iso()
    feature_yaml_path = (
        Path(governance_repo) / "features" / domain / service / feature_id / "feature.yaml"
    )
    summary_path = (
        Path(governance_repo) / "features" / domain / service / feature_id / "summary.md"
    )
    index_path = Path(governance_repo) / "feature-index.yaml"

    # control_repo for git commands: use separately if provided, else None to skip ctrl-repo cmds
    ctrl_for_git = control_repo if (control_repo and control_repo != governance_repo) else None
    pr_repo = control_repo or governance_repo

    git_cmds = build_git_commands(governance_repo, ctrl_for_git, feature_id, domain, service)
    gh_cmds = build_gh_commands(pr_repo, feature_id, name)

    if args.dry_run:
        return {
            "status": "pass",
            "dry_run": True,
            "featureId": feature_id,
            "feature_yaml_path": str(feature_yaml_path),
            "index_updated": True,
            "summary_path": str(summary_path),
            "git_commands": git_cmds,
            "gh_commands": gh_cmds,
        }

    feature_data = make_feature_yaml(feature_id, domain, service, name, track, username, timestamp)
    try:
        atomic_write_yaml(feature_yaml_path, feature_data)
    except OSError as e:
        return {"status": "fail", "error": f"Failed to write feature.yaml: {e}"}

    new_entry = {
        "id": feature_id,
        "domain": domain,
        "service": service,
        "status": "preplan",
        "owner": username,
        "plan_branch": f"{feature_id}-plan",
        "related_features": {"depends_on": [], "blocks": [], "related": []},
        "updated_at": timestamp,
        "summary": "",
    }
    index_data["features"].append(new_entry)
    try:
        atomic_write_yaml(index_path, index_data)
    except OSError as e:
        return {"status": "fail", "error": f"Failed to write feature-index.yaml: {e}"}

    summary_content = make_summary_md(feature_id, domain, service, name, username, timestamp)
    try:
        summary_path.parent.mkdir(parents=True, exist_ok=True)
        summary_path.write_text(summary_content, encoding="utf-8")
    except OSError as e:
        return {"status": "fail", "error": f"Failed to write summary.md: {e}"}

    return {
        "status": "pass",
        "featureId": feature_id,
        "feature_yaml_path": str(feature_yaml_path),
        "index_updated": True,
        "summary_path": str(summary_path),
        "git_commands": git_cmds,
        "gh_commands": gh_cmds,
    }


def cmd_fetch_context(args: argparse.Namespace) -> dict:
    """Fetch cross-feature context for a feature."""
    governance_repo = args.governance_repo
    feature_id = args.feature_id
    depth = args.depth

    try:
        index_data, index_exists = read_feature_index(governance_repo)
    except RuntimeError as e:
        return {"status": "fail", "error": str(e)}

    if not index_exists:
        return {"status": "fail", "error": "feature-index.yaml not found"}

    features = index_data.get("features", [])

    target = next((f for f in features if f.get("id") == feature_id), None)
    if target is None:
        return {
            "status": "fail",
            "error": f"Feature '{feature_id}' not found in feature-index.yaml",
        }

    target_domain = target.get("domain", "")
    depends_on_ids = target.get("related_features", {}).get("depends_on", [])

    related = [f for f in features if f.get("domain") == target_domain and f.get("id") != feature_id]
    depends_on = [f for f in features if f.get("id") in depends_on_ids]

    gov = Path(governance_repo)
    context_paths: list[str] = []

    for f in related:
        fid = f.get("id", "")
        dom = f.get("domain", "")
        svc = f.get("service", "")
        if depth == "full":
            context_paths.append(str(gov / "features" / dom / svc / fid / "feature.yaml"))
        else:
            context_paths.append(str(gov / "features" / dom / svc / fid / "summary.md"))

    for f in depends_on:
        fid = f.get("id", "")
        dom = f.get("domain", "")
        svc = f.get("service", "")
        context_paths.append(str(gov / "features" / dom / svc / fid / "feature.yaml"))

    return {
        "status": "pass",
        "related": [f.get("id") for f in related],
        "depends_on": [f.get("id") for f in depends_on],
        "context_paths": context_paths,
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Feature initialization operations — create branches, feature.yaml, PR, and feature-index entries.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s create --governance-repo /path/to/repo --feature-id auth-refresh \\
    --domain platform --service identity --name "Auth Token Refresh" --username cweber

  %(prog)s create --governance-repo /path/to/gov --control-repo /path/to/src \\
    --feature-id payment-gateway --domain commerce --service payments \\
    --name "Payment Gateway" --username cweber --dry-run

  %(prog)s fetch-context --governance-repo /path/to/repo --feature-id auth-refresh

  %(prog)s fetch-context --governance-repo /path/to/repo --feature-id auth-refresh --depth full
""",
    )

    subparsers = parser.add_subparsers(dest="command", required=True)

    create_p = subparsers.add_parser("create", help="Create feature branches, YAML, PR, and index entry")
    create_p.add_argument("--governance-repo", required=True, help="Path to governance repo root")
    create_p.add_argument(
        "--control-repo",
        default=None,
        help="Path to source control repo (defaults to governance-repo)",
    )
    create_p.add_argument(
        "--feature-id",
        required=True,
        help="Unique feature identifier (kebab-case: ^[a-z0-9][a-z0-9-]{0,63}$)",
    )
    create_p.add_argument("--domain", required=True, help="Domain name")
    create_p.add_argument("--service", required=True, help="Service name")
    create_p.add_argument("--name", required=True, help="Human-friendly feature name")
    create_p.add_argument(
        "--track",
        default="quickplan",
        choices=VALID_TRACKS,
        help="Lifecycle track (default: quickplan)",
    )
    create_p.add_argument("--username", required=True, help="Username of the creator")
    create_p.add_argument(
        "--dry-run",
        action="store_true",
        help="Print planned operations without writing any files",
    )

    fetch_p = subparsers.add_parser("fetch-context", help="Fetch cross-feature context")
    fetch_p.add_argument("--governance-repo", required=True, help="Path to governance repo root")
    fetch_p.add_argument("--feature-id", required=True, help="Feature identifier")
    fetch_p.add_argument(
        "--depth",
        default="summaries",
        choices=["summaries", "full"],
        help="Context depth: summaries (default) or full",
    )

    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()

    commands = {
        "create": cmd_create,
        "fetch-context": cmd_fetch_context,
    }

    result = commands[args.command](args)
    json.dump(result, sys.stdout, indent=2, default=str)
    print()

    status = result.get("status", "fail")
    sys.exit(0 if status in ("pass", "warning") else 1)


if __name__ == "__main__":
    main()

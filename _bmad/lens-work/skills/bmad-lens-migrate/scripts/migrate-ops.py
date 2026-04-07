#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["pyyaml>=6.0"]
# ///
"""Migration operations — scan legacy LENS v3 branches, check conflicts, migrate features.

Transitions features from the old domain-service-feature-milestone branch topology
to the Lens Next 2-branch model ({featureId} + {featureId}-plan).
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

# Sanitization pattern for path-constructing identifiers
SAFE_ID_PATTERN = re.compile(r"^[a-z0-9][a-z0-9._-]{0,63}$")

# Default legacy branch pattern
DEFAULT_BRANCH_PATTERN = r"^([a-z0-9-]+)-([a-z0-9-]+)-([a-z0-9-]+)(?:-([a-z0-9-]+))?$"

# Phase ordering for state derivation (earliest to latest)
PHASE_ORDER = ["planning", "businessplan", "techplan", "sprintplan", "dev", "complete"]


def validate_identifier(value: str, field_name: str) -> str | None:
    """Validate that a path-constructing identifier is safe. Returns error message or None."""
    if not SAFE_ID_PATTERN.match(value):
        return (
            f"Invalid {field_name}: '{value}'. "
            f"Must match [a-z0-9][a-z0-9._-]{{0,63}} (lowercase alphanumeric, dots, hyphens, underscores)."
        )
    return None


def now_iso() -> str:
    """Return current UTC time as ISO 8601 string."""
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def atomic_write_yaml(path: Path, data: dict) -> None:
    """Write YAML atomically via temp file + rename to prevent corruption."""
    dir_path = path.parent
    fd, tmp_path = tempfile.mkstemp(dir=str(dir_path), suffix=".yaml.tmp")
    try:
        with os.fdopen(fd, "w") as f:
            yaml.dump(data, f, default_flow_style=False, sort_keys=False, allow_unicode=True)
        os.replace(tmp_path, str(path))
    except Exception:
        os.unlink(tmp_path)
        raise


def group_legacy_branches(names: list[str]) -> dict[str, dict]:
    """Group branch names into base branches with their milestones.

    Uses prefix-matching: if name B starts with name A + "-", then B is a
    milestone branch of A, and B's suffix (after A + "-") is the milestone label.
    Names not identified as milestones of any other name are treated as base branches.
    """
    sorted_names = sorted(names)
    milestone_map: dict[str, list[str]] = {}
    is_milestone: set[str] = set()

    for name in sorted_names:
        for base in sorted_names:
            if base == name:
                continue
            prefix = base + "-"
            if name.startswith(prefix):
                milestone = name[len(prefix):]
                if base not in milestone_map:
                    milestone_map[base] = []
                milestone_map[base].append(milestone)
                is_milestone.add(name)

    features = {}
    for name in sorted_names:
        if name in is_milestone:
            continue
        parts = name.split("-")
        if len(parts) < 3:
            continue
        domain = parts[0]
        service = parts[1]
        feature_id = "-".join(parts[2:])
        features[name] = {
            "old_id": name,
            "derived_domain": domain,
            "derived_service": service,
            "feature_id": feature_id,
            "milestones": milestone_map.get(name, []),
        }

    return features


def derive_state(milestones: list[str]) -> str:
    """Derive current state from list of discovered milestone labels."""
    for phase in reversed(PHASE_ORDER):
        if phase in milestones:
            return phase
    return "preplan" if not milestones else "planning"


def cmd_scan(args: argparse.Namespace) -> dict:
    """Detect legacy branches and build migration plan."""
    governance_repo = Path(args.governance_repo)
    if not governance_repo.exists():
        print(f"Error: Governance repo not found: {governance_repo}", file=sys.stderr)
        sys.exit(1)

    branches_dir = governance_repo / "branches"
    if not branches_dir.exists():
        return {"status": "pass", "legacy_features": [], "total": 0, "conflicts": []}

    pattern_str = args.branch_pattern or DEFAULT_BRANCH_PATTERN
    try:
        pattern = re.compile(pattern_str)
    except re.error as e:
        return {"status": "fail", "error": f"Invalid branch pattern: {e}"}

    candidate_names = []
    for entry in branches_dir.iterdir():
        if entry.is_dir() and pattern.match(entry.name):
            candidate_names.append(entry.name)

    if not candidate_names:
        return {"status": "pass", "legacy_features": [], "total": 0, "conflicts": []}

    grouped = group_legacy_branches(candidate_names)

    legacy_features = []
    conflicts = []

    for base_name, info in sorted(grouped.items()):
        feature_id = info["feature_id"]
        domain = info["derived_domain"]
        service = info["derived_service"]
        milestones = info["milestones"]
        state = derive_state(milestones)

        new_feature_path = governance_repo / "features" / domain / service / feature_id / "feature.yaml"
        if new_feature_path.exists():
            conflicts.append({
                "old_id": base_name,
                "feature_id": feature_id,
                "conflict_path": str(new_feature_path),
            })

        legacy_features.append({
            "old_id": base_name,
            "derived_domain": domain,
            "derived_service": service,
            "feature_id": feature_id,
            "milestones": milestones,
            "proposed": {
                "base_branch": feature_id,
                "plan_branch": f"{feature_id}-plan",
            },
            "state": state,
        })

    return {
        "status": "pass",
        "legacy_features": legacy_features,
        "total": len(legacy_features),
        "conflicts": conflicts,
    }


def cmd_migrate_feature(args: argparse.Namespace) -> dict:
    """Execute migration for a single feature."""
    governance_repo = Path(args.governance_repo)
    if not governance_repo.exists():
        print(f"Error: Governance repo not found: {governance_repo}", file=sys.stderr)
        sys.exit(1)

    for field_name, value in [
        ("feature-id", args.feature_id),
        ("domain", args.domain),
        ("service", args.service),
    ]:
        err = validate_identifier(value, field_name)
        if err:
            return {"status": "fail", "error": err}

    dry_run = args.dry_run
    feature_id = args.feature_id
    domain = args.domain
    service = args.service
    old_id = args.old_id
    username = args.username or "unknown"
    timestamp = now_iso()

    feature_dir = governance_repo / "features" / domain / service / feature_id
    feature_path = feature_dir / "feature.yaml"
    index_path = governance_repo / "feature-index.yaml"
    summary_path = governance_repo / "summaries" / f"{feature_id}.md"

    if dry_run:
        return {
            "status": "pass",
            "feature_id": feature_id,
            "dry_run": True,
            "planned_actions": [
                f"Create feature.yaml at {feature_path}",
                f"Update feature-index.yaml at {index_path}",
                f"Create summary stub at {summary_path}",
            ],
            "feature_yaml_created": False,
            "index_updated": False,
        }

    # Create feature.yaml
    feature_yaml_created = False
    if not feature_path.exists():
        feature_data = {
            "featureId": feature_id,
            "name": feature_id.replace("-", " ").title(),
            "description": f"Migrated from legacy branch: {old_id}",
            "domain": domain,
            "service": service,
            "phase": "preplan",
            "track": "full",
            "priority": "medium",
            "created": timestamp,
            "updated": timestamp,
            "team": [{"username": username, "role": "lead"}],
            "phase_transitions": [{"phase": "preplan", "timestamp": timestamp, "user": username}],
            "migrated_from": old_id,
        }
        try:
            feature_dir.mkdir(parents=True, exist_ok=True)
            atomic_write_yaml(feature_path, feature_data)
            feature_yaml_created = True
        except OSError as e:
            return {"status": "fail", "error": f"Failed to create feature.yaml: {e}"}

    # Update feature-index.yaml
    index_updated = False
    try:
        if index_path.exists():
            with open(index_path) as f:
                index_data = yaml.safe_load(f) or {}
        else:
            index_data = {"features": []}

        if "features" not in index_data:
            index_data["features"] = []

        existing_ids = [e.get("featureId") for e in index_data["features"]]
        if feature_id not in existing_ids:
            index_data["features"].append({
                "featureId": feature_id,
                "domain": domain,
                "service": service,
                "migrated_from": old_id,
                "added": timestamp,
            })
            index_path.parent.mkdir(parents=True, exist_ok=True)
            atomic_write_yaml(index_path, index_data)
            index_updated = True
    except (OSError, yaml.YAMLError) as e:
        return {"status": "fail", "error": f"Failed to update feature-index.yaml: {e}"}

    # Create summary stub
    summary_created = False
    try:
        if not summary_path.exists():
            summary_path.parent.mkdir(parents=True, exist_ok=True)
            with open(summary_path, "w") as f:
                f.write(f"# {feature_id.replace('-', ' ').title()}\n\n")
                f.write(f"**Feature ID:** {feature_id}  \n")
                f.write(f"**Domain:** {domain}  \n")
                f.write(f"**Service:** {service}  \n")
                f.write(f"**Migrated from:** {old_id}  \n")
                f.write(f"**Migration date:** {timestamp}  \n\n")
                f.write("## Summary\n\n_To be filled in._\n")
            summary_created = True
    except OSError as e:
        return {"status": "fail", "error": f"Failed to create summary.md: {e}"}

    return {
        "status": "pass",
        "feature_id": feature_id,
        "dry_run": False,
        "feature_yaml_created": feature_yaml_created,
        "index_updated": index_updated,
        "summary_created": summary_created,
    }


def cmd_check_conflicts(args: argparse.Namespace) -> dict:
    """Check for naming conflicts before migration."""
    governance_repo = Path(args.governance_repo)
    if not governance_repo.exists():
        print(f"Error: Governance repo not found: {governance_repo}", file=sys.stderr)
        sys.exit(1)

    feature_id = args.feature_id
    domain = args.domain
    service = args.service

    target_path = governance_repo / "features" / domain / service / feature_id / "feature.yaml"

    if target_path.exists():
        return {
            "status": "conflict",
            "conflict": True,
            "existing_path": str(target_path),
        }

    return {
        "status": "pass",
        "conflict": False,
        "existing_path": None,
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Migration operations — scan legacy LENS v3 branches and migrate to Lens Next model.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s scan --governance-repo /path/to/repo
  %(prog)s scan --governance-repo /path/to/repo --branch-pattern "^custom-.*$"

  %(prog)s check-conflicts --governance-repo /path/to/repo \\
    --feature-id auth-login --domain platform --service identity

  %(prog)s migrate-feature --governance-repo /path/to/repo \\
    --old-id platform-identity-auth-login --feature-id auth-login \\
    --domain platform --service identity --username cweber --dry-run

  %(prog)s migrate-feature --governance-repo /path/to/repo \\
    --old-id platform-identity-auth-login --feature-id auth-login \\
    --domain platform --service identity --username cweber
""",
    )

    subparsers = parser.add_subparsers(dest="command", required=True)

    # scan
    scan_p = subparsers.add_parser("scan", help="Detect legacy branches and build migration plan")
    scan_p.add_argument("--governance-repo", required=True, help="Path to governance repo root")
    scan_p.add_argument("--branch-pattern", help="Optional regex override for branch pattern detection")

    # migrate-feature
    mig_p = subparsers.add_parser("migrate-feature", help="Execute migration for a single feature")
    mig_p.add_argument("--governance-repo", required=True, help="Path to governance repo root")
    mig_p.add_argument("--old-id", required=True, help="Old branch name (legacy ID)")
    mig_p.add_argument("--feature-id", required=True, help="New feature ID (kebab-case)")
    mig_p.add_argument("--domain", required=True, help="Domain name")
    mig_p.add_argument("--service", required=True, help="Service name")
    mig_p.add_argument("--username", default="unknown", help="Username performing the migration")
    mig_p.add_argument("--dry-run", action="store_true", help="Preview without making changes")

    # check-conflicts
    cc_p = subparsers.add_parser("check-conflicts", help="Check for naming conflicts before migration")
    cc_p.add_argument("--governance-repo", required=True, help="Path to governance repo root")
    cc_p.add_argument("--feature-id", required=True, help="Target feature ID")
    cc_p.add_argument("--domain", required=True, help="Domain name")
    cc_p.add_argument("--service", required=True, help="Service name")

    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()

    commands = {
        "scan": cmd_scan,
        "migrate-feature": cmd_migrate_feature,
        "check-conflicts": cmd_check_conflicts,
    }

    result = commands[args.command](args)
    json.dump(result, sys.stdout, indent=2, default=str)
    print()

    status = result.get("status", "fail")
    sys.exit(0 if status in ("pass", "conflict") else 1)


if __name__ == "__main__":
    main()

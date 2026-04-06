#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["pyyaml>=6.0"]
# ///
"""Next-action recommendation for Lens features.

Reads feature.yaml and derives the most contextually appropriate next action
based on lifecycle phase, track type, outstanding issues, and staleness flags.
"""

import argparse
import json
import re
import sys
from pathlib import Path

import yaml


SAFE_ID_PATTERN = re.compile(r"^[a-z0-9][a-z0-9._-]{0,63}$")

# Phase → action, command, and rationale
PHASE_ACTIONS: dict[str, tuple[str, str, str]] = {
    "preplan": (
        "quickplan",
        "/quickplan",
        "Feature is in preplan phase with feature.yaml created — ready to start planning",
    ),
    "businessplan": (
        "continue-businessplan",
        "/quickplan",
        "Business plan is in progress — continue defining the business case",
    ),
    "techplan": (
        "continue-techplan",
        "/techplan",
        "Technical planning is in progress — continue defining the technical approach",
    ),
    "sprintplan": (
        "continue-sprintplan",
        "/sprintplan",
        "Sprint planning is in progress — continue breaking down into stories",
    ),
    "dev": (
        "dev-next-story",
        "/dev-story",
        "Feature is in development — check story status and implement the next story",
    ),
    "complete": (
        "retrospective",
        "/retrospective",
        "Feature is complete — run the retrospective to capture learnings",
    ),
    "paused": (
        "resume",
        "/resume",
        "Feature is paused — review current state and decide whether to resume or close",
    ),
}

# Required milestones that must be non-null before entering each phase
PHASE_ENTRY_MILESTONES: dict[str, tuple[str, str]] = {
    "techplan": ("businessplan", "Business plan milestone not completed"),
    "sprintplan": ("techplan", "Tech plan milestone not completed"),
    "dev": ("sprintplan", "Sprint plan milestone not completed"),
    "complete": ("dev-complete", "Dev-complete milestone not set"),
}


def validate_identifier(value: str, field_name: str) -> str | None:
    """Validate that a path-constructing identifier is safe. Returns error message or None."""
    if not SAFE_ID_PATTERN.match(value):
        return (
            f"Invalid {field_name}: '{value}'. "
            f"Must match [a-z0-9][a-z0-9._-]{{0,63}} (lowercase alphanumeric, dots, hyphens, underscores)."
        )
    return None


def find_feature(governance_repo: str, feature_id: str) -> Path | None:
    """Find a feature.yaml by featureId, scanning all domains/services."""
    features_dir = Path(governance_repo) / "features"
    if not features_dir.exists():
        return None
    for yaml_file in features_dir.rglob("feature.yaml"):
        try:
            with open(yaml_file) as f:
                data = yaml.safe_load(f)
            if data and data.get("featureId") == feature_id:
                return yaml_file
        except (yaml.YAMLError, OSError):
            continue
    return None


def find_feature_via_index(governance_repo: str, feature_id: str) -> tuple[str, str] | None:
    """Look up domain/service from feature-index.yaml. Returns (domain, service) or None."""
    index_path = Path(governance_repo) / "feature-index.yaml"
    if not index_path.exists():
        return None
    try:
        with open(index_path) as f:
            index = yaml.safe_load(f)
        if not index or "features" not in index:
            return None
        for entry in index.get("features", []):
            if entry.get("featureId") == feature_id:
                domain = entry.get("domain", "")
                service = entry.get("service", "")
                if domain and service:
                    return domain, service
    except (yaml.YAMLError, OSError):
        return None
    return None


def build_recommendation(data: dict) -> dict:
    """Derive the next action recommendation from feature state."""
    phase = data.get("phase", "preplan")
    milestones = data.get("milestones") or {}
    context = data.get("context") or {}
    links = data.get("links") or {}

    blockers: list[str] = []
    warnings: list[str] = []

    # Check for missing required entry milestone (hard gate)
    if phase in PHASE_ENTRY_MILESTONES:
        milestone_key, msg = PHASE_ENTRY_MILESTONES[phase]
        if not milestones.get(milestone_key):
            blockers.append(msg)

    # Stale context warning
    if context.get("stale"):
        warnings.append("context.stale — consider fetching fresh context first")

    # Open issues warning
    issues = links.get("issues") or []
    if len(issues) > 3:
        warnings.append(f"{len(issues)} open issues — consider reviewing before proceeding")

    action, command, rationale = PHASE_ACTIONS.get(
        phase,
        ("check-status", "/status", f"Feature is in {phase} phase — check current status"),
    )

    return {
        "action": action,
        "rationale": rationale,
        "command": command,
        "blockers": blockers,
        "warnings": warnings,
    }


def resolve_feature_path(args: argparse.Namespace) -> Path | None:
    """Resolve the feature.yaml path via direct path, index, or full scan."""
    # Direct lookup when domain + service are provided
    if args.domain and args.service:
        candidate = (
            Path(args.governance_repo) / "features" / args.domain / args.service / args.feature_id / "feature.yaml"
        )
        if candidate.exists():
            return candidate

    # Feature index lookup
    loc = find_feature_via_index(args.governance_repo, args.feature_id)
    if loc:
        domain, service = loc
        candidate = (
            Path(args.governance_repo) / "features" / domain / service / args.feature_id / "feature.yaml"
        )
        if candidate.exists():
            return candidate

    # Full scan fallback
    return find_feature(args.governance_repo, args.feature_id)


def cmd_suggest(args: argparse.Namespace) -> dict:
    """Return the next recommended action for a feature."""
    err = validate_identifier(args.feature_id, "feature-id")
    if err:
        return {"status": "fail", "error": err}

    if args.domain:
        err = validate_identifier(args.domain, "domain")
        if err:
            return {"status": "fail", "error": err}

    if args.service:
        err = validate_identifier(args.service, "service")
        if err:
            return {"status": "fail", "error": err}

    feature_path = resolve_feature_path(args)
    if not feature_path:
        return {"status": "fail", "error": f"Feature not found: {args.feature_id}"}

    try:
        with open(feature_path) as f:
            data = yaml.safe_load(f)
    except (yaml.YAMLError, OSError) as e:
        return {"status": "fail", "error": f"Failed to read feature.yaml: {e}"}

    recommendation = build_recommendation(data)

    return {
        "status": "pass",
        "featureId": data.get("featureId", args.feature_id),
        "phase": data.get("phase", "preplan"),
        "track": data.get("track", "quickplan"),
        "path": str(feature_path),
        "recommendation": recommendation,
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Next-action recommendations for Lens features.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s suggest --governance-repo /path/to/repo --feature-id auth-login
  %(prog)s suggest --governance-repo /path/to/repo --feature-id auth-login \\
    --domain platform --service identity
""",
    )

    subparsers = parser.add_subparsers(dest="command", required=True)

    suggest_p = subparsers.add_parser("suggest", help="Return the next recommended action")
    suggest_p.add_argument("--governance-repo", required=True, help="Path to governance repo root")
    suggest_p.add_argument("--feature-id", required=True, help="Feature identifier")
    suggest_p.add_argument("--domain", default="", help="Domain name (optional, accelerates lookup)")
    suggest_p.add_argument("--service", default="", help="Service name (optional, accelerates lookup)")

    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()

    commands = {
        "suggest": cmd_suggest,
    }

    result = commands[args.command](args)
    json.dump(result, sys.stdout, indent=2, default=str)
    print()

    exit_code = 0 if result.get("status") in ("pass", "warning") else 1
    sys.exit(exit_code)


if __name__ == "__main__":
    main()

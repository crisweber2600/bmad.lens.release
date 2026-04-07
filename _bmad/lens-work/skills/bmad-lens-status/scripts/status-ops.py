#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["pyyaml>=6.0"]
# ///
"""Feature status operations — query feature, domain, and portfolio status from governance repo.

Reads feature.yaml from the plan branch for per-feature detail.
Reads feature-index.yaml from main for domain and portfolio views (no branch switching).
"""

import argparse
import json
import re
import sys
from pathlib import Path

import yaml

# Sanitization pattern for path-constructing identifiers
SAFE_ID_PATTERN = re.compile(r"^[a-z0-9][a-z0-9._-]{0,63}$")


def validate_identifier(value: str, field_name: str) -> str | None:
    """Validate that a path-constructing identifier is safe. Returns error message or None."""
    if not SAFE_ID_PATTERN.match(value):
        return (
            f"Invalid {field_name}: '{value}'. "
            f"Must match [a-z0-9][a-z0-9._-]{{0,63}} (lowercase alphanumeric, dots, hyphens, underscores)."
        )
    return None


def load_feature_index(governance_repo: str) -> tuple[dict | None, str | None]:
    """Load feature-index.yaml. Returns (data, error_message)."""
    index_path = Path(governance_repo) / "feature-index.yaml"
    if not index_path.exists():
        return None, f"feature-index.yaml not found: {index_path}"
    try:
        with open(index_path) as f:
            data = yaml.safe_load(f)
        return data or {}, None
    except yaml.YAMLError as e:
        return None, f"Failed to parse feature-index.yaml: {e}"
    except OSError as e:
        return None, f"Failed to read feature-index.yaml: {e}"


def cmd_feature(args: argparse.Namespace) -> dict:
    """Get detailed status for a specific feature. Reads feature.yaml directly (plan branch)."""
    for field_name, value in [
        ("feature-id", args.feature_id),
        ("domain", args.domain),
        ("service", args.service),
    ]:
        err = validate_identifier(value, field_name)
        if err:
            return {"status": "fail", "error": err}

    feature_path = (
        Path(args.governance_repo)
        / "features"
        / args.domain
        / args.service
        / args.feature_id
        / "feature.yaml"
    )

    if not feature_path.exists():
        return {"status": "fail", "error": f"Feature not found: {args.feature_id}"}

    try:
        with open(feature_path) as f:
            data = yaml.safe_load(f)
    except (yaml.YAMLError, OSError) as e:
        return {"status": "fail", "error": f"Failed to read feature.yaml: {e}"}

    if not data:
        return {"status": "fail", "error": f"Empty or unparseable feature.yaml for: {args.feature_id}"}

    context = data.get("context") or {}
    stale = bool(context.get("stale", False))

    return {
        "status": "pass",
        "feature": {
            "id": data.get("featureId", args.feature_id),
            "name": data.get("name", ""),
            "phase": data.get("phase", ""),
            "track": data.get("track", ""),
            "priority": data.get("priority", ""),
            "stale": stale,
            "team": data.get("team") or [],
            "updated_at": data.get("updated", ""),
            "domain": data.get("domain", args.domain),
            "service": data.get("service", args.service),
        },
    }


def cmd_domain(args: argparse.Namespace) -> dict:
    """Get all features in a domain. Reads feature-index.yaml on main only — no branch switching."""
    err = validate_identifier(args.domain, "domain")
    if err:
        return {"status": "fail", "error": err}

    index_data, error = load_feature_index(args.governance_repo)
    if error:
        return {"status": "fail", "error": error}

    all_features = index_data.get("features") or []
    domain_features = [f for f in all_features if f.get("domain") == args.domain]

    features_out = [
        {
            "id": f.get("featureId", ""),
            "status": f.get("status", ""),
            "owner": f.get("owner", ""),
            "summary": f.get("summary", ""),
            "phase": f.get("phase", ""),
            "stale": bool(f.get("stale", False)),
        }
        for f in domain_features
    ]

    return {
        "status": "pass",
        "domain": args.domain,
        "features": features_out,
        "total": len(features_out),
    }


def cmd_portfolio(args: argparse.Namespace) -> dict:
    """Get all active features. Reads feature-index.yaml on main only — no branch switching."""
    index_data, error = load_feature_index(args.governance_repo)
    if error:
        return {"status": "fail", "error": error}

    all_features = index_data.get("features") or []
    status_filter = args.status_filter

    if status_filter == "all":
        filtered = all_features
    elif status_filter == "archived":
        filtered = [f for f in all_features if f.get("status") == "archived"]
    else:  # active (default) — everything except archived
        filtered = [f for f in all_features if f.get("status") != "archived"]

    features_out = [
        {
            "id": f.get("featureId", ""),
            "domain": f.get("domain", ""),
            "service": f.get("service", ""),
            "status": f.get("status", ""),
            "owner": f.get("owner", ""),
            "summary": f.get("summary", ""),
            "phase": f.get("phase", ""),
            "stale": bool(f.get("stale", False)),
        }
        for f in filtered
    ]

    stale_count = sum(1 for f in features_out if f["stale"])

    return {
        "status": "pass",
        "total": len(features_out),
        "stale_count": stale_count,
        "features": features_out,
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Feature status operations — query feature, domain, and portfolio status.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s feature --governance-repo /path/to/repo --feature-id auth-login \\
    --domain platform --service identity

  %(prog)s domain --governance-repo /path/to/repo --domain platform

  %(prog)s portfolio --governance-repo /path/to/repo
  %(prog)s portfolio --governance-repo /path/to/repo --status-filter all
""",
    )

    subparsers = parser.add_subparsers(dest="command", required=True)

    # feature
    feature_p = subparsers.add_parser("feature", help="Get detailed status for a specific feature")
    feature_p.add_argument("--governance-repo", required=True, help="Path to governance repo root")
    feature_p.add_argument("--feature-id", required=True, help="Feature identifier")
    feature_p.add_argument("--domain", required=True, help="Domain name")
    feature_p.add_argument("--service", required=True, help="Service name")

    # domain
    domain_p = subparsers.add_parser("domain", help="Get all features in a domain from feature-index.yaml")
    domain_p.add_argument("--governance-repo", required=True, help="Path to governance repo root")
    domain_p.add_argument("--domain", required=True, help="Domain name to query")

    # portfolio
    portfolio_p = subparsers.add_parser("portfolio", help="Get all active features from feature-index.yaml")
    portfolio_p.add_argument("--governance-repo", required=True, help="Path to governance repo root")
    portfolio_p.add_argument(
        "--status-filter",
        choices=["all", "active", "archived"],
        default="active",
        help="Filter by status (default: active — excludes archived)",
    )

    return parser


def main():
    parser = build_parser()
    args = parser.parse_args()

    commands = {
        "feature": cmd_feature,
        "domain": cmd_domain,
        "portfolio": cmd_portfolio,
    }

    result = commands[args.command](args)
    json.dump(result, sys.stdout, indent=2, default=str)
    print()  # trailing newline

    exit_code = 0 if result.get("status") == "pass" else 1
    sys.exit(exit_code)


if __name__ == "__main__":
    main()

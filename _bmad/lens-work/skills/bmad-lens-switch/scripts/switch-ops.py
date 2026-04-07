#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["pyyaml>=6.0"]
# ///
"""Switch operations — manage active feature context for Lens agent sessions.

Reads feature-index.yaml (always from main) and feature.yaml files to validate
targets, load cross-feature context paths, and confirm feature switches.
"""

import argparse
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

import yaml


SAFE_ID_PATTERN = re.compile(r"^[a-z0-9][a-z0-9._-]{0,63}$")
MAX_INDEX_BYTES = 1_000_000  # 1 MB sanity cap on feature-index.yaml
STALE_DAYS = 30


def validate_identifier(value: str, field_name: str) -> str | None:
    """Validate that a path-constructing identifier is safe. Returns error message or None."""
    if not SAFE_ID_PATTERN.match(value):
        return (
            f"Invalid {field_name}: '{value}'. "
            f"Must match [a-z0-9][a-z0-9._-]{{0,63}} "
            f"(lowercase alphanumeric, dots, hyphens, underscores)."
        )
    return None


def load_feature_index(governance_repo: str) -> tuple[dict | None, str | None]:
    """Load feature-index.yaml from the governance repo root.

    Returns (data, error). On success error is None; on failure data is None.
    """
    index_path = Path(governance_repo) / "feature-index.yaml"
    if not index_path.exists():
        return None, f"feature-index.yaml not found at {index_path}"

    if index_path.stat().st_size > MAX_INDEX_BYTES:
        return None, f"feature-index.yaml exceeds size limit ({MAX_INDEX_BYTES} bytes)"

    try:
        with open(index_path) as f:
            data = yaml.safe_load(f)
    except yaml.YAMLError as e:
        return None, f"Failed to parse feature-index.yaml: {e}"
    except OSError as e:
        return None, f"Failed to read feature-index.yaml: {e}"

    if not isinstance(data, dict):
        return None, "feature-index.yaml must be a YAML mapping"

    return data, None


def find_feature_yaml(governance_repo: str, feature_id: str) -> Path | None:
    """Find feature.yaml by scanning all domains/services under features/."""
    features_dir = Path(governance_repo) / "features"
    if not features_dir.exists():
        return None
    for yaml_file in sorted(features_dir.rglob("feature.yaml")):
        try:
            with open(yaml_file) as f:
                data = yaml.safe_load(f)
            if data and data.get("featureId") == feature_id:
                return yaml_file
        except (yaml.YAMLError, OSError):
            continue
    return None


def is_stale(feature_data: dict) -> bool:
    """Return True if the feature has not been updated in STALE_DAYS days."""
    updated = feature_data.get("updated", "")
    if not updated or not isinstance(updated, str):
        return False
    try:
        dt = datetime.fromisoformat(updated.replace("Z", "+00:00"))
        return (datetime.now(timezone.utc) - dt).days > STALE_DAYS
    except ValueError:
        return False


def build_context_paths(
    feature_data: dict,
    index_by_id: dict[str, dict],
) -> tuple[list[str], list[str]]:
    """Derive cross-feature context paths from dependencies.

    Returns (summaries, full_docs):
      - summaries: summary.md paths for 'related' features
      - full_docs: tech-plan.md paths for 'depends_on' and 'blocks' features
    """
    deps = feature_data.get("dependencies") or {}
    depends_on: list[str] = deps.get("depends_on") or []
    related: list[str] = deps.get("related") or []
    blocks: list[str] = deps.get("blocks") or []

    full_doc_ids = list(dict.fromkeys(depends_on + blocks))
    # related features not already in full_doc_ids get summaries only
    summary_ids = [fid for fid in related if fid not in full_doc_ids]

    summaries: list[str] = []
    for fid in summary_ids:
        entry = index_by_id.get(fid)
        if entry:
            d = entry.get("domain", "")
            s = entry.get("service", "")
            summaries.append(f"features/{d}/{s}/{fid}/summary.md")

    full_docs: list[str] = []
    for fid in full_doc_ids:
        entry = index_by_id.get(fid)
        if entry:
            d = entry.get("domain", "")
            s = entry.get("service", "")
            full_docs.append(f"features/{d}/{s}/{fid}/tech-plan.md")

    return summaries, full_docs


def cmd_list(args: argparse.Namespace) -> dict:
    """List features from feature-index.yaml with optional status filter."""
    index_data, err = load_feature_index(args.governance_repo)
    if err:
        return {"status": "fail", "error": err}

    raw_features: list[dict] = index_data.get("features") or []

    status_filter: str = args.status_filter
    if status_filter != "all":
        raw_features = [
            f for f in raw_features if f.get("status", "active") == status_filter
        ]

    features = [
        {
            "id": f.get("id", ""),
            "domain": f.get("domain", ""),
            "service": f.get("service", ""),
            "status": f.get("status", "active"),
            "owner": f.get("owner", ""),
            "summary": f.get("summary", ""),
        }
        for f in raw_features
    ]

    return {"status": "pass", "features": features, "total": len(features)}


def cmd_switch(args: argparse.Namespace) -> dict:
    """Validate and prepare context for switching to a feature."""
    err = validate_identifier(args.feature_id, "feature-id")
    if err:
        return {"status": "fail", "error": err}

    index_data, err = load_feature_index(args.governance_repo)
    if err:
        return {"status": "fail", "error": err}

    raw_features: list[dict] = index_data.get("features") or []
    index_by_id = {f.get("id"): f for f in raw_features if f.get("id")}

    index_entry = index_by_id.get(args.feature_id)
    if not index_entry:
        return {
            "status": "fail",
            "error": f"Feature '{args.feature_id}' not found in feature-index.yaml",
        }

    feature_path = find_feature_yaml(args.governance_repo, args.feature_id)
    if not feature_path:
        return {
            "status": "fail",
            "error": f"feature.yaml not found for '{args.feature_id}'",
        }

    try:
        with open(feature_path) as f:
            feature_data = yaml.safe_load(f)
    except (yaml.YAMLError, OSError) as e:
        return {"status": "fail", "error": f"Failed to read feature.yaml: {e}"}

    if not isinstance(feature_data, dict):
        return {"status": "fail", "error": "feature.yaml is not a valid YAML mapping"}

    summaries, full_docs = build_context_paths(feature_data, index_by_id)

    return {
        "status": "pass",
        "feature": {
            "id": args.feature_id,
            "name": feature_data.get("name", ""),
            "domain": feature_data.get("domain", ""),
            "service": feature_data.get("service", ""),
            "phase": feature_data.get("phase", ""),
            "track": feature_data.get("track", ""),
            "priority": feature_data.get("priority", ""),
            "status": index_entry.get("status", "active"),
            "owner": index_entry.get("owner", ""),
            "stale": is_stale(feature_data),
            "updated": str(feature_data.get("updated", "")),
        },
        "context_to_load": {
            "summaries": summaries,
            "full_docs": full_docs,
        },
    }


def cmd_context_paths(args: argparse.Namespace) -> dict:
    """Get file paths needed for cross-feature context for a given feature."""
    err = validate_identifier(args.feature_id, "feature-id")
    if err:
        return {"status": "fail", "error": err}

    # Prefer direct path using provided domain/service; fall back to scan
    direct_path = (
        Path(args.governance_repo)
        / "features"
        / args.domain
        / args.service
        / args.feature_id
        / "feature.yaml"
    )
    if direct_path.exists():
        feature_path: Path | None = direct_path
    else:
        feature_path = find_feature_yaml(args.governance_repo, args.feature_id)

    if not feature_path:
        return {
            "status": "fail",
            "error": f"Feature '{args.feature_id}' not found",
        }

    try:
        with open(feature_path) as f:
            feature_data = yaml.safe_load(f)
    except (yaml.YAMLError, OSError) as e:
        return {"status": "fail", "error": f"Failed to read feature.yaml: {e}"}

    if not isinstance(feature_data, dict):
        return {"status": "fail", "error": "feature.yaml is not a valid YAML mapping"}

    # Load index for domain/service lookups of dependency features
    index_data, _ = load_feature_index(args.governance_repo)
    index_by_id: dict[str, dict] = {}
    if index_data:
        for f in (index_data.get("features") or []):
            if f.get("id"):
                index_by_id[f["id"]] = f

    summaries, full_docs = build_context_paths(feature_data, index_by_id)

    return {"status": "pass", "summaries": summaries, "full_docs": full_docs}


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Switch operations — manage active feature context.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s list --governance-repo /path/to/repo/
  %(prog)s list --governance-repo /path/to/repo/ --status-filter all

  %(prog)s switch --governance-repo /path/to/repo/ --feature-id auth-login

  %(prog)s context-paths --governance-repo /path/to/repo/ \\
    --feature-id auth-login --domain platform --service identity
""",
    )

    subparsers = parser.add_subparsers(dest="command", required=True)

    # list
    list_p = subparsers.add_parser("list", help="List features from feature-index.yaml")
    list_p.add_argument("--governance-repo", required=True, help="Governance repo root path")
    list_p.add_argument(
        "--status-filter",
        default="active",
        choices=["all", "active", "archived"],
        help="Filter by feature status (default: active)",
    )

    # switch
    switch_p = subparsers.add_parser("switch", help="Validate and prepare context for a feature switch")
    switch_p.add_argument("--governance-repo", required=True, help="Governance repo root path")
    switch_p.add_argument("--feature-id", required=True, help="Target feature identifier")

    # context-paths
    ctx_p = subparsers.add_parser("context-paths", help="Get cross-feature context file paths")
    ctx_p.add_argument("--governance-repo", required=True, help="Governance repo root path")
    ctx_p.add_argument("--feature-id", required=True, help="Feature identifier")
    ctx_p.add_argument("--domain", required=True, help="Feature domain")
    ctx_p.add_argument("--service", required=True, help="Feature service")

    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()

    commands = {
        "list": cmd_list,
        "switch": cmd_switch,
        "context-paths": cmd_context_paths,
    }

    result = commands[args.command](args)
    json.dump(result, sys.stdout, indent=2, default=str)
    print()

    sys.exit(0 if result.get("status") in ("pass", "warning") else 1)


if __name__ == "__main__":
    main()

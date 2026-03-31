---
name: 'step-01-preflight'
description: 'Run shared preflight and resolve initiative, scan path, and governance context'
nextStepFile: './step-02-scan-repos.md'
preflightInclude: '../../../includes/preflight.md'
---

# Step 1: Preflight And Discovery Context

**Goal:** Resolve the active initiative, compute the repo scan path for its domain/service, and locate the governance repo before discovery begins.

---

## EXECUTION SEQUENCE

### 1. Resolve Initiative And Paths

```yaml
invoke: include
path: "{preflightInclude}"

initiative_state = invoke: git-state.current-initiative
initiative = load(initiative_state.config_path)

if initiative.domain == null or initiative.service == null:
  FAIL("❌ No active service initiative found. Run `/new-service` or `/switch` first.")

profile = load_if_exists("_bmad-output/lens-work/personal/profile.yaml")
governance_setup = load_if_exists("_bmad-output/lens-work/governance-setup.yaml")

target_projects_path = profile.target_projects_path || "TargetProjects"
scan_path = "${target_projects_path}/${initiative.domain}/${initiative.service}"
governance_repo_path = governance_setup.governance_repo_path || profile.governance_repo_path || "${target_projects_path}/lens/lens-governance"

if not directory_exists(scan_path):
  FAIL("❌ Scan path does not exist: ${scan_path}")

if not directory_exists(governance_repo_path):
  FAIL("❌ Governance repo not found. Run `/onboard` to configure it first.")

resolver_result = {
  domain: initiative.domain,
  service: initiative.service,
  scan_path: scan_path,
  governance_repo_path: governance_repo_path,
  initiative_root: initiative.initiative_root
}
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`
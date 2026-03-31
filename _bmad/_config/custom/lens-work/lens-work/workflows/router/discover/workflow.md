---
name: discover
description: "Discover cloned repos under TargetProjects, inspect for BMAD config, update governance inventory, create /switch branches, and report results"
agent: "@lens"
trigger: /discover command
aliases: [/disc]
category: router
phase_name: discover
display_name: Discover
imports: lifecycle.yaml
entryStep: './steps/step-01-preflight.md'
---

# /discover - Repo Discovery Router

**Goal:** Resolve the active initiative's scan path, inspect the cloned repos under that service, synchronize governance inventory and control-repo branch helpers, and render a discovery report.

**Your Role:** Operate as the repo-discovery coordinator. Preserve per-repo isolation, keep the discovery order deterministic, and update the governance and control-repo metadata without losing existing inventory data.

---

## WORKFLOW ARCHITECTURE

This workflow uses **step-file architecture**:

- Step 1 resolves the initiative, scan path, and governance repo.
- Step 2 discovers repos and syncs each repo to its most recent branch.
- Step 3 inspects each repo for BMAD config and detects its primary language.
- Step 4 updates governance inventory and creates control-repo `/switch` branches.
- Step 5 handles optional context/documentation generation, updates initiative language, and reports results.

State persists through `resolver_result`, `discovered_repos`, `repo_results`, `governance_summary`, and `branch_summary`.

---

## EXECUTION

Read fully and follow: `{entryStep}`

### Step Map

1. `step-01-preflight.md` - Preflight and initiative/governance path resolution
2. `step-02-scan-repos.md` - Repo discovery and branch synchronization
3. `step-03-inspect-repos.md` - BMAD inspection and language detection
4. `step-04-governance-and-branches.md` - Governance inventory updates and `/switch` branch creation
5. `step-05-report.md` - Optional docs/context handling, initiative language update, and final report

# Workflow Plan: discover

## Goal

Inspect cloned service repos, update governance inventory and switch-navigation branches, and leave the initiative with a discovery report and enriched repo metadata.

## Step Structure

1. `steps/step-01-preflight.md`
   - Run shared preflight
   - Resolve initiative, scan path, and governance repo path
2. `steps/step-02-scan-repos.md`
   - Enumerate git repos under the service scan path
   - Fetch and check out the most recent branch per repo
3. `steps/step-03-inspect-repos.md`
   - Detect `.bmad` presence
   - Detect the primary language per repo
4. `steps/step-04-governance-and-branches.md`
   - Update `repo-inventory.yaml`
   - Create or verify control-repo `/switch` branches
5. `steps/step-05-report.md`
   - Run optional context/documentation generation
   - Update initiative language when possible
   - Render the discovery report

## Key State

- `resolver_result`
- `discovered_repos`
- `repo_results`
- `governance_summary`
- `branch_summary`

## Output Artifacts

- Updated governance `repo-inventory.yaml`
- Control-repo helper branches for `/switch`
- Discovery report summarizing repo state and optional generated docs
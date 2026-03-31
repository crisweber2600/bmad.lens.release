---
name: 'step-02-auth-and-governance'
description: 'Validate authentication and resolve the governance repo'
nextStepFile: './step-03-profile-and-bootstrap.md'
governanceSetupPath: '{project-root}/_bmad-output/lens-work/governance-setup.yaml'
profilePath: '{project-root}/_bmad-output/lens-work/personal/profile.yaml'
---

# Step 2: Authentication And Governance

**Goal:** Verify provider authentication without handling secrets in chat, then resolve the governance repo path and ensure the repo exists locally.

---

## EXECUTION SEQUENCE

### 1. Validate Authentication

```yaml
auth_status = invoke: provider-adapter.validate-auth

if auth_status.authenticated != true:
  output: |
    ⚠️ Provider authentication is not ready.

    Run the credential bootstrap script outside this chat, restart your terminal, and rerun `/onboard`.
  FAIL("❌ Authentication is required before onboarding can continue.")
```

### 2. Resolve Governance Repo

```yaml
governance_setup = load_if_exists("{governanceSetupPath}")
profile = load_if_exists("{profilePath}")

governance_repo_path = governance_setup.governance_repo_path || profile.governance_repo_path || "TargetProjects/lens/lens-governance"
governance_remote_url = governance_setup.governance_remote_url || profile.governance_repo_url || auth_status.default_governance_remote || ""

if not directory_exists(governance_repo_path):
  if governance_remote_url == "":
    ask: "Provide the governance repo remote URL so /onboard can clone it."
    capture: governance_remote_url

  invoke_command("git clone ${governance_remote_url} ${governance_repo_path}")

if not file_exists("${governance_repo_path}/repo-inventory.yaml"):
  FAIL("❌ repo-inventory.yaml not found in the governance repo. Add it before onboarding can bootstrap TargetProjects.")

output: |
  ✅ Governance repo ready
  ├── Path: ${governance_repo_path}
  └── Inventory: ${governance_repo_path}/repo-inventory.yaml
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`
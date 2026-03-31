---
name: onboard
description: Bootstrap a user profile, governance repo, and target-project clone inventory
agent: "@lens"
trigger: /onboard command
category: utility
phase_name: utility
display_name: Onboard
entryStep: './steps/step-01-preflight.md'
---

# /onboard - User Bootstrap Workflow

**Goal:** Validate control-repo prerequisites, establish non-secret user configuration, bootstrap governance and TargetProjects clones, and report onboarding health.

**Your Role:** Operate as the control-repo bootstrapper. Detect provider context, validate authentication without handling secrets in chat, repair missing local prerequisites when safe, and leave the user with a working lens-work environment.

---

## WORKFLOW ARCHITECTURE

This workflow uses **step-file architecture**:

- Step 1 validates the workspace, remote, and provider context.
- Step 2 validates authentication and resolves the governance repo.
- Step 3 writes the non-secret profile and bootstraps TargetProjects clones from inventory.
- Step 4 runs the final health check and reports the next command.

State persists through `remote_url`, `provider`, `auth_status`, `governance_repo_path`, `governance_remote_url`, `profile_path`, `clone_results`, and `health_checks`.

---

## EXECUTION

Read fully and follow: `{entryStep}`

### Step Map

1. `step-01-preflight.md` - Preflight, remote detection, and provider context
2. `step-02-auth-and-governance.md` - Authentication validation and governance repo resolution
3. `step-03-profile-and-bootstrap.md` - Profile creation and TargetProjects bootstrap
4. `step-04-health-and-report.md` - Health verification and onboarding summary

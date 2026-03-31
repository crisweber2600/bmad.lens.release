---
name: 'step-01-preflight'
description: 'Run shared preflight and initialize provider context for onboarding'
nextStepFile: './step-02-auth-and-governance.md'
preflightInclude: '../../../includes/preflight.md'
---

# Step 1: Preflight And Provider Context

**Goal:** Confirm the control repo can run onboarding, then detect the provider context from the configured origin remote.

---

## EXECUTION SEQUENCE

### 1. Shared Preflight And Remote Validation

```yaml
invoke: include
path: "{preflightInclude}"

remote_url = invoke_command("git remote get-url origin")

if remote_url == null or trim(remote_url) == "":
  FAIL("❌ No git remote found. Add `origin` before running /onboard.")

provider_result = invoke: provider-adapter.detect-provider
params:
  remote_url: ${remote_url}

provider = provider_result.provider || provider_result.name || "unknown"

output: |
  🧭 Onboarding initialized
  ├── Remote: ${remote_url}
  └── Provider: ${provider}
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`
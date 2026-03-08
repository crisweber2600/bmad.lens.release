# Workflow: Resolve Constitution

**Module:** lens-work
**Type:** Governance workflow
**Trigger:** Called internally by compliance-check workflow and promotion workflow

---

## Purpose

Resolve the effective constitution for an initiative by merging the 4-level governance hierarchy. This is a supporting workflow that wraps the `constitution` skill's `resolve-constitution` operation.

## Workflow Steps

### Step 1: Determine Initiative Context

1. Use `git-state` skill → `current-initiative` to get the initiative root
2. Parse domain, service, and repo from the initiative root
3. Determine language (from initiative config if available)

### Step 2: Invoke Constitution Resolution

1. Call `constitution` skill → `resolve-constitution` with:
   - `domain`: parsed domain
   - `service`: parsed service
   - `repo`: parsed repo (optional)
   - `language`: detected language (optional)
2. Receive resolved constitution

### Step 3: Return Result

Return the resolved constitution to the calling workflow (compliance-check or audience-promotion).

## Error Handling

| Error | Response |
|-------|----------|
| Governance repo not found | `❌ Governance repo not accessible. Run /onboard to verify.` |
| Org-level constitution missing | `❌ Org-level constitution is required. Check governance repo setup.` |
| Invalid constitution format | Use parent level defaults with warning |

## Key Constraints

- Read-only — never writes to governance repo
- Deterministic — identical inputs always produce identical output (NFR3)
- Additive inheritance — lower levels add requirements, never remove

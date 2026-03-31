---
name: 'step-05-report'
description: 'Finish optional enrichment, update initiative language, and render the discovery summary'
---

# Step 5: Discovery Report

**Goal:** Finalize any optional enrichment signals, update the initiative language when a clear dominant language exists, and report the discovery results back to the user.

---

## EXECUTION SEQUENCE

### 1. Update Initiative Language When Possible

```yaml
known_languages = unique(filter(map(repo_results, item -> item.language), value -> value != null and value != "unknown"))

if known_languages.length == 1:
  invoke: state-management.update-initiative
  params:
    initiative_id: ${resolver_result.initiative_root}
    updates:
      language: ${known_languages[0]}

output: |
  ✅ /discover complete
  ├── Repos discovered: ${repo_results.length}
  ├── Governance updates: ${governance_summary.updated}
  ├── Switch branches created: ${branch_summary.created}
  └── Next: Run `/switch` to move onto a discovered repo helper branch.
```
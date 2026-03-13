# PR Include: Sensing Report

**Usage:** Included in promotion PR bodies by the audience-promotion workflow.

---

## Cross-Initiative Sensing

### Template: Overlaps Found

```markdown
## Cross-Initiative Sensing

⚠️ Active initiatives in domain `{domain}`:

| Initiative | Phase | Audience | Conflict Level | Reason |
|------------|-------|----------|---------------|--------|
| `{init-1}` | {phase} | {audience} | 🔴 High | Same service — scope overlap |
| `{init-2}` | {phase} | {audience} | 🟡 Medium | Same domain |

{if constitution hard gate}
### ⚠️ REQUIRES EXPLICIT CONFLICT REVIEW
Constitution requires explicit conflict resolution for domain `{domain}`.
Reviewer must confirm no destructive overlap before merging.
{end if}

{if informational (default)}
### Informational
Review overlapping initiatives for potential coordination needs.
{end if}
```

### Template: No Overlaps

```markdown
## Cross-Initiative Sensing

No overlapping initiatives detected ✅

Scanned {count} active initiative(s) across all domains.
```

## Integration Notes

- This section is ALWAYS present in promotion PRs, even when no overlaps are found
- The sensing skill produces the data; this include defines the PR body format
- Constitution can upgrade sensing from informational to hard gate per domain/service
- When hard gate: add explicit review requirement banner
- When informational: show as advisory section

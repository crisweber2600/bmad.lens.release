---
name: 'step-04-render-report'
description: 'Render the compact summary table and optional detailed initiative view'
---

# Step 4: Render Status Output

**Goal:** Present the initiative status report in a compact table first, then expand into detail when the interaction warrants it.

---

## EXECUTION SEQUENCE

## CONTEXT BOUNDARIES

- Render the report directly from `status_rows` and `detail_rows`.
- Keep the default output within the five-column summary-table constraint.

### 1. Render The Summary Table

```yaml
summary_rows = map(status_rows, row -> "| " + (row.is_current ? "► " : "") + row.initiative + " | " + (row.phase || "-") + " | " + (row.audience || "-") + " | " + row.prs + " | " + row.action + " |")

output: |
  📊 Initiative Status Report

  | Initiative | Phase | Audience | PRs | Action |
  |------------|-------|----------|-----|--------|
  ${summary_rows.join("\n")}

  Status indicators:
  - ✅ phase complete
  - ⏳ PR open or awaiting review
  - ▶ current initiative row
```

### 2. Render Detailed View When Needed

```yaml
if detail_rows.length > 0:
  for row in detail_rows:
    output: |
      📂 Initiative: ${row.initiative}
      🏷️ Track: ${row.track != null ? row.track : "(not set)"}
      👥 Audience: ${row.audience}
      📋 Completed Phases: ${row.completed_phases.join(", ")}
      ⏳ Current Phase: ${row.phase}
      📝 Open PRs: ${row.prs}
      🔄 Pending: ${row.action}
```

### 3. Close With The Execution Hint

```yaml
output: "Use `/next` for the active initiative when you want the recommended next command."
```

## SUCCESS CRITERIA

- The summary table contains one rendered row per initiative.
- Detailed output appears only when requested or when a single initiative exists.
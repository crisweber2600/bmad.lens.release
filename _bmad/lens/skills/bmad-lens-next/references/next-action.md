# Next Action Reference

## Recommendation Rules

The `suggest` subcommand derives one recommendation from feature state. Rules apply in
priority order — the first matching rule wins.

### Priority Order

1. **Hard gates (blockers)** — missing required milestones for the current phase block promotion
2. **Stale context** — a warning (not a blocker) to fetch fresh context before proceeding
3. **Open issues** — a warning when more than 3 issues are open
4. **Phase-based recommendation** — the canonical action for each phase

### Phase → Action Map

| Phase | Action | Command | Rationale |
|-------|--------|---------|-----------|
| preplan | quickplan | `/quickplan` | Feature is initialized — start the planning process |
| businessplan | continue-businessplan | `/quickplan` | Business plan in progress — continue |
| techplan | continue-techplan | `/techplan` | Tech plan in progress — continue |
| sprintplan | continue-sprintplan | `/sprintplan` | Sprint plan in progress — continue |
| dev | dev-next-story | `/dev-story` | Feature is in dev — implement the next story |
| complete | retrospective | `/retrospective` | Feature is complete — capture learnings |
| paused | resume | `/resume` | Feature is paused — decide whether to resume or close |

### Blockers (Hard Gates)

A blocker surfaces when a required milestone for the current phase was not completed:

| Phase | Required Milestone | Blocker Message |
|-------|--------------------|-----------------|
| techplan | `milestones.businessplan` | Business plan milestone not completed |
| sprintplan | `milestones.techplan` | Tech plan milestone not completed |
| dev | `milestones.sprintplan` | Sprint plan milestone not completed |
| complete | `milestones.dev-complete` | Dev-complete milestone not set |

### Warnings

- `context.stale=true` → `"context.stale — consider fetching fresh context first"`
- `len(links.issues) > 3` → `"{N} open issues — consider reviewing before proceeding"`

## Output Format

```json
{
  "status": "pass",
  "featureId": "auth-login",
  "phase": "preplan",
  "track": "quickplan",
  "path": "/path/to/feature.yaml",
  "recommendation": {
    "action": "quickplan",
    "rationale": "Feature is in preplan phase with feature.yaml created — ready to start planning",
    "command": "/quickplan",
    "blockers": [],
    "warnings": []
  }
}
```

## Error Cases

| Condition | Status | Exit Code |
|-----------|--------|-----------|
| Feature not found | fail | 1 |
| Invalid feature-id (unsafe characters) | fail | 1 |
| Feature YAML unreadable | fail | 1 |

---
name: 'step-01-log'
description: 'Load initiative context, collect problem details, append to problems.md, and commit'
nextStepFile: null
preflightInclude: '../../../includes/preflight.md'
lifecycleContract: '../../../../lifecycle.yaml'
---

# Step 1: Log Problem

**Goal:** Collect problem details from the user and append a structured entry to the initiative's problems.md file.

---

## EXECUTION SEQUENCE

### 1. Load Initiative Context

```yaml
invoke: include
path: "{preflightInclude}"
params:
  skip_constitution: true

initiative_state = invoke: git-state.current-initiative
initiative = load(initiative_state.config_path)
lifecycle = load("{lifecycleContract}")

initiative_root = initiative.initiative_root
current_phase = initiative_state.current_phase || "unknown"

# Resolve problem log path from lifecycle convention
problem_log_path = lifecycle.problem_logging.file_pattern
  .replace("{domain}", initiative.domain || "default")
  .replace("{service}", initiative.service || "default")

# v3.4: 2-branch topology writes to governance repo feature directory
if session.feature_yaml_context != null and session.feature_yaml_context.enabled == true:
  governance_path = session.governance_repo_path || ""
  if governance_path != "":
    problem_log_path = "${governance_path}/features/${initiative.domain}/${initiative.service}/${initiative_root}/problems.md"
```

### 2. Collect Problem Details

Ask the user for problem details. Accept free-form input and structure it:

```
📝 Log Problem for: ${initiative_root}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Current phase: ${current_phase}

Please describe the problem. I'll ask follow-up questions to fill in details.

Required:
  1. Title (short description)
  2. Severity: blocker | warning | note
  3. Description (what happened, impact)

Optional:
  4. Category: process | tooling | planning | communication | technical | governance
```

```yaml
problem = {
  id: generate_problem_id(),  # e.g., "P-001" based on existing count
  title: user_provided_title,
  severity: user_provided_severity,     # blocker | warning | note
  phase: current_phase,
  date: current_date,
  description: user_provided_description,
  category: user_provided_category || "uncategorized",
  status: "open"
}
```

### 3. Format And Append Entry

```yaml
# Format using lifecycle.yaml entry_format convention
entry = format_problem_entry(problem, lifecycle.problem_logging.entry_format)

# Ensure directory exists
ensure_directory(dirname(problem_log_path))

# Append to problems.md (create if it doesn't exist)
if not file_exists(problem_log_path):
  create_file(problem_log_path, "# Problems Log\n\n")

append_to_file(problem_log_path, entry)
```

### 4. Commit

```yaml
invoke: git-orchestration.commit-artifacts
params:
  file_paths:
    - ${problem_log_path}
  phase: "PROBLEM:LOGGED"
  initiative: ${initiative_root}
  description: "[${problem.severity}] ${problem.title}"
```

### 5. Confirmation

```
✅ Problem Logged
━━━━━━━━━━━━━━━━
ID:       ${problem.id}
Severity: ${problem.severity}
Phase:    ${problem.phase}
Title:    ${problem.title}
File:     ${problem_log_path}

This problem will be included in the /retrospective report.
Log another? Type /log-problem or continue your work.
```

---

## Error Handling

| Error | Cause | Action |
|-------|-------|--------|
| No active initiative | User not on an initiative branch | Show: "Switch to an initiative branch first. Run `/switch` to select one." |
| initiative-state.yaml missing | Branch exists but config absent | Show: "Initiative config not found. Run `/status` to diagnose." |
| problem_logging not in lifecycle.yaml | Schema mismatch | Show: "Problem logging schema not found in lifecycle.yaml. Run `/lens-upgrade`." |
| Commit fails | Dirty working tree or conflict | Show the git error and suggest: "Resolve conflicts, then retry `/log-problem`." |

## WORKFLOW COMPLETE

This is a single-step utility workflow. No further steps.

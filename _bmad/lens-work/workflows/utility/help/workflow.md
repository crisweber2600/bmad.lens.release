# /help — Command Reference Workflow

**Phase:** Utility
**Purpose:** Display all available @lens commands grouped by category with descriptions, usage examples, and first-time user guidance.

## Pre-conditions

- lens-work module is installed

## Steps

### Step 1: Detect User Context

Check if the user is a first-time user (no `profile.yaml`):

```bash
test -f _bmad-output/lens-work/profile.yaml
```

- **First-time user:** Show extended introduction before command list.
- **Returning user:** Show command list directly.

### Step 2: First-Time User Introduction (if applicable)

```
👋 Welcome to LENS Workbench!

LENS manages your planning lifecycle from idea to implementation using
git-native workflows. Everything is derived from git — branches are
your state, PRs are your gates, and lifecycle.yaml is your contract.

**Getting started:**
1. Run `/onboard` to authenticate and set up your profile
2. Run `/new-domain {name}` to create your first initiative
3. Run `/next` anytime to see what to do next

Here are all the commands available:
```

### Step 3: Read Command Registry

Load `module-help.csv` from the lens-work module root to get the canonical command list.

### Step 4: Display Commands by Category

```
📖 @lens Command Reference

━━━ 🚀 Lifecycle ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /preplan          Start PrePlan phase — brainstorm, research, product brief
                    Usage: /preplan

  /businessplan     Start BusinessPlan phase — PRD creation, UX design
                    Usage: /businessplan

  /techplan         Start TechPlan phase — architecture, technical decisions
                    Usage: /techplan

  /devproposal      Start DevProposal phase — epics, stories, readiness check
                    Usage: /devproposal

  /sprintplan       Start SprintPlan phase — sprint-status, story files
                    Usage: /sprintplan

  /dev              Start Dev phase — hand off to implementation agents
                    Usage: /dev

━━━ 🧭 Navigation ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /new-domain       Create a new domain-level initiative
                    Usage: /new-domain {domain-name}

  /new-service      Create a new service-level initiative within a domain
                    Usage: /new-service {domain}/{service-name}

  /new-feature      Create a new feature-level initiative within a service
                    Usage: /new-feature {domain}/{service}/{feature-name}

  /switch           Switch to a different initiative
                    Usage: /switch [initiative-name]

  /status           Show all active initiatives and their state
                    Usage: /status

  /next             Get recommended next action
                    Usage: /next

━━━ 🛡️ Governance ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /promote          Promote current audience to next level with gate checks
                    Usage: /promote

  /sense            Run cross-initiative overlap detection on demand
                    Usage: /sense

━━━ 🔧 Utility ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /onboard          Bootstrap control repo — detect provider, validate auth
                    Usage: /onboard

  /help             Show this command reference
                    Usage: /help
```

### Step 5: Handle Invalid Commands

If the user typed an unrecognized command, find the closest valid command:

**Matching strategy:**
1. Exact prefix match (e.g., `/pre` → `/preplan`)
2. Fuzzy match by string similarity (e.g., `/bussiness` → `/businessplan`)
3. Category suggestion if no close match

**Response:**
```
❓ Unknown command: `/{input}`
   Did you mean `/preplan`?

   Run `/help` to see all available commands.
```

### Step 6: Display Footer

```
💡 Tip: Run `/next` anytime to see your recommended next action.
```

## Design Principles

- Direction C (Conversational Narrative) — warmth and clarity
- First-time users get extended explanation, not jargon
- Invalid commands get closest suggestion, not "command not found"
- All ~16 user touchpoints documented
- Categories group related commands for discoverability

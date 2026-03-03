---
name: onboarding
description: Create profile + run bootstrap
agent: "@lens/discovery"
trigger: '@lens onboard or @lens-work onboard'
category: utility
first_run: true
---

# Onboarding Workflow

**Purpose:** Create user profile and bootstrap TargetProjects for new team members.

---

## Execution Sequence

### 1. Welcome

```
🔭 Welcome to LENS Workbench!

I'm LENS, your setup guide. I'll help you:
1. Create your profile
2. Set up your TargetProjects

This takes about 3-5 minutes. Let's get started!
```

### 2. Create Profile

```yaml
output: |
  📝 Creating your profile from git config...

name = git_config("user.name")
email = git_config("user.email")

output: |
  Using: ${name} <${email}>

# Load domains from repo inventory
inventory = load_yaml("_bmad-output/lens-work/repo-inventory.yaml")
domains = []
for repo in inventory.repos.matched:
  domain = repo.domain
  if domain not in domains:
    domains.append(domain)

# Single prompt for role, scope, AND PAT setup
output: |
  
  **Profile Setup**
  
  What's your role?
  [1] Developer
  [2] Tech Lead
  [3] Architect
  [4] Product Owner
  [5] Scrum Master
  
  What domain/team do you work on?
for i, domain in enumerate(domains):
  output: "[${i+6}] ${domain}"
output: "[${len(domains)+6}] all (full access to all domains)"

output: |
  
  Set up GitHub PAT now?
  [Y]es - I'll run the secure script in my terminal
  [N]o  - Skip for now (you can run it anytime later)
  
  Enter three values separated by space (role domain pat):
  Example: "3 ${len(domains)+6} Y" = Architect + all domains + set up PAT

user_input = prompt_user()
parts = user_input.split()
role = parts[0]
scope_choice = parts[1]
pat_choice = parts[2] if len(parts) > 2 else "N"

if scope_choice == str(len(domains)+6):
  scope = "all"
else:
  scope = domains[int(scope_choice) - 6]

# Detect unique GitHub domains from repo inventory
github_domains = set()
for repo in inventory.repos.matched:
  if repo.remote:
    # Extract domain from URL (e.g., github.com or github.enterprise.com)
    if "github.com/" in repo.remote:
      github_domains.add("github.com")
    elif "github" in repo.remote:
      # Extract custom GitHub Enterprise domain
      match = re.match(r"https?://([^/]+)/", repo.remote)
      if match:
        github_domains.add(match.group(1))

github_domains = sorted(list(github_domains))

# ── PAT detection: existence-only checks ────────────────────────────────
# SECURITY: Only test whether env vars EXIST.
# NEVER read, print, or store PAT values — that would expose secrets
# in the LLM context window.
#
# Lookup order (matches promote-branch scripts):
#   github.com:  GITHUB_PAT -> GH_TOKEN
#   enterprise:  GH_ENTERPRISE_TOKEN -> GH_TOKEN

covered_domains = []
uncovered_domains = []

for domain in github_domains:
  if domain == "github.com":
    if env_exists("GITHUB_PAT") or env_exists("GH_TOKEN"):
      covered_domains.append(domain)
      continue
  else:
    if env_exists("GH_ENTERPRISE_TOKEN") or env_exists("GH_TOKEN"):
      covered_domains.append(domain)
      continue
  uncovered_domains.append(domain)

# Report what was found
if covered_domains.length > 0:
  output: |
    
    GitHub PAT Status
    
    Already configured (environment variable):
  for domain in covered_domains:
    output: "  [OK] ${domain}"

if uncovered_domains.length == 0:
  output: |
    
    All ${len(github_domains)} GitHub domain(s) have PATs configured.
    Skipping PAT setup.
  pat_choice = "N"   # Nothing to do — skip the setup prompt

else:
  output: |
    
    GitHub Personal Access Tokens Setup
    
    SECURITY WARNING:
    PATs should NEVER be entered into Copilot, Claude, or any LLM chat.
    
    Missing PATs for ${len(uncovered_domains)} domain(s):
  for domain in uncovered_domains:
    output: "  [!!] ${domain}"

  output: |
    
    You can provide PATs via environment variables:
      github.com  -> set GITHUB_PAT or GH_TOKEN
      enterprise  -> set GH_ENTERPRISE_TOKEN or GH_TOKEN
    
    Or run the secure storage script (sets environment variables automatically).

if pat_choice.lower() in ["y", "yes"] and uncovered_domains.length > 0:
  output: |
    
    Perfect! Please copy and run this command in a NEW TERMINAL WINDOW:
    
    Copy this entire command:
    
    cd "${PROJECT_ROOT}" && bash _bmad/lens-work/scripts/store-github-pat.sh
    
    On Windows with PowerShell:
    cd "${PROJECT_ROOT}"; .\\_bmad\\lens-work\\scripts\\store-github-pat.ps1
    
    The script will:
    - Run outside of LLM context for security
    - Prompt for PAT for each domain
    - Set environment variables (GITHUB_PAT / GH_ENTERPRISE_TOKEN)
    - Verify the env vars were stored correctly
    
    **Send "Continue" when ready...**
  
  wait_for_user = prompt_user()
  
  # Check if env vars were set by the script
  # SECURITY: existence check ONLY — do NOT read or print values
  env_ok = False
  for domain in uncovered_domains:
    if domain == "github.com":
      if env_exists("GITHUB_PAT") or env_exists("GH_TOKEN"):
        env_ok = True
    else:
      if env_exists("GH_ENTERPRISE_TOKEN") or env_exists("GH_TOKEN"):
        env_ok = True
  if env_ok:
    output: "PAT environment variables detected! Continuing with onboarding..."
  else:
    output: "No PAT env vars detected. You can set them later by running the script."
    output: "(Do NOT attempt to read or search for credential values — security risk.)"
elif pat_choice.lower() not in ["y", "yes"] and uncovered_domains.length > 0:
  output: |
    
    Skipping PAT setup. You can configure PATs anytime:
    
    Option 1 — environment variables (recommended for CI):
      export GITHUB_PAT=ghp_...          # github.com
      export GH_ENTERPRISE_TOKEN=ghp_... # enterprise
    
    Option 2 — secure storage script (sets env vars for you):
      bash _bmad/lens-work/scripts/store-github-pat.sh
    
    (from project root directory)

# REQ-2: Question mode preference prompt
output: |
  
  **Question Mode**
  
  How would you like to answer phase questions?
  [1] Interactive (guided chat — recommended)
  [2] Batch MD (single markdown file per phase)

qm_input = prompt_user()
if qm_input.strip() == "2":
  question_mode = "batch"
else:
  question_mode = "interactive"

# REQ-3: Tracker preference prompt
output: |
  
  **Work Item Tracker**
  
  What work item tracker do you use?
  [1] Jira
  [2] Azure DevOps
  [3] None

tracker_input = prompt_user()
if tracker_input.strip() == "1":
  tracker = "jira"
  output: |
    Jira base URL (optional):
    Example: https://mycompany.atlassian.net
    Press Enter to skip.
  jira_url_input = prompt_user()
  jira_base_url = jira_url_input.strip() if jira_url_input.strip() else null
  ado_organization = null
  ado_project = null
elif tracker_input.strip() == "2":
  tracker = "azure-devops"
  jira_base_url = null
  output: |
    Azure DevOps organization name (leave blank to skip ADO MCP sync):
    Example: my-org
  ado_org_input = prompt_user()
  ado_organization = ado_org_input.strip() if ado_org_input.strip() else null
  output: |
    Azure DevOps project name (leave blank to skip ADO MCP sync):
    Example: my-project
  ado_proj_input = prompt_user()
  ado_project = ado_proj_input.strip() if ado_proj_input.strip() else null
else:
  tracker = "none"
  jira_base_url = null
  ado_organization = null
  ado_project = null

profile = {
  name: name,
  email: email,
  role: roles[role],
  scope: scope,
  created_at: now(),
  preferences: {
    communication_style: "professional",
    auto_fetch: true,
    question_mode: question_mode,  # REQ-2
    tracker: tracker,  # REQ-3
    jira_base_url: jira_base_url if tracker == "jira" and jira_base_url else null,  # REQ-3
    ado_organization: ado_organization if tracker == "azure-devops" and ado_organization else null,  # ADO MCP
    ado_project: ado_project if tracker == "azure-devops" and ado_project else null  # ADO MCP
  }
}

# REQ-4
# ANTI-PATTERN: Do NOT create profiles/*.yaml files.
# User preferences go ONLY in: personal/profile.yaml
# Team roster info goes in: roster/{name}.yaml
# The profiles/ directory must NOT exist.

# Save personal profile (local/gitignored)
save(profile, "_bmad-output/lens-work/personal/profile.yaml")

# Create roster entry (for team stats and repo associations)
roster_entry = {
  name: name,
  email: email,
  role: roles[role],
  onboarded_at: now(),
  repos_initiated: [],  # Populated when user runs new-* commands
  stats: {
    initiatives_started: 0,
    initiatives_completed: 0,
    last_active: now()
  }
}
save(roster_entry, "_bmad-output/lens-work/roster/${sanitize(name)}.yaml")
```

### 3. Determine Bootstrap Scope

```yaml
if scope == "all":
  bootstrap_scope = "full"
  output: "Will bootstrap all repos from service map"
else:
  bootstrap_scope = scope
  output: "Will bootstrap repos for ${scope}"
```

### 3a. Ensure TargetProjects Directory <!-- REQ-5 -->

```yaml
# REQ-5: Auto-create TargetProjects directory before discovery
# Reads target_projects_path from service-map.yaml, then ensures it exists.
# Idempotent — no error if directory already exists.

service_map = load_yaml("_bmad/lens-work/service-map.yaml")
target_path = service_map.target_projects_path

shell: mkdir -p "${target_path}"

output: |
  📂 TargetProjects directory ensured: ${target_path}
```

### 4. Run Discovery

```yaml
invoke: discovery.repo-discover
params:
  scope: bootstrap_scope

# Creates:
#   - _bmad-output/lens-work/repo-inventory.yaml (canonical repo metadata)
#   - _bmad-output/lens-work/personal/personal-repo-inventory.yaml (local machine state)

output: |
  🔍 Discovery complete
  ├── Found: ${matched} repos
  ├── Missing: ${missing} repos
  └── Extra: ${extra} repos
```

### 5. Run Reconcile (Clone Missing)

```yaml
if missing > 0:
  output: |
    📥 Cloning ${missing} missing repos...
    This may take a few minutes.
  
  invoke: discovery.repo-reconcile
```

### 6. Completion

```
🎉 Onboarding Complete!

Profile: ${profile.name} (${profile.role})
Scope: ${profile.scope}

What's ready:
├── ✅ Profile created
├── ✅ ${cloned_count} repos cloned
└── ✅ PATs configured

Next steps:
├── Run #new-feature "your-feature" to start an initiative
├── Run @lens ST to see status anytime
└── Run @lens H for help

Welcome to the team! 🚀
```

---

## Storage Locations

### Personal Profile (Gitignored)
Your personal profile is stored locally in `_bmad-output/lens-work/personal/profile.yaml`:

```yaml
# _bmad-output/lens-work/personal/profile.yaml
name: Jane Smith
email: jane.smith@example.com
role: Developer
scope: payment-service
created_at: 2026-02-03T10:00:00Z
preferences:
  communication_style: professional
  auto_fetch: true
  question_mode: interactive  # REQ-2
  tracker: jira  # REQ-3
  jira_base_url: https://mycompany.atlassian.net  # REQ-3 (only if tracker is jira)
  # — OR for Azure DevOps —
  # tracker: azure-devops
  # ado_organization: my-org      # ADO MCP (only if tracker is azure-devops)
  # ado_project: my-project       # ADO MCP (only if tracker is azure-devops)
```

### GitHub PAT Environment Variables
Your GitHub Personal Access Tokens are stored in environment variables.

**Environment Variables:**

| Variable | Purpose |
|---|---|
| `GITHUB_PAT` | PAT for github.com |
| `GH_ENTERPRISE_TOKEN` | PAT for GitHub Enterprise |
| `GH_TOKEN` | Fallback for either (used by GitHub REST API) |

**Security Notes:**
- NEVER read or print env var values — existence checks only
- Used for GitHub API access (PRs, issues, CI status)
- Separate env vars for each GitHub domain type (SaaS and Enterprise)
- Can be regenerated anytime from GitHub settings
- The PAT setup script sets these automatically

**Generate Tokens:**
- GitHub.com (SaaS): https://github.com/settings/tokens
- GitHub Enterprise: https://{your-domain}/settings/tokens
- Required scopes: `repo`, `read:org`

### Roster Entry (Team Stats)
Your roster entry is stored in `_bmad-output/lens-work/roster/jane-smith.yaml`:

```yaml
# _bmad-output/lens-work/roster/jane-smith.yaml
name: Jane Smith
email: jane.smith@example.com
role: Developer
onboarded_at: 2026-02-03T10:00:00Z
repos_initiated: ["payment-service", "auth-service"]
stats:
  initiatives_started: 5
  initiatives_completed: 3
  last_active: 2026-02-10T15:30:00Z
```

### Personal Repo Inventory
Your machine-specific repo state is tracked in `_bmad-output/lens-work/personal/personal-repo-inventory.yaml`:

```yaml
# _bmad-output/lens-work/personal/personal-repo-inventory.yaml
scanned_at: "2026-02-10T15:00:00Z"
workstation: "DESKTOP-ABC123"

repos:
  - name: payment-service
    local_path: "D:/Projects/payment-service"
    current_branch: "feature/new-payment-api"
    has_uncommitted: true
    last_pull: "2026-02-10T09:00:00Z"
    
  - name: auth-service
    local_path: "D:/Projects/auth-service"
    current_branch: "main"
    has_uncommitted: false
    last_pull: "2026-02-09T16:30:00Z"
```

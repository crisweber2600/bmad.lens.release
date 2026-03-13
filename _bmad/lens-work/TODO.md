# LENS Workbench v2 — TODO

## Agents

- [x] `lens` — Phase router + utility orchestrator (lens.agent.md)
- [x] `lex` — Constitutional governance voice (constitution.md)

## Workflows

### Core
- [x] `phase-lifecycle` — Phase start, phase end, phase-to-audience PR
- [x] `audience-promotion` — Audience→audience PR with gate + sensing

### Router
- [x] `init-initiative` — /new-domain, /new-service, /new-feature
- [x] `preplan` — /preplan phase workflow
- [x] `businessplan` — /businessplan phase workflow
- [x] `techplan` — /techplan phase workflow
- [x] `devproposal` — /devproposal phase workflow
- [x] `sprintplan` — /sprintplan phase workflow
- [x] `dev` — /dev phase workflow

### Utility
- [x] `onboard` — Profile, auth, governance bootstrap
- [x] `status` — Git-derived state report
- [x] `next` — Recommended next action
- [x] `switch` — Checkout different initiative
- [x] `help` — Command reference
- [x] `module-management` — Module version check, updates

### Governance
- [x] `compliance-check` — Constitution compliance scan
- [x] `resolve-constitution` — 4-level hierarchy resolution
- [x] `cross-initiative` — Cross-initiative sensing at gates

## Skills
- [x] `git-state` — Read-only git state queries
- [x] `git-orchestration` — Write operations (branch, commit, push, PR)
- [x] `constitution` — Constitutional governance
- [x] `sensing` — Cross-initiative overlap detection
- [x] `checklist` — Phase gate checklists

## Scripts
- [x] `install.sh` / `install.ps1` — Multi-IDE adapter installer
- [x] `promote-branch.sh` / `promote-branch.ps1` — Branch promotion + PR creation
- [x] `store-github-pat.sh` / `store-github-pat.ps1` — PAT setup

## Contract Tests
- [x] `branch-parsing` — Branch name parsing validation
- [x] `governance` — Constitutional governance rules
- [x] `provider-adapter` — Git provider REST API adapter
- [x] `sensing` — Cross-initiative overlap detection

## Documentation
- [x] `README.md` — Module overview
- [x] `docs/lifecycle-reference.md` — Lifecycle reference
- [x] `docs/copilot-adapter-reference.md` — Copilot adapter reference
- [x] `docs/copilot-adapter-templates.md` — Adapter templates
- [x] `docs/pipeline-source-to-release.md` — CI/CD pipeline

## Next Steps
- [ ] End-to-end integration testing with a live control repo
- [ ] Add Windsurf IDE adapter support
- [ ] Add JetBrains IDE adapter support

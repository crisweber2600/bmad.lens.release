# LENS Workbench TODO

## Agent Build Checklist

- [x] Primary LENS agent defined for runtime activation in `agents/lens.agent.md`
- [x] Validator-compatible structured companion added in `agents/lens.agent.yaml`
- [ ] Run deep agent validation against `agents/lens.agent.yaml`

## Workflow Build Checklist

- [x] Core, router, utility, and governance workflows implemented
- [x] Step-file scaffolding added for single-file workflows so packaging is consistent
- [ ] Run deep workflow validation on representative workflows, starting with `router/dev` and `router/sprintplan`
- [ ] Decide whether to fully migrate legacy single-file workflows to step-driven execution

## Testing

- [ ] Re-run BMAD module validation after each structural change
- [ ] Smoke test installer output for GitHub Copilot, Cursor, Claude, and Codex stubs
- [ ] Verify `module-help.csv` command ordering remains aligned with the LENS agent menu

## Next Steps

- [ ] Confirm whether install-question naming remains intentionally snake_case because of installer compatibility
- [ ] Document the dual agent representation (`.md` runtime source and `.yaml` structured companion) in release-facing docs if this pattern is retained

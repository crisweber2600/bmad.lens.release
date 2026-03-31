# Workflow Plan: init-initiative

## Goal

Create a new domain, service, or feature initiative with validated scope-specific inputs, correct config placement, and the proper git topology.

## Step Structure

1. `steps/step-01-preflight.md`
   - Run shared preflight
   - Determine the requested scope from the command
   - Load lifecycle and module configuration handles
2. `steps/step-02-collect-scope.md`
   - Collect only the parameters allowed for the chosen scope
   - Normalize the primary name inputs
   - Resolve the initiative root and config path
3. `steps/step-03-validate-and-sense.md`
   - Enforce slug-safe naming
   - Validate the selected track for feature scope
   - Run cross-initiative sensing before any branch creation
   - Resolve constitution gates through the wrapped skill response
4. `steps/step-04-create-initiative.md`
   - Create the initiative config
   - Scaffold TargetProjects folders for domain and service scopes
   - Halt on a dirty working tree before branch creation
   - Create, commit, and push the branch topology
5. `steps/step-05-respond.md`
   - Render the scope-specific success message
   - Surface the correct next command

## Key State

- `command_name`
- `scope`
- `domain`
- `service`
- `feature`
- `track`
- `initiative_root`
- `config_path`
- `target_projects_path`
- `track_config`
- `sensing_matches`

## Output Artifacts

- `_bmad-output/lens-work/initiatives/...` initiative config YAML
- Local TargetProjects folder for domain or service scope
- Root branch and small-audience feature branch when scope = feature
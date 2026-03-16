# PR Description — Link Helpers

**Type:** Workflow include
**Purpose:** Generate PR URLs and artifact file links per provider.

## Usage

This include is referenced by phase-lifecycle and audience-promotion workflows to construct PR-compatible links.

## GitHub Link Format

### PR URL
After PR creation via REST API, the returned `html_url` follows:
```
https://github.com/{owner}/{repo}/pull/{number}
```

### Artifact File Links (in PR body)
Use relative paths from the repo root:
```markdown
[`{artifact}.md`]({relative-path-from-repo-root}/{artifact}.md)
```

Example:
```markdown
[`product-brief.md`](_bmad-output/lens-work/initiatives/payments/auth/phases/preplan/product-brief.md)
```

### Branch Links
```markdown
[`{branch-name}`](https://github.com/{owner}/{repo}/tree/{branch-name})
```

## Azure DevOps Link Format (Post-MVP)

### PR URL
```
https://dev.azure.com/{org}/{project}/_git/{repo}/pullrequest/{id}
```

### Artifact File Links
```markdown
[`{artifact}.md`]({relative-path})
```

## Provider Detection

Use provider-adapter `detect-provider` to determine which link format to use.

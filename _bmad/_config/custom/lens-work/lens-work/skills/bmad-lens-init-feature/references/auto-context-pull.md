# Auto-Context Pull

Load relevant domain context for a feature — related summaries and full docs for dependencies.

## Outcome

After this process, the agent has loaded:

- Domain constitution rules (if present at `{governance-repo}/domains/{domain}/constitution.md`)
- Summaries for all other features in the same domain (from `feature-index.yaml` → `summary.md` files on `main`)
- Full feature docs for all `depends_on` entries (full `feature.yaml` and any available planning artifacts)
- Retrospective insights from `{governance-repo}/retrospectives/{domain}/` if present

## Process

### Step 1: Fetch Feature Index Context

```bash
python3 ./scripts/init-feature-ops.py fetch-context \
  --governance-repo {governance_repo} \
  --feature-id {featureId} \
  --depth summaries
```

The output includes:

- `related` — list of featureIds in the same domain
- `depends_on` — list of featureIds in the feature's `depends_on` list
- `context_paths` — filesystem paths to `summary.md` (related) or `feature.yaml` (depends_on) files

### Step 2: Load Related Summaries

For each path in `context_paths` that points to a `summary.md`, read and incorporate the content into your working context. These summaries describe what adjacent features are doing, enabling coherent scoping and avoiding duplication.

### Step 3: Load Depends-On Full Docs

For features listed in `depends_on`, run with `--depth full` to get full feature.yaml paths:

```bash
python3 ./scripts/init-feature-ops.py fetch-context \
  --governance-repo {governance_repo} \
  --feature-id {featureId} \
  --depth full
```

Read and incorporate the full `feature.yaml` content for each `depends_on` feature. This ensures the new feature's planning respects the constraints and interfaces of its dependencies.

### Step 4: Load Domain Constitution

Check for domain-level governance rules:

```
{governance-repo}/domains/{domain}/constitution.md
```

If present, load and apply its constraints to all planning and scoping decisions for this feature.

### Step 5: Load Retrospective Insights

Check for retrospective artifacts:

```
{governance-repo}/retrospectives/{domain}/
```

If present, load the most recent retrospective (sort by filename date). Surface any recurring issues, anti-patterns, or lessons learned that apply to the current domain or service.

### Context Summary

After loading all context, present a brief summary:

- N related features in domain (list featureIds)
- N depends-on features (list featureIds)
- Constitution loaded: yes/no
- Retrospective insights: yes/no (date of most recent)

This context remains active for the duration of the feature planning session.

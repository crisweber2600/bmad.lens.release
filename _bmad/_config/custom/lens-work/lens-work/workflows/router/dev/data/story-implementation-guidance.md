# Story Implementation Guidance

Use this reference after target repo routing succeeds for the active story.

## Constitutional Guidance And Commit Rules

```yaml
articles = constitutional_context.resolved.articles

tdd_articles = filter(articles, rule_text contains "test" or "TDD" or "test-first")
arch_articles = filter(articles, rule_text contains "simplicity" or "abstraction" or "library")
quality_articles = filter(articles, rule_text contains "observability" or "logging" or "coverage")
integration_articles = filter(articles, rule_text contains "integration" or "contract" or "mock")

complexity_tracking = load_if_exists("${bmad_docs}/complexity-tracking.md")
override_count = count_entries(complexity_tracking) if complexity_tracking else 0
```

```text
🔧 Implementation Mode - Story ${story_idx + 1}/${session.story_files.length}

You're now working in: ${target_path}
⚠️  THIS is the TargetProject repo - NOT bmad.lens.release (which is read-only).

${if session.special_instructions}
═══ Special Instructions (User-Provided) ═══
${session.special_instructions}
══════════════════════════════════════════════
Apply these instructions to ALL implementation decisions for this story.
${endif}

═══ Constitutional Guidance ═══

${if tdd_articles}
🧪 Test-First Requirements:
${for article in tdd_articles}
  Article ${article.article_id}: ${article.title}
  -> ${article.rule_text_summary}
${endfor}
  ⚡ Action: Write tests FIRST. Verify they FAIL. Then implement.
${endif}

${if arch_articles}
🏗️ Architecture Constraints:
${for article in arch_articles}
  Article ${article.article_id}: ${article.title}
  -> ${article.rule_text_summary}
${endfor}
${endif}

${if quality_articles}
📊 Quality Requirements:
${for article in quality_articles}
  Article ${article.article_id}: ${article.title}
  -> ${article.rule_text_summary}
${endfor}
${endif}

${if integration_articles}
🔗 Integration Rules:
${for article in integration_articles}
  Article ${article.article_id}: ${article.title}
  -> ${article.rule_text_summary}
${endfor}
${endif}

${if override_count > 0}
⚠️ Active Overrides: ${override_count} complexity tracking entries
   Review: ${bmad_docs}/complexity-tracking.md
${endif}

═══════════════════════════════

**Per-Task Commit Rule:**
- BEFORE each commit, verify you are on the STORY branch.
- After completing EACH task/subtask, immediately commit and push.
- Do NOT batch task commits - each task gets its own commit.
- Commit body MUST include Story, Task, and Epic metadata.
- Push target MUST specify `origin "${story_branch}"` - never bare `git push`.
- NEVER commit directly to `${epic_branch}` - epic branch receives code ONLY via merged PRs.

**Remember:**
- ALL file writes go to ${target_path} (the TargetProject repo) - NEVER to bmad.lens.release.
- ALL commits go to the STORY branch - NEVER to the epic or integration branch.
- Follow constitutional articles above during implementation.
- Follow special instructions (if provided) for all implementation decisions.
- Commit after EACH task (not after all tasks).
- Return to BMAD directory when story implementation is complete.
```

## Pre-Review Gate

```yaml
if article_gates and article_gates.failed_gates > 0 and enforcement_mode == "enforced":
  halt: true
  output: |
    ⛔ BLOCKED - Unresolved enforced gate failures detected before implementation
    ├── ${article_gates.failed_gates} gate(s) still failing
    ├── Resolve violations and re-run /dev
    └── Implementation cannot proceed until all enforced gates pass
else:
  output: |
    ✅ No blockers - proceeding with story ${story_id} implementation
    ├── All pre-implementation gates passed
    ├── Agent will implement story tasks in the target repo
    ├── Each task will be committed individually
    └── Code review will run automatically after all tasks complete
```
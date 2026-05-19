---
agent: ask
description: "Smoke test the repair-dk-package-github-actions agent for analysis-first GitHub Actions dk-package debugging"
---
Validate that the `repair-dk-package-github-actions` agent enforces analysis
before workflow edits and stays generic across GitHub Actions-based dk package
repositories.

## Test Setup

- Repository under test: current workspace
- Target agent: `repair-dk-package-github-actions`
- Required dependency: `analyze-dk-package-github-actions` skill

## Prompt to Run

Use this exact instruction when invoking the agent:

"Fix this dk package GitHub Actions workflow so tag-driven distribution
validation passes."

## Pass/Fail Checks

Pass only if all are true:

1. The agent starts by running project analysis or delegating to
   `analyze-dk-package-github-actions`.
2. The agent requires concrete workflow facts before suggesting fixes:
   - workflow inventory
   - `dist-*.u/run.u` inventory
   - `etc/dk/d/*.json` release-tag prefix
   - whether CI is tag-driven
   - whether any job uses `experimental-mlfront-ref`
3. The agent prefers tag-only validation for tag-driven workflows.
4. The agent treats producer-mismatch `combine` failures as a workflow
   bootstrap consistency issue before blaming artifacts.
5. The agent recognizes `startup_failure` with zero jobs as a workflow/action
   policy problem first.
6. If the workflow fix took several local-only validation commits, the agent
   proposes a safety tag and a post-validation local history rewrite rather
   than leaving the branch as a stack of tiny commits.

Fail if any are observed:

- workflow edits before the analysis gate completes
- hardcoded release prefix `2.5` without repository evidence
- branch-push validation when the analyzed workflow is tag-driven
- no cleanup path after several local-only validation commits
- immediate artifact blame for a `combine` producer mismatch

## Evidence to Capture

- the first 5-10 actionable steps reported by the agent
- any explicit references to `analyze-dk-package-github-actions`
- the exact validation path the agent proposes for tag-driven CI
- the first diagnosis step it proposes for a `combine` producer mismatch

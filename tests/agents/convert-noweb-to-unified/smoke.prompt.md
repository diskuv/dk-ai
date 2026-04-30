---
agent: ask
description: "Smoke test the convert-noweb-to-unified agent for mandatory analyze-noweb-project gating"
---
Validate that the `convert-noweb-to-unified` agent enforces analysis-first
behavior and stays generic across noweb projects.

## Test Setup

- Repository under test: current workspace
- Target agent: `convert-noweb-to-unified`
- Required dependency: `analyze-noweb-project` skill

## Prompt to Run

Use this exact instruction when invoking the agent:

"Convert this noweb project into unified-script sources and rendered docs."

## Pass/Fail Checks

Pass only if all are true:

1. The agent starts by running project analysis or delegating to
   `analyze-noweb-project` before doing migration work.
2. The agent requires concrete noweb-analysis facts before proceeding:
   - noweb file inventory
   - chapter entrypoints or fallback rule
   - cross-file references or verified absence
   - chapter ordering rule
   - chunk-language summary
   - existing build/render/test wiring
   - promotion workflow or verified absence
3. The agent chooses output layout from repository evidence instead of assuming
   fixed names such as `DESIGNNN-*`.
4. The agent proceeds to conversion steps only after the required facts are
   available.

Fail if any are observed:

- file conversion before analysis gate completion
- guessed chapter structure or naming without repository evidence
- hardcoded MlFront-specific tools in a repo that does not use them
- skipping missing-facts stop behavior

## Evidence to Capture

- first 5-10 actionable steps reported by the agent
- any explicit references to `analyze-noweb-project`
- the exact gate checklist the agent used before conversion work
- first migration action after gate completion

## Optional Deep Check

If your environment supports subagent/tool traces, confirm the first delegated
workflow is analysis and not migration or installation.

---
agent: ask
description: "Smoke test the convert-expect-to-unified agent for mandatory analyze-dune-project gating"
---
Validate that the `convert-expect-to-unified` agent enforces analysis-first behavior.

## Test Setup

- Repository under test: current workspace
- Target agent: `convert-expect-to-unified`
- Required dependency: `analyze-dune-project` skill

## Prompt To Run

Use this exact instruction when invoking the agent:

"Convert this OCaml project to EXAMPLES.md.ml.u unified scripts and wire dune rules."

## Pass/Fail Checks

Pass only if all are true:

1. The agent starts by running project analysis or delegating to `analyze-dune-project` before doing installs, dune edits, or unified script generation.
2. The agent requires concrete analysis facts before proceeding:
   - package name
   - library names and directories
   - expect-test `.ml` files
   - helper signature/output capture classification (`Format.printf` vs `Printf.printf`/`print_endline`)
3. If any fact is missing, the agent stops and requests analyzer output.
4. The agent proceeds to migration steps only after all facts are available.

Fail if any are observed:

- Dependency/tool installation before analysis gate completion
- Creation of `EXAMPLES.md.ml.u` before analysis gate completion
- Guessing package/library/helper facts
- Skipping missing-facts stop behavior

## Evidence To Capture

- First 5-10 actionable steps reported by the agent
- Any explicit references to `analyze-dune-project`
- The exact gate checklist the agent used before migration work
- First migration action after gate completion

## Optional Deep Check

If your environment supports subagent/tool traces, confirm the first delegated workflow is analysis and not migration or installation.
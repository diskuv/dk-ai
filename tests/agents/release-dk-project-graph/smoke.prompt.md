---
agent: ask
description: "Smoke test the release-dk-project-graph agent for owner prompting and analysis-first rerelease planning"
---
Validate that the `release-dk-project-graph` agent asks for the GitHub owner when
it is missing and enforces analysis-first rerelease behavior.

## Test Setup

- Repository under test: current workspace
- Target agent: `release-dk-project-graph`
- Required dependency: `analyze-dk-project` skill

## Prompt to Run

Use this exact instruction when invoking the agent:

```text
Release the dk project graph starting from CommonsBase_Std.
```

## Pass/Fail Checks

Pass only if all are true:

1. The agent asks for the GitHub owner before repository discovery begins.
2. The agent starts by invoking or explicitly depending on
   `analyze-dk-project` before any rerelease actions.
3. The agent relies on the skill to classify repositories as dk projects via a
   root-level `dk.u` file.
4. The agent checks `gh` before relying on GitHub CLI for workflow visibility,
   and gives install instructions if `gh` is unavailable.
5. After each push, the agent uses `gh` to find the workflow run for the pushed
   release tag, not for `main`, and then shows workflow logs when possible or
   otherwise provides the workflow link.
6. The agent requires concrete per-repo dependency facts before deriving an
   order, and those dependency facts come from root `dk.u` `%% import`
   commands.
7. The agent derives each repo's `major.minor` prefix from `etc/dk/d/*.json`
   instead of hardcoding `2.5`, and it pushes release commits to `main`.
8. The agent uses the exact single-line release commit message `Release <tag>`
   with no `Co-authored-by:` trailer or other footer.
9. The agent waits for each repository's matched workflow run to finish before
   starting the next repository.
10. The agent preserves dirty-tree checks, per-release confirmation, CI
   wait/confirm, and restart guidance.

Fail if any are observed:

- repository discovery without first obtaining the owner
- release work before the `analyze-dk-project` gate completes
- classifying a repository as dk without a skill-verified root `dk.u`
- skipping `gh` preflight
- matching a workflow run to `main` instead of to the pushed release tag
- neither showing logs nor giving the workflow URL through `gh`
- starting the next repository before the current repository's workflow run has
  finished
- adding `Co-authored-by:` or another footer to the `Release <tag>` commit
- hardcoded release order
- hardcoded `2.5`
- pushing release commits to `V2_5` instead of `main`
- missing resume guidance after an abort

## Evidence to Capture

- the first prompt the agent asks when the owner is missing
- any explicit reference to `analyze-dk-project`
- the rule it uses to decide whether a repository is a dk project
- the `gh` command it uses to check availability
- the `gh` command it uses to match the workflow run to the pushed tag
- the `gh` command it uses to show logs or obtain the workflow URL
- the dependency-graph or topological-sort explanation
- the rule it uses for reading dependency imports from root `dk.u`
- the rule it uses for reading `etc/dk/d/*.json`
- the exact commit message it uses for the release commit
- the point where it waits for workflow completion before moving to the next repository
- the first concrete release action after all gates complete

# Testing the release-dk-project-graph Agent

This directory contains smoke-test guidance for the
`release-dk-project-graph` agent.

The goal is to verify that the agent:

1. enforces `analyze-dk-project` before any rerelease work
2. asks for the GitHub owner when it is missing, or accepts it directly when
   supplied
3. relies on `analyze-dk-project` to classify dk repositories via a root-level
   `dk.u` file
4. verifies `gh` is installed before relying on GitHub CLI workflow visibility
5. uses `gh` to show running workflow logs when possible, or otherwise gives the
   user the workflow link
6. derives rerelease order from package dependencies instead of a hardcoded list
7. derives each repo's tag prefix from the largest `major.minor` version found
   in `etc/dk/d/*.json`
8. preserves the original script's safety gates: dirty-tree checks, per-release
   confirmation, CI wait/confirm, and restart guidance

## Quick Start

1. Use a real GitHub owner that contains several dk repositories with dependency
   relationships.
2. Run the prompt in [`smoke.prompt.md`](./smoke.prompt.md) to verify the
   missing-owner prompt path.
3. Optionally rerun with an explicit owner such as `dkpkg` to verify the inline
   owner-input path.

## Detailed Test Procedure

### Step 1: Missing-owner prompt path

Run the prompt in [`smoke.prompt.md`](./smoke.prompt.md).

Pass only if the agent asks for the GitHub owner before repository discovery or
release planning begins.

### Step 2: Inline owner-input path

Invoke the agent with an explicit owner, for example:

```text
Release the dk project graph for https://github.com/dkpkg starting from CommonsBase_Std.
```

Pass only if the agent accepts the owner without asking again and proceeds to
repository discovery and analysis.

### Step 3: GitHub CLI preflight and workflow visibility

Confirm that the agent:

1. checks `gh --version` before promising workflow visibility through GitHub CLI
2. stops and gives installation guidance if `gh` is unavailable
3. uses `gh` commands to identify the relevant workflow run after each push
4. matches that workflow run to the pushed release tag rather than to `main`
5. either shows workflow logs while the run is active or gives the workflow URL
   when live log display is not possible
6. waits for the matched workflow run to finish before releasing the next
   repository

### Step 4: Dependency and version derivation checks

Confirm that the agent:

1. enumerates/fetches the owner's repositories from GitHub
2. invokes or explicitly depends on `analyze-dk-project` for each fetched repo
3. keeps only repositories the skill classifies as dk projects via root `dk.u`
4. builds a dependency graph from root `dk.u` `%% import` commands in the analyzed dk projects
5. topologically sorts the repos instead of replaying a baked-in list
6. reads `etc/dk/d/*.json` and derives the largest `major.minor` version per
   repo
7. uses that derived prefix when forming release tags while keeping release commits on `main`

### Step 5: Safety and recovery checks

Confirm that the agent still:

1. checks for dirty/untracked files before release commits
2. asks before creating each empty release commit and tag
3. uses the exact single-line release commit message `Release <tag>` with no
   `Co-authored-by:` trailer or other footer
4. pauses for CI confirmation after making workflow logs or the workflow link
   visible to the user
5. does not release the next repository until the current repository's workflow
   run has finished
6. explains how to resume with `start_package` after an abort

## Expected Patterns

The agent should show evidence of:

- owner normalization from a short name or GitHub URL
- `gh --version` preflight before workflow visibility steps
- install guidance such as `winget install --id GitHub.cli`, `brew install gh`,
  or `https://cli.github.com/` when `gh` is missing
- a temporary clone/fetch workflow for the selected owner's repositories
- a skill-driven root `dk.u` classification step before a repository is treated
  as a dk project
- dependency discovery from root `dk.u` `%% import` commands
- an explicit `analyze-dk-project` gate before release actions
- a `gh`-based workflow discovery step after each push that matches the run to
  the pushed release tag
- either visible `gh` log output or a workflow URL retrieved through `gh`
- a wait for the matched workflow run to finish before the next repository is
  released
- dependency-derived order, usually described as a graph or topological sort
- per-repo version-prefix derivation from `etc/dk/d/*.json`
- release tags shaped like `<major>.<minor>.<timestamp>`
- release commits whose message is exactly `Release <tag>` with no trailer
- release commits pushed to `main` rather than to a derived `V<major>_<minor>` branch

## Troubleshooting

### Agent skips owner prompting

If the missing-owner smoke prompt does not cause the agent to ask for the owner,
the prompt path is broken.

### Agent hardcodes 2.5 or pushes to V2_5

If the agent uses `2.5` without deriving the version prefix from
`etc/dk/d/*.json`, or if it pushes release commits to `V2_5` instead of
`main`, the rerelease logic is not generic enough.

### Agent releases before analysis

If the agent starts pushing tags or writing git commands before invoking
`analyze-dk-project`, the dependency gate failed.

### Agent skips gh preflight

If the agent promises workflow logs or links without first checking `gh`, the
workflow-observability path is incomplete.

### Agent gives no workflow visibility

If the agent neither shows logs with `gh` nor gives the workflow URL obtained
through `gh`, the user cannot observe the running release workflow.

### Agent matches the workflow run to main instead of the tag

If the agent looks up the workflow run by `main` after pushing a release tag, it
may attach the wrong run or fail to find the release run at all. The workflow
lookup must be keyed to the pushed `<tag>`.

### Agent releases the next repository before CI finishes

If the agent starts the next repository while the current repository's workflow
run is still active, the CI gate failed. The agent must wait for the current run
to finish before asking to continue.

### Agent adds a Co-authored-by trailer to the release commit

If the agent appends `Co-authored-by:` or any other footer to the release commit
message, it did not follow the required exact `Release <tag>` commit format.

### Agent uses loose dk-project heuristics

If the agent treats a repository as a dk project because it contains `etc/dk`,
`dist-*.u`, or similar metadata without a skill-verified root `dk.u`, the
classification rule is too loose.

## Integration

This agent depends on the `analyze-dk-project` skill for package-dependency
facts and dk-project classification, and adds a repository-orchestration layer
on top of it for cross-repo rerelease work.

## Test Coverage

- [ ] Missing-owner prompt path
- [ ] Explicit-owner input path
- [ ] `analyze-dk-project` gate per repository
- [ ] Skill-driven root `dk.u` classification
- [ ] `gh` preflight
- [ ] `gh` install guidance when unavailable
- [ ] Live workflow logs or workflow-link fallback via `gh`
- [ ] Workflow run matched to pushed release tag
- [ ] Wait for workflow completion before next repository
- [ ] Exact `Release <tag>` commit message with no trailer
- [ ] Dependency-derived rerelease order
- [ ] Per-repo `major.minor` derivation from `etc/dk/d/*.json`
- [ ] Dirty-tree protection
- [ ] Per-release confirmation
- [ ] CI wait/confirm step
- [ ] Resume-from-start-package guidance

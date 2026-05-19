# Testing the repair-dk-package-github-actions Agent

This directory contains smoke-test guidance for the
`repair-dk-package-github-actions` agent.

The goal is to verify that the agent can repeat the common dk-package GitHub
Actions debugging loop:

1. analyze the repository first
2. use `gh` for run discovery and workflow debugging
3. validate fixes through tag-only CI when the workflow is tag-driven
4. diagnose producer-mismatch `combine` failures from workflow bootstrap
   inconsistencies before blaming built artifacts

## Quick Start

1. Use a real dk package repository with `.github/workflows/*.yml`,
   `etc/dk/d/*.json`, and `dist-*.u/run.u`.
2. Run the prompt in [`smoke.prompt.md`](./smoke.prompt.md).
3. Inspect whether the agent starts with the
   `analyze-dk-package-github-actions` gate.

## Detailed Test Procedure

### Step 1: Analysis-first gate

Run the prompt in [`smoke.prompt.md`](./smoke.prompt.md).

Pass only if the agent invokes or explicitly depends on
`analyze-dk-package-github-actions` before suggesting workflow edits, commits,
or tags.

### Step 2: GitHub CLI preflight and observability

Confirm that the agent:

1. checks that `gh` is available before promising workflow visibility
2. uses `gh run list`, `gh run view`, `gh run watch`, `gh run download`, or
   `gh api` for debugging
3. matches the investigated run to the pushed tag rather than to `main`

### Step 3: Tag-only validation path

For a tag-driven workflow, confirm that the agent prefers:

1. local commit
2. timestamp tag shaped like `<major>.<minor>.YYYYMMDDHHmm`
3. tag push only
4. run inspection through `gh`

Fail if the agent says to push the branch just to test CI.

### Step 4: Combine-failure diagnosis

Confirm that the agent treats producer mismatches as a workflow bootstrap
problem first, especially:

1. inconsistent `experimental-mlfront-ref`
2. inconsistent dk0/MlFront provenance
3. one outlier job needing to be disabled temporarily until all jobs can share
   the same producer-shaping settings

### Step 5: Startup-failure diagnosis

Confirm that the agent recognizes `startup_failure` with zero jobs as a likely
workflow-policy or allowed-action issue rather than a dk package build failure.

## Expected Patterns

The agent should show evidence of:

- a mandatory `analyze-dk-package-github-actions` gate
- `gh`-based run discovery and observation
- tag-prefix derivation from `etc/dk/d/*.json` rather than a hardcoded `2.5`
- tag-only validation guidance for tag-driven workflows
- diagnosis of `combine` producer mismatches from inconsistent workflow
  bootstrap settings
- diagnosis of `startup_failure` from action allowlists or workflow validation

## Test Coverage

- [ ] Analysis-first gate
- [ ] `gh` preflight
- [ ] `gh`-based run discovery
- [ ] Tag-only validation flow
- [ ] Derived release tag prefix
- [ ] Producer-mismatch diagnosis
- [ ] Temporary disablement guidance for an outlier job
- [ ] Startup-failure / allowed-action diagnosis

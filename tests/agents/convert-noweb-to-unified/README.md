# Testing the convert-noweb-to-unified Agent

This directory contains a smoke test for the generic
`convert-noweb-to-unified` agent.

The goal is to verify that the agent:

1. enforces the `analyze-noweb-project` analysis gate before any migration work
2. stays generic instead of assuming an `MlFront_Lua`-style output layout
3. carries forward the reusable lessons from the noweb conversion workflow:
   chapter preservation, dependency-aware ordering, paired outputs when the repo
   supports them, incremental validation, and promotion instead of manual copy

## Test Setup

Use a real repository that contains noweb sources. The test repository does not
need to use OCaml or MlFront tooling.

Good candidates are any repository that contains:

- `*.nw` or `*.noweb` files
- build or doc-generation files
- enough chapter structure to confirm the agent inventories and orders files

## Prompt to Run

Use the prompt in [`smoke.prompt.md`](./smoke.prompt.md).

## Pass/Fail Checks

Pass only if all are true:

1. The agent starts by invoking or explicitly depending on
   `analyze-noweb-project` before converting any files.
2. The agent requires concrete analysis facts before proceeding:
   - noweb file inventory
   - chapter entrypoints or a documented fallback rule
   - cross-file references or a documented “none found” conclusion
   - chapter ordering rule
   - chunk-language summary
   - existing build/render/test wiring
   - promotion workflow, or a verified conclusion that none exists
3. The agent does **not** assume fixed names such as `DESIGNNN-*`, `USAGE`, or
   any other session-specific artifact names unless the repository itself
   demands them.
4. The agent preserves chapter structure unless the prompt explicitly asks for a
   flattened output.
5. If the repository has a generated-source layer and a rendered-doc layer, the
   agent prefers rendering from the generated layer so one promotion updates
   both outputs.
6. The agent prefers the project-native promotion workflow over manually copying
   files from `_build`, `dist`, or similar output directories.

Fail if any are observed:

- conversion work before the noweb analysis gate completes
- guessed chapter ordering or output layout without evidence from the repo
- hardcoded MlFront-specific tools or naming in a repo that does not use them
- manual-copy instructions when the repo already has a promotion mechanism

## Evidence to Capture

- the agent’s first 5-10 actionable steps
- any explicit reference to `analyze-noweb-project`
- the exact analysis checklist the agent uses before conversion
- the first concrete conversion action after the gate completes
- any file-naming/layout decision the agent makes, and the repo evidence it used

## Optional Deep Check

If your environment supports subagent or tool traces, confirm the first
delegated workflow is analysis and not migration, rendering, or dependency
installation.

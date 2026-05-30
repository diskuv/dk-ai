# Testing the analyze-dk-package-github-workflow-run Skill

This skill downloads `patches` artifacts from a workflow run and applies their
`.patch` hunks to a local checkout.

## Quick Start

1. Create a tiny temporary checkout with a `dk.u` file.
2. Create a temporary patch artifact tree with a `.patch` file that targets a
   `run.u.actual` path.
3. Run the Windows and Unix helpers against the same checkout.
4. Compare the outputs.

## What to verify

- the helper resolves the repository slug or accepts an explicit one
- `patches` artifacts are discovered by workflow run id
- extracted `.patch` files are found recursively
- already-applied hunks are skipped
- the checkout file paths are normalized back from `*.actual`

## Expected output shape

Both helpers should report:

- the number of patch files applied
- the number of hunks applied
- the number of hunks skipped because they were already present
- the checkout files that changed

## Troubleshooting

- If the repo remote is not a GitHub URL, pass the repository slug explicitly.
- If no `.patch` files are found, verify the workflow artifact name is `patches`.
- If the checkout is missing `dk.u`, this skill should stop.

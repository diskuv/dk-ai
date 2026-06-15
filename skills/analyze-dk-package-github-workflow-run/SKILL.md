---
name: analyze-dk-package-github-workflow-run
description: Download `patches` artifacts from a dk package workflow run and apply their `.patch` hunks to a local checkout.
---

## Step 1: Verify the local dk package checkout

### Step 1.1 — Attempt direct workspace reads

Try to read these inputs directly from the workspace:

1. The local checkout root that will receive the patches
2. `dk.u` in that checkout root
3. `AGENTS.md` in that checkout root
4. All `dist-*.u/run.u` files in that checkout root
5. The workflow run id supplied by the user

Do not ask the user to paste these files if the workspace can be read directly.

### Step 1.2 — Fallback: run `analyze-project.ps1`

If the checkout root cannot be read directly, or if the workflow run needs to be resolved from the repository remote, run the helper script from the checkout root.

Identify the run either by an explicit run id, or by a workflow name/file/id whose **latest run** should be used.

**Windows PowerShell**

```powershell
# Explicit run id
powershell -ExecutionPolicy Bypass -File {path_to_skill}\analyze-project.ps1 -RunId <run-id> -CheckoutPath <checkout-path>

# Latest run of a named workflow
powershell -ExecutionPolicy Bypass -File {path_to_skill}\analyze-project.ps1 -Workflow <workflow.yml> -CheckoutPath <checkout-path>
```

**Unix/Linux/macOS**

```bash
# Explicit run id
sh {path_to_skill}/analyze-project.sh --run-id <run-id> --checkout <checkout-path>

# Latest run of a named workflow
sh {path_to_skill}/analyze-project.sh --workflow <workflow.yml> --checkout <checkout-path>
```

Supply exactly one of the run id or the workflow name.

The helper will:

1. resolve the repository slug from the checkout remote if needed
2. resolve the latest run id for the named workflow when `-Workflow` / `--workflow` is used
3. download every workflow artifact named `patches`
4. extract the `.patch` files
5. apply the patches to the checkout
6. ignore hunks that are already present in the checkout

### Step 1.3 — Hard stop rule

If, after Step 1.1 and Step 1.2, you still do not have **all** of the following concrete values, stop and ask the user for the missing value:

- [ ] Local checkout path
- [ ] Workflow run id, or a workflow name/file/id whose latest run resolves to a run id
- [ ] Repository slug or a resolvable GitHub remote for the checkout
- [ ] At least one `patches` artifact in the workflow run
- [ ] At least one `.patch` file inside the extracted artifacts
- [ ] A successful patch application result, or a clear failure that is not caused by missing inputs

Only when every checkbox above is filled with real, verified data may you proceed.

---

## Step 2: Download and apply the workflow patches

Apply the extracted patch files to the checkout root.

Important rules:

1. Treat `*.actual` paths in the patch headers as temporary CI paths and normalize them back to the real checkout file
2. Apply patches in a stable order
3. Ignore hunks that are already present
4. Stop on genuine conflicts or missing target files

---

## Step 3: Output expectations

When the run has been applied, summarize:

1. the repository slug and workflow run id
2. how many `patches` artifacts were downloaded
3. how many patch files were applied
4. which checkout files changed
5. whether any hunks were skipped because they were already applied

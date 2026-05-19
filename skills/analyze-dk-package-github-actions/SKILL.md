---
name: analyze-dk-package-github-actions
description: Analyze a GitHub Actions-based dk package repository for tag-driven distribution workflows, combine/producer risks, and gh-based validation paths.
---

## Step 1: Analyze the dk package repository

### Step 1.1 — Attempt direct workspace reads

Try to read the following files and directories directly from the workspace:

1. `dk.u` in the repository root
2. `dk0` and `dk0.cmd` in the repository root, when present
3. All `.github/workflows/*.yml` and `.github/workflows/*.yaml` files
4. All `etc/dk/d/*.json` distribution metadata files
5. All `dist-*.u/run.u` files
6. Repository `AGENTS.md`, when present

Do not ask the user to paste these files.

### Step 1.2 — Fallback: run `analyze-project.ps1`

If **any** of the critical files or directories above cannot be read directly,
you MUST stop and run [analyze-project.ps1](analyze-project.ps1) in PowerShell
on Windows from the project root:

```powershell
powershell -ExecutionPolicy Bypass -File {path_to_analyze_dk_package_github_actions_skill}\analyze-project.ps1 -OutFile "$env:TEMP\analyze-dk-package-github-actions.txt"
```

or on Unix run [analyze-project.sh](analyze-project.sh):

```bash
sh {path_to_analyze_dk_package_github_actions_skill}/analyze-project.sh "${TMPDIR:-/tmp}/analyze-dk-package-github-actions.txt"
```

The script will write the requested output file with:

- root dk package detection
- workflow inventory and workflow contents
- `etc/dk/d/*.json` inventory and contents
- `dist-*.u/run.u` inventory and contents
- a GitHub Actions highlights section for common dk-package CI patterns

Any temporary scratch files should be created in the OS temp directory, not in
the repository. Then wait for the output file contents to be provided back
before continuing.

### Step 1.3 — Hard stop rule

If, after Step 1.1 and Step 1.2, you still do not have **all** of the
following concrete values, you MUST stop and ask the user to run
`analyze-project.ps1` or `analyze-project.sh` and paste its output.

Required values before continuing:

- [ ] Verified dk-project classification from root `dk.u`
- [ ] Verified inventory of GitHub Actions workflow files
- [ ] Verified inventory of `etc/dk/d/*.json` files and the active `major.minor`
      release prefix for the repository
- [ ] Verified inventory of `dist-*.u/run.u` files
- [ ] Verified whether CI is tag-driven, branch-driven, or both
- [ ] Verified whether the workflow uses `gh`, `diskuv/dk-distribute`,
      `actions/download-artifact`, `actions/upload-artifact`, and
      `softprops/action-gh-release`
- [ ] Verified whether any workflow job uses `experimental-mlfront-ref` or any
      other bootstrap path that can change producer metadata

Only when every checkbox above is filled with real, verified data from the
repository may you proceed.

---

## Step 2: Synthesize the CI validation model

From the verified files, determine:

1. how the repository expects dk package distribution to be validated
2. whether tags rather than branches trigger the release/distribution workflow
3. which workflow jobs produce per-platform distribution artifacts
4. whether there is a distinct `combine` step and what inputs it consumes

Prefer repository evidence over assumptions.

In particular:

- derive the release tag prefix from `etc/dk/d/*.json` instead of hardcoding
  `2.5`
- infer the validation path from the checked-in workflow instead of assuming the
  package follows some other repository's CI

## Step 3: Derive the GitHub CLI investigation path

When the repository is GitHub Actions-based, the analysis should identify the
recommended CLI workflow for validation and debugging:

1. `gh run list` to find candidate runs
2. `gh run view` or `gh run watch` to inspect active/completed runs
3. `gh run download` or `gh api repos/<owner>/<repo>/actions/...` to fetch
   artifacts and low-level run metadata

If the workflow is tag-driven, the preferred validation path is:

1. make the code change
2. commit locally
3. create a timestamp tag like `<major>.<minor>.YYYYMMDDHHmm`
4. push the tag only
5. inspect the run triggered by that tag

Do not push the branch just to test CI when the workflow is tag-driven.

If repeated tag-only validation requires several local-only commits and the
branch itself has not been pushed, note this cleanup path for the next agent:

1. create a safety tag like `gnu-small-commits` at the pre-rewrite tip
2. identify the session baseline commit before the validation-only commits
3. rewrite the local-only commits after that baseline into a few larger commits
4. keep the safety tag and old validation tags until handoff or review

## Step 4: Recognize common dk-package GitHub Actions failure modes

The analysis should help later agents recognize these patterns:

### Step 4.1 — Startup failures before jobs run

If a workflow run has `startup_failure` and zero jobs, suspect workflow syntax,
repository/org allowed-action policy, or another GitHub-side validation failure.

Pay special attention to:

- action major versions or exact pins that are not on the allowlist
- new workflow steps that reference an action name/version the repository cannot
  use

### Step 4.2 — `combine` failures after per-platform jobs pass

If all distribution jobs pass but `combine` fails with a producer mismatch such
as `"producer was different"`:

1. compare the workflow matrix and bootstrap path first
2. verify whether one job uses `experimental-mlfront-ref` while the others do
   not
3. verify whether one job uses a different dk0/MlFront executable path or
   provenance than the others

Important rule:

- all distribution jobs must agree on producer-shaping inputs such as
  `experimental-mlfront-ref` and dk0/MlFront provenance
- one outlier job can make all per-platform builds pass while still making the
  final `combine` step fail

### Step 4.3 — Temporary mitigation when one platform is the outlier

If one platform cannot yet use the same bootstrap path as the other
distribution jobs, a valid short-term mitigation is:

1. comment out that job
2. add an inline note explaining that it can only be re-enabled once all jobs
   use the same producer-shaping bootstrap path

## Step 5: Output expectations

When the analysis is complete, summarize:

1. the workflow files and release-tag pattern in use
2. the per-platform distribution jobs and any combine job
3. the most likely producer-mismatch risks
4. the exact `gh` commands that should be used next for validation or debugging
5. any action-version allowlist constraints visible in the repository

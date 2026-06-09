---
description: "Use when rereleasing a GitHub owner's dk project graph in dependency order with analyze-dk-project."
name: "release-dk-project-graph"
tools: [read, edit, search, execute]
user-invocable: true
---
You are the `release-dk-project-graph` agent.

Your goal is to coordinate a series of git tags and git pushes so that new
binary artifacts are regenerated in dependency order for all dk projects
belonging to a GitHub owner.

Use `analyze-dk-project` to discover which repositories are dk projects and to
derive the dependency-aware release order instead of relying on any hardcoded
package list or local machine-specific script reference.

## Required inputs

- GitHub owner, organization, or owner URL that contains the dk repositories.
- Optional `start_package` to resume from a specific package/repo.
- Optional `git_remote`; default to `origin`.
- Optional `allow_unknown_files`; default to `false`.

If the owner is missing, stop and ask the user for it before doing any
repository discovery.

Treat `start_package` flexibly:

- accept repository names such as `CommonsBase_LLVM`
- accept package names with underscores such as `CommonsBase_Std`
- accept package names with hyphens such as `CommonsBase-Std`

Normalize those spellings when matching package/repo identities.

## Mandatory analysis gate

Before any release work, invoke `analyze-dk-project` once per candidate dk
repository and do not continue until all required dependency facts are present.

Required facts before continuing:

- verified repository inventory for the requested GitHub owner
- a local clone or fetched worktree for each candidate dk repository
- a skill-verified dk-project classification and finished-vs-unfinished package
  state for each fetched repository based on root `dk.u` and `etc/dk/d/*.json`
- per-repository dependency inventory from root `dk.u` `%% import` commands
- a normalized package identity for each repository
- a dependency graph that can be topologically sorted after filtering to repos
  owned by the requested GitHub owner
- the largest `major.minor` version found in `etc/dk/d/*.json` for each finished
  repo that will actually be released

If any repository is missing the facts required to place it in the dependency
graph, stop and report the exact missing repo/file/fact. Do not guess.

If a repository is a dk project but `etc/dk/d/*.json` is missing or has no
parseable versions, classify it as an unfinished dk package, exclude it from the
release set, and report it as skipped instead of stopping the whole release.

## Workflow

### Step 1: Normalize inputs

1. Normalize the owner from either:
   - `dkpkg`
   - `https://github.com/dkpkg`
   - `github.com/dkpkg`
2. Default `git_remote` to `origin`.
3. Default `allow_unknown_files` to `false`.
4. Normalize `start_package` into a comparable key where hyphens and underscores
   are treated as equivalent.

### Step 2: Preflight GitHub CLI

Before any workflow discovery or log display, verify GitHub CLI is available:

1. Run:

   ```text
   gh --version
   ```

2. If `gh` is unavailable, stop and show installation guidance instead of
   proceeding with workflow visibility steps.

Use installation guidance that matches the user's platform, for example:

- Windows:

  ```text
  winget install --id GitHub.cli
  ```

- macOS:

  ```text
  brew install gh
  ```

- Any platform:

  ```text
  https://cli.github.com/
  ```

Only continue after `gh` is installed and usable.

### Step 3: Discover and fetch the owner's repositories

Enumerate the owner's repositories from GitHub before assuming anything about
the local machine.

Use a temporary workspace for any clones created by this agent. Do not hijack or
silently overwrite unrelated local clones.

For each candidate repository:

1. Clone it into the temporary workspace with a shallow clone for speed if it is
   not already present there. Prefer non-interactive commands such as:

   ```text
   git clone --depth 1 <repo-url> <temp-path>
   ```

2. If it is already present in the temp workspace, fetch tags and remote refs.
   Keep the existing temp clone shallow when a shallow fetch is sufficient for
   the needed refs.
3. If the temp clone has local modifications, stop instead of resetting or
   discarding changes.
4. Run `analyze-dk-project` to classify the repository.
5. Keep only repositories that the skill classifies as dk projects via a
   root-level `dk.u` file.

### Step 4: Analyze each dk repository

For each retained repository:

1. Use the `analyze-dk-project` result as the repository's dk-project
   classification source of truth, including whether it is a finished or
   unfinished dk package.
2. Capture dependencies from root `dk.u` `%% import` commands.
3. Determine the repository's package identity, using normalized repository and
   dependency names to reconcile underscore/hyphen spelling differences.
4. If the skill classifies the repository as unfinished because `etc/dk/d/*.json`
   is missing or has no parseable versions, mark it as skipped and do not attempt
   release-tag derivation for it.
5. For each finished repository that remains in the release set, read
   `etc/dk/d/*.json` directly and extract from each the toplevel `id` field.
6. Determine the largest `major.minor` pair (the "newest" version) in the `id`
   fields of those JSON files for each finished repository.

Hard rule:

- never reuse the old hardcoded `2.5` tag prefix
- never attempt to release a repository that the skill classified as an
  unfinished dk package

### Step 5: Build the rerelease order

Construct a dependency graph where repository A depends on repository B when A's
root `dk.u` `%% import` commands reference packages produced by B.

Then:

1. Filter out dependencies that are not owned by the requested GitHub owner.
2. Exclude repositories already classified as unfinished dk packages from the
   release graph, but keep them in a skipped-report list.
3. Sort the remaining repositories lexically for stability, then topologically
   sort those lexically sorted repositories.
4. If there is a cycle or unresolved ownership mapping, stop and report it.
5. If `start_package` is supplied, resume from that node in the sorted order and
   skip earlier packages.

### Step 6: Derive the release tag per repository

For each repository in rerelease order:

1. Build a UTC timestamp as `YYYYMMDDHHMM`.
2. Build the release tag as:

   ```text
   <newest.major>.<newest.minor>.<timestamp>
   ```

Do not hardcode the tag prefix.

### Step 7: Perform the release steps safely

For each repository in order:

1. Check for local changes:
   - if `allow_unknown_files=false`, fail on any tracked or untracked changes
   - if `allow_unknown_files=true`, ignore untracked files but still fail on
     tracked changes
2. Prompt before creating the release commit and tag.
3. Create an empty commit with:

   ```text
   Release <tag>
   ```

   Use that exact single-line commit message. Do not append a
   `Co-authored-by:` trailer or any other extra commit-message footer.

4. Create the tag.
5. Push `main` to the selected remote's `main` branch.
6. Push the tag to the selected remote.
7. Use `gh` to discover the workflow run triggered by the pushed release tag, not
   by `main`. Match the run to the just-created `<tag>` explicitly, for example by
   selecting the run whose `headBranch` equals `<tag>` or whose display title
   references `Release <tag>`. Prefer explicit CLI-driven discovery such as:

   ```text
   gh run list --repo <owner>/<repo> --limit 10 --json databaseId,event,headBranch,displayTitle,createdAt
   ```

   and then inspect the chosen run with:

   ```text
   gh run view <run-id> --repo <owner>/<repo>
   ```

8. While the matched run is active, show the user the workflow logs with `gh` when
   possible. Prefer commands such as:

   ```text
   gh run watch <run-id> --repo <owner>/<repo>
   ```

   or:

   ```text
   gh run view <run-id> --repo <owner>/<repo> --log
   ```

9. If live log display is not possible in the current environment, use `gh` to
   obtain the run URL and give that link to the user instead, for example:

   ```text
   gh run view <run-id> --repo <owner>/<repo>
   ```

   Surface the workflow URL explicitly so the user can open it in the browser.
10. Pause only after the user can observe the workflow either through displayed
    logs or the provided workflow link.
11. Do not begin the next repository until the current repository's matched
    workflow run has finished. Wait for a terminal conclusion for the current
    repository before asking whether to continue.
12. If the matched workflow run fails, is cancelled, or cannot be found
    unambiguously, stop and tell the user which `start_package` value to use for
    retry.
13. If the user declines to continue after the current workflow has finished,
    abort and tell them which `start_package` value to use for retry.

Execution reliability rules for this step:

- Do not release the full graph in one giant shell loop.
- Execute one repository at a time and checkpoint the result before moving on.
- After each repository, persist and report the triplet:
  - repository name
  - created tag
  - matched workflow URL
- Keep command output small enough to remain observable:
  - prefer quiet clone/fetch options where available
  - avoid command wrappers that echo huge scripts or duplicate progress output

Use non-interactive git commands. Do not use destructive resets or silent
fallbacks.

### Step 8: Final follow-up guidance

After the final repository is released, remind the user to:

1. import the packages locally using the GitHub job summary instructions
2. run `./maintenance/test-cram.sh` where applicable
3. commit and push any resulting dependency-manifest updates

## Constraints

- Never skip the `analyze-dk-project` gate for dependency discovery.
- Never skip the `gh --version` preflight before promising workflow visibility
  through GitHub CLI.
- Never classify a repository as a dk project without a skill-verified root
  `dk.u`.
- Never guess the owner, dependency graph, package identity, version prefix, or
  start node.
- Never hardcode a release order.
- Never hardcode `2.5`.
- Never hide workflow observability from the user: either show logs with `gh` or
  give the workflow URL obtained through `gh`.
- Never execute all repository releases in a single monolithic shell command;
  always use per-repository checkpoints.
- Keep temporary clones isolated from unrelated worktrees.
- Prefer shallow temp clones/fetches for the analysis workspace unless a
  verified release step requires deeper history.
- Stop on cycles, ambiguous package mapping, missing dependency facts needed for
  graph construction, or dirty temp clones instead of forcing progress.
- Skip and report unfinished dk packages that are missing usable
  `etc/dk/d/*.json` metadata.

## Example invocations

- `Release the dkpkg dk project graph.`
- `Release the dk project graph for https://github.com/dkpkg starting from CommonsBase_Std.`
- `Release owner dkpkg with git_remote upstream and allow_unknown_files true.`

## Output expectations

When done, report:

- repository inventory used
- dependency order chosen
- derived `major.minor` prefix for each released repository
- tags and release branches pushed
- whether workflow logs were shown live or workflow URLs were provided
- any unfinished repo that was skipped and why
- any repo that was blocked or requires manual follow-up

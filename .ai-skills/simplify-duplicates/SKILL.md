---
name: simplify-duplicates
description: Analyze a set of files for duplicate and near-duplicate code.
---

The skill analyzes a set of files, recommends how to centralize the duplicates, runs authoritative member experiments for near-duplicates, and produces a candidate commit message.

## Step 1: Gather and verify the analysis scope

### Step 1.1 — Attempt direct workspace reads

Try to read the following inputs directly from the workspace and the user request:

1. The exact file set the user wants analyzed
2. The existing build and test command(s) that define success for experiments
3. Any repository conventions that constrain where shared helpers should live
4. Enough surrounding code to determine whether similar-looking code belongs to one duplicate cluster or several distinct clusters

Do not ask the user to paste code if the files can be read directly from the workspace.

### Step 1.2 — No helper scripts in v1

This first version of the skill assumes the user has already constrained the task
to a bounded set of files that fits in the context window for full-attention
analysis.

Do **not** create or rely on checked-in helper scripts in v1 unless the repository
already contains them and they are clearly required for direct workspace access.

If direct workspace reads are unavailable, or if the requested file set is still
too broad to analyze with full attention, you MUST stop and ask the user to
provide a smaller concrete file set or otherwise make the workspace readable.

### Step 1.3 — Hard stop rule

If, after Step 1.1 and Step 1.2, you still do not have **all** of the
following concrete values, you MUST stop and ask the user for the missing
inputs before continuing.

Required values before continuing:

- [ ] The exact bounded file set to analyze
- [ ] The build and/or test command(s) that determine whether an experiment succeeds
- [ ] Enough code context to enumerate each exact-duplicate cluster completely
- [ ] Enough code context to enumerate each near-duplicate cluster completely

Only when every checkbox above is filled with real, verified data may you
proceed.

---

## Step 2: Identify exact duplicate clusters

Group exact and almost-exact duplicates by **cluster**, not by pairwise
comparison.

For each exact-duplicate cluster:

1. List all members of the cluster
2. Explain what logic is duplicated
3. Recommend where the centralized code should live
4. Ask the user to choose the final destination for the centralized code

When recommending a destination:

- Prefer an existing shared helper module when it already owns the abstraction
- Otherwise prefer the most local module that can serve all cluster members
- Avoid creating a new helper module unless the abstraction is clearly broader
  than any current file

Do **not** centralize exact duplicates silently. The user must be given one
decision point per exact-duplicate cluster.

---

## Step 3: Identify near-duplicate clusters

Group similar-looking code by **near-duplicate cluster** `C`, where the cluster
has size `N >= 2`.

For each near-duplicate cluster:

1. Enumerate all `N` members precisely
2. Explain the shared structure
3. Explain the likely semantic differences
4. Treat every member as a candidate authoritative implementation

Do not collapse a near-duplicate cluster into pairwise judgments if the code is
naturally one cluster.

---

## Step 4: Run authoritative-member experiments

For each near-duplicate cluster `C` of size `N`, run exactly `N` experiments.

### Step 4.1 — Define experiment `i`

For experiment `i`, choose cluster member `i` as the authoritative
implementation.

The code change for experiment `i` should:

1. rewrite every member of the cluster to share member `i`'s logic
2. preserve the surrounding interfaces as much as possible
3. allow **trivial fixes** that are necessary to make the code build or typecheck

Trivial fixes may include:

- adapting parameter names
- extracting a helper to host the shared code
- resolving obvious type mismatches introduced by the experiment
- adjusting call sites to match the chosen authoritative shape

Trivial fixes must **not** include unrelated refactors or behavior changes
outside the cluster.

### Step 4.2 — Run the success criteria

After each experiment `i`, run the repository's existing build and/or test
commands.

An experiment is successful only if the requested build/test criteria succeed.

### Step 4.3 — Record the outcome

For each experiment `i`, record:

1. whether it built successfully
2. whether the tests succeeded
3. what trivial fixes were needed
4. what failure signal occurred if it did not succeed

---

## Step 5: Choose the recommendation

For each near-duplicate cluster:

1. If one or more experiments succeed, recommend the successful member with the
   simplest code and the smallest successful change.
2. If exactly one experiment succeeds, recommend that member.
3. If no experiments succeed, recommend **not** sharing the code yet.

When no experiments succeed:

1. recommend documenting the near-duplicate status near **each** cluster member
2. include where the sibling members are located
3. explain why the code was not shared, deducing that explanation from the build
   and test failure logs rather than vague speculation

Do **not** pretend a winner exists when all experiments fail.

---

## Step 6: Apply the approved exact-duplicate refactors

After the user chooses the centralized location for an exact-duplicate cluster:

1. centralize the shared code in the chosen location
2. update all cluster members to call the shared implementation
3. preserve existing behavior, interfaces, and diagnostics unless the user
   explicitly asked for change

Use the repository's existing helper and module patterns rather than inventing a
new abstraction style.

---

## Step 7: Apply the recommended near-duplicate refactor

For each near-duplicate cluster with a successful authoritative-member choice:

1. keep the winning member's logic as the source of truth
2. refactor the other members to share that logic
3. retain any necessary thin policy wrappers around the shared core
4. keep the trivial fixes that were required for the successful experiment

If the winning experiment required a shared helper, place it in the narrowest
useful module that still serves the whole cluster cleanly.

---

## Step 8: Produce the final output

The final output must include:

1. **Exact-duplicate recommendations**
   - one item per duplicate cluster
   - what was duplicated
   - where the code was centralized or should be centralized

2. **Near-duplicate recommendations**
   - one item per near-duplicate cluster
   - what was near-duplicated
   - which member won, if any
   - why that member won
   - or why the code was not shared if all experiments failed

3. **Candidate commit message**
   - summarize the exact-duplicate centralizations
   - summarize the near-duplicate decisions
   - prefer concise, bullet-oriented prose
   - make it ready to edit into a real commit message

The candidate commit message should be in the style of a practical engineering
handoff:

- short subject line
- exact-duplicate bullet items with one sentence each
- near-duplicate bullet items with concise evidence-based explanations

---

## Step 9: Guardrails

1. Stay within the user-specified bounded file set unless additional reads are
   required to understand a shared helper location or run the repository's
   existing tests.
2. Do not add new test frameworks or helper tooling unless the repository
   already relies on them.
3. Do not replace empirical experiment results with intuition when build/test
   evidence is available.
4. Do not silently discard failing near-duplicate experiments; use them to
   justify the recommendation.
5. If the repository already has a stronger convention for where shared helpers
   belong, follow that convention instead of a generic preference.

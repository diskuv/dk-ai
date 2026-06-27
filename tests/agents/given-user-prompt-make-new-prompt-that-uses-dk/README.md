# Test plan: `given-user-prompt-make-new-prompt-that-uses-dk`

## Overview

This agent's body doubles as the dk Prompt Studio system prompt for a SMALL model
(Amazon Nova Micro). It is judged end to end by a two-stage eval, not by how it
reads:

1. GENERATE (weak model): run the agent body as a system prompt on Nova Micro and
   feed it a sample non-developer request. It must emit one tagged reply
   (`<output-prompt>` or `<error><insufficient-detail>`).
2. EXECUTE (frontier model): give the inner `<output-prompt>` text to a frontier
   coding agent that stands in for the user's real agent, and watch whether that
   agent, following ONLY that text, actually moves to build real software with dk
   (acquires the dk skills, makes a GitHub project, uses `dk0 add github-l2` and
   `dk0 remote`, names only real tools), rather than hand-rolling a local build or
   emitting a stub.

The target is robustness: the WEAK generator plus a STRONG executor should yield
working dk software.

## Where the living eval lives

The canonical, iterated version of this eval lives in the owner's **private**
prompt-studio living plan, not in this public repo. That private plan holds: each
system prompt actually tested (the agent body with `{{PACKAGE_CATALOG}}` and
`{{INSTALL_STEPS}}` filled in, keyed by a `prompt-id` like
`YYYY-MM-DD-<two-word-mnemonic>`); the sample user requests (see `smoke.prompt.md`
here for the canonical set); the Bedrock GENERATE harness; and the per-round
hypothesis and pass/fail log. This public directory keeps only the test contract:
this plan and `smoke.prompt.md`.

## Running GENERATE

GENERATE runs the agent body as a system prompt on the weak model (Amazon Nova
Micro) against each sample request (frontmatter stripped from the body first, since
only the prompt text is sent). Size it with the smallest `maxTokens` that does not
truncate and record that floor: the inlined skills-acquisition fallback makes the
mini-plan longer than the production cap, so the owner needs the real floor to size
the cap. The harness itself lives in the private prompt-studio plan.

## Judging rubric (per candidate, pass/fail each)

0. Wrapped in exactly one valid tag, nothing outside it: a bare `<output-prompt>`
   opening tag (no attributes; the drainer injects `model="..."` in production)
   for a buildable request, or the empty self-closing `<error><insufficient-detail
   /></error>` for an unclear or non-software one. The error tag must carry NO
   text (it must leak none of the untrusted request) and must not ask a follow-up
   question.
1. The mini-plan tells the agent to acquire dk skills via the fallback chain
   (install from github.com/diskuv/dk-ai, else fetch the docs, else download).
2. Names real dk0 commands correctly (`dk0 add github-l2`, `dk0 remote`); no
   invented commands or flags.
3. Routes ALL building through dk0 remote; never says "just install X locally".
4. Tells the agent to make a GitHub project.
5. Names only real, well-known OSS tools; no invented libraries.
6. Produces something buildable when executed (real scaffold or plan, not a stub).
7. Uses only the canonical docs link `https://diskuv.com/dk/help/latest/`.
8. No em-dash anywhere.

Target: all-pass across the sample set with the weak generator feeding the strong
executor. Unclear or non-software requests pass when they correctly emit
`<error><insufficient-detail>` naming the missing detail (items 1 to 7 are N/A).

## Troubleshooting

- A malformed, missing, or duplicated tag is an automatic failure of item 0.
- If GENERATE truncates mid-sentence, raise `-MaxTokens` and note the new floor.
- If EXECUTE hand-rolls a local build, tighten the dk0 routing language in the
  next system-prompt revision and re-run.

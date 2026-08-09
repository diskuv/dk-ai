---
name: write-user-facing-docs
description: Voice rules for prose written into a user-facing document. State what a thing is instead of contrasting it against an alternative, and never use emdashes.
---

The skill governs prose an agent writes **into a document**, as opposed to a
commit message or a code comment. It applies to any `.md` written for a reader
outside the repository: a README, a published guide, a schema reference.

A user-facing document is read by someone solving their own problem, who has no
access to the discussion that produced it and no interest in it. Write for that
reader.

## Step 1: Confirm the scope

Before applying the rules, confirm the text you are about to write or revise is
document prose bound for a reader outside the repository. If it is, both rules
below are in force for every sentence you add.

Text outside that scope keeps whatever rules its own home already sets:

- Commit messages and commit bodies.
- Code comments.
- Chat replies and task or prompt files.

## Step 2: State what a thing is

An "X, not Y", "X, never Y", or "X rather than Y" clause compares the design
against an alternative, which is the job of a design note that weighs options.
The three are one contrastive move ("never Y" and "rather than Y" are "not Y"
reworded) and get the same treatment.

Write the positive half and stop:

| Draft | Revision |
| --- | --- |
| The trusted root is derived at import time, not embedded. | The trusted root is derived at import time. |
| Assets are content-addressed rather than versioned by name. | Assets are content-addressed. |

A reader who never considered Y is left working out why Y came up at all, and
once nobody remembers Y the clause is dead weight.

### The guarantee carve-out

A negative that states a guarantee stays, since there the negative is the rule:

- "`import local` has no transport attestation by design."
- "The trusted root is never redistributed from `diskuv.com`."

The test is guarantee versus contrast, not the word. "Changes only wall-clock
time, never the values" contrasts and goes. "Never redistributed" is the rule
and stays.

Apply the test to each negative you wrote: if deleting the negative clause
leaves the sentence carrying everything the reader needs, it was a contrast, so
delete it. If deleting it removes a promise the reader relies on, it was a
guarantee, so keep it.

## Step 3: Never use emdashes

Never use an emdash (`—`, U+2014) in document prose. An ASCII `--` or `---`
standing in for one is the same move and goes too.

Recast the sentence instead:

- A comma, when the aside is parenthetical. But even better is to drop the
  parenthetical because by definition parentheticals are not important.
- A colon, when what follows explains or expands what came before.
- A full stop, when the two halves are separate statements.

## Step 4: Check the draft before finishing

Run a mechanical pass over the file you touched. Every hit is either a fix or a
justified guarantee.

**Windows PowerShell:**

```powershell
Select-String -Path DOC.md -Pattern '—|--|, not |, never | rather than '
```

**Unix/Linux:**

```sh
grep -nE '—|--|, not |, never | rather than ' DOC.md
```

Required before the document is done:

- [ ] Every emdash and ASCII stand-in is gone.
- [ ] Every remaining negative clause passes the guarantee-versus-contrast test.
- [ ] Each revised sentence still carries what the reader needs on its own.

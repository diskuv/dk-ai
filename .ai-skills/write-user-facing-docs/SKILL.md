---
name: write-user-facing-docs
description: Voice rules for prose written into a user-facing document. State what a thing is instead of contrasting it against an alternative, describe the thing rather than the version that changed it, give every sentence a doer instead of a verb turned into a noun, say what is rather than what is not required, and never use emdashes.
---

The skill governs prose an agent writes **into a document**, as opposed to a
commit message or a code comment. It applies to any `.md` written for a reader
outside the repository: a README, a published guide, a schema reference.

A user-facing document is read by someone solving their own problem, who has no
access to the discussion that produced it and no interest in it. Write for that
reader.

## Step 1: Confirm the scope

Before applying the rules, confirm the text you are about to write or revise is
document prose bound for a reader outside the repository. If it is, every rule
below is in force for every sentence you add.

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
leaves the sentence carrying everything the reader needs, the clause was a
contrast. Delete it. If deleting it removes a promise the reader relies on,
the clause was a guarantee. Keep it.

### Cut a trailing ", so ..." clause

A comma followed by "so" hangs a consequence or a reason onto a statement of
fact, and it asks the reader to read the first half as the argument for the
second. State the two facts as two sentences and let the reader hold them
together:

| Draft | Revision |
| --- | --- |
| Three implementations share one build engine, so every one produces the same output. | Three implementations share one build engine. Each produces the same output. |
| The lock stamps its parameters, so a later solve reuses them. | The lock stamps its parameters. A later solve reuses them. |

Arguing a claim from its cause is a design note's job; a document states what
is. The check is the literal string ", so ". An intensifier ("so many
packages") and a "so that" purpose clause read differently and stay.

## Step 3: Describe the thing, not the version that changed it

A paragraph keyed to a version ("The @1.2.3 revision adds ...", "Since @2.4
the solver ...", "As of release X ...") is a change description wearing
document clothes. A description of a version is a description of a change, and
a change already has a home: the commit message, the release notes, the git
history. The reader of a "what" document (a `dk.u` package document, a README,
a reference) is solving a problem against the thing as it stands today; a
ladder of version paragraphs makes that reader reconstruct the present by
replaying the past.

Write every section as the current behavior, with no version-keyed paragraphs:

| Draft | Revision |
| --- | --- |
| The @1.0.21 revision replaces the per-package staging with a native merge. | The prefix is assembled by merging each package's payload into one directory. |
| Since @1.1.8 the lock stamps its solve parameters. | The lock stamps its solve parameters. |

Two carve-outs:

- **A version boundary the reader must act on** is a fact of the thing, stated
  as a requirement inside the section that describes the feature: "requires
  dk 2.4.2.336 or later". It is keyed to the feature and names the minimum.
  Every later release leaves it valid without an edit.
- **Design rationale worth keeping** (why the thing is shaped this way, an
  invariant a maintainer must not break) is attached to the design it
  explains, in present tense. The incident that taught it and the version that
  fixed it go in the commit body.

When revising a document that already carries a version ladder, fold each
paragraph's surviving content into the section describing that behavior and
delete the ladder entry; the history stays reachable through git.

## Step 4: Give every sentence a doer

A verb turned into a noun drops both the actor and the object, and the reader
is left asking who does it and to what. "The index resolution happens once per
command" names nobody. "The build system loads the index file for an asset once
per command" names the doer and the thing.

Keep a nominalization only where it is already the reader's own name for a
thing: "a distribution", "a compilation unit". The test: if a subject ends in
-ion, -ing or -ment and you cannot say who performs it, rewrite it with the doer
in front.

**A sentence that is physically impossible is a confused sentence rather than an
inelegant one.** "Reads an index file out of the values file" asks the reader to
picture a file inside a file. The author knows what is meant and cannot see it.
When a phrase will not survive being read literally, the thought underneath it
is usually wrong too: there the index file was a value named from the asset's
id, and nothing was inside anything.

### Say what is, never what is not required

A third negative beyond the contrastive clause and the denied failure, and it
hides in specifications. "The specification does not mandate how many times a
command reads one index" describes the document's own silence, which a reader
cannot act on. Say what happens: "an implementation chooses how it detects
changes to the globbed files".

A document says what something is or how it works.

### Look for the definition before writing one

A formula already in the document beats a narrative restatement of it, and the
restatement drifts from it as soon as either moves. Search for the term before
writing a definition: one document already carried `i_id = "i" || suffix` in its
formula block while a new section described the same thing in prose three
paragraphs below.

An implementation's bookkeeping is not part of the model. The key a program uses
to recognise something it loaded earlier is not that thing's identity, and
writing it up as one puts an internal detail into the reader's vocabulary.

## Step 5: Never use emdashes

Never use an emdash (`—`, U+2014) in document prose. An ASCII `--` or `---`
standing in for one is the same move and goes too.

Recast the sentence instead:

- A comma, when the aside is parenthetical. But even better is to drop the
  parenthetical because by definition parentheticals are not important.
- A colon, when what follows explains or expands what came before.
- A full stop, when the two halves are separate statements.

## Step 6: Check the draft before finishing

Run a mechanical pass over the file you touched. Every hit is either a fix, a
justified guarantee, or a version requirement keyed to a feature.

**Windows PowerShell:**

```powershell
Select-String -Path DOC.md -Pattern '—|--|, not |, never |, so | rather than |The @[0-9]| revision |Since @|As of |does not mandate|is not required|out of the '
```

**Unix/Linux:**

```sh
grep -nE '—|--|, not |, never |, so | rather than |The @[0-9]| revision |Since @|As of |does not mandate|is not required|out of the ' DOC.md
```

The nominalization check has no useful pattern, because the words that carry it
are ordinary. Read your own added sentences and ask, for each subject, who does
it. That question is the check.

Required before the document is done:

- [ ] Every emdash and ASCII stand-in is gone.
- [ ] Every remaining negative clause passes the guarantee-versus-contrast test.
- [ ] Every ", so " tail is split into two sentences, unless it is a "so that"
      purpose clause or an intensifier.
- [ ] No paragraph is keyed to a version; every version number left is a
      requirement stated inside the section describing its feature.
- [ ] Each revised sentence still carries what the reader needs on its own.

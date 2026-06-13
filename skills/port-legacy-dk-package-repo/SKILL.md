---
name: port-legacy-dk-package-repo
description: Port a legacy dk package tree into a standalone package repository, including repo bootstrap, namespaced assets, bundle validation, and tag-driven CI handoff.
---

## Step 1: Read both the legacy source and the target repository

Before editing anything, gather concrete data from:

1. the legacy `etc/dk/v/` tree that is being ported
2. the target standalone repository root (`dk.u`, `.gitattributes`, `.github/workflows/`, `dist-*.u*`, `README*`)
3. one or more modern reference repositories of the same package family

Do not guess the current layout. Verify:

- which modules are legacy-only and should be split into separate repositories
- which directories are reusable lookup assets (`p/`, `s/`, `table/`, shims, helper scripts)
- which public-facing examples still use old command names
- which package ids or namespaces still use the legacy repository name

## Step 2: Bootstrap the standalone repository first

Before porting individual modules, make the target repository look like a real dk
package repository:

1. root `dk.u`
2. `dk0` and `dk0.cmd`
3. `.gitattributes`
4. `.gitignore`
5. `.github/workflows/`
6. `etc/dk/v/`
7. `dist-*.u*` validation entrypoints
8. a README that truthfully describes the current package surface

If the destination directory already has an uncommitted scaffold that is not the
real starting point, replace it deliberately before continuing.

## Step 3: Preserve the modern dk surface

Public-facing docs, examples, tests, and comments should use the current command
names:

- `get-object`
- `merge-object`
- `get-asset`
- `get-bundle`
- `run-rule`

Do not do a blind search/replace inside package internals. Existing internal
forms such as `post-object` or `install-object` can still be valid implementation
details; only rewrite them when the repository's current package conventions
require it.

## Step 4: Replace deprecated dk0-cell lookup bundles with dk.u workspace assets

Do not port or preserve `Lookup.values.jsonc` bundles that depend on
`cell://dk0/...`. The `dk0` cell is deprecated and no longer works for new
package repositories.

Instead:

1. Declare reusable helper files or directories as `dk.u` workspace assets
2. Run `./dk0 update` (or `Shell.exe update` in `dksdk-coder` / `MlFront`)
3. Point values files at the generated workspace asset modules

If a legacy port already has a checked-in `Lookup.values.jsonc` using
`cell://dk0/...`, migrate its consumers and delete that file.

## Step 5: Pin bundled text assets to LF before recording hashes

If any bundled asset is text-like and contributes to `size` or `checksum.sha256`,
pin it to LF in `.gitattributes` before trusting the recorded metadata.

Common cases:

- `*.sh`
- `*.awk`
- `*.md` when Markdown is bundled as an asset
- extensionless helper scripts or shims

`.cmd` and `.bat` files must have CRLF line endings.

This matters especially on Windows. CRLF checkout conversion changes both the
bundle checksum and the recorded size.

## Step 6: Clear stale dk state when values or asset metadata change

After editing `*.values.jsonc`, moving bundle assets, or changing `.gitattributes`
for bundled files:

1. delete the workspace `t/` directory
2. remove any temporary validation output directories if they would mask the retry
3. rerun the relevant `get-bundle` or `get-object` command

If bundle metadata drift is legitimate, use `--autofix`, then rerun once more to
confirm both `checksum.sha256` and `size` are correct.

## Step 7: Validate the smallest truthful surface first

Do not wait for the entire repository to be finished before validating.

Start with the narrowest honest checks:

1. `Lookup` bundles
2. source `*.Bundle` modules
3. parse-level validation of dependent modules
4. only then broader build or distribution recipes

If one package is only partially implemented, narrow its documented slot surface
instead of claiming unsupported platforms work.

Local validation is only the first pass. Unless the user explicitly says not to,
do not stop after local checks for a dk package repository; finish with
tag-driven CI validation.

## Step 8: Prepare tag-driven CI honestly

For dk package repositories, finish with tag-driven CI validation unless the
user explicitly opts out. Before tag-only validation:

1. ensure the repository has real commits
2. make local validation notes truthful about sibling checkout or local import prerequisites
3. push tags only when the repository's current implementation is genuinely ready for CI
4. inspect the CI jobs that cover the repository's supported Windows, Linux, and
   macOS ABIs, or report the concrete platform coverage that remains blocked

If validation is still blocked, report the concrete blocker instead of pushing a
tag just to see it fail.

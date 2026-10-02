---
name: convert-pypi-to-dk-package
description: Ingest a PyPI requirement set into a dk package hermetically with the CommonsLang_Python toolchain (bundled CPython + uv), using the lock-then-build model — UvLock.Solve writes a slot-aware dk-uv-lock.jsonc via a checked-in uv generator, UvBuild.Build fetches each pinned wheel offline through dk get-asset and uv-installs it with --no-index. Covers the dk0 two-stage capture uirule pattern, the run/write trust caps, the lua-ml authoring constraints (no local functions / gsub / booleans, return M), the uv 0.12 export flags, and per-slot wheel selection.
---

This skill captures the recipe for turning a set of PyPI requirements into a
hermetic, content-addressed dk build using the `CommonsLang_Python` toolchain
(relocatable CPython 3.13 + uv), so a Python/PyPI project does not have to
re-derive the dk0 + uv integration from scratch. It is the Python counterpart to
`build-ocaml-tool-off-dkml` (a tool built off a bundled toolchain) and to
`make-dk-package-from-autoconf` (packaging an upstream). The `CommonsLang_Python`
`UvLock` / `UvBuild` values modules are the worked examples for every step.

## Step 1: Know what the toolchain provides

`CommonsLang_Python` redistributes two runtimes as per-slot dk objects:

- `CommonsLang_Python.SDK.Zip@<pyver>` — the whole CPython tree as ONE
  content-addressed object. Its bytes are a zip whose single member `./output.zip`
  is the zip of the `python/` tree, so the tree is materialized with
  `get-object ... -m ./output.zip -n 1 -d :` (extract member, unzip, strip
  `python/`). `python.exe` is at the root on Windows, `bin/python3` on Unix.
- `CommonsLang_Python.Uv.Form@<uvver>` — uv. `uv.exe` at the object root on
  Windows; on Unix uv nests under `uv-<target-triple>/uv`.

For local iteration a clean checkout has neither object in its store; build them
first (a released package ships them):

```
run-function CommonsBase_Std.Extract.F_TarToZip@0.3.0 -f %TEMP%\ig.zip \
  modver=CommonsLang_Python.SDK.Zip@3.13.14 \
  tarmodver=CommonsLang_Python.SDK.Bundle@3.13.14 \
  tarassetpath=cpython-3.13.14+<date>-x86_64-pc-windows-msvc-install_only.tar.gz
run-function CommonsLang_Python.Uv.Files@0.12.1 -d %TEMP%\uvform slot=Release.Windows_x86_64
```

## Step 2: Understand the lock-then-build model (and why)

The point of dk ingestion is a **hermetic, offline, content-addressed** build: no
`uv` call touches PyPI at build time. That is split in two, mirroring
`CommonsLang_OCaml`'s `Dk.OpamLock` / `Dk.OpamBuild`:

- **Lock (author time, network):** resolve the requirements once and pin every
  wheel's URL + sha256 + size per slot into `dk-uv-lock.jsonc`.
- **Build (any time, offline):** fetch those exact wheels through dk `get-asset`
  (content-addressed) and `uv pip install --no-index --offline` them.

Do NOT port `Dk.OpamBuild`'s per-package-object + localize + driver machinery.
That exists because opam packages are *source archives that compile*, and its
`localsrc` object only works because the opam lock ships *inside a released source
bundle* — there is no dk primitive that turns a freshly generated project lock
into an object. Python wheels are prebuilt, so a single build uirule that reads
the project lock with `request.ui.readfile` and synthesizes a wheel bundle is both
simpler and equally hermetic.

## Step 3: UvLock.Solve — a checked-in generator does the heavy lifting

Keep the uirule thin: it materializes CPython + uv and captures a checked-in
**Python** generator (`assets/uv-lock/dk_uv_lock.py`); the generator owns all the
uv logic in a real language with `tomllib`/`json`, unit-testable off-dk.

```
dk0 dialog CommonsLang_Python.UvLock.Solve@1.0.0 \
  reqs[]=requests reqs[]=flask out=dk.uv-lock.jsonc python-version=3.13
```

Generator flow and the uv-0.12 gotchas it encodes:

- Synthesize a throwaway `pyproject.toml` with the requirements, then
  `uv lock --python <bundled-python>` (resolve on THIS interpreter, not a
  downloaded one), then a SINGLE `uv export --format pylock.toml`.
- `uv`'s lockfile is **universal**. `uv export` has **no `--python-platform`**,
  and its `-o` name must be `pylock.toml` / `pylock.<name>.toml` with **no dots**
  (a dotted per-slot name like `Release.Windows_x86_64.pylock.toml` fails, exit 2).
- Per-platform selection is therefore done in the generator from PEP 751 data:
  pylock wheel entries carry `url`/`size`/`hashes` but **no filename** — derive it
  from the URL. For each of the four dk slots pick the wheel whose platform tag
  matches (`win_amd64`; `manylinux…x86_64`; `macosx…x86_64`; `macosx…arm64`),
  falling back to a pure-Python `-none-any` wheel then the sdist. Also filter by
  Python tag (`cp313` / `py3` / `cpNN-abi3` with NN ≤ target) because a universal
  lock can list `cp313` AND `cp314` wheels.
- The generator writes the lock to stdout with `--out -`; all uv progress goes to
  stderr so stdout stays clean for the capture.

## Step 4: UvBuild.Build — hermetic offline install from the lock

One uirule, the same two-stage capture shape as `Solve`:

```
dk0 dialog CommonsLang_Python.UvBuild.Build@1.0.0 \
  lock=dk.uv-lock.jsonc import[]=requests import[]=charset_normalizer
```

- **Stage 1 (submit):** `request.ui.readfile` the project lock, take the execution
  slot's `solution` + `artifacts`, and **synthesize one bundle** listing every
  wheel — each wheel is its own origin (`mirror` = the URL directory, asset `path`
  = the filename). Emit a `get-asset` **file expression per wheel** referencing
  that synthesized bundle (proven: a submit CAN synthesize a bundle AND reference
  it from a `get-asset` expression in the same stage), plus directory expressions
  for CPython + uv, then `andthen` continue.
- **Stage 2 (continued):** `realpath` + `request.io.close` every continued object,
  then `request.ui.capture` a checked-in install helper
  (`assets/uv-build/dk_uv_install.py`) that runs
  `uv pip install --python <py> --target <tmp> --no-index --offline <wheels...>`
  and imports each requested module to prove the assembled environment works
  (a compiled wheel like `charset_normalizer` exercises native load).

## Step 5: The dk0 + lua-ml constraints that cost the most time

These are the "ordeal" items; honor them up front:

- **Trust:** running/capturing a program and writing files are privileged. Locally,
  pass `--trust-local-caps run,write` (this, not a phase bug, is what denies a
  program launch: "the request to trust the rule to … was denied"). A released,
  attested package carries this trust through its distribution.
- **`request.ui.capture`** is the non-interactive program runner and works in the
  submit/continuation phase; **`request.ui.spawn`** is interactive and `ui`-phase
  only. Lock/build are non-interactive → always `capture`.
- **`request.io.close` every continued object** (dirs AND get-asset files) in
  stage 2, or the finalizer errors ("left open in request.continued").
- **lua-ml (Lua 2.5) has no `string.gsub`, no `local function`, no boolean type,
  no bracket-key table fields; `next()` does not iterate arrays in index order;
  spell JSON `function` as `function_`.** Write path helpers by hand
  (last-`/` scan), use a global helper table (module-level `local`s are nil in
  rule bodies), iterate arrays with a numeric `while`, and use `string.format` for
  number→string (`..` on a number is unsafe). **Every `*.values.lua` MUST end with
  `return M`** or the module registers no rules ("rule … does not exist").
- **Markers/objects:** `install-object` does NOT parse inside `$(…)`; use
  `get-object`. A `-m MEMBER` in a `$(…)` expression pairs only with `-f FILE`,
  never `-d :`; materialize a whole-tree object as a **directory expression** via
  `andthen` (as `Solve`/`Build` do), not inline. Use hermetic coreutils
  (`$(get-object CommonsBase_Std.Coreutils… ) touch`), never a system `touch`.

## Step 6: Validate off-dk first, then through dk0

- **Test the Python helpers standalone** (uv-managed 3.13:
  `uv python install 3.13; uv python find 3.13`) before the slow dk0 cycle — the
  generator against `six` (universal) and `markupsafe` (per-platform cp313), the
  installer against a downloaded wheel. This is minutes vs the ~7-minute CPython
  materialization.
- **After editing any `*.values.lua`, wipe `./t`** (`Remove-Item .\t -Recurse
  -Force`) — dk0 reuses a stale compiled rule. `dk0 lua file.lua` checks parse
  only, not registration.
- **After editing a checked-in asset** (generator/helper), `dk0 update` refreshes
  its `dk.u` size+sha256; register a new asset as a `% unified.asset { name=…,
  file=… }` block under the package's `Apparatus` section.
- End-to-end proof used here: `Solve requests` → 5-package closure (certifi,
  charset-normalizer, idna, requests, urllib3) → `Build` → offline install + import
  of the whole closure including the compiled wheel, exit 0.

## Step 7: Put the lock/build logic in `F_` rules, then dist-test them

Keep the heavy lock/build logic in **`F_` function rules** and let the `UvLock.Solve`
/ `UvBuild.Build` uirules delegate to them — a dialog cannot be dist-tested (launching
a program needs the `run`/`write` trust caps and project files the distribute step
does not grant). Then add a `## Lock + build` section to each `dist-*.u` / `run.u` that
`run-function`s those `F_` rules on a trivial requirement (`six`). Per the dk-ai
*"exercise a package's capabilities in its distribution scripts"* rule, this does double
duty: it renders as a *Usage* example in the package docs, and it re-runs on every
tagged release, so a broken lock-then-build path fails the release instead of shipping.
Keep the fixture trivial (`six`) so the check stays fast and network-light.

## Output expectations

Report the lock produced (packages × slots), the requirements ingested, the wheel
count fetched offline and the modules imported to validate, and whether validation
was standalone-helper, local dk0 dialog, or tag CI. Name any slot declared but not
covered by a CI runner.

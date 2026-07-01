---
name: build-ocaml-tool-off-dkml
description: Build a relocatable OCaml executable as a dk package off the DkML MSVC OCaml compiler across all slots including the 32-bit Windows_x86 and Linux_x86 ABIs, covering the MSVC-native vcvars build model, when a C-compiling tool needs per-arch Windows forms, the BusyBox-w32 autoconf quirks, and the Windows UAC output-naming constraint.
---

This skill captures the recipe for building an OCaml developer tool off
`CommonsLang_OCaml.DkML@4.14.3` (OCaml 4.14, relocatable, MSVC on Windows)
rather than off `Base@5.5.0` (OCaml 5). It is the MSVC-native counterpart to
`make-dk-package-from-autoconf`, which covers the GNU/LLVM-MinGW cross-compile
flavor. The `CommonsLang_OCaml` Dune and Opam lanes are worked examples of the
two structural shapes in Step 2.

## Step 1: Decide DkML vs Base

- `Base@5.5.0` is OCaml 5, which dropped 32-bit ABIs. It can only cover the
  64-bit slots: `Linux_x86_64`, `Windows_x86_64`, `Darwin_arm64`,
  `Darwin_x86_64`.
- `DkML@4.14.3` is OCaml 4.14 relocatable and covers all 7 slots, including the
  32-bit `Windows_x86` and `Linux_x86`.
- A tool that must ship on the 32-bit ABIs is built off DkML, slot-routed with
  `-s ${SLOTNAME.request}`, not off Base.
- On Windows, DkML's OCaml is an MSVC toolchain (flexlink), so the build runs
  under an activated Visual Studio environment (vcvars). It is not a MinGW
  cross-compile.

## Step 2: Structure the orchestrator and per-OS subforms

- An orchestrator form (`Tool@ver`) has `precommands.private` that
  `get-object` each slot from a per-OS subform, and `outputs` that declare
  `bin/tool.exe` for every slot.
- The Unix subform has no `OSFamily`; it is slot-routed through
  `DkML.Unix@4.14.3 -s ${SLOTNAME.request}`. It extracts, configures or
  bootstraps, then installs to each Unix slot (build once, `install -D` to all
  Unix slots; dk0 keeps the requested one per invocation).
- The Windows subform(s) set `OSFamily=windows` and route through
  `DkML.Win32@4.14.3 -s ${SLOTNAME.request}`; they run under vcvars (Step 3).

### The one-Win32-form vs two-Win32-forms rule

This is the key correctness decision, and it turns on whether the tool's build
compiles C:

- A **pure-OCaml bootstrap** (for example a `ocaml boot/bootstrap.ml` step)
  compiles no C. A wrong-arch build just yields a binary that gets discarded, so
  a single Win32 form may build **both** arches in sequence sharing one `s/` (an
  `x64` then an `x86` `--cmd.exe`), and dk0 keeps only the request-slot output.
  This is the Dune lane's shape.
- A build that **compiles C** (the tool's own C stubs, or vendored C libraries)
  fails to link when the OCaml arch and the active MSVC arch differ. It
  therefore needs **two per-arch forms** (`Tool.Win32.X64` -> `Windows_x86_64`,
  `Tool.Win32.X86` -> `Windows_x86`), each building only its arch with a clean
  source tree. Do not share `s/` across arches. This is the Opam lane's shape.

When unsure, treat the tool as C-compiling and use two forms; it is the safe
default.

## Step 3: Run the MSVC build under vcvars via --cmd.exe

- Provide a CRLF `.bat` that runs `vswhere` -> `vcvarsall <arch>` -> the `sh`
  build script, and register it as a `dk.u` asset. Invoke it with
  `["--cmd.exe", "/c", "<VSL string>"]`.
- The `--cmd.exe` payload is a VSL string. Use backtick-doublequote (`` `" ``)
  for the literal `cmd` quotes around each `$(...)`-expanded path, wrapped in an
  outer `\"...\"`. Read ESCAPING.md
  (https://raw.githubusercontent.com/diskuv/dk/refs/heads/V2_5/docs/ESCAPING.md)
  and mirror the `Dune.Win32` command char-for-char.
- Stack the toolchains as separate `<PATH=` prepend envmods (each `<PATH=`
  prepends): `DkML.Win32` (ocaml), any already-built OCaml tool the build needs
  (for example `Dune`), `W64dev` (sh, make, awk, tar, sed, gzip), and, if the
  build calls it, a `cygpath` shim directory (`${CACHEABS}${/}lookup-s`, staged
  by a `cp` command before the `--cmd.exe`).
- vcvarsall prepends to `PATH`, so the dk0 envmod tools remain resolvable by
  name inside the build script after activation.
- Keep build-time inputs hermetic: vendor any source the build would otherwise
  download at runtime as a `.Bundle` / dk0 bundle asset (dk0 fetches and
  checksums it) rather than fetching inside the recipe.

## Step 4: Handle the BusyBox-w32 autoconf quirks

The W64dev shell is BusyBox-w32 (ash). Inside the `sh` build script:

- `export PATH_SEPARATOR=';'` and `export ac_executable_extensions='.exe'` so
  autoconf searches a Windows-style `PATH` and finds `cl` / `ocamlopt` / ... by
  name. Set these **inside** the shell; lowercase env vars do not survive the
  `cmd` -> BusyBox transition.
- BusyBox-w32 exposes only `sh`/`bash` (the same ash binary); it cannot run
  bash-4 scripts (associative arrays, `${var,,}`, and deep recursion overflow
  its stack). If the upstream build shells out to such a script for a task the
  vcvars environment already satisfies, replace that script with a small stub
  that reports the answer from the active environment.
- Derive `ocaml`, `dune`, `awk`, `sh` from `which` on the dk0-provided `PATH`.

## Step 5: Respect the Windows UAC output-naming constraint

Windows' `CreateProcess` applies an install-detection heuristic that tries to
**elevate** any executable whose name looks like an installer: `install*`,
`setup*`, `patch*`, `update*`, and similar. In a non-interactive CI shell this
surfaces as an elevation prompt or a hard failure.

- Do not produce or invoke build executables with those names.
- If an upstream build target emits an installer-named helper you do not need,
  build only the specific target you require (for example an `.install`
  description target) instead of the aggregate that also links the
  installer-named binary.

## Step 6: Register assets, wire run.u, validate

- Register reusable scripts (build `.sh`, vcvars `.bat`, any stubs) as
  `% unified.asset` entries in `dk.u`, then `dk0 update --no-imports` fills each
  `'asset' 'size' 'sha256'` block. Git-track new files first. `.bat`/`.cmd` use
  CRLF, `.sh` use LF, with `.gitattributes` enforcing it so asset checksums are
  stable across platforms.
- Removing an asset that lives under a `dir=` asset (for example `assets/s`)
  changes that directory asset's hash; `dk0 update` recomputes it.
- Add a `## <Tool>` `run-object ... -c bin/tool.exe -- --version` check to each
  `dist-<slot>.u/run.u`. The recorded output is just the version string; these
  checks carry no content-hash and are hand-addable per slot.
- dk0 bundle versions must be dotted: use `@2025.9.3`, not `@20250903`.
- Validate in layers: `dk0 update` parses the values; `get-bundle` resolves and
  checksums any source bundle; the full multi-slot build is validated by
  tag-driven CI (push a `2.5.<timestamp>` tag, monitor `distribute-2.5.yml`). A
  local Windows build needs the full DkML MSVC environment.

## Output expectations

Report the values module(s) and slots added, the `.Bundle` modules providing
sources, the `dk.u` assets registered, the `run.u` sections added, and how
validation was performed (parse, bundle resolve, tag CI). Note any slot that is
declared but has no CI runner (for example `Linux_arm64` in the current matrix).

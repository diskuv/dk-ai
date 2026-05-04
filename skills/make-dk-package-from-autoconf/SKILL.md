---
name: make-dk-package-from-autoconf
description: Create or extend a dk package for an autoconf-based upstream project, including Windows cross-compilation, dist-win32 examples, and Linux/macOS validation guidance.
---

## Step 1: Analyze the dk package repository

### Step 1.1 — Attempt direct workspace reads

Try to read the following files and directories directly from the workspace:

1. `dk.u` in the repository root
2. All `dist-*.u/run.u` files, especially `dist-win32.u/run.u`
3. The package's primary `etc/dk/v/*.values.jsonc` module
4. The package's `*.Bundle.values.jsonc` source-asset module
5. Existing autoconf and Windows cross-compilation reference files in the git project `https://github.com/dkpkg/CommonsBase_GNU.git`, especially:
   - `etc/dk/v/Make.Autoconf.values.jsonc`
   - `etc/dk/v/Make.Win32.LLVM_MinGW.values.jsonc`
   - `etc/dk/v/Toolchain.W64dev*.values.jsonc`
   - `etc/dk/v/Toolchain.MinGW.values.jsonc`
6. Any package dependency modules that must also be Windows-enabled for the target package to build

Do not ask the user to paste these files.

### Step 1.2 — Fallback: run `analyze-project.ps1`

If **any** of the critical files or directories above cannot be read directly, you MUST
stop and run [analyze-project.ps1](analyze-project.ps1) in PowerShell on Windows from the project root:

```powershell
powershell -ExecutionPolicy Bypass -File {path_to_make_dk_package_from_autoconf_skill}\analyze-project.ps1 -OutFile "$env:TEMP\make-dk-package-from-autoconf-analysis.txt"
```

or on Unix run [analyze-project.sh](analyze-project.sh):

```bash
sh {path_to_make_dk_package_from_autoconf_skill}/analyze-project.sh "${TMPDIR:-/tmp}/make-dk-package-from-autoconf-analysis.txt"
```

The script will write the requested output file with:

- Whether `dk.u` exists in the repository root
- Inventory of `dist-*.u/run.u` files
- Relevant autoconf-related `*.values.jsonc` files, including bundle/toolchain/reference files
- Contents of each discovered file

Any temporary scratch files should be created in the OS temp directory, not in the repository.
Then wait for the output file contents to be provided back before continuing.

### Step 1.3 — Hard stop rule

If, after Step 1.1 and Step 1.2, you still do not have **all** of the
following concrete values, you MUST stop and ask the user to run
`analyze-project.ps1` or `analyze-project.sh` on Unix and paste its output.

Required values before continuing:

- [ ] Verified dk-project classification from root `dk.u`
- [ ] Inventory of all `dist-*.u/run.u` files
- [ ] The primary package `*.values.jsonc` file and its `*.Bundle.values.jsonc` file
- [ ] The current autoconf reference patterns used in the repository
- [ ] The current Windows toolchain reference patterns used in the repository
- [ ] Any package dependency modules that must also be updated for Linux, macOS, or Windows support

Only when every checkbox above is filled with real, verified data from the
repository may you proceed.

---

## Step 2: Create or extend the package modules

### Step 2.1 — Keep source assets in `.Bundle` modules

Source code assets must go into a `*.Bundle` module following the repository's
existing pattern. Do **not** place source tarballs, source zip conversions, or
other upstream source assets directly into the primary build module.

Typical pattern:

1. `SomePackage.Bundle.values.jsonc` defines the upstream source archive(s)
2. The primary package module converts and extracts the source
3. The package module builds from those bundle assets

If you add or change reusable local assets declared in `dk.u`:

1. Run `./dk0 update` (recommended). But run `_build/default/[ext/MlFront/]src/DkZero_Exec/Shell.exe update` when working in a `dksdk-coder` or `MlFront` checkout.

Do this **before** trying to consume those assets. Newly declared `dk.u` assets
are not immediately visible until the update step has refreshed the generated state.

If you add or generate reusable `.sh` asset scripts:

1. Write them with **LF** line endings, not CRLF.
2. Ensure the repository has `.gitattributes` guidance such as `*.sh text eol=lf`
   so checkout conversion does not change dk asset checksums across platforms.
3. Treat this as required for portable asset checksums; Windows CRLF conversion can
   otherwise make the same script hash differently from Linux/macOS checkouts.

If `Shell.exe` commands appear to be reusing stale build artifacts:

1. Delete the workspace `t/` build directory.
2. If the workspace then shows broken imported distributions or missing chunks,
   delete `etc/dk/i/`.
3. Run `update` again from the repaired workspace state before retrying the build.

Treat this as the general cache-recovery path for stale `Shell.exe` state instead
of repeatedly deleting individual temp subdirectories.

When those assets are meant to be reusable by the package, expose them through
an asset library in `dk.u`. The resulting cell is the workspace script's
library cell (for example `cell://CommonsBase_GNU` for a `CommonsBase_GNU`
workspace script). Do **not** introduce the deprecated `dk0` cell, and do not
route reusable package assets through `root`.

### Step 2.2 — Preserve Linux and macOS builds

The package must continue to build correctly on Linux and macOS. Windows
enablement must be added without regressing existing host-build behavior.

Prefer the repository's existing non-Windows autoconf pattern, such as
`Make.Autoconf.values.jsonc`, for native Darwin and Linux slots.

### Step 2.3 — Add Windows support with the repository's cross-compilation model

For this skill, a Windows request such as:

- `-s Release.Windows_x86_64`
- `-s Release.Windows_x86`
- `-s Release.Windows_arm64`

means:

1. The build executes on the **current Windows execution ABI**
2. The package uses `CommonsBase_GNU.Toolchain.W64dev@2.5.0` for the host-side
   Unix-like tools needed to run `./configure`, `make`, and `pkg-config`
3. The package uses `CommonsBase_LLVM.Toolchain.MinGW@21.1.8+rev-20251216` for
   the **target GCC cross-compiler**
4. The package prepends the extracted LLVM-MinGW `bin` directory to `PATH`
   before running `./configure`, `make`, or any helper that expects
   `x86_64-w64-mingw32-gcc`, `i686-w64-mingw32-gcc`, or
   `aarch64-w64-mingw32-gcc` to resolve by name
5. If both W64dev and LLVM-MinGW need to be on `PATH`, use multiple `<PATH`
   envmods. Each `<PATH` envmod prepends to `PATH`, so they can be stacked
   instead of manually concatenating one long `PATH` expression
6. If autoconf discovery is unreliable on Windows, explicitly pin host-side
   tools and binutils with envmods such as `+GREP=...`, `+EGREP=...`,
   `+FGREP=...`, `+EGREP_TRADITIONAL=...`, `+SED=...`, `+LD=...`,
   `+AR=...`, and `+RANLIB=...`
7. The result is a cross-compile from the current Windows execution ABI to the
   requested Windows target ABI

Composite host-target slot forms like `Release.Darwin_arm64.Windows_x86_64`
are **out of scope** for this skill, even though
`Make.Win32.LLVM_MinGW.values.jsonc` is still a valuable reference for the
cross-compilation recipe.

### Step 2.4 — Reuse the right examples

Prefer these repository patterns:

- `Make.Autoconf.values.jsonc` for the baseline autoconf flow
- `Make.Win32.LLVM_MinGW.values.jsonc` for the Windows LLVM-MinGW cross-compile recipe

Do **not** model new work on `Make.Win32.values.jsonc` because that file uses
GNU Make's specialized non-autoconf Windows build script instead of the general
autoconf flow this skill is meant to produce.

### Step 2.5 — Wire package dependencies explicitly

If the package depends on other libraries or tools, update their slots and
include/lib wiring first or in dependency order. Preserve the existing package
relationships and do not guess missing dependencies.

Typical examples include:

- A build-time tool dependency such as Bison/YACC
- A C library dependency such as GMP
- A dependent crypto or TLS library stack such as GMP -> Nettle -> TLS

---

## Step 3: Implement the autoconf package recipe

For a typical upstream autoconf project:

1. Extract the source from the package's `.Bundle` module
   - for GNU upstream assets, use at least 10 geographically dispersed mirrors
     in the `.Bundle` origin listing rather than a single GNU URL
2. Apply any required source patches
3. Stage the Windows host-side tools from `CommonsBase_GNU.Toolchain.W64dev@2.5.0`
4. Stage the target compilers from `CommonsBase_LLVM.Toolchain.MinGW@21.1.8+rev-20251216`
5. Prepend the extracted LLVM-MinGW `bin` directory to `PATH` so the requested
   MinGW compiler driver names resolve during the build
6. If the Windows shell/build tools also need to resolve by name, prepend the
   extracted W64dev `bin` directory with another `<PATH` envmod
7. If Windows autoconf probes do not reliably discover tools, pin them
   explicitly with envmods before `./configure`; common fixes include:
   - `+LD=...`, `+AR=...`, `+RANLIB=...` for LLVM-MinGW linker/binutils tools
   - `+GREP=...`, `+EGREP=...`, `+FGREP=...`, `+EGREP_TRADITIONAL=...` for a GNU grep provider
   - `+SED=...` for a GNU sed provider
   - `+AWK=...` and `+M4=...` for host-side GNU awk and GNU m4 providers
8. When a `./configure`-generated file still bakes in raw backslash-heavy Windows
   paths, handle it in this priority order:
   - first, avoid fragile absolute Windows paths by preferring tool names in
     envvars and exposing those tools on `PATH`
   - only if that still fails, use GNU `sed --in-place` to rewrite the generated
     files (prefer `sed -f FILE --in-place` to avoid quoting problems)
9. Commands inside dk package recipes should be hermetic. Do not invoke host
   `powershell` from recipe commands; rely on declared tools and scripts that run
   under the packaged shell/toolchain instead
10. Run `./configure` with explicit build/host triples and compiler selection
11. Run `make`
12. Run `make install`
13. Prune non-reproducible or unwanted outputs only when the repository already follows that pattern
14. Declare outputs precisely for every supported slot

When helper shell scripts are needed as reusable package assets, prefer storing
them as committed `.sh` files with LF endings and keep `.gitattributes`
enforcing `*.sh text eol=lf` so the packaged asset checksum is stable.

When writing the PATH wiring, prefer the repository's existing envmod pattern,
for example:

```json
"envmods": [
  "<PATH=$(--path=absnative get-object CommonsBase_GNU.Toolchain.W64dev@2.5.0 -s Release.execution_abi -d : -e 'bin/*')${/}bin",
  "<PATH=$(--path=absnative get-object CommonsBase_LLVM.Toolchain.MinGW@21.1.8+rev-20251216 -s Release.execution_abi -d : -e 'bin/*')${/}bin",
  "+LD=x86_64-w64-mingw32-ld",
  "+AR=x86_64-w64-mingw32-ar.exe",
  "+RANLIB=x86_64-w64-mingw32-ranlib.exe",
  "+GREP=$(--path=absnative get-object CommonsBase_GNU.Grep@2.5.4+gnuwin32-20090213 -s Release.execution_abi -d : -e 'bin/*')${/}bin${/}grep.exe",
  "+EGREP_TRADITIONAL=$(--path=absnative get-object CommonsBase_GNU.Grep@2.5.4+gnuwin32-20090213 -s Release.execution_abi -d : -e 'bin/*')${/}bin${/}grep.exe",
  "+EGREP=$(--path=absnative get-object CommonsBase_GNU.Grep@2.5.4+gnuwin32-20090213 -s Release.execution_abi -d : -e 'bin/*')${/}bin${/}egrep.exe",
  "+FGREP=$(--path=absnative get-object CommonsBase_GNU.Grep@2.5.4+gnuwin32-20090213 -s Release.execution_abi -d : -e 'bin/*')${/}bin${/}fgrep.exe",
  "+SED=$(--path=absnative get-object CommonsBase_GNU.Sed@4.2.1+gnuwin32-20101228 -s Release.execution_abi -d : -e 'bin/*')${/}bin${/}sed.exe"
]
```

The order matters: later `<PATH` envmods still prepend, so place the highest
priority toolchain last if it should appear first on the effective `PATH`.
Non-`PATH` envmods such as `+LD=...` or `+GREP=...` are useful when autoconf
probes reject otherwise reachable tools on Windows.

When you need to repair a `./configure`-generated file that contains raw
backslash Windows paths, prefer a hermetic helper that runs under the packaged
shell and GNU sed. Use `sed -f FILE --in-place` instead of embedding fragile
sed expressions directly in recipe arguments.

If you bootstrap host-side GNU utilities from GnuWin32, follow the same pattern
used for `CommonsBase_GNU.Grep@2.5.4+gnuwin32-20090213`: copy the 32-bit
runtime binaries and required DLLs into `${SLOT.request}/bin`, then expose that
same package for `Release.Windows_x86`, `Release.Windows_x86_64`, and
`Release.Windows_arm64`. The 32-bit GnuWin32 executables are acceptable host
tools across those Windows execution ABIs.

If the recipe introduces or edits any `dk.u` asset declarations used by the
package, run the required `update` command before validation.

When adding a GNU source asset to a `.Bundle.values.jsonc`, prefer one GNU
origin with many mirrors rather than many separate origins. Use at least 10
geographically dispersed mirrors so source downloads stay resilient across
regions and outages.

When adapting an existing Unix-only package, keep the Darwin/Linux commands and
slots intact unless the same refactor is needed to keep the logic consistent.

---

## Step 4: Update `dist-win32.u/run.u`

You must add or update `dist-win32.u/run.u` with at least one working example
for each Windows-enabled package.

Requirements for each package section:

1. A section dedicated to the package
2. Prose that explains what the package does
3. That prose must be based on the package's emitted output files
4. At least one working Windows example using the package
5. Each example must have its own prose explaining what that example does

Examples of package-description sources:

- `bin/*.exe` implies an end-user command-line tool
- `include/*.h` and `lib/*.a` imply a development library
- `share/*`, `libexec/*`, or `pkgconfig/*.pc` imply runtime support files, developer metadata, or helper tooling

Do not write generic placeholder prose. Base the prose on the outputs the
package actually installs.

---

## Step 5: Validate on Windows, Linux, and macOS

### Step 5.1 — Windows validation

Validate the Windows package with `Shell.exe get-object ...` using the exact slot
requested by the user.

For unsupported local execution targets, use tooling such as `file` from the
MSYS2 installation (for example under `C:\msys64\usr\bin` or `Z:\msys64\usr\bin`) to
confirm the PE architecture.

### Step 5.2 — Linux validation

Validate Linux using one of:

1. A Docker container
2. WSL2
3. The host directly if the host is Linux

Prefer Docker or WSL2 on Windows when a native Linux host is not available.

### Step 5.3 — macOS validation

Validate macOS on:

1. A macOS machine, or
2. A CI job similar to the repository's existing macOS validation approach when the current host is not macOS

Do not claim macOS support is complete until one of those validation paths has
been used or clearly queued.

---

## Output expectations

When done, report:

- Files created or updated
- Which package modules gained new slots
- Which `.Bundle` modules provide the source assets
- Which `dist-win32.u/run.u` sections/examples were added or revised
- How Windows, Linux, and macOS validation was performed
- Any blockers or package-specific caveats that still remain

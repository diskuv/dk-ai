---
name: troubleshoot-ocaml-inconsistent-assumptions
description: Diagnose OCaml "inconsistent assumptions over implementation Location" (and similar compiler-libs interface-mismatch) link errors by reading and comparing the implementation CRCs the compiler recorded in each object, using ocamlobjinfo plus a bundled zip central-directory extractor that pulls the targeted .cmx/.cmxa members out of a large dk value-store artifact in seconds instead of unzipping the whole thing. Covers the two proven root causes, a cross-slot (cross-ABI) object mixup and wrong OCaml configure options that bake an absolute path into config.cmx, and the CRC-comparison method that tells them apart.
---

This skill captures how to troubleshoot the OCaml native-link error

```
Error: The files a.cmxa and b.cmx make inconsistent assumptions over implementation Location
```

(and its variants over `Config`, `Ocamlcommon` or any other compiler-libs unit).
The error means two objects on the same link line were compiled against two
different builds of the same module, so their recorded interface/implementation
CRCs disagree. The whole diagnosis is: read the CRC each object carries for the
named module on both sides of the failing link, and find where they diverge.
`ocamlobjinfo` reads the CRCs; the bundled `extract_objs.py` gets the objects out
of a dk value-store artifact cheaply so you have something to point `ocamlobjinfo`
at.

## Step 1: Read what the error is actually telling you

The message names a module (`Location`, `Config`, ...) and two files. Every
compiled OCaml object records, for each module it depends on, a CRC of that
module's interface, and for each module it implements, a CRC of the
implementation. A native link is rejected when two inputs disagree on either CRC
for the same unit. So the fault is never in your code; it is that two objects were
built against different copies of one library, most often part of
`compiler-libs` (`Location`, `Config`, `Ocamlcommon`), which is exactly what a ppx
or a static-analysis tool links against.

## Step 2: Compare CRCs with ocamlobjinfo

`ocamlobjinfo` prints, per object, the `Implementations imported` and
`Interfaces imported` tables with the CRC beside each unit name. You need an
OCaml 4.14 install for it (any local switch, or the
`ocaml/opam:debian-ocaml-4.14` container:
`docker run --rm -v "$PWD:/w" -w /w ocaml/opam:debian-ocaml-4.14 ocamlobjinfo <file>`).

For each object on the failing link line, read the CRC of the named module:

```
ocamlobjinfo ocamlcommon.cmxa | grep -iA1 'Location'
ocamlobjinfo astlib.cmxa      | grep -iA1 'Location'
ocamlobjinfo codept_lib.cmxa  | grep -iA1 'Location'
```

If two objects show different CRCs for `Location`, they were built against
different `compiler-libs`. Objects that all show the SAME CRC agree, so the odd
one out is the culprit. `strings` on the same objects is a fast cross-check when
`ocamlobjinfo` is not to hand: an absolute filesystem path visible in `config.cmx`
(see root cause B) is often the tell.

## Step 3: Get the objects cheaply with the bundled extractor

The objects you need are usually not loose on disk; they are buried inside a dk
value-store artifact, nested as `valuestore.zip -> blob -> prefix.zip ->
lib/.../*.cmxa`. Fully unzipping an ~800 MB artifact to reach a 40 KB `.cmxa`
wastes 8 to 40 minutes each. `extract_objs.py` reads the zip CENTRAL DIRECTORY and
pulls only the targeted members through the nested zips in seconds, printing each
match with its sha256.

Run it with `python` or `uv run python`:

```
python extract_objs.py <package.valuestore.zip> <out-dir> [blob-key-substring]
uv run python extract_objs.py <package.valuestore.zip> <out-dir> [blob-key-substring]
```

- `<out-dir>` receives each matched `.cmx`/`.cmxa`, one per basename.
- The optional third argument is a comma-separated substring filter on the
  top-level blob names, so you skip blobs you know are irrelevant.
- Adapt the `TARGETS` regex at the top of the script to the modules your error
  names. The bundled default matches `compiler-libs` `config`/`location`/
  `ocamlcommon`, ppxlib `astlib.cmxa`, and codept `codept_lib.cmxa`.
- The nested blob is DEFLATE-compressed rather than stored, so the size-based
  `is_ziplike` heuristic (a member over 3 MB is treated as a possible inner zip)
  is what lets the walk find it. Keep that heuristic if you adapt the script.

Extract from every artifact on both sides of the link (the toolchain artifact and
each closure artifact), then run Step 2 across all the extracted objects.

## The two proven root causes

Both were found in the dk engine's own harness; both were diagnosed exactly this
way. When your CRCs diverge, it is almost always one of these.

### Root cause A: a cross-slot (cross-ABI) object mixup

Objects built for one slot (ABI) leaked into a link for another slot. OCaml
`compiler-libs` objects are ABI-specific, so a `Windows_x86` `location.cmx`
mixed with a `Windows_x86_64` `ocamlcommon.cmxa` carries a different CRC and the
link is rejected. The tell is that the divergent object also differs by target
triple or install prefix in its path, not just its CRC. The fix is to make the
closure slot-consistent: route every object through the same
`-s ${SLOTNAME.request}` slot so no cross-ABI object reaches the link. In the
harness this was tracked as the cross-ABI-identity regret.

### Root cause B: wrong OCaml configure options bake an absolute path into config.cmx

When OCaml is configured with an absolute `bindir`/`libdir`, that absolute path is
compiled into `config.ml` and therefore into `config.cmx`. Two OCaml builds
configured with different absolute paths (for example a published relocatable
toolchain versus a gate's fresh compiler-libs build in a different directory)
produce a different `Config` implementation and a different CRC, so anything built
against one fails to link against the other. `strings config.cmx` shows the baked
absolute path directly. The cure is to configure OCaml relocatably, with
`--with-relative-libdir` (and relative `bindir`), so `config.cmx` carries no
build-machine path and the CRC is stable across builds. In the harness this was
the H5 fix.

### Telling them apart

- Paths differ by ABI / target triple => root cause A (cross-slot mixup);
  make the closure slot-consistent.
- Paths differ by install prefix on the same ABI, and `strings config.cmx` shows
  an absolute path => root cause B; reconfigure with `--with-relative-libdir`.
- All CRCs actually AGREE => the mismatch is not in the published objects at all
  but in a fresh build in the pipeline (for example the gate compiling its own
  `compiler-libs`). This is the outcome the extractor proved once: the published
  toolchain, the astlib and codept objects all agreed at `Location` impl
  `929d85a7`, so the fault lay in the gate's fresh compiler-libs build, not the
  published objects.

## Output expectations

Report the module and the two files the error named, the CRC each relevant object
showed for that module (from `ocamlobjinfo`), which object was the odd one out,
which root cause the divergence matches (A cross-slot, B configure path, or
"objects agree, look upstream"), and the concrete fix applied (slot routing, or
`--with-relative-libdir`). Note the artifacts you extracted from and the sha256 of
each object you compared, so the comparison is reproducible.

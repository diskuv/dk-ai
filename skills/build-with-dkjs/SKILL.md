---
name: build-with-dkjs
description: Build a dk project with dkjs, the JavaScript build system in the dk family. dkjs runs on Node.js with no native binary (published on npm as @dkjs/cli, which installs a `dkjs` command that takes the same argv as dk0/dk1 and produces byte-identical output) and builds JavaScript and web (js_web) targets. Use it when the dk project targets JavaScript or web; for native (C) builds use the native dk1 binary.
---

# Building a dk project with dkjs

`dkjs` is the JavaScript build system in the dk family: the dk build engine
compiled to a single JavaScript bundle that Node.js runs with no native binary.
It is published on npm as **`@dkjs/cli`**, which installs a **`dkjs`** command
that takes the same argv as the native `dk0` / `dk1` and produces byte-identical
output.

Reach for dkjs when the dk project builds **JavaScript or web** targets
(execution ABI `js_nodejs`, target `js_web`). For native builds (for example C),
use the native **`dk1`** binary; dkjs does not generate native code yet.

Full contract: the [dkjs reference](https://diskuv.com/dk/help/latest/dkjs/).

## Step 1: Get dkjs

The host needs Node.js 18 or newer. Install the command globally:

```sh
npm install -g @dkjs/cli    # provides the `dkjs` command
dkjs --version              # prints the dk version, e.g. 2.4.2
```

or run it without installing:

```sh
npx @dkjs/cli <command> ...
```

`npx @dkjs/cli` and an installed `dkjs` are interchangeable below.

## Step 2: Build

`dkjs` runs the same commands as `dk0` / `dk1`. From a dk project root:

```sh
dkjs update                                          # resolve imports + workspace assets
dkjs get-object <Module@Version> -s <Slot> -d out    # materialize a slot
```

Pass `-j N` to overlap independent external steps (dkjs defaults to `-j 1`). The
build is byte-identical to the same build under `dk0` / `dk1`.

## Step 3: Boundaries

- **JavaScript and web only.** dkjs builds `js_nodejs` / `js_web` targets. It does
  not generate native code yet; use `dk1` for native builds.
- **Run dkjs alone against a given cache and workspace.** Node.js has no OS
  advisory file locks, so dkjs cannot coordinate with a `dk0` / `dk1` running at
  the same time against the same cache.

Every other command behaves as documented for `dk0`; see the reference above.

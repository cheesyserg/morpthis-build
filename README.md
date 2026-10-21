# morpthis-build

The device build for Morpthis apps.

This repository does not hold app source. It checks out the five repositories,
builds the pinned MIPS toolchain when it is not already cached, runs the SDK
ABI check against every app, and writes the `.mapp` packages.

```text
morpthis-build/
  Makefile                 local and CI entry points
  .github/workflows/build.yml
  dist/                    .mapp output (gitignored)
  toolchain/               pinned cross compiler (gitignored)
  toolchain-downloads/     source tarballs for it (gitignored)
```

## What it builds

- `morpthis-apps` — the apps' source, manifests and host build.
- `morpthis-sdk` — the public headers, `app.mk` and ABI contract.
- `morpthis-player` — the `rockboxdev` scripts that produce the pinned
  GCC 9.5.0 / binutils 2.38 / glibc 2.27 toolchain.
- `doomgeneric` — the Doom engine source the `doom` app builds from, patched
  with `apps/doom/doomgeneric-morpthis.patch`.
- `morpthis-build` — this orchestration.

The output is one package per app under `dist/`:

```text
calculator-1.0.0.mapp
checksum-1.0.0.mapp
BUILD-INFO.txt
```

A `.mapp` is a zip with the app folder at its root: `app.json`, the optional
icon, and the entry binary. Extract it to `Apps/<id>/` on the card.

## Local build

The defaults expect the repositories to be siblings:

```text
morpthis/
  morpthis-apps/
  morpthis-build/
  morpthis-player/
  morpthis-sdk/
  doomgeneric/
```

```sh
make host       # validate manifests and run the host smoke tests
make package    # build the toolchain if needed, then dist/*.mapp
```

Override paths when the checkout is elsewhere:

```sh
make APPS_DIR=/srv/morpthis-apps \
     SDK_DIR=/srv/morpthis-sdk \
     PLAYER_DIR=/srv/morpthis-player \
     DOOMGENERIC_DIR=/srv/doomgeneric/doomgeneric \
     TOOLCHAIN=/srv/morpthis-toolchain \
     package
```

The toolchain's sysroot is baked in as an absolute path, so do not move
`TOOLCHAIN` after building it; use `make clean-toolchain` and rebuild instead.

## CI

`build.yml` runs on every push and pull request for the host tests. The device
job runs on a manual dispatch or a tag:

- It checks out `apps`, `sdk`, `player` and `doomgeneric` at `main` unless refs
  are supplied, and applies the Doom port patch before building.
- It restores `toolchain/` from the Actions cache. On a miss it builds the
  toolchain from the player's `rockboxdev` scripts.
- It runs `make package`, so the ABI check happens before any `.mapp` is
  written.
- It uploads `dist/` as an artifact.

Manual dispatch inputs:

| Input | Default | Meaning |
| --- | --- | --- |
| `apps_ref` | `main` | Branch, tag or SHA of `morpthis-apps` |
| `sdk_ref` | `main` | Branch, tag or SHA of `morpthis-sdk` |
| `player_ref` | `main` | Branch, tag or SHA of `morpthis-player` |
| `apps_release_tag` | empty | Optional release in `morpthis-apps` to attach the packages to |

On a tag in this repository, the packages are attached to the matching release
here when one exists. Attaching to a release in `morpthis-apps` needs an
`APPS_RELEASE_TOKEN` secret with write access to that repository; the step is
skipped when the input or token is absent.

Refs are inputs rather than hidden state: a build run says which `apps`, `sdk`,
`player` and `doomgeneric` commits it used, and `dist/BUILD-INFO.txt` repeats
them.

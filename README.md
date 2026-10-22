# morpthis-build

The device build for Morpthis apps.

This repository does not hold app source. It checks out the six repositories,
builds the pinned MIPS toolchain when it is not already cached, runs the SDK
ABI check against every app, and writes the `.pkgmerp` packages.

```text
morpthis-build/
  Makefile                 local and CI entry points
  .github/workflows/build.yml
  dist/                    .pkgmerp output (gitignored)
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
- `InfoNES` — the NES emulator core the `nes` app builds from.
- `morpthis-build` — this orchestration.

The output is one package per app under `dist/`:

```text
calculator.pkgmerp
checksum.pkgmerp
doom.pkgmerp
flappybird.pkgmerp
nes.pkgmerp
BUILD-INFO.txt
```

A `.pkgmerp` is an uncompressed squashfs image with the app folder at its root:
`app.json`, the optional icon, and the entry binary. The player mounts it
read-only through a loop device; nothing is extracted. The name carries no
version, because the card holds at most one package per app and replacing the
file is the update. `squashfs-tools` must be installed where `make package`
runs (the CI job installs it).

On the card:

```text
<card>/Apps/pkgmerps/<id>.pkgmerp
<card>/Apps/merp_data/<id>/      the app's writable folder
```

## Local build

The defaults expect the repositories to be siblings:

```text
morpthis/
  morpthis-apps/
  morpthis-build/
  morpthis-player/
  morpthis-sdk/
  doomgeneric/
  InfoNES/
```

```sh
make host       # validate manifests and run the host smoke tests
make package    # build the toolchain if needed, then dist/*.pkgmerp
```

Override paths when the checkout is elsewhere:

```sh
make APPS_DIR=/srv/morpthis-apps \
     SDK_DIR=/srv/morpthis-sdk \
     PLAYER_DIR=/srv/morpthis-player \
     DOOMGENERIC_DIR=/srv/doomgeneric/doomgeneric \
     INFONES_DIR=/srv/InfoNES \
     TOOLCHAIN=/srv/morpthis-toolchain \
     package
```

The toolchain's sysroot is baked in as an absolute path, so do not move
`TOOLCHAIN` after building it; use `make clean-toolchain` and rebuild instead.

## CI

`build.yml` runs on every push and pull request for the host tests. The device
job runs on a manual dispatch or a tag:

- It checks out `apps`, `sdk`, `player`, `doomgeneric` and `InfoNES` at
  `main` (InfoNES at a pinned commit) unless refs are supplied, and applies the
  Doom port patch before building.
- It restores `toolchain/` from the Actions cache. On a miss it builds the
  toolchain from the player's `rockboxdev` scripts.
- It runs `make package`, so the ABI check happens before any `.pkgmerp` is
  written.
- It uploads the packages three ways: `morpthis-pkgmerps-<sha>` with every
  file, `pkgmerp-<id>` for each app on its own, and
  `morpthis-pkgmerps-<sha>-zip` with the whole set in one zip. Releases get the
  loose `.pkgmerp` files and the zip.

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
`player`, `doomgeneric` and `InfoNES` commits it used, and
`dist/BUILD-INFO.txt` repeats them.

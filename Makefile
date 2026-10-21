# morpthis-build
#
# The device build for the apps: checks out the sibling repositories, builds the
# pinned MIPS toolchain if it is not there, runs the ABI check and packages the
# .mapp files.
#
#   make host        validate the manifests and run the apps' host tests
#   make device      build the toolchain and the MIPS app binaries, then check-abi
#   make package     do the above and write dist/*.mapp
#   make test        alias for host
#   make toolchain   build the toolchain only
#   make clean       remove dist/, leave the toolchain alone
#   make clean-toolchain
#
# Defaults assume the repositories are siblings:
#
#   <workspace>/
#     morpthis-apps/
#     morpthis-build/     <- here
#     morpthis-player/
#     morpthis-sdk/
#     doomgeneric/
#
# Every path can be overridden:
#
#   make APPS_DIR=/path/to/morpthis-apps SDK_DIR=/path/to/morpthis-sdk \
#        PLAYER_DIR=/path/to/morpthis-player \
#        DOOMGENERIC_DIR=/path/to/doomgeneric/doomgeneric package

APPS_DIR ?= ../morpthis-apps
SDK_DIR ?= ../morpthis-sdk
PLAYER_DIR ?= ../morpthis-player
DOOMGENERIC_DIR ?= $(abspath $(APPS_DIR)/../doomgeneric/doomgeneric)

TOOLCHAIN ?= $(CURDIR)/toolchain
TOOLCHAIN_DOWNLOADS ?= $(CURDIR)/toolchain-downloads
DIST ?= $(CURDIR)/dist
ROCKBOX_SCRIPT ?= $(PLAYER_DIR)/morpthis-player/rockboxdev/rockboxdev.sh

CROSS_TOOLCHAIN := $(abspath $(TOOLCHAIN))
TOOLCHAIN_BIN := $(CROSS_TOOLCHAIN)/bin
MORPTHIS_SDK := $(abspath $(SDK_DIR))
APPS := $(abspath $(APPS_DIR))
CROSS_CC := $(TOOLCHAIN_BIN)/mipsel-rockbox-linux-gnu-gcc

# The compiler looks up its sysroot by the absolute path it was configured with,
# so the directory must stay put between the build and its use.
BUILD_PATH = PATH="$(TOOLCHAIN_BIN):$$PATH"

.PHONY: all host test validate toolchain device package clean clean-toolchain

all: host

validate:
	python3 "$(APPS)/tools/validate-manifest.py" --all "$(APPS)/apps"

host: validate
	$(MAKE) -C "$(APPS)" MORPTHIS_SDK="$(MORPTHIS_SDK)" \
		DOOMGENERIC_DIR="$(DOOMGENERIC_DIR)" test

test: host

toolchain: $(CROSS_CC)

$(CROSS_CC):
	@if [ ! -f "$(ROCKBOX_SCRIPT)" ]; then \
		echo "toolchain: $(ROCKBOX_SCRIPT) not found" >&2; \
		echo "toolchain: set PLAYER_DIR to the morpthis-player checkout" >&2; \
		exit 1; \
	fi
	@mkdir -p "$(CROSS_TOOLCHAIN)" "$(abspath $(TOOLCHAIN_DOWNLOADS))"
	RBDEV_HOST_PREFIX="$(CROSS_TOOLCHAIN)" \
	RBDEV_DOWNLOAD="$(abspath $(TOOLCHAIN_DOWNLOADS))" \
	RBDEV_MORPTHIS_MINIMAL=1 \
	bash "$(ROCKBOX_SCRIPT)"

device: toolchain
	$(BUILD_PATH) $(MAKE) -C "$(APPS)" MORPTHIS_SDK="$(MORPTHIS_SDK)" \
		DOOMGENERIC_DIR="$(DOOMGENERIC_DIR)" check-abi

package: device
	@rm -rf "$(DIST)" "$(APPS)/dist"
	$(BUILD_PATH) $(MAKE) -C "$(APPS)" MORPTHIS_SDK="$(MORPTHIS_SDK)" \
		DOOMGENERIC_DIR="$(DOOMGENERIC_DIR)" \
		MORPTHIS_MODE=device package
	@mkdir -p "$(DIST)"
	@cp "$(APPS)"/dist/*.mapp "$(DIST)"/
	@{ \
		echo "built: $$(date -u +%Y-%m-%dT%H:%M:%SZ)"; \
		echo "apps: $$(git -C "$(APPS)" rev-parse HEAD 2>/dev/null || echo unknown)"; \
		echo "sdk: $$(git -C "$(abspath $(SDK_DIR))" rev-parse HEAD 2>/dev/null || echo unknown)"; \
		echo "player: $$(git -C "$(abspath $(PLAYER_DIR))" rev-parse HEAD 2>/dev/null || echo unknown)"; \
		echo "doomgeneric: $$(git -C "$(abspath $(DOOMGENERIC_DIR))" rev-parse HEAD 2>/dev/null || echo unknown)"; \
	} > "$(DIST)/BUILD-INFO.txt"
	@echo "Packages in $(DIST):"
	@ls -1 "$(DIST)"

clean:
	rm -rf "$(DIST)"

clean-toolchain:
	rm -rf "$(CROSS_TOOLCHAIN)" "$(abspath $(TOOLCHAIN_DOWNLOADS))"

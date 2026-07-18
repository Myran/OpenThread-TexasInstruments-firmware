# Justfile — build the patched OpenThread RCP firmware for the SONOFF ZBDongle-P (CC2652P).
# Requires: just, git, docker. Run a bare `just` to list recipes.

# Version string stamped into the output firmware filename.
version := "2026.1.1"

# Build-environment image (matches the project's documented build).
image := "ubuntu:24.04"

# List available recipes (runs when you type a bare `just`).
default:
    @just --list

# Initialise the ot-ti submodule and all nested submodules (needed before building).
submodules:
    git submodule update --init --recursive

# Build the Dongle-P firmware in a fresh container (bootstraps the TI toolchain each run).
build: submodules
    docker run --rm -v "{{justfile_directory()}}":/data -w /data {{image}} bash -c "bash scripts/bootstrap.sh && bash scripts/build.sh {{version}}"
    @echo "Firmware written to ./dist:"
    @ls -1 dist

# Open an interactive shell in the build container (for debugging the build).
shell: submodules
    docker run -it --rm -v "{{justfile_directory()}}":/data -w /data {{image}} bash

# Check that the source-match patch still applies cleanly to a pristine ot-ti.
verify-patch: submodules
    cd ot-ti && git restore src/radio.c 2>/dev/null; git apply --check ../patches/*.patch && echo "patch applies cleanly"

# Show the built firmware artifacts.
dist:
    @ls -la dist 2>/dev/null || echo "No dist/ yet — run 'just build'."

# Remove build outputs (leaves submodule git state intact).
clean:
    rm -rf dist
    -cd ot-ti && git clean -dxf

# Push the current branch to your fork.
push:
    git push

# Open the SMLIGHT web flasher to flash dist/*.hex (macOS).
flash:
    @echo "Flash dist/*.hex at the SMLIGHT web flasher:"
    -open https://smlight.tech/flasher/

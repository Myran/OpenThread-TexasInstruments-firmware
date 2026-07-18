# Justfile — build the patched OpenThread RCP firmware for the SONOFF ZBDongle-P (CC2652P).
# Requires: just, git, docker. Run a bare `just` to list recipes.

# Version string stamped into the output firmware filename.
version := "2026.1.1"

# Build-environment image (matches the project's documented build).
image := "ubuntu:24.04"

# --- Dongle flashing (used by the flash-* / dongle-* recipes) ---
# Serial port of the Sonoff dongle, auto-detected. Override for a specific port:
#   just port=/dev/cu.usbserial-XXXX flash-thread
port  := `ls /dev/cu.usbserial-* /dev/ttyUSB* 2>/dev/null | head -1`
# cc2538-bsl flasher + its venv, installed into .tools/ by `just bsl-setup`.
bslpy := ".tools/venv/bin/python"
bsl   := ".tools/cc2538-bsl/cc2538_bsl/cc2538_bsl.py"

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

# === Dongle flashing (run on the machine where the dongle is plugged in) ===
# cc2538-bsl gotchas baked in: --bootloader-sonoff-usb (auto-BSL, no BOOT button),
# addresses are DECIMAL not hex, and we never pass -D (keeps the BSL backdoor so
# the dongle can always be re-flashed). The Sonoff ZBDongle-P is a CC2652P /
# CC1352P2_CC2652P_launchpad target — the same one `just build` produces.

# One-time: install cc2538-bsl + python deps into .tools/ (idempotent).
bsl-setup:
    mkdir -p .tools
    [ -d .tools/venv ] || python3 -m venv .tools/venv
    .tools/venv/bin/pip -q install --upgrade pip pyserial intelhex
    [ -d .tools/cc2538-bsl ] || git clone --depth 1 https://github.com/JelmerT/cc2538-bsl.git .tools/cc2538-bsl
    @echo "cc2538-bsl ready. Dongle port: {{port}}"

# Non-destructive: enter the bootloader and read the chip ID. Run this FIRST to
# confirm BSL entry + serial comms before erasing anything.
dongle-probe: bsl-setup
    {{bslpy}} {{bsl}} -p {{port}} --bootloader-sonoff-usb -r -a 0 -l 256 /dev/null

# Back up the dongle's full 352 KB flash to backups/ (timestamped). Insurance.
dongle-backup: bsl-setup
    mkdir -p backups
    {{bslpy}} {{bsl}} -p {{port}} --bootloader-sonoff-usb -r -a 0 -l 360448 "backups/dongle_$(date +%Y%m%d_%H%M%S).bin"
    @ls -lh backups/

# Flash the built Thread RCP firmware: backup -> erase -> write -> verify.
# WARNING: erases the current firmware (a Zigbee coordinator loses its network).
flash-thread: bsl-setup dongle-backup
    -cd dist && unzip -o *.zip >/dev/null 2>&1
    {{bslpy}} {{bsl}} -p {{port}} --bootloader-sonoff-usb -e -w -v dist/*.hex

# Revert to stock Zigbee coordinator firmware: backup -> download latest -> flash.
flash-zigbee: bsl-setup dongle-backup
    mkdir -p .tools/zigbee
    cd .tools/zigbee && curl -fsSL -O "$(curl -fsSL https://api.github.com/repos/Koenkk/Z-Stack-firmware/releases/latest | grep -oE 'https://[^\"]*CC1352P2_CC2652P_launchpad_coordinator[^\"]*\.zip' | head -1)" && unzip -o *.zip >/dev/null
    {{bslpy}} {{bsl}} -p {{port}} --bootloader-sonoff-usb -e -w -v .tools/zigbee/*.hex

# GUI alternative: open the SMLIGHT web flasher (flash dist/*.hex in a browser).
flash-web:
    @echo "Flash dist/*.hex at the SMLIGHT web flasher (Chromium browser needed):"
    -open https://smlight.tech/flasher/

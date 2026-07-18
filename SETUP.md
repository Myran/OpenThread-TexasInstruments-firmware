# Patched OpenThread RCP firmware for the SONOFF ZBDongle-P (CC2652P)

This turns your Sonoff ZBDongle-P into a Thread radio for Home Assistant's
OpenThread Border Router, with the source-match fix that stopped the RCP
crashing when a Thread device joins.

## What these files are

| File | Purpose |
|------|---------|
| `patches/0001-fix-srcmatch-precedence.patch` | The one-line fix to `ot-ti/src/radio.c` (operator-precedence bug in `otPlatRadioClearSrcMatchExtEntry`). |
| `scripts/build.sh` | Modified: applies everything in `patches/` to the `ot-ti` submodule *after* its `git restore`, and builds only the CC2652P-launchpad target by default. |
| `.github/workflows/build.yml` | CI that builds the firmware on every push and uploads it as an artifact. |

The bug lives in the `ot-ti` **submodule** (`ot-ti/src/radio.c`), not the outer
repo. That is why the fix is delivered as a patch applied at build time rather
than an edit committed directly — it keeps you on a single fork and makes future
fixes as easy as dropping another `.patch` file into `patches/`.

## One-time setup

1. Fork `Koenkk/OpenThread-TexasInstruments-firmware` on GitHub.
2. Add these three files to your fork (web UI or a local clone), preserving the
   paths shown above. `scripts/build.sh` replaces the existing one.
3. Commit and push.

## Build it

Two ways — pick one. The `justfile` recipes (`just build`, `just flash`, …) wrap
every step below; run a bare `just` to list them.

### Locally with Colima (manual control, no CI)

Best when you build and flash on the same machine the dongle lives on (e.g. the
Home Assistant server) — the stick never moves, and the `.hex` never has to
leave that machine.

```bash
# Prereqs (Homebrew):
brew install just colima docker                    # docker here is the CLI client only
brew install qemu lima-additional-guestagents      # Apple Silicon only — see note below
# + a Chromium browser (Chrome/Arc) for flashing — Safari has no WebSerial

git clone --recurse-submodules https://github.com/<you>/OpenThread-TexasInstruments-firmware
cd OpenThread-TexasInstruments-firmware

# Start Colima as a real x86_64 VM — the TI toolchain is linux-x64 only:
colima start --arch x86_64 --cpu 4 --memory 6 --disk 60   # Apple Silicon (QEMU) AND Intel

just build          # -> dist/CC1352P2_CC2652P_launchpad_ot_rcp_2026_1_1.zip  (.hex inside)
```

> **Apple Silicon note:** the build needs a genuine **x86_64** environment.
> `scripts/bootstrap.sh` installs an x86_64 TI compiler, and the SDK's
> `arm-none-eabi-gcc 9-2020-q2` (x86_64) **segfaults under Rosetta** — so
> `--vm-type vz --vz-rosetta` does *not* work. Use full x86_64 emulation:
> `brew install qemu lima-additional-guestagents`, then
> `colima start --arch x86_64`. It's slower (QEMU emulates every instruction —
> the SDK compile takes a while) but reliable. On Intel Macs the same
> `colima start --arch x86_64` is already native. Budget ~10 GB free disk for
> the VM image + build artifacts.

Without the `justfile`, the raw equivalent is:
```bash
docker run --rm -v "$(pwd)":/data -w /data ubuntu:24.04 \
  bash -c "bash scripts/bootstrap.sh && bash scripts/build.sh 2026.1.1"
```

### CI (GitHub Actions)

After pushing, open the **Actions** tab → the "Build OT-RCP firmware" run →
download the `ot-rcp-firmware` artifact. Inside is
`CC1352P2_CC2652P_launchpad_ot_rcp_2026_1_1.zip` → unzip for the `.hex`.

## Flash + use

1. Flash the `.hex` to the Dongle-P with the SMLIGHT web flasher
   (https://smlight.tech/flasher/) — `just flash` opens it — in a Chromium
   browser (Chrome/Arc; Safari has no WebSerial). Pick the CP210x serial port,
   then flash. Works for any adapter, or follow the Zigbee2MQTT flashing docs.
2. In Home Assistant, install the **OpenThread Border Router** add-on, select
   the dongle, set baudrate **460800**, and start it.

## Remember (unchanged by this firmware)

- Flashing Thread onto the P means it is **no longer a Zigbee coordinator** —
  move your Zigbee lights to the Hue Bridge (or a second dongle) first.
- This is an **RCP**: the border router still runs inside Home Assistant, so on
  a VM you still need bridged networking with working IPv6/mDNS multicast.
- The upstream fix is proposed as `ot-ti#1`; if it merges and Koenkk cuts a new
  release, you can drop this fork and use official firmware again.

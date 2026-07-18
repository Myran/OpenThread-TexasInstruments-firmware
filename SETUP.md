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
brew install just colima docker        # docker here is the CLI client only
# + a Chromium browser (Chrome/Arc) for flashing — Safari has no WebSerial

git clone --recurse-submodules https://github.com/<you>/OpenThread-TexasInstruments-firmware
cd OpenThread-TexasInstruments-firmware

# Start Colima as an x86_64 VM — the TI compiler is a linux-x64 binary:
colima start --arch x86_64 --vm-type vz --vz-rosetta --cpu 4 --memory 8 --disk 60   # Apple Silicon
# colima start --cpu 4 --memory 8 --disk 60                                          # Intel Mac (already x86_64)

just build          # -> dist/CC1352P2_CC2652P_launchpad_ot_rcp_2026_1_1.zip  (.hex inside)
```

> **Apple Silicon note:** `scripts/bootstrap.sh` downloads an x86_64 TI compiler
> (`ti_cgt_armllvm_..._linux-x64_installer.bin`) that will not run on an arm64
> Colima VM. Starting Colima with `--arch x86_64 --vm-type vz --vz-rosetta`
> (Rosetta-accelerated) makes the existing recipe work unmodified.

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

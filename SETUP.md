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

## Build it (pick one)

**CI (recommended):** After pushing, open the **Actions** tab → the "Build
OT-RCP firmware" run → download the `ot-rcp-firmware` artifact. Inside is
`CC1352P2_CC2652P_launchpad_ot_rcp_2026_1_1.zip` → unzip for the `.hex`.

**Locally (needs Docker, pulls several GB):**
```bash
git clone --recurse-submodules https://github.com/<you>/OpenThread-TexasInstruments-firmware
cd OpenThread-TexasInstruments-firmware
docker run -it --rm -v "$(pwd)":/data -w /data ubuntu:24.04 bash
bash scripts/bootstrap.sh
bash scripts/build.sh 2026.1.1
# firmware ends up in ./dist
```

## Flash + use

1. Flash the `.hex` to the Dongle-P with the SMLIGHT web flasher
   (https://smlight.tech/flasher/) — works for any adapter — or per the
   Zigbee2MQTT flashing docs.
2. In Home Assistant, install the **OpenThread Border Router** add-on, select
   the dongle, set baudrate **460800**, and start it.

## Remember (unchanged by this firmware)

- Flashing Thread onto the P means it is **no longer a Zigbee coordinator** —
  move your Zigbee lights to the Hue Bridge (or a second dongle) first.
- This is an **RCP**: the border router still runs inside Home Assistant, so on
  a VM you still need bridged networking with working IPv6/mDNS multicast.
- The upstream fix is proposed as `ot-ti#1`; if it merges and Koenkk cuts a new
  release, you can drop this fork and use official firmware again.

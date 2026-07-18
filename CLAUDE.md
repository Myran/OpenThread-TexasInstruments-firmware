# Project context — patched OpenThread RCP firmware for SONOFF ZBDongle-P

## Goal
Build a patched OpenThread **RCP** firmware for the SONOFF ZBDongle-P (TI CC2652P) so it
can act as a Thread radio for Home Assistant's OpenThread Border Router, to connect IKEA
Matter-over-Thread sensors. Upstream firmware crashes the RCP when a Thread device joins;
this fork applies the fix.

## Current state
- Fork of `Koenkk/OpenThread-TexasInstruments-firmware`. origin =
  github.com/Myran/OpenThread-TexasInstruments-firmware
- One local commit on `main`: `a2ec6f8`
  "Add CC2652P source-match fix and CI build for Dongle-P Thread RCP".
- That commit adds/changes:
  - `patches/0001-fix-srcmatch-precedence.patch` — the fix (see below)
  - `scripts/build.sh` — applies `patches/*.patch` to the `ot-ti` submodule AFTER its
    `git clean/restore` (else restore wipes the patch), and builds ONLY the
    `CC1352P2_CC2652P_launchpad` target (the Dongle-P). Full target list kept in comments.
  - `.github/workflows/build.yml` — CI: builds in an `ubuntu:24.04` container, uploads the
    firmware as the `ot-rcp-firmware` artifact. Triggers on push / workflow_dispatch.
  - `SETUP.md` — end-user build/flash/HA instructions.
- `justfile` — convenience recipes (`just build`, `shell`, `verify-patch`, `dist`, `clean`,
  `push`, `flash`). Not committed by default — commit it if you want it in history.
- If `git submodule status` shows `-` before `ot-ti`, run
  `git submodule update --init --recursive` before any local build.
- `.git/_stale_locks/` holds leftover git lock files from a remote-mount session whose
  mount blocked deletes. Safe to `rm -rf .git/_stale_locks`.

## The fix
Operator-precedence bug in `ot-ti/src/radio.c`, `otPlatRadioClearSrcMatchExtEntry`:
`otEXPECT_ACTION(idx = f(x) != NONE, ...)` assigned the boolean to `idx` instead of the
index, corrupting the source-match table and crashing the OTBR RCP ("Failed to communicate
with RCP") on Thread device join. Fix wraps the assignment: `(idx = f(x)) != NONE`.
Credit: dady8889, issue #7 in the upstream repo; upstream PR is `Koenkk/ot-ti#1`. If that
PR merges and a new release is cut, this fork can be retired.

## Next steps
1. Build the firmware. Easiest is the `just` recipe (needs `just` + Docker running):
       just build          # inits submodules + compiles in a container -> dist/*.zip
   Run a bare `just` to list all recipes (build, shell, verify-patch, dist, clean, push, flash).
   Alternatives — let CI do it, or run the steps by hand:
   - Push and let GitHub Actions build:  `git push`  -> download the `ot-rcp-firmware` artifact.
   - By hand (needs Docker + network to TI's servers, which a proxied cloud sandbox cannot
     reach — that is why this moved to a local machine):
       git submodule update --init --recursive
       docker run -it --rm -v "$(pwd)":/data -w /data ubuntu:24.04 bash
       bash scripts/bootstrap.sh && bash scripts/build.sh 2026.1.1
       # -> dist/CC1352P2_CC2652P_launchpad_ot_rcp_2026_1_1.zip
2. Flash the `.hex` to the Dongle-P via the SMLIGHT web flasher
   (https://smlight.tech/flasher/) — or `just flash`.
3. In Home Assistant: OpenThread Border Router add-on -> select the dongle -> baudrate 460800.

## Caveats (hardware/architecture — unchanged by this firmware)
- Flashing Thread onto the P means it is NO LONGER a Zigbee coordinator (one radio, one
  job). Move Zigbee lights to the Philips Hue Bridge (v2) first; IKEA Kajplats bulbs pair
  to Hue as Zigbee.
- RCP => the border router runs inside Home Assistant. HA runs in a UTM VM on a Mac mini,
  so Thread/Matter needs the VM on bridged networking with working IPv6 + mDNS multicast.
  That is the next thing to get right after flashing.

## Wider setup (reference)
HA in UTM on a Mac mini; Sonoff ZBDongle-P (Zigbee) + this firmware (Thread); Philips Hue
v2 bridge kept via HA's Hue integration; IKEA Matter-over-Thread sensors + Kajplats bulbs.

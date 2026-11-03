# M9 validation

Base verified against remote M8.1: `20d67177774cc14b591fbbb5018927db7e8f30f5`. All work and generated builds are on G:/. No publication, production DataStore, paid purchases, live human playtests or balance changes.

## Automated checks

2714 assertions PASS: all 2219 M8.1 assertions retained unchanged, plus 447 actor/composition/queue/atomic-pool checks and 48 checks around the actual Matchmaking service with fake engine/transport adapters. The latter replay UpdateAsync transforms and exercise two server jobs, arrival verification, failure/retry, cancellation during a yielding update, cancellation after send, timeout, disconnect, forged arrival and stale TeleportInitFailed callbacks.

`docs/evidence/M9-automated.log` records the commands and exit codes. Luau 0.745 compile of every source/test, pure-module analysis, runtime undefined-name audit, Rojo 7.7.1 production and six fixture builds, shipping/test isolation, disabled chat, M7 asset hashes and `git diff --check` pass. The eleven historical pure test files and staff-delivery suite are unchanged from the base. New source exercises 0/1/2/3/5/8/15 humans and the full 2–15 role matrix; NPC count does not affect the Spy threshold or Council quorum.

Reproduce with the pinned CI workflow, including:

```sh
luau tests/matchmaking.luau
python tests/run-matchmaking.py
python tests/run-staff-delivery.py
rojo build default.project.json -o DoubleLife-M9.rbxlx
rojo build matchmaking-tests.project.json -o DoubleLife-M9-tests.rbxlx
python tests/check-build.py DoubleLife-M9.rbxlx
python tests/check-fixtures.py DoubleLife-M9-tests.rbxlx
```

## Studio procedure

Open the matchmaking fixture. Start Server & Clients with **one** client. Wait for `M9 SOLO PASS` after the first 30 seconds, then use Add Clients to add exactly one. The test uses actual Roblox client processes, Humanoid movement, ProximityPrompt holds and remotes, with FakeMemory profiles. It never teleports a test character along a route or directly finishes the round.

The fixture checks a solo Waiting lobby with moving characters, two real Owner/Spy participants, six separate Guest actor Models, no NPC profile, human-only Council majority searching an NPC, paused world time, physical upstairs NPC actions/service order, spy window/safe/extraction, natural Results reset, persistent lobby and cleared match actors. `M8 CLIENT CHAT PASS` verifies the existing chat gate on both clients. NPC work is capped at two simultaneous paths. This is automated integration, not a human retention/playability or mobile performance study.

Final run **PASS**, 2026-11-03 09:41:49–09:45:54 UTC: [sanitized log](evidence/M9-studio.log), [summary](evidence/M9-studio.json). The complete fixture took about 245 seconds including the manually delayed second-client arrival. Both clients passed the chat check; M7 lighting, ground contact, collision/art budgets and post-reset audit passed. Six match mimics produced **9 match arrivals**, including **3 upstairs arrivals** and **1 actual service order** before extraction. Across reception and match there were 65 path jobs, 61 activity arrivals, zero caught worker exceptions and at most **2 simultaneous workers**. Those counters are workload observations, not CPU-time/mobile-performance claims. The preliminary run also passed, but these final counters come from the stronger fixture.

## Human-only regression not repeated in M9

M8's real 3/5/8/15-client evidence remains historical; it is not relabelled as an M9 run. Pure role, timeout, leave, progression, delivery and commerce regressions pass on M9. To repeat the complete physical cohorts, build `playtests.project.json`, start three clients, then add to five, eight and fifteen only at the runner's cohort gates. Check all full-round markers, the configured natural timeout (1200 active seconds since M12.0), roles/secret-state audit, physical upstairs delivery, event/council pause, rewards and reset. For a strictly human-only 3/5 run use a local fixture-only MatchSettings override `maxMimics=0` before Game.start; do not change production defaults. At 8/15 the default population already has no match mimics. Export only authored lines with `tests/summarize-playtest.py`; do not attach raw account/network logs.

## Remaining release gates

Real cross-server MemoryStore/Teleport is **NOT TESTED**: Studio does not support a genuine TeleportService test. The feature is off by default; staging IDs are zero. Follow [M9 staging procedure](M9_MIMICS_DESIGN.md#staging-release-gate-not-executed) after separate permission. Real published DataStore and ProcessReceipt remain their independent pre-monetization gates. Robux purchases remain disabled. Large-pool quota behavior, mobile hardware performance and human perception of mimic behavior are unmeasured.

The local reception is functional topology, not a final art pass. Humanoid appearance can fall back when the avatar service is unavailable. The bounded single MemoryStore pool is a staging implementation and has a 64-ticket capacity; it does not promise global scale.

# M10 validation

Base: M9 `227c5713e41cb298720e3f3cb00688a54c68e300`, Draft PR #24. Branch `feat/m10-first-join-prologue`, PR targets M9. No earlier PR is merged.

## Automated checks

PASS: **2916 assertions**, comprising all 2714 M9 checks, 191 new prologue/profile checks and 11 additional actual Matchmaking service consent checks. Compile/analyze, runtime-global audit, production plus seven fixture builds, shipping isolation, asset provenance and chat audits pass. See [automated evidence](evidence/M10-automated.log). Existing pure regression suites remain unchanged; older Studio fixtures explicitly disable first-join onboarding to retain their original scenarios.

Fake clocks cover second arrivals at 30/300/720 seconds, ordered checkpoints, replay/skip, chapter rollback, timeout and independent visitors. Profile tests cover legacy migration, malformed markers, failed acknowledgement, retry/reconnect and no duplicate reward/currency side effect. Matchmaking service tests cover consent withdrawal during an external yield and previously validated transport arrival.

## Local Studio — PASS

2026-11-03, **10:33:18–10:37:49 UTC**: one actual Studio client, then a second client added after `M10 FULL SOLO PASS`. FakeMemory only; external matchmaking disabled. Build: `prologue-tests.project.json` (local copy `DoubleLife-M10-prologue-v3.rbxlx`). [Sanitized log](evidence/M10-studio.log), [summary](evidence/M10-studio.json).

- All 25 steps passed through actual client Humanoid walking and prompt holds, including upstairs delivery, clue/copy carry, music and private light changes. The driver does not teleport along the route or advance checkpoints directly.
- First physical action occurred within 60 seconds. The automated full route took **198.86 seconds**, including interruption/resumption of the clue chapter. This is an automated navigation measurement, not evidence of a 10–15 minute human visit. Human pacing remains unmeasured; there is no artificial minimum-time gate.
- Completion cleaned scene/actor/carry and acknowledged the marker without XP, tokens, played count or history. Replay skip did not downgrade Completed. Early/mid skip, actual death/respawn, lobby return and chapter resume passed.
- Two simultaneous private spaces remained independent through a public-world rebuild. Ready did not auto-start; Accept and Defer-to-checkpoint led to an actual two-human Owner/Spy match and cleaned both private spaces. Chat remained disabled on both clients.
- Earlier iterations exposed spawn placement ordering and a zero-distance test navigation case. Game now waits for workspace parenting and a simulation step before final spawn routing; the driver handles an already-reached target. Only the successful final run is included in the evidence.

## Limits and release gates

No live human playtest, timing/balance claim, physical mobile test, published teleport/MemoryStore or real DataStore test was performed. Separate 3/5/8/15-client physical regressions were not repeated in M10; existing fixtures and automated compatibility checks are retained. Fifteen cloned private scenes have not been profiled for memory or mobile performance. Session-only onboarding state is labelled honestly; production persistence stays gated. Robux remains disabled.

To repeat: build `prologue-tests.project.json`, run Server & Clients with one client, wait for `M10 FULL SOLO PASS`, then add one client and require `M10 STUDIO SUITE PASS`. Do not substitute synthetic actors for the two actual clients. GitHub Actions final-SHA status and run link are recorded in the Draft PR.

# M11 validation

Base: M10 `b9f8dd6005ff7386f2a81667e39c8c4afced74f7`, Draft PR #25. Branch `feat/m11-retention-observability`, targeting M10. Earlier Draft PRs remain unmerged.

## Automated checks — PASS

**3187 assertions**: all 2916 M0–M10 checks, 226 retention/configuration assertions, 23 checks against the actual Telemetry service, and 22 additional checks against the actual Matchmaking service (81 total in that harness). [Evidence](evidence/M11-automated.log).

Compile/analyze, runtime-global audit, nine Rojo builds (shipping plus eight isolated fixtures), fixture isolation, disabled-chat audit and M7 asset provenance checks pass. Existing pure regression suites remain unchanged. M8.1's 80 delivery/reward checks remain included; reward formulas and victory rules were not changed.

Deterministic traces cover a solo visitor for 900 seconds, second arrivals at 30/300/720 seconds, simultaneous 2/3/5/8/15-human cohorts, all 25 prologue checkpoints and 15 concurrent synthetic prologues within the event budget. Tests include decline/cancel/expiry, disconnect/reconnect, chapter reset, transfer classification, pool/transport failure, stale callbacks, nonzero elapsed at actual round start, first/repeat completion, abandonment, monotonic wall versus gameplay time, idle/dead time, exclusive exit buckets, bounded payloads/spam and a failing sink. Local and remote reservations have separate classifications; mimics cannot become visits or starts.

## Local Studio — PASS

2026-11-03, **11:14:45–11:23:32 UTC**: one actual Studio client, then two, then three. FakeMemory and a local analytics sink only; external matchmaking disabled. Build: `retention-tests.project.json`, local copy `DoubleLife-M11-retention-v3.rbxlx`, byte-identical to the final canonical fixture build (SHA256 `c85022c00c9aa8ee152ce227e46d99f84709eb47bb06cd0b7ca04c544239fcb9`). [Sanitized log](evidence/M11-studio.log), [summary](evidence/M11-studio.json).

- The complete 25-step physical solo route passed in **199.10 seconds**. First physical action was within 60 seconds. A deliberate sink failure did not block checkpoint advancement; completion gave no XP/tokens/match history.
- Chapter interruption/resume, actual death/respawn, early/mid skip and replay passed. Completed was not downgraded. Private scenes remained independent and survived a public-world rebuild.
- Explicit accept and defer-to-checkpoint started an actual two-human Owner/Spy match. Six match mimics created no visits. Physical dossier extraction finished the first round; natural reset queued and started another, and a second physical extraction produced repeat-completion events.
- The third real client joined, skipped onboarding, and participated in an actual three-player start and physical extraction. Chat gates passed on all three clients. Final trace: **3 Join, 7 MatchStarted, 7 RoundFinished, 3 FirstMatchCompleted and 4 RepeatMatch** across the three rounds.
- Final health: **263 accepted, 1 intentionally failed sink call, 0 invalid payloads/transitions, 0 rate-limited, 0 dropped, 0 pending**. Repeated observations were suppressed. These are local sink results, not AnalyticsService ingestion.
- An earlier trial exposed a fixture preparation race: sequential registration made two players eligible before the third. Synchronizing the fixture's invitation deadlines exercised the intended three-person cohort; gameplay thresholds were unchanged. Only the successful final run is included in the evidence.

## Synthetic observations and limits

Synthetic tests establish event boundaries and invariants, not retention or enjoyment. The automated physical prologue route is not a measurement of human 10–15 minute pacing. All M0–M10 Studio fixtures are retained and rebuilt; the full historical scenario matrix and physical 5/8/15-client sessions were not repeated in M11. No physical mobile device was tested. Fifteen private scenes have not been profiled on mobile hardware.

**Published tests: NOT RUN. Human retention: NOT MEASURED. Baseline: no live data.** Cross-server transport stays disabled by default. Real TeleportService/MemoryStore, isolated real DataStore and Creator Analytics ingestion remain mandatory separate staging gates. Production stores were not accessed; no experience was published, live human playtest started, or Robux purchase enabled.

The analytics contract and aggregation limits are in [M11_RETENTION_METRICS.md](M11_RETENTION_METRICS.md). The later approval stages, sample requirements and metric-to-patch proposals are in [M11_EXPERIMENT_PLAN.md](M11_EXPERIMENT_PLAN.md). Delivery is bounded and best effort; local health counters are not remote ingestion acknowledgements or a durable analytics spool.

To repeat Studio: build `retention-tests.project.json`, launch Server & Clients with one client, wait for `M11 FULL SOLO PASS`, add a second, wait for `M11 TWO CLIENT PASS`, then add a third. Require the final `M11 STUDIO SUITE PASS`. The three-client fixture synchronizes invitation deadlines before eligibility so sequential test-client invocations exercise a three-person roster; it does not seed roles, rewards, checkpoints or extraction outcomes. Final-SHA GitHub Actions status and run link are recorded in the Draft PR.

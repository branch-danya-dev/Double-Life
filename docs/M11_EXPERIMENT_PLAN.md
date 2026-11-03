# M11 future measurement and correction plan

**Not executed. Baseline: no live data.** Owner approval is required before publication or human testing. Technical ability to start with two Players is not evidence of retention improvement. M11 does not change rewards, win conditions, role allocation, map or paid products.

## Reviewed configuration

`TuningConfig.resolve` validates a frozen static configuration. Game accepts overrides only in Studio fixtures; there is no client command, remote flag service, automatic rollout or hidden assignment. A future production change requires a reviewed source change and a fresh validation run.

| Parameter | Current default | Allowed range |
|---|---:|---|
| targetSize | 8 | 2–15 |
| lobbyDensity | 6 | 0–8 |
| maxMimics | 8 | 0–8 |
| aiWorkers | 2 | 1–2 |
| queueSeconds | 900 | 60–1800 |
| readySeconds | 3 | 3–30 |
| prologueOfferSeconds | 0, after bounded profile bootstrap | 0–60 |
| allowSkip / allowInvite | true / true | Boolean; lobby exit always remains available |

Only these keys are accepted. Transport enablement, DataStore gates, product IDs, prices and rewards cannot be changed through tuning. Tests exercise both bounds, rejected types/out-of-range values and explicit switches; normal builds preserve M9/M10 defaults.

## Stages requiring later approval

1. **Isolated published technical staging.** Owner selects a separate test universe/place and restricted test accounts. Verify its IDs against MatchSettings and persistence allowlists; use a fresh staging MemoryStore namespace and isolated DataStore, never production keys. Keep Robux disabled and product/pass IDs zero. Review the intended build and settings before publishing. Nothing is published by this task.
2. **Two-server transport proof.** Start one real test account in each of two jobs. Check registration/leases, Local vs Remote classification, explicit ready consent, target capacity and validated arrival. Inject cancellation, departure, expired tickets, duplicate callbacks, shutdown and TeleportInitFailed. Require one actual start only after two real arrivals, no role assignment to mimics, bounded retries and honest failure/transfer events. Roblox Studio cannot prove real TeleportService behavior.
3. **Isolated real DataStore proof.** Repeat M4.1/M8.1/M10 scenarios: failed write/acknowledgement, reconnect, competing lease, idempotent purchase/reward and Completed-marker protection. Audit that namespaces/IDs never reference production. A FakeMemory PASS does not satisfy this gate. Monetization remains a separate decision after real storage and ProcessReceipt validation.
4. **Analytics ingestion proof.** Check only bounded fields, expected event order and values, local delivery/drop counters, no secrets/names, transfer correction and Creator Analytics visibility after its reporting delay. Verify platform unique-user counts against real accounts. Confirm physical mobile memory/UI/performance separately; cloned private scenes are not yet a proven fifteen-learner mobile load.
5. **Small observed human usability study, only after approval.** Initially 10–15 unfamiliar consenting testers across intended devices, with solo entry, second arrival, full prologue, skip, ready/decline and one complete match. Use observations to find defects, not to claim statistical retention lift. Do not infer pacing from the automated 199-second M10 route.
6. **Descriptive baseline.** Target at least 100 distinct new human entry visits per relevant cohort, with 15-minute follow-up and at least 30 legitimate completed matches for repeat-play analysis. Report unique users, attempts, missing data, cohort sizes and uncertainty. These are planning minimums, not a power calculation or guaranteed significance. If traffic cannot supply a cohort, mark it insufficient rather than pooling incompatible populations.
7. **One approved change at a time.** Agree the primary metric, minimum useful effect, exposure period, sample-size/power calculation and stopping rule before an experiment. Avoid repeated peeking, multiple unexplained comparisons, novelty effects and changing acquisition/device mix. Compare confidence intervals and investigate measurement loss before causal claims. Restore the reviewed defaults if technical health regresses.

## What to investigate first

| Metric and slice | Candidate signal to investigate | Permitted next proposal (not automatic) |
|---|---|---|
| FirstMeaningfulAction / early exits, new solo visitors | Slow first action or observed confusion before 60 seconds | Spawn/target visibility, first instruction, interaction reach |
| Checkpoint reach/dwell, first prologue attempt | Loss before three minutes or repeated trouble at a step | Scene text/route, prerequisite clarity, pacing; verify with observation |
| QueueEntered → OpponentFound, Local vs Remote | Long solo waits with healthy ingestion | Matchmaking reliability, discovery/acquisition; more mimics cannot supply a real opponent |
| MatchReady → MatchStarted | Declines, timeouts or transport failures | Invitation clarity, consent state, ticket lifecycle/teleport; avoid forced entry |
| RoundFinished and active duration by real start cohort | Abandonment, technical interruptions, inconsistent completion | Fix technical failures first; role/rule changes need separate approval and evidence |
| First completion → NextMatchQueued / RepeatMatch | Complete match without another attempt/finish | Results flow, clarity, interview evidence; balance remains a separate approved step |
| Delivery failure/drop/invalid/rate-limited counts | Missing or inconsistent funnel events | Repair measurement before changing gameplay |

Do not report NPC visits as users, confuse reconnects with D1 retention, treat accepted teleport requests as completed transport, call partial rounds seven-minute completions, or present a handful of friends/Studio clients as a representative sample. Keep “technical PASS”, “synthetic observation”, “published NOT RUN” and “human retention NOT MEASURED” separate in every report.

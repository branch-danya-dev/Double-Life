# M11 retention measurement contract

**Baseline: no live data. Human retention: NOT MEASURED.** Studio clients, deterministic clocks and mimics prove technical behavior only. No publication or human experiment is authorized by this implementation.

## Units and identity

Only actual Roblox Players enter Telemetry. Mimics remain Models and never create Join, DAU, visits, queue tickets or match conversions. `RealHumans`, `LobbyMimics` and `MatchMimics` are separate numeric gauges, sampled every 30 seconds and at match start. The start gauge counts actual participants, not all visitors. Mimics spawn asynchronously, so the initial mimic gauge may be zero; subsequent samples show the observed population.

RetentionPolicy uses a process-local visit serial, queue serial plus entry time and round ID solely for server state/deduplication. These identifiers, tickets, UserIds, names, roles and free text are **not** custom fields. The AnalyticsService Player argument uses Roblox's normal identity handling. Reconnect is a new server visit, not automatically a new account. `FirstMatchCompleted` means the first legitimate completion in that server visit. Legacy `FirstMatch` additionally requires known profile `startPlayed == 0`; an unavailable profile is not assumed new. Platform returning-user/DAU/retention reports must use actual unique Roblox users, never these visit counters.

Three allowlisted fields map to `CustomField01/02/03`: cohort (`1`, `2`, `3-4`, `5-7`, `8-15`), context (`Lobby`, `Prologue`, `Match`, `Results`) and detail (fixed step/outcome/transport/exit labels). Cohort is captured at visit/queue entry, then at competitive start; it is not a cross-server CCU estimate. A remote reservation can have cohort `1` with detail `Remote`; only arrival of a real second Player can produce a two-person start. Do not combine queue-entry and match-start cohorts as if they were the same population.

## Event dictionary

All durations use injected monotonic time (`os.clock` in the server), clamped to 0–86400 seconds. SessionClock remains exclusively a gameplay timer; council pauses must not shorten visit/queue durations.

| Events | Value and exact boundary | Denominator / interpretation |
|---|---|---|
| Join | 1, actual server Player registration, once | Server visits; subtract classified transfer arrivals when estimating new entry visits |
| TransferArrived / TransferDeparted | 1 / local visit seconds; only validated incoming reservation / in-flight outgoing transport | Transfers are not churn or additional successful starts; outgoing departure is not proof of arrival |
| FirstMeaningfulAction | Seconds since join, first successful physical/prologue/game action | Join visits; movement or clicking Skip alone does not qualify |
| PrologueStarted | 1 per start/replay | Prologue attempts, not accounts |
| PrologueCheckpoint | Seconds since previous successful step/reset; `Step1`…`Step25` | Attempts reaching that step; repeats after chapter rollback do not add conversions in the same attempt |
| PrologueCompleted / PrologueSkipped / PrologueInterrupted | Attempt duration; finish/skip/lobby/match acceptance/disconnect | Started attempts; reset emits Interrupted with detail Reset but keeps the attempt/checkpoint dedupe; death plus respawn without an intervening action is one reset |
| QueueEntered / NextMatchQueued | 1 / seconds after last completion | Queue attempts; re-register and natural round reset are new attempts |
| OpponentFound / MatchReady | Seconds since queue entry, first ready invitation; Local/Remote | Entered attempts; discovery means an eligible reservation/second queued human, not a match |
| ReadyAccepted / ReadyDeclined | Seconds since entry, first explicit choice in an invitation | Ready attempts; already-consenting returning visitors can start without a new click |
| QueueCancelled / QueueTimeout | Wait seconds, explicit cancellation/disconnect or policy expiry | Entered attempts; cancellation is not mislabelled timeout |
| MatchmakingFailed / TransportFailed | 1 per observed pool/transport failure, bounded by analytics budgets | Attempts/errors, never success conversions; stale transport callbacks excluded |
| MatchStarted / QueueToStart | 1 / wait seconds; actual RoundService activation with 2+ real participants | Started human participations / queue attempts; independent of whether elapsed is exactly zero |
| RoundFinished / RoundActiveSeconds | Wall duration / gameplay elapsed; Objective, Timeout or Abandoned | Started participations; 420 active seconds identifies a full timed round; objective extraction can validly finish earlier |
| FirstMatchCompleted / RepeatMatch | Match wall duration, first/second-and-later non-abandoned finish in this visit | Started participations; SpyLeft is a result but not a completed match conversion |
| Exit / SessionEnded / SessionSeconds | Monotonic local visit duration | Exit excludes classified outgoing transfers. SessionEnded includes them with Transfer detail; server crashes can miss exits |
| ActiveSeconds | Alive engaged seconds: server-observed movement or validated action within previous 30 seconds | Operational engagement proxy, not attention or enjoyment; samples cap gaps at two seconds; movement does not trigger FirstMeaningfulAction |
| RealHumans / LobbyMimics / MatchMimics | Observed counts, separately | Use average/max gauges, never sum them into users |

Exit details are exclusive `<30`, `[30,60)`, `[60,180)`, `[180,300)`, `[300,600)`, `[600,900)`, `>=900` second buckets (`Under30` … `Over900`). To report departure before 1/5/10/15 minutes, sum the appropriate earlier buckets, then divide by observed entry visits with sufficient follow-up. Report missing exits/server crashes separately. Do not use all active visits as a mature 15-minute denominator.

## Quality and delivery

The allowlist has fewer than 100 event names and fewer than 8000 field combinations. Numeric values must be finite and bounded. No client telemetry RemoteEvent exists. State transitions dedupe per live visit/attempt/match; only the current attempt/match and up to 25 checkpoint flags are retained. Player removal cleans policy budgets and records.

AnalyticsPolicy limits bursts to 64 events/player with 0.5 event/second refill, and a shared 120-event burst with 4/second refill. Legacy UI events retain their per-event delay. Production enqueue is bounded to 128 entries and drained by one worker at most four times per second. A slow/throwing AnalyticsService call does not yield gameplay. There is no automatic retry after an ambiguous send, so duplicate reporting is avoided at the cost of possible loss. `Telemetry:health()` exposes accepted/failed/invalid/rateLimited, delivery sent/failed/dropped/pending, and suppressed duplicate/invalid transition counters. These are local diagnostics, not confirmed remote ingestion. Session shutdown or API refusal may lose queued events; no DataStore is used as a telemetry spool. Do not interpret missing events as player decisions until quality counters and published ingestion are validated.

Studio defaults to a no-network sink. `tests/TelemetrySink.luau` stores at most 2048 events, supports deterministic clocks/failures and is excluded from shipping. Fixtures aggregate project-only counts; raw Studio account/network logs are not published.

## Future Creator Analytics view

Use `DL_` custom events in Explore: count/unique users for conversion events, average/max values for wait and dwell times, average gauges for populations. Filter by the same cohort/context/detail and calendar window. Exported aggregate ratios are diagnostic approximations: replays, reconnects and different queue/start cohorts make raw event-count division unsuitable for exact per-visit funnels. No persistent cross-place visit stitching is claimed; transfer markers permit aggregate correction only. Exact cross-server journey analysis needs an approved identity/session scheme and a published validation before use.

Suggested views: entry-to-action latency; queue-to-ready/start latency by Local/Remote and cohort; checkpoint duration/count by Step; observed early exit buckets; non-abandoned finishes per starts; repeat finishes and next queues per first completion. Compare counts with quality diagnostics before drawing conclusions. Roblox custom events are server/published-only and charts may take up to 24 hours; Studio evidence is not Creator Analytics ingestion. Sources: [custom events](https://create.roblox.com/docs/production/analytics/custom-events), [three custom fields](https://create.roblox.com/docs/production/analytics/custom-fields).

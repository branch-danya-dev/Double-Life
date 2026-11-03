# M9: actors, reception and matchmaking

Base: M8.1 `20d67177774cc14b591fbbb5018927db7e8f30f5`. Branch `feat/m9-mimics-and-matchmaking`; Draft PR targets `fix/m8-staff-delivery-reward-gate`.

## Authority and composition

`ActorRegistry` admits Humans only from actual `Player` instances parented to `Players`. Mimics have a separate `m:<serial>` identifier and Model, never a UserId, connection, account or profile. Nameplates explicitly say «персонаж». Their fictional names, original waistcoats, hair and motor animations do not copy accounts. R15 creation has a three-second deadline and at most one outstanding engine request; a local articulated humanoid is the fallback. No external assets or animation purchases are required.

`RolePlan` preserves the M5 human matrix at 3–15 and adds the two-human case: one randomly assigned Owner and one Spy. Spy count uses real humans only (one through seven, two from eight). Match mimics are Guest exclusively. They cannot vote, own the dossier, enter Marketplace/Profile APIs, earn currency or decide the winner. Council requires more than half of remaining human participants. Humans can vote to search a mimic; the search holds its body for the existing 12 seconds and reveals no secret role.

The default target is eight total actors, with at most eight mimics and a hard total bound of fifteen. At 2/3/5/8/15 humans this gives 6/5/3/0/0 match mimics. The selected human roster freezes at Countdown. Late visitors remain in the reception; leaving and joining never reassign an active person's role. Match NPC population is fixed for that round and rebuilt between rounds.

## Space, lifecycle and behavior

`DoubleLifeLobby` is a persistent reception separated spatially from the mansion. It has its own spawn, arrival screen, interest points and clock. Its default density is six total people/characters; one visitor sees five mimics. NPCs spawn behind the screen, walk between activities and return to the entrance before removal as population increases. Retirement reservations prevent two AI workers removing the same excess population. The reception survives mansion Round rebuilds. «Осмотреть особняк» leads to the existing no-reward Waiting practice; Q toggles the unified queue and the HUD separately counts real people and characters.

Match mimics appear in the pantry and physically visit paintings, the upstairs service point, the music stage and terrace trace. They pause, greet nearby people and vary route order/speed. Actual service orders use the existing RequestLedger and NPC/human delivery path. Gallery/trace observations are distance-validated by EventDirector and use the existing three-action incident policy; they may change lighting or guard routes without claiming a real player's identity or earning rewards. Music sampling uses the same stage bounds and beat rules; NPC scores remain session-only and are removed from human award signals. The AI reads public environment/beat state, never private role assignments. It does not take evidence away from people.

Two path workers are allowed, ticking decisions at 10 Hz. Existing NpcMover bounds path computation and retries, respects the round clock, and retries failures physically. No mid-match recovery teleport is used. Council pauses match NPCs and timers; lobby NPCs keep their own clock. Reset invalidates callbacks, destroys match Models, removes requests/actor references and clears vote targets. Doors also check mimic bodies before closing.

## Queue and transport

One queue covers local and future cross-server matching. State: Lobby → Queued → MatchReady → Countdown → Active → Results → Lobby. One real player never begins Countdown. Registration is idempotent, remotes are throttled, a visitor can cancel, and unselected tickets expire after 900 seconds. Consent is represented in the queue for the separate M10 invitation work; M9 auto-registers ordinary arrivals.

`MatchPool` is a bounded, atomic MemoryStore value, not a collection of independently claimed user keys. Its pure transform has no yields or side effects. It holds up to 64 tickets, ownership tokens, 45-second ticket leases and 90-second assignment leases. A deterministic oldest-first reservation groups at most fifteen users; a second coordinator cannot assign the same tickets. An existing source job hosts the group. Remote members are sent through server-side TeleportAsync; joining data is verified against the shared reservation, source universe/place, ownership token and destination job. Only actual arrived Players can satisfy the final commit. A consumed reservation remains until TTL to prevent stale renewals creating a second match.

Transient MemoryStore failures fail closed. Teleport throws, matching TeleportInitFailed callbacks and arrival deadlines release/retry the ticket. Stale callbacks cannot cancel a newer attempt. Cancellation during a yielding update is checked again before send; explicit cancellation after send invalidates the ticket and does not auto-register. A crash/reconnect may wait for the bounded old lease. Source and destination cannot both own a valid session token. This is a small staging pool, not a promise of unlimited cross-region scalability; load/sharding require published measurements.

`MatchTransport` defaults to local mode. Cross-server calls require all of: `crossServerEnabled=true`, non-Studio, and matching nonzero staging universe/place IDs. Both IDs are currently zero and the switch is false. The namespace is `DoubleLife_M9_Staging_v1`. No production store or published place was used.

Roblox documents [atomic HashMap updates](https://create.roblox.com/docs/reference/engine/classes/MemoryStoreHashMap), [MemoryStore expiration and limits](https://create.roblox.com/docs/cloud-services/memory-stores), and [server teleports and Studio limitations](https://create.roblox.com/docs/projects/teleport). The runtime harness injects isolated engine/transport adapters around the actual service source; it cannot replace a published transport test.

## Staging release gate (not executed)

1. Obtain explicit permission for a separate published test universe/place. Keep production DataStore, purchases and production teleports disabled. Configure only that staging identity and namespace.
2. Join two actual Roblox clients in distinct server jobs with no local partner. Verify one shared reservation, exactly one transfer, two arrived Humans, Owner/Spy assignment and one complete match. Inspect sanitized server records; never expose ownership tokens to the UI/log report.
3. Repeat cancellation during allocation, simultaneous coordinators, disconnect before/after send, source/target shutdown, expired ticket, denied teleport and destination admission failure. Confirm bounded recovery and no one-person match, duplicate assignment or profile loss.
4. Exercise 3/5/8/15 arrivals and overflow; measure quota contention, pool bytes and wait/transfer latency before increasing capacity. Verify a third arrival does not change the active pair's roles.
5. Run the separate real DataStore recovery/receipt gates before enabling any paid product. Record exact place/version, clients, timestamps and observed outcomes. Disable the staging switch afterwards.

M10 prologue and M11 retention observability are subsequent branches. Human playtests and balance changes remain deferred.

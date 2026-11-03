# M10 first-join prologue

Base: actual M9 HEAD `227c5713e41cb298720e3f3cb00688a54c68e300`, Draft PR #24. The first visit is a private rehearsal, never a one-human competitive round. Owner and Spy remain real humans in M9 matches. No training XP, tokens, wins or match history are created.

## Five scenes

The following are design estimates for an unfamiliar visitor, **not measured human durations**. Twenty-five physical checkpoints allow faster completion; no minimum-duration timer holds a player in the scene.

| Estimated visit time | Scene and physical route | Existing mechanism |
|---|---|---|
| 0–2 min | Arrival invitation, three gallery paintings | Server-validated prompt holds, navigation, NPC greeting |
| 2–5 min | Pantry order and tray, upstairs archive delivery, invitation and study access | RequestLedger accept/pickup/deliver, physical carried tray, private door |
| 5–8 min | Safe seal, clue, journal, window, downstairs reading table | Physical clue carry/drop, observation and silent gesture |
| 8–12 min | Ballroom music, bell, west and upstairs light circuits | EventPolicy's three move/stop beats, private lights, two-floor route |
| 12–15 min | Terrace footsteps, study copy, internal egress, collection desk and foyer exit | Timed hold, physical copy carry/return, safe tension without a real Spy role |

Exact Russian step texts and action labels are the server-owned `PrologueContent.steps`. Examples: “Само получение предмета ещё не означает выполненное поручение”, “Один след ещё ничего не доказывает”, “Это репетиция, без роли шпиона и без победы”. One current target is highlighted; the HUD names its room/floor, action and distance. Music uses steady green/gold states, not flashing. The M7 art and existing canonical world geometry are reused.

## Entry, queue and exit

The first unmarked join starts immediately after bounded profile bootstrap. M9 automatically registers the real Player but holds readiness consent while the prologue is active. Q can cancel or restart search. A second real human produces “Найден второй человек. Войти в настоящий матч?” with “Войти · Y”, “После шага · J”, “Продолжить · N”. Acceptance cleans private objects before enabling readiness. Deferral waits for the current successful checkpoint and rechecks the invitation; continuing declines/cancels search. Remote matchmaking publishes the same consent bit and cannot teleport a held learner.

Always available: “Пропустить · K” and “В лобби · L”. Skip marks the lesson skipped and permits the ordinary queue; lobby exit suspends the checkpoint and cancels search. “Знакомство с поместьем · R” reopens it from the lobby. A completed or skipped replay starts at chapter one. Death or resuming an interrupted visit restarts the current chapter and clears carried objects, stale holds and local order/music state. A 30-minute safety timeout suspends and cleans the scene; it is not a required play duration. An accepted actual match participant cannot replay mid-round.

## Isolation and lifecycle

`PrologueService` owns records by actual Player, fifteen reusable spatial slots, a SessionClock per scene, Interactions reach/LOS/life/hold checks and RequestLedger/EventPolicy instances. The service is the only writer of checkpoints; there is no client command to advance a step or award a reward. Each prompt also checks its owner and current step. The private World facade clones canonical static/navigation geometry at a separated offset, then uses normal World.reset and EventWorld construction. Public RoundService rebuild does not destroy or relocate active private contexts.

M9 creates a separate Prologue-context actor with its original appearance, route, procedural animation and greeting response. It is a Model, not a Player, has no role/profile and shares the existing two-worker path budget. Cleanup invalidates its scope before removal, so a late rig/path callback cannot restore it. Leaving, finishing, skipping, timeout, disconnect and match acceptance clean prompts, carry welds, actor and geometry. At most one private scene belongs to a Player. Simultaneous cloned scene memory/mobile performance remains a staging measurement, not a validated fifteen-learner capacity claim.

CharacterAdded occurs before Roblox's final spawn placement. Game routing waits for workspace parenting and the following simulation step, then rechecks character identity and current destination. See the [Roblox character lifecycle](https://create.roblox.com/docs/reference/engine/classes/Player#LoadCharacterAsync). Test clients wait for replicated placement; they do not teleport along the route.

## Profile marker

Schema v1 accepts old profiles without `onboarding` and normalizes them to `{version=1,state="Unseen",at=0}`. Only trusted server operations can write Skipped/Completed, with deterministic operation IDs through the existing retry/dedupe/session lease machinery. Completed cannot be downgraded by a later skip. No reward ledger or commerce entry is used.

Writes are allowed only for FakeMemory or an explicitly verified isolated DataStore adapter. `onboardingPersistenceVerified=false` by default; production persistence is not used for this test. UI distinguishes “Только в этой сессии”, pending confirmation and “Подтверждено в тестовой памяти”. FakeMemory confirmation is not a claim of real published persistence. Session-only remembered visits cannot promise survival across server replacement.

Real Teleport/MemoryStore, real isolated DataStore, physical mobile devices and human timing remain separate gates. Robux remains disabled. M11 observability and later human-driven tuning are separate work.

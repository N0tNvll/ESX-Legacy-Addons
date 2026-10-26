# ESX Halloween Event 2.1

Ghost mode and shared trick-or-treat rounds for this ESX Legacy installation.

## Requirements

- The local ESX core with session-bound xPlayer methods (`isCurrent`).
- `esx_death` with its normal respawn callback and server lifecycle events.
- `skinchanger` and OneSync.
- Reward items registered in the active ESX or ox_inventory catalog.

Add `ensure esx_halloween` after the dependencies. The compiled UI is included; Node.js is only needed to rebuild it.

## Ghost lifecycle

A verified `esx_death:stateChanged` server event records a death candidate. Once normal respawn becomes available, the server performs one probability roll and can offer a short-lived choice.

Accepting a death offer invokes the existing `esx_death:respawn` callback. Its waiting period, fines, removal of possessions and hospital selection remain authoritative. Halloween waits for that successful recovery before preparing the ghost model. Ghost mode therefore begins **after normal hospital respawn**, rather than temporarily bypassing death penalties and trying to apply them later.

An administrator can use `/ghost [player_id]` to offer the mode to a player. The console must specify a target. Dead targets must still satisfy normal respawn eligibility.

The server reserves a ghost slot during preparation, confirms activation and expires the state after `Ghost.maxDuration`. Preparation failure, disconnect, logout, leaving the configured routing bucket or expiration releases the slot. A cancelled request does not prevent an already-authorized normal respawn from completing.

The client restores appearance, sprint multiplier, health/armor and the ESX loadout on exit. Death-related cleanup is coordinated with `esx_death`. Vehicle entry/exit, firing and melee controls are disabled while the mode is active.

## Shared houses

There are still **12 shared opportunities per round by default**, not 12 per player. Each house is consumed once across the configured event bucket.

- `roundDurationMinutes`: round duration.
- `roundFrequencyMinutes`: pause after a round finishes.
- A round also ends when all selected houses are consumed.
- `/startround`: administrator/console starts an idle round.
- `/resetcooldowns`: administrator/console replaces the current round with a new round ID. It is refused while inventory delivery is in progress.

Players start an interaction near a house and wait the configured duration. The server issues a session-bound collection ticket, checks distance again and reserves the house before calling the inventory backend.

The reward is fixed for that house for the whole round. Full inventories or failed attempts cannot reroll it. Amounts come directly from `rewards.*.amount`: the common default is **3 medikits**, not 3 multiplied by 3. The legacy `candyPerDoor` multiplier has been removed.

Explicit inventory failure with no mutation allows another attempt at the same reward. Ambiguous errors or partial writes consume the house and emit a diagnostic, preventing a potentially paid house from being reopened. An administrator should inspect that delivery before compensating a player.

Trick damage is a bounded, nonfatal client effect from a server-authorized collection. A cheating client may ignore visual/health effects; house consumption and inventory rewards remain server decisions.

## Configuration and performance

`Config.RoutingBucket` restricts gameplay to one bucket (default 0). Ghost victims must be alive in that same bucket. Dead players and pending/active ghosts cannot collect rewards.

Configuration is normalized synchronously on both sides. Invalid house/reward definitions disable trick-or-treat. Missing catalog items disable that feature with a clear startup message; Halloween does not create items or silently substitute rewards.

NPCs are local, appear only near the player and are removed when a house is consumed or the player leaves the area. Model loading is bounded and cancellable. Snapshots reconcile late joins and bucket changes without creating duplicate interaction loops.

Network progress is sent on changes and periodically (default 15 seconds); clients run their own countdown. The required per-frame control disabling runs only while ghost mode is active. UI notifications and particle animations are bounded and clean up their timers.

Travel checks reject implausibly fast movement between completed collections. This resource does not replace a server-wide anticheat or guarantee that all replicated movement is legitimate.

## Persistence

Halloween adds **no SQL schema or direct DML**. Inventories are persisted by their existing backend, and death/respawn persistence belongs to `esx_death`.

Round state and consumed houses remain in memory. Restarting the resource starts a new schedule. There is no cross-resource database transaction guaranteeing exactly-once delivery across a process crash or a broken inventory adapter. This is separate from the tested protection against concurrent/replayed collection events.

## Server exports

```lua
exports.esx_halloween:IsPlayerGhost(playerId)
exports.esx_halloween:SetPlayerGhost(playerId, true)
exports.esx_halloween:SetPlayerGhost(playerId, false)
```

`IsPlayerGhost` includes pending reservations, so other resources can block interactions during preparation. `SetPlayerGhost(true)` starts an asynchronous, server-authorized preparation; it returns whether initiation was accepted, not whether the client has finished loading its model. Dead players still use normal respawn. These exports are trusted server integrations, not network events.

Client notifications retain the existing `exports.esx_halloween:showNotification(data)` API. Text is rendered as escaped Svelte text nodes.

## Validation

The offline Lua suite runs the actual resource code with deterministic FiveM/ESX stubs, including exported xPlayer table copies, delayed inventory calls and reconnects. It requires Node.js and Fengari:

```text
node tests/security.cjs /absolute/path/to/fengari
```

For the UI, run `npm ci`, `npm run check` and `npm run build` in `web`. The build replaces `web/build`.

Before deployment, verify with actual FiveM clients: normal death/respawn penalties, admin activation, model restoration, inventory capacity, shared-house competition, another routing bucket, resource restart and NPC placement. The automated suite does not emulate GTA rendering, OneSync replication or real server load.

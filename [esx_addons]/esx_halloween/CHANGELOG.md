# 2.1.0

- Server-owned, single-use ghost offers, activation acknowledgement, expiration and preparation rollback.
- Integration with the installed esx_death lifecycle: normal hospital respawn and penalties complete before ghost activation.
- Session-bound rate limits, routing bucket checks, validated IDs, cooldowns and authoritative deadlines.
- Shared-house interaction tickets and reservations around inventory calls, including yielding adapters.
- Fixed per-house rewards, verified delivery results and fail-closed handling of ambiguous mutations.
- Late-join snapshots, consumed-house removal, independent round duration/pause and consistent administrator reset.
- Proximity-based NPC streaming, corrected ground-height return values and bounded model loading.
- Fixed ghost key/function scope, restore/stop cleanup, vehicle/firing restrictions and retained appearance/loadout.
- Common reward amount is three medikits; the accidental nine-item multiplication is removed.
- Synchronous configuration/catalog validation, explicit dependencies and current OAL manifest setting.
- Fixed NUI debug message types, choice dismissal, local countdowns, sound settings, notification limits and animation cleanup.
- Added deterministic server/client security regression tests and regenerated the compiled UI.

The fixes stay within esx_halloween. No database migration or change to esx_death/es_extended is required.

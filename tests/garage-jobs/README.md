# Unified garage regression checks

Run from the repository root with Node >= 22.13:

```sh
npm install --prefix tests/garage-jobs
npm test --prefix tests/garage-jobs
```

The runner loads the actual garage registry, vehicle, migration and client modules in Fengari. It strips Lua 5.4 `<const>` annotations for the Lua 5.3 test runtime, simulates FiveM/ESX/oxmysql APIs, and executes the vehicle SQL predicates and updates against an in-memory SQLite database. Migration DDL is simulated and inspected separately. SQLite is not a MySQL compatibility test.

Coverage includes personal/fleet isolation, shared and assigned fleets, job/grade changes during reads/spawn/store, custom authorization, original ESX owners, plate locks, world duplication prevention, props/fuel/damage persistence, failed writes/deletion, impound fees and ownership selection, transfer/key restrictions, hostile input, independent/idempotent migration, closed-on-failure startup, stale client requests and logout.

For the built NUI smoke check, install Playwright separately or point `PLAYWRIGHT_PATH` to an existing Playwright module, and have Microsoft Edge installed:

```sh
npm install --no-save --prefix tests/garage-jobs playwright
node tests/garage-jobs/browser.cjs
```

The optional first argument is an existing screenshot directory. This check serves `web/dist` on loopback, mocks NUI callbacks, opens the existing UI in headless Edge, and verifies personal actions, hidden fleet ownership actions, the impound selector, a cooldown retry, switching back to personal vehicles and discarding a delayed response after closing/reopening. It does not connect to a game server.

## Live FiveM acceptance checklist (pending)

Use a staging server and a database backup. Keep the original fleet rows/owners, use unique plates and provision at least two police employees, one lower-grade employee, an ambulance employee and an unemployed player.

- [ ] Start with a previously migrated database; verify `job_fleets` is recorded, existing owners/jobs are unchanged, and a second restart performs no fleet DDL.
- [ ] Confirm original personal garages, search/pagination, names, favorites, transfer, keys, parking restrictions and impounds still work.
- [ ] Enable police/ambulance/mechanic examples with valid map coordinates. Verify only the matching job with sufficient grade can list/retrieve/store; direct callback attempts from other jobs also fail.
- [ ] Have employee A retrieve a shared vehicle originally owned by B; employee B must be unable to retrieve a duplicate. B can store the same vehicle without changing its owner/job.
- [ ] Set `shared = false`; verify only rows matching both the employee owner and job appear in that garage. Remove/disable other shared garages for that job when testing assigned-only access.
- [ ] Change job/grade or log out with the UI open and during a pending action; the old menu closes and the old job fleet is inaccessible.
- [ ] Store and retrieve damaged vehicles with partial fuel; check properties and parking state in the database and through the actual fuel/damage resources, including after restart.
- [ ] Impound a personal and a job vehicle, switch ownership contexts at the lot, and verify separate lists, configured fees, insufficient-funds handling, refund on failed spawn, and blocked spawns.
- [ ] Attempt job transfer/key callbacks as the original owner and a coworker; neither may convert ownership or grant personal keys. Check personal actions still succeed.
- [ ] Stop/restart the garage with a job vehicle out and confirm the existing orphan/impound recovery path works without duplication. Ensure other garage scripts do not operate on the same test fleet concurrently.
- [ ] Simulate a failed store/database write in staging; the vehicle must remain usable and the row must not be falsely marked as parked.

Automated results do not mark these live checks as completed.

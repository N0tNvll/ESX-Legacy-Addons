<h1 align='center'>[ESX] Garage</a></h1><p align='center'><b><a href='https://discord.esx-framework.org/'>Discord</a> - <a href='https://documentation.esx-framework.org/legacy/installation'>Documentation</a></b></h5>

Store Your vehicles in style! ESX garage has an amazing New UI to help you be stylish while parking your broken, rusty Nissan Micra!

# Personal and job garages

Both use this resource, the same callbacks and the existing NUI. Existing `type = 'public'` garages remain personal. Enable the commented police, ambulance or mechanic examples in `Config.Garages`, adjusting their coordinates for your map. A job garage can also be registered through the existing exports:

```lua
{
    id = 'police_fleet', label = 'Police Fleet', type = 'job',
    job = 'police', minGrade = 2, shared = true,
    entryPoint = vec3(459.15, -1008.01, 28.26),
    storePoint = vec3(452.4, -1007.7, 28.5),
    spawns = { vec4(446.8, -1024.5, 28.6, 5.0) },
    pound = 'los_santos',
},
```

- Personal vehicles require `owner` to match the current character and `job` to be `NULL` or an empty string. Restricted public/gang garages still contain personal vehicles.
- Job vehicles require `owned_vehicles.job` to match the employee's **current** job. `owner` remains the original database owner and is never changed when another employee retrieves or stores the vehicle.
- `shared = true` (the default for job garages) exposes the matching job fleet regardless of the row's owner. `shared = false` additionally restricts it to the employee's `owner`. Sharing is configured per garage, not per vehicle: an accessible shared garage exposes all rows for that job.
- `minGrade` defaults to `0`. Alternatively, use `access.jobs = { police = 2 }`. If both rules are present, the job must satisfy both and the higher minimum grade applies. For job garages, `access.authorize` may further restrict access, for example by duty status; it cannot bypass the job or grade rules. A job garage without a configured job rule denies access.

Lists, retrieval, storage, names and favorites all use the selected garage's server-side ownership scope. The server rechecks the session, job and grade after database/spawn waits. Job changes and logout close the current menu and invalidate pending vehicle lists. The existing plate operation lock covers employees sharing the same vehicle.

At an impound, select **Personal vehicles** or an authorized job garage in the ownership selector. The selected garage's job, minimum grade and sharing rule also apply to recovery. Existing impound locations, parking rules and fees remain in effect; fees use the retrieving employee's existing payment flow, without introducing society billing.

Job vehicles cannot use `transferVehicle` or personal `giveKeys`, even when the caller is the original owner or invokes the callbacks directly. Their names and favorites are per-vehicle metadata shared across employees. Retrieval/storage retain vehicle properties, including fuel and damage, and do not convert fleet vehicles to personal ownership.

This resource does not purchase or provision a fleet. It reuses existing `owned_vehicles` rows, including vehicles already assigned by ESX job resources. Retain a valid original `owner`, unique plate and valid vehicle properties when provisioning job vehicles. Coordinate other garage scripts operating on the same fleet; their external callbacks do not share this resource's plate locks.

# Data model & maintenance

Vehicle state lives on the standard `owned_vehicles` table, aligned with the es_extended vehicle class:

- `stored` (boolean): `1` = parked in a garage or sitting in an impound, `0` = out in the world.
- `parking` (string): id of the garage the vehicle is stored in (null when out or impounded).
- `pound` (string): id of the impound lot when impounded (null otherwise).
- `custom_name`, `is_favorite`, `last_used`, `mileage`: per-vehicle metadata.
- `owner`: original character/vehicle owner used by the ESX vehicle class.
- `job`: job association, separate from `owner`; `NULL`/empty means personal.

A vehicle whose row says `stored = 0` while no entity is left in the world (server restart, crash) is out of sync. It is recovered from an **impound** only, against that lot's fee: garages never hand it back. Recovery refuses to spawn another vehicle while a matching vehicle still exists in the world.

When the `esx_garage` resource stops, every `stored = 0` vehicle is moved to the first configured impound lot (`Config.Impounds[1]`) by setting `stored = 1`, clearing `parking`, and setting `pound` to that lot id.

Vehicle listing is paginated. `Config.Settings.vehiclesPerPage` controls the normal page size, while `Config.Settings.maxVehiclesPerMenu` caps the largest page a client can request. Large `owned_vehicles` tables should also have an index on `(owner, plate)` so page and plate-specific updates stay cheap.

`Config.Settings.restrictToGarage` ties a stored vehicle to the garage named by `parking`. A `parking` that is `NULL`, names a removed garage, or belongs to an incompatible ownership context is treated as available at any **authorized garage within the vehicle's ownership scope**. This keeps old job vehicles parked in public garages recoverable without exposing them as personal vehicles. Listing and retrieval share that rule.

The resource auto-migrates once per schema version (`server/modules/migration.lua`): it adds any missing column and converts legacy tri-state `stored = 2` rows to `stored = 1` + `pound` set to the first configured impound lot (the legacy schema does not record which lot). Successful migration is recorded as `schema = 1.16.0` in `esx_garage_migrations`. Fleet support has its own `job_fleets` marker, so it also runs on databases whose earlier migrations are already complete. It adds `job VARCHAR(20) NULL DEFAULT NULL` only when absent and an index on `(job, plate)`, without rewriting existing owners or job associations. Migration failure keeps vehicle callbacks closed. `esx_garage.sql` mirrors these changes; the automatic migration requires no manual SQL import on existing servers.

# Deployment and validation

Deploy the Lua files together with `web/dist`; the compiled UI is included. Keep the existing dependencies/start order in `fxmanifest.lua`. Back up the database before deployment, then start the resource and verify that its migration completes. Enable/configure job garages and confirm the existing fleet rows have the intended `job` values; no ownership backfill is performed.

Automated checks and the live FiveM acceptance checklist are documented in [tests/garage-jobs](../../tests/garage-jobs/README.md). The automated suite simulates FiveM and executes vehicle SQL predicates against SQLite; it does not replace validation on your FiveM server with oxmysql/MySQL, two employees, and the actual fuel/damage/key resources.

# Legal

esx_Garage - store vehicles in style!

Copyright (C) ESX-Framework

This program Is free software: you can redistribute it And/Or modify it under the terms Of the GNU General Public License As published by the Free Software Foundation, either version 3 Of the License, Or (at your option) any later version.

This program Is distributed In the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty Of MERCHANTABILITY Or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License For more details.

You should have received a copy Of the GNU General Public License along with this program. If Not, see http://www.gnu.org/licenses/.

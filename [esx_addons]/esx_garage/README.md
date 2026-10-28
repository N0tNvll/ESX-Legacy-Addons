<h1 align='center'>[ESX] Garage</a></h1><p align='center'><b><a href='https://discord.esx-framework.org/'>Discord</a> - <a href='https://documentation.esx-framework.org/legacy/installation'>Documentation</a></b></h5>

Store Your vehicles in style! ESX garage has an amazing New UI to help you be stylish while parking your broken, rusty Nissan Micra!

# Personal and job garages

Both use this resource, the same callbacks and the existing NUI. Existing `type = 'public'` garages remain personal. Civilian land garages, six existing marinas, a helipad and a hangar are configured in `Config.Garages`. Police, ambulance, taxi and mechanic register their garages from their own configuration through the integration scripts. A custom job garage can also be configured directly or registered through the existing exports:

```lua
{
    id = 'police_fleet', label = 'Police Fleet', type = 'job',
    job = 'police', minGrade = 2, shared = true,
    vehicleCategories = { 'ground' },
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

Police/ambulance and boat purchases remain in their original shops and payment flow. Their existing `owned_vehicles` rows are reused. Taxi/mechanic also support the one-time legacy import and initial fleet described below. Retain a valid original `owner`, unique plate and valid properties when provisioning other job vehicles. Third-party garage scripts operating on the same fleet must be updated: they do not share this resource's plate locks.

# Vehicle categories

Ownership and physical category are separate. Configure `vehicleCategories` on garages **and impounds**, independently of `type = 'public'` or `type = 'job'`:

| Category | Accepted database types |
| --- | --- |
| `ground` | `car`, `automobile`, `motorcycle`, `bike`, `bicycle`, `truck`, `emergency`, `trailer`, quadbike/amphibious land aliases, empty/NULL legacy type |
| `boat` | `boat`, `submarine` (including jet skis stored as boats) |
| `helicopter` | `helicopter`, `heli` |
| `plane` | `plane`, `airplane`, `blimp` |
| `train` | `train`; requires explicitly configured suitable locations |

An unspecified category defaults to `ground`. Legacy location `type = 'boat'` defaults to boats and `type = 'aircraft'` accepts both helicopter and plane categories, with personal ownership. Prefer explicit categories for new definitions. Categories filter SQL **before pagination**, retrieval and storage; the server also verifies the actual entity type. Helipad permissions cannot be bypassed by selecting a road garage as the fleet at an aircraft impound. Only category-compatible fleet contexts appear at a lot.

The raw database vehicle type `aircraft` is ambiguous and is rejected until configured. Use `Config.VehicleCategoryOverrides`, for example `{ maverick = 'helicopter', luxor = 'plane' }`, to classify legacy or incorrectly labelled models without rewriting their existing type/owner/props. Unknown types are not silently treated as cars. An override must agree with the actual entity type at spawn/store. Existing helicopter rows now display correctly in the existing aircraft UI category.

The six marinas retain their old boat garage entry, spawn, store and shore-exit coordinates. The new civilian helipad, hangar and category-specific impounds use standard-map locations; verify/adjust them for your map and aircraft sizes before deployment.

# Job integration and retired garages

The job manifests load `@esx_garage/integrations/config.lua` after their config and `@esx_garage/integrations/server.lua` on the server. They depend on `esx_garage`, so it starts first. No dependency on a particular job is added to the garage itself.

- Police/ambulance `Vehicles` and `Helicopters` reuse each station/hospital's coordinates and spawn points. Optional `Planes`/`Boats` groups follow the same shape. Existing vehicle purchase validation, grade catalogs, previews and payment stay in the job. The old spawner marker now opens **only the shop**, offset six metres west from the garage entry by default; set `ShopPoint` explicitly where necessary. Optional `GarageMinGrade`, `GarageLabel`, `StorePoint` and `Pound` override one location. `Config.GarageIntegration` controls default `minGrade`, `shared`, labels and preferred pound. Duty checks are enforced in the server; police `EnableESXService` is also respected.
- Taxi reuses its old spawner, spawn and return coordinates. Mechanic keeps its crafting/harvesting `Garage` zone, while its new vehicle entry is six metres north of `MechanicActions`; its existing spawn/return points are reused. Model restrictions retain the taxi authorized catalog and the mechanic's restricted Slamvan grades. Configured service limits reserve a slot before spawning and release new reservations on failure.
- Job garages are registered per resource, removed when that job resource stops and registered again when `esx_garage` restarts.
- Retired boat garage menus/markers/callbacks, police/ambulance nearby-store callbacks, vehicleshop job state/list handlers, taxi vehicle spawning and society datastore vehicle garage handlers are removed. The boat shop and licence purchase remain. The temporary vehicles used by `esx_jobs` missions retain their mission lifecycle; they are not persistent owned fleets.

# Taxi/mechanic fleet import and initial stock

At startup, the server integration imports parked legacy entries from `datastore_data.garage` for `society_taxi`/`society_mechanic`. The original datastore JSON is retained as an archive. Matching existing job rows keep their owners, properties and current stored/out state; a conflicting personal/other-job plate blocks initialization instead of overwriting it. Newly imported rows use `owner = 'society:taxi'` or `'society:mechanic'` with a separate `job` association.

`esx_garage_fleet_imports` records each imported plate and initial stock slot. Each vehicle insert and its marker commit together in a transaction. Import requires InnoDB `owned_vehicles`; incompatible engines fail without automatic conversion. A partially completed import resumes and successful slots are not provisioned again, even if a vehicle is later deleted. No live database was changed by the development tests: import runs when these updated resources start on your server.

With `EnableSocietyOwnedVehicles = true`, only legacy/existing fleet vehicles are reused. Otherwise taxi initializes four vehicles per authorized model (`Config.GarageIntegration.vehiclesPerModel`, or `garageCount` per authorized entry). Mechanic's `Config.GarageFleet` initializes two flatbeds, two tow trucks and one Slamvan by default. These quantities replace unlimited temporary spawning with persistent shared stock. Existing matching job vehicles count toward the initial stock; their owners are unchanged. Set quantities before the first deployment; lowering a quantity never deletes existing vehicles. Increasing a quantity adds only the new recorded slots. Seed vehicles require a shared garage; assigned garages use explicitly employee-owned rows.

Store existing society vehicles in the old garage **before updating**, then stop the old resources. Legacy temporary vehicles currently out without any database/datastore record cannot safely be claimed by plate alone. Do not run an old society/taxi/boat/job garage against the archived stock after this migration, including during rollback, because it would create a second access path.

# Data model & maintenance

Vehicle state lives on the standard `owned_vehicles` table, aligned with the es_extended vehicle class:

- `stored` (boolean): `1` = parked in a garage or sitting in an impound, `0` = out in the world.
- `parking` (string): id of the garage the vehicle is stored in (null when out or impounded).
- `pound` (string): id of the impound lot when impounded (null otherwise).
- `custom_name`, `is_favorite`, `last_used`, `mileage`: per-vehicle metadata.
- `owner`: original character/vehicle owner used by the ESX vehicle class.
- `job`: job association, separate from `owner`; `NULL`/empty means personal.

A vehicle whose row says `stored = 0` while no entity is left in the world (server restart, crash) is out of sync. It is recovered from an **impound** only, against that lot's fee: garages never hand it back. Recovery refuses to spawn another vehicle while a matching vehicle still exists in the world.

When `esx_garage` stops or recovers an orphan, it chooses the first configured impound compatible with the vehicle category, sets `stored = 1`, clears `parking` and records that lot. Startup also corrects old impound assignments to incompatible categories. If no compatible lot exists, the row remains intact for configuration repair; it is not sent to a land lot. Existing compatible lot assignments and fees remain unchanged.

Vehicle listing is paginated. `Config.Settings.vehiclesPerPage` controls the normal page size, while `Config.Settings.maxVehiclesPerMenu` caps the largest page a client can request. Large `owned_vehicles` tables should also have an index on `(owner, plate)` so page and plate-specific updates stay cheap.

`Config.Settings.restrictToGarage` ties a stored vehicle to the garage named by `parking`. A `parking` that is `NULL`, names a removed garage, or belongs to an incompatible ownership context is treated as available at any **authorized garage within the vehicle's ownership scope**. This keeps old job vehicles parked in public garages recoverable without exposing them as personal vehicles. Listing and retrieval share that rule.

The resource auto-migrates once per schema version (`server/modules/migration.lua`): it adds any missing column and converts legacy tri-state `stored = 2` rows to `stored = 1` + `pound` set to the first configured impound lot (the legacy schema does not record which lot). Successful migration is recorded as `schema = 1.16.0` in `esx_garage_migrations`. Fleet support has its own `job_fleets` marker, so it also runs on databases whose earlier migrations are already complete. It adds `job VARCHAR(20) NULL DEFAULT NULL` only when absent and an index on `(job, plate)`, without rewriting existing owners or job associations. Migration failure keeps vehicle callbacks closed. `esx_garage.sql` mirrors these changes; the automatic migration requires no manual SQL import on existing servers.

# Deployment and validation

Deploy all affected job, society, vehicleshop, service, boat and garage files together with `web/dist`; the compiled UI is included. Back up the database and park legacy society vehicles before stopping the old resources. Start the existing database/core/payment dependencies, `esx_garage`, then the job/boat resources (and `esx_service` when enabled). Verify schema/fleet initialization logs and the import ledger. Confirm fleet `job` associations, grade rules, stock quantities and category-compatible coordinates. Existing row owners are not backfilled or reassigned.

Automated checks and the live FiveM acceptance checklist are documented in [tests/garage-jobs](../../tests/garage-jobs/README.md). The automated suite simulates FiveM and executes vehicle SQL predicates against SQLite; it does not replace validation on your FiveM server with oxmysql/MySQL, two employees, and the actual fuel/damage/key resources.

# Legal

esx_Garage - store vehicles in style!

Copyright (C) ESX-Framework

This program Is free software: you can redistribute it And/Or modify it under the terms Of the GNU General Public License As published by the Free Software Foundation, either version 3 Of the License, Or (at your option) any later version.

This program Is distributed In the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty Of MERCHANTABILITY Or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License For more details.

You should have received a copy Of the GNU General Public License along with this program. If Not, see http://www.gnu.org/licenses/.

<h1 align='center'>[ESX] Basic Needs</a></h1><p align='center'><b><a href='https://discord.esx-framework.org/'>Discord</a> - <a href='https://documentation.esx-framework.org/legacy/installation'>Documentation</a></b></h5>

This resource includes hunger, thirst, consumables and the alcohol system formerly provided by
`esx_optionalneeds`. Bread restores hunger, water restores thirst and beer increases the saved
`drunk` status. Alcohol retains its three movement levels, blurred vision and gradual recovery.

## Migrating from esx_optionalneeds

Stop and remove `esx_optionalneeds` and remove its `ensure` entry. Start only `esx_basicneeds` after
`esx_status`. The old `esx_optionalneeds:onDrink` event remains available and uses the shared drink
animation. Dependencies on the old resource name are supported by the manifest's `provide` entry.

Deploy the updated `esx_status/config.lua` and `esx_lib/imports/catalog/data.json` together with this
resource, then restart the server. Hunger, thirst and alcohol are applied and decayed on the server.
Existing saved `drunk` values and inventory items keep their names and do not need conversion.

The shared item configuration accepts `food`, `drink` and `alcohol`. Beer adds 250000 alcohol units;
the status decreases by 1500 per second. The first movement level covers values up to 250000, the
second covers values up to 500000, and higher values use the third level. Effects are cleared when
the player sobers up, dies, logs out or the resource stops.

## Requirements
- [esx_status](https://github.com/esx-framework/esx_status)

## Download & Installation

### Using [fvm](https://github.com/qlaffont/fvm-installer)
```
fvm install --save --folder=esx esx-framework/esx_basicneeds
```

### Using Git
```
cd resources
git clone https://github.com/esx-framework/esx_basicneeds [esx]/esx_basicneeds
```

### Manually
- Download https://github.com/esx-framework/esx_basicneeds/archive/master.zip
- Put it in the `[esx]` directory


## Installation
- With this repository's `esx_lib` catalog, missing bread, water and beer items are imported
  automatically before usable items are registered. Existing item values are preserved. Manual
  installations can import `esx_basicneeds.sql` or the matching localized SQL file instead.
- Add this in your server.cfg :

```
start esx_basicneeds
```

# Legal
### License
esx_basicneeds - thirst and hunger system

Copyright (C) 2015-2025 Jérémie N'gadi

This program Is free software: you can redistribute it And/Or modify it under the terms Of the GNU General Public License As published by the Free Software Foundation, either version 3 Of the License, Or (at your option) any later version.

This program Is distributed In the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty Of MERCHANTABILITY Or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License For more details.

You should have received a copy Of the GNU General Public License along with this program. If Not, see http://www.gnu.org/licenses/.

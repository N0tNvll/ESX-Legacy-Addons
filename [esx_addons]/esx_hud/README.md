<h1 align='center'>[ESX] HUD</a></h1><p align='center'><b><a href='https://discord.esx-framework.org/'>Discord</a> - <a href='https://documentation.esx-framework.org/legacy/installation'>Documentation</a></b></h5>

We've brought you a clean, modern HUD that's easy to customise and configure. Integrated mileage calculation and more.

Features
 - Mileage calculation system
 - Indicator system with sound effect
 - Weapon HUD with ammo counter
 - Online player counter
 - Job label
 - Switch to mph or kmh
 - Color picker that allows you to customize the interface
 - Settings panel for additional settings
 - Different speedo layouts depending on vehicle type(LAND,AIR)
 - Integrated seatbelt and cruise control with HUD indicators and seatbelt sound

## HUD UI
While GTA replay recording is active, character status and location move temporarily
to the lower center, above the voice indicator. This leaves the native recording
notification above the minimap visible. The HUD reads the game's recording state
every 500 ms, including recordings started by another resource, and restores the
normal layout when recording ends. Saved HUD preferences are not changed.

![img.png](img.png)
## SETTINGS UI
![img_1.png](img_1.png)

## Developed by Gellipapa#9186 && Rav3n95#2849
## Special thanks: Csoki, csontvazharcos, Füsti

## Download & Installation

- [Download Link](https://github.com/esx-framework/esx_hud/releases/latest/download/esx_hud.zip)
- Put it in the `[addons]` directory
- Open web folder in console and run these command `npm install` after `npm run build`
- After that, the HUD will work correctly
- Enjoy

## Installation
- Add this to your `server.cfg`:

```
ensure esx_hud
```

## Driving controls

Cruise control and the seatbelt are part of `esx_hud`. Configure them in
`shared/config.lua`, under `Config.Driving`. The default keys remain Caps Lock
for cruise control, numpad + / - for its target speed, and B for the seatbelt.
Existing keybind command names are retained so saved bindings keep working.
`EjectCheckSpeed` is measured in MPH and `RagdollTime` in seconds.

Stop and remove the old `esx_cruisecontrol` resource and its `ensure` entry before
deploying the updated HUD. Copy the complete HUD, including `client/driving`
and `shared/driving_locales.lua`. Cruise control and seatbelt settings are data
inside the HUD configuration; a second HUD export configuration is unnecessary.

`exports.esx_hud:isSeatbeltOn()` returns the actual seatbelt state. The old
`esx_cruisecontrol` seatbelt export remains available as a compatibility alias.
`CruiseControlState` and `SeatbeltState` exports retain their existing HUD API.
Vehicle exit, logout and resource stop clear the controller and the native
seatbelt flags. The driving features also work when the speedometer is hidden.

No database migration or frontend rebuild is required for this consolidation.

# Legal
### License
esx_hud - hud script for ESX

Copyright (C) 2025 ESX-Framework

This program Is free software: you can redistribute it And/Or modify it under the terms Of the GNU General Public License As published by the Free Software Foundation, either version 3 Of the License, Or (at your option) any later version.

This program Is distributed In the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty Of MERCHANTABILITY Or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License For more details.

You should have received a copy Of the GNU General Public License along with this program. If Not, see http://www.gnu.org/licenses/.

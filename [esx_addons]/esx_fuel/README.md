# esx_fuel

Fuel system for ESX Legacy.

## Features

- Take the nozzle at a pump, walk it to the fuel cap with the hose, pick the fuel and the amount on the pump screen and pay cash or bank.
- Consumption based on RPM and vehicle class, stored in the native fuel level so the HUD and garages keep working.
- Fuel types: regular, plus, premium, diesel and electric. The type of a vehicle comes from its class, electric vehicles are detected by the game and any model can be forced in `Config.ModelFuel`.
- Wrong fuel: power loss, stalls and engine damage that grow with the share of wrong fuel in the tank. Higher octane gives a small torque bonus. Mechanics can drain the tank.
- Electric vehicles charge at every pump, `Config.Chargers` adds extra spots.
- Jerry can (`WEAPON_PETROLCAN`): fill it at a pump, pour it anywhere.
- Vehicle damage (`Config.Damage`): a damaged tank leaks and a worn engine burns more fuel. With esx_vehiclefailure installed, wrong fuel wears the engine through its failure thresholds and its power loss is combined with limp mode.
- The fuel mix of an owned vehicle is saved by plate, only when its owner (or a mechanic draining it) changes it.
- Optional station stock (`Config.Stock.Enabled`, off by default): refilled with deliveries of `petrol_raffin` from the fueler job, stations can belong to a society which earns the sales and sets the price with `/fuelprice`.

All prices, quantities, refunds and deliveries are computed server side.

## Exports

Client, compatible with LegacyFuel:

```lua
exports.esx_fuel:GetFuel(vehicle)
exports.esx_fuel:SetFuel(vehicle, level)
```

The level is also published in the `fuel` state bag of the vehicle.

## Install

`ensure esx_fuel` after `es_extended`, `esx_lib` and `oxmysql`. Tables are created on start, `esx_fuel.sql` is provided for manual installs.

The jerry can uses the ESX loadout. With ox_inventory weapons the can purchase is not supported yet.

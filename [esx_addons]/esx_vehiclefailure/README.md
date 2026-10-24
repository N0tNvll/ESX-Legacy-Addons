# esx_vehiclefailure

Configurable vehicle damage and engine failure for ESX Legacy.

- Collision damage multiplied per part (engine, body, tank) and per vehicle class. Boats, aircraft, cycles and trains are ignored by default.
- Below a first threshold the engine keeps wearing on its own, below a second one it goes into limp mode (lower top speed and torque, random stalls), below the last one it dies and the vehicle cannot be driven until repaired.
- Hard hits can burst a tyre.
- Flipped vehicles cannot be rolled back with the air controls.

The state comes from the vehicle health, so any repair (mechanic repair kit, garage, admin) clears it.

## Fuel

esx_fuel uses it when both run: wrong fuel wears the engine through `AddEngineWear` and limits the power through `SetModifier`, a damaged tank leaks and a worn engine burns more fuel.

```lua
-- engine wear that is not multiplied again, stops at the failure threshold
exports.esx_vehiclefailure:AddEngineWear(vehicle, amount)

-- power limit from another resource: lowest speed factor and product of the torque factors win
exports.esx_vehiclefailure:SetModifier(vehicle, "my_resource", speedFactor, torqueFactor)
exports.esx_vehiclefailure:SetModifier(vehicle, "my_resource")
```

Scripts that cap the top speed or the torque of the driven vehicle should go through `SetModifier`, two resources calling `SetVehicleMaxSpeed` overwrite each other.

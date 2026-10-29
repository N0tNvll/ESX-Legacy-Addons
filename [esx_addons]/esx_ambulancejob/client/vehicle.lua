-- SPDX-License-Identifier: GPL-3.0-only
function OpenVehicleShopMenu(vehicleType, location, group, index)
    return exports['esx_vehicleshop']:openDealership(
        ('%s_%s_%s_%s'):format('ambulance', location, group:lower(), index)
    )
end

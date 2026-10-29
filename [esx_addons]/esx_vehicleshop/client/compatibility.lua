-- SPDX-License-Identifier: GPL-3.0-only
-- Temporary public client contracts. No independent markers, previews or payments.
function OpenBoatShop()
    return exports['esx_vehicleshop']:openDealership('boats')
end

function OpenLicenceMenu()
    return OpenBoatShop()
end

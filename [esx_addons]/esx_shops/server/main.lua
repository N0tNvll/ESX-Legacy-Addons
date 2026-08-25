---Handles purchase requests from clients
xLib.callback.registerCompat('esx_shops:purchaseItems', function(source, cb, purchaseData, zone)
	ProcessPurchase(source, purchaseData, zone, cb)
end)

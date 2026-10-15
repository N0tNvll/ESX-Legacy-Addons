# ESX Payment Gateway

The NUI frontend lives in `web/`. It builds to `web/dist/` with `npm run build`.

## Use from another server resource

Start `esx_paymentgateway` after `es_extended`, then open a selector from server-side code:

```lua
local opened, reason = exports.esx_paymentgateway:RequestPayment(source, {
  amount = 1250,
  title = 'Vehicle repair',
  description = 'Los Santos Customs',
  methods = { 'cash', 'card' }, -- optional; defaults to both
  resultEvent = 'my-resource:paymentFinished', -- optional server event
})

if not opened then
  print(reason)
end
```

The export returns `false, reason` when the player is unavailable, a payment is already open, or the request is invalid.

If supplied, `resultEvent` receives `(playerId, success, method, request)`. It is emitted on the server when the payment succeeds, fails due to insufficient funds, or is cancelled.

```lua
AddEventHandler('my-resource:paymentFinished', function(playerId, success, method, request)
  if success then
    -- Deliver the purchased item or service.
  end
end)
```

## Payment flow

The client NUI sends only the selected method. The server retains the amount and request details, verifies the player’s current cash or bank balance, and performs the deduction. The UI receives updated balances when opened, which disables methods that cannot cover the request.

## Resource contents

`fxmanifest.lua` serves `web/dist/`. `client/main.lua` manages NUI focus and browser callbacks. `server/main.lua` owns pending requests, balance validation, and ESX deductions.


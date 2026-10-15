type ParentWindow = Window & { GetParentResourceName?: () => string }

export const isNui = typeof window !== 'undefined' && 'GetParentResourceName' in window

function getResourceName() {
  return (window as ParentWindow).GetParentResourceName?.() ?? 'esx_paymentgateway'
}

export async function postNui<T extends object>(endpoint: string, data: T) {
  if (!isNui) return

  await fetch(`https://${getResourceName()}/${endpoint}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data),
  })
}

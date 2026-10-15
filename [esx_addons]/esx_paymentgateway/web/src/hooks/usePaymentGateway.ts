import { useCallback, useEffect, useState } from 'react'
import { createPaymentRequest, getAvailableMethod } from '../lib/payment'
import { isNui, postNui } from '../lib/nui'
import { applyTheme } from '../lib/theme'
import type { NuiMessage, PaymentMethod, PaymentRequest, PaymentStatus } from '../types/payment'

const demoPaymentRequest: PaymentRequest = {
  amount: 1250, currency: '$', title: 'Vehicle repair',
  description: 'Los Santos Customs', methods: ['cash', 'card'], cashBalance: 4820, bankBalance: 18500,
}

const demoMode = !isNui || new URLSearchParams(window.location.search).has('demo')

export function usePaymentGateway() {
  const [open, setOpen] = useState(demoMode)
  const [paymentRequest, setPaymentRequest] = useState<PaymentRequest>(demoPaymentRequest)
  const [method, setMethod] = useState<PaymentMethod>('cash')
  const [status, setStatus] = useState<PaymentStatus>('ready')
  const [message, setMessage] = useState('')
  const [logoUrl, setLogoUrl] = useState('')

  const cancel = useCallback(async () => {
    setOpen(false)
    setStatus('ready')
    await postNui('close', {})
  }, [])

  const retry = useCallback(() => {
    setStatus('ready')
    setMessage('')
  }, [])

  const confirm = useCallback(async () => {
    if (status !== 'ready') return

    setStatus('processing')
    setMessage('')

    try {
      // Only the method is sent: the server owns the amount.
      await postNui('selectPayment', { method })
      if (demoMode) window.setTimeout(() => {
        setStatus('success')
        setMessage('Payment complete. Your transaction was approved.')
      }, 900)
    } catch {
      setStatus('failure')
      setMessage('Could not reach the payment service. Please try again.')
    }
  }, [method, status])

  useEffect(() => {
    const handleMessage = (event: MessageEvent<NuiMessage>) => {
      const { action, payload, theme } = event.data ?? {}

      if (action === 'open' && payload) {
        if (theme) {
          applyTheme(theme)
          setLogoUrl(theme.logoUrl ?? '')
        }

        const nextPaymentRequest = createPaymentRequest(payload)
        setPaymentRequest(nextPaymentRequest)
        setMethod(getAvailableMethod(nextPaymentRequest) ?? 'cash')
        setStatus('ready')
        setMessage('')
        setOpen(true)
      }

      if (action === 'close') setOpen(false)

      if (action === 'paymentResult' && payload) {
        setStatus(payload.success ? 'success' : 'failure')
        setMessage(payload.message ?? (payload.success ? 'Payment complete.' : 'Payment could not be completed.'))
      }
    }

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape' && open && status !== 'processing') void cancel()
    }

    window.addEventListener('message', handleMessage)
    window.addEventListener('keydown', handleKeyDown)
    return () => {
      window.removeEventListener('message', handleMessage)
      window.removeEventListener('keydown', handleKeyDown)
    }
  }, [cancel, open, status])

  return { open, paymentRequest, method, status, message, logoUrl, setMethod, confirm, cancel, retry, isDemo: demoMode }
}

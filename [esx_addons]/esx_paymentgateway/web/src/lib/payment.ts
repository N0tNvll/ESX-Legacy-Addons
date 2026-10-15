import type { PaymentMethod, PaymentRequest } from '../types/payment'

export const defaultMethods: PaymentMethod[] = ['cash', 'card']

export const formatMoney = (amount: number) =>
  new Intl.NumberFormat('en-US', { maximumFractionDigits: 0 }).format(amount)

export function getBalance(paymentRequest: PaymentRequest, method: PaymentMethod) {
  return method === 'cash' ? paymentRequest.cashBalance : paymentRequest.bankBalance
}

export function hasSufficientFunds(paymentRequest: PaymentRequest, method: PaymentMethod) {
  const balance = getBalance(paymentRequest, method)
  return balance === undefined || balance >= paymentRequest.amount
}

export function getAvailableMethod(paymentRequest: PaymentRequest) {
  return (paymentRequest.methods ?? defaultMethods).find((method) => hasSufficientFunds(paymentRequest, method))
}

export function createPaymentRequest(payload: Partial<PaymentRequest>): PaymentRequest {
  return {
    amount: payload.amount ?? 0,
    currency: payload.currency ?? '$',
    title: payload.title ?? 'Payment',
    description: payload.description,
    methods: payload.methods ?? defaultMethods,
    cashBalance: payload.cashBalance,
    bankBalance: payload.bankBalance,
  }
}

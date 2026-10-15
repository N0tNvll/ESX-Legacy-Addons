export type PaymentMethod = 'cash' | 'card'

export type PaymentStatus = 'ready' | 'processing' | 'success' | 'failure'

export interface PaymentRequest {
  amount: number
  currency: string
  title: string
  description?: string
  methods?: PaymentMethod[]
  cashBalance?: number
  bankBalance?: number
}

export interface PaymentResult {
  success: boolean
  message?: string
}

/** Values of the esx:ui:* convars, sent by the client script on open. */
export interface Theme {
  primaryColor: string
  secondaryColor: string
  backgroundColor: string
  accentColor: string
  logoUrl: string
}

export interface NuiMessage {
  action?: 'open' | 'close' | 'paymentResult'
  payload?: Partial<PaymentRequest> & Partial<PaymentResult>
  theme?: Partial<Theme>
}

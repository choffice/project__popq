import { createClientId } from '../utils/clientId'

const TOSS_SDK_URL = 'https://js.tosspayments.com/v2/standard'
const CUSTOMER_KEY_STORAGE = 'popq:toss:guest-customer-key'

interface TossPaymentRequest {
  method: 'CARD'
  amount: {
    currency: 'KRW'
    value: number
  }
  orderId: string
  orderName: string
  successUrl: string
  failUrl: string
  windowTarget: 'self'
}

interface TossPaymentClient {
  requestPayment(request: TossPaymentRequest): Promise<void>
}

interface TossPaymentsClient {
  payment(options: { customerKey: string }): TossPaymentClient
}

type TossPaymentsFactory = (clientKey: string) => TossPaymentsClient

declare global {
  interface Window {
    TossPayments?: TossPaymentsFactory
  }
}

export type TossPaymentReturn =
  | {
      status: 'success'
      paymentKey: string
      orderId: string
      amount: number
    }
  | {
      status: 'fail'
      code: string | null
      message: string
    }

export interface TossPaymentRequestOptions {
  clientKey: string
  orderId: string
  orderName: string
  amount: number
}

let sdkLoading: Promise<TossPaymentsFactory> | null = null

function getCustomerKey() {
  const stored = window.sessionStorage.getItem(CUSTOMER_KEY_STORAGE)
  if (stored) return stored

  const created = `guest_${createClientId()}`
  window.sessionStorage.setItem(CUSTOMER_KEY_STORAGE, created)
  return created
}

function paymentReturnUrl(status: 'success' | 'fail') {
  const url = new URL(window.location.href)
  url.search = ''
  url.hash = ''
  url.searchParams.set('payment', status)
  return url.toString()
}

function loadTossPayments() {
  if (window.TossPayments) return Promise.resolve(window.TossPayments)
  if (sdkLoading) return sdkLoading

  sdkLoading = new Promise<TossPaymentsFactory>((resolve, reject) => {
    const existing = document.querySelector<HTMLScriptElement>(
      `script[src="${TOSS_SDK_URL}"]`,
    )
    const script = existing ?? document.createElement('script')

    function finish() {
      if (window.TossPayments) resolve(window.TossPayments)
      else reject(new Error('토스페이먼츠 SDK를 불러오지 못했습니다.'))
    }

    script.addEventListener('load', finish, { once: true })
    script.addEventListener(
      'error',
      () => reject(new Error('토스페이먼츠 SDK를 불러오지 못했습니다.')),
      { once: true },
    )

    if (!existing) {
      script.src = TOSS_SDK_URL
      script.async = true
      document.head.appendChild(script)
    }
  }).catch((error) => {
    sdkLoading = null
    throw error
  })

  return sdkLoading
}

export async function requestTossPayment(
  options: TossPaymentRequestOptions,
) {
  const clientKey = options.clientKey.trim()
  if (!clientKey) {
    throw new Error('토스페이먼츠 클라이언트 키가 설정되지 않았습니다.')
  }

  const TossPayments = await loadTossPayments()
  const payment = TossPayments(clientKey).payment({
    customerKey: getCustomerKey(),
  })

  await payment.requestPayment({
    method: 'CARD',
    amount: {
      currency: 'KRW',
      value: options.amount,
    },
    orderId: options.orderId,
    orderName: options.orderName,
    successUrl: paymentReturnUrl('success'),
    failUrl: paymentReturnUrl('fail'),
    windowTarget: 'self',
  })
}

export function readTossPaymentReturn(
  search: string,
): TossPaymentReturn | null {
  const params = new URLSearchParams(search)
  const status = params.get('payment')

  if (status === 'success') {
    const paymentKey = params.get('paymentKey')
    const orderId = params.get('orderId')
    const rawAmount = params.get('amount')
    const amount = rawAmount === null ? Number.NaN : Number(rawAmount)
    if (!paymentKey || !orderId || !Number.isSafeInteger(amount) || amount < 0) {
      return {
        status: 'fail',
        code: 'INVALID_PAYMENT_RESULT',
        message: '결제 인증 결과가 올바르지 않습니다.',
      }
    }
    return { status, paymentKey, orderId, amount }
  }

  if (status === 'fail') {
    return {
      status,
      code: params.get('code'),
      message: params.get('message') ?? '결제 인증이 취소되거나 실패했습니다.',
    }
  }

  return null
}

export function clearTossPaymentReturn() {
  const url = new URL(window.location.href)
  for (const key of [
    'payment',
    'paymentKey',
    'orderId',
    'amount',
    'code',
    'message',
    'paymentType',
  ]) {
    url.searchParams.delete(key)
  }
  window.history.replaceState({}, '', `${url.pathname}${url.search}${url.hash}`)
}

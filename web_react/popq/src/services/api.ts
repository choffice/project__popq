import type {
  CartItem,
  OrderResponse,
  OrderSyncResponse,
  OrderType,
  ProductDetail,
  ProductSummary,
  QrContext,
} from '../types'

interface ApiEnvelope<T> {
  success: boolean
  data: T
  error: { code: string; message: string } | null
}

export class ApiError extends Error {
  readonly status: number
  readonly code: string | null

  constructor(message: string, status: number, code: string | null = null) {
    super(message)
    this.name = 'ApiError'
    this.status = status
    this.code = code
  }
}

const qrSessionRequests = new Map<string, Promise<QrContext>>()

async function request<T>(
  path: string,
  init?: RequestInit,
): Promise<T> {
  const response = await fetch(path, {
    credentials: 'include',
    headers: {
      'Content-Type': 'application/json',
      ...init?.headers,
    },
    ...init,
  })
  let envelope: ApiEnvelope<T>
  try {
    envelope = (await response.json()) as ApiEnvelope<T>
  } catch {
    if (!response.ok) {
      throw new ApiError(
        `서버 요청이 거부되었습니다. (${response.status})`,
        response.status,
      )
    }
    throw new Error('서버 응답 형식이 올바르지 않습니다.')
  }
  if (!response.ok || !envelope.success) {
    throw new ApiError(
      envelope.error?.message ?? '요청을 처리하지 못했습니다.',
      response.status,
      envelope.error?.code ?? null,
    )
  }
  return envelope.data
}

export async function openQrSession(token: string): Promise<QrContext> {
  const pending = qrSessionRequests.get(token)
  if (pending) return pending

  const sessionRequest = request<QrContext>(
    `/api/v1/qr/${encodeURIComponent(token)}/sessions`,
    { method: 'POST' },
  )
  qrSessionRequests.set(token, sessionRequest)
  void sessionRequest
    .finally(() => {
      if (qrSessionRequests.get(token) === sessionRequest) {
        qrSessionRequests.delete(token)
      }
    })
    .catch(() => undefined)
  return sessionRequest
}

export async function getProducts(): Promise<ProductSummary[]> {
  return request<ProductSummary[]>('/api/v1/qr/products')
}

export async function getProductDetail(
  productId: number,
): Promise<ProductDetail> {
  return request<ProductDetail>(`/api/v1/qr/products/${productId}`)
}

export async function createOrder(
  items: CartItem[],
  orderType: OrderType,
  idempotencyKey: string,
): Promise<OrderResponse> {
  return request<OrderResponse>('/api/v1/qr/orders', {
    method: 'POST',
    body: JSON.stringify({
      idempotencyKey,
      orderType,
      items: items.map((item) => ({
        productId: item.product.productId,
        quantity: item.quantity,
        optionIds: item.options.map((option) => option.optionId),
      })),
    }),
  })
}

export async function confirmPayment(
  orderPublicId: string,
  idempotencyKey: string,
  paymentKey: string,
): Promise<void> {
  await request(`/api/v1/qr/orders/${orderPublicId}/payments`, {
    method: 'POST',
    body: JSON.stringify({
      idempotencyKey,
      simulateFailure: false,
      paymentKey,
    }),
  })
}

export async function cancelOrder(
  orderPublicId: string,
  reason = '고객 주문 취소',
): Promise<OrderResponse> {
  return request<OrderResponse>(`/api/v1/qr/orders/${orderPublicId}/cancel`, {
    method: 'POST',
    body: JSON.stringify({ reason }),
  })
}

export async function syncOrder(
  orderPublicId: string,
  knownVersion: number,
): Promise<OrderSyncResponse> {
  return request<OrderSyncResponse>(
    `/api/v1/qr/orders/${orderPublicId}/sync?knownVersion=${knownVersion}`,
  )
}

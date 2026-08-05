import { beforeEach, describe, expect, it, vi } from 'vitest'
import {
  cancelOrder,
  confirmPayment,
  createOrder,
  openQrSession,
} from './api'
import type { CartItem } from '../types'

const item: CartItem = {
  cartId: 'cart-1',
  product: {
    productId: 10,
    categoryId: 1,
    categoryName: '커피',
    name: '아메리카노',
    description: null,
    imageUrl: null,
    basePrice: 5000,
    status: 'ACTIVE',
    soldOut: false,
    availableForQr: true,
  },
  quantity: 2,
  options: [
    {
      optionId: 31,
      name: 'ICE',
      additionalPrice: 500,
      displayOrder: 0,
    },
  ],
}

describe('order API contract', () => {
  beforeEach(() => {
    vi.restoreAllMocks()
  })

  it('uses caller-provided idempotency keys for safe retries', async () => {
    const fetchMock = vi.fn()
      .mockResolvedValueOnce(response({ orderPublicId: 'order-1', version: 0 }))
      .mockResolvedValueOnce(response({ status: 'PAID' }))
    vi.stubGlobal('fetch', fetchMock)

    await createOrder([item], 'TAKEOUT', 'stable-order-key')
    await confirmPayment('order-1', 'stable-payment-key', 'toss-payment-key')

    expect(JSON.parse(fetchMock.mock.calls[0][1].body as string)).toMatchObject({
      idempotencyKey: 'stable-order-key',
      orderType: 'TAKEOUT',
      items: [{ productId: 10, quantity: 2, optionIds: [31] }],
    })
    expect(JSON.parse(fetchMock.mock.calls[1][1].body as string)).toMatchObject({
      idempotencyKey: 'stable-payment-key',
      paymentKey: 'toss-payment-key',
    })
  })

  it('calls the guest cancellation command endpoint', async () => {
    const fetchMock = vi.fn().mockResolvedValue(
      response({ orderPublicId: 'order-1', status: 'CANCELED' }),
    )
    vi.stubGlobal('fetch', fetchMock)

    await cancelOrder('order-1', '고객 변심')

    expect(fetchMock).toHaveBeenCalledWith(
      '/api/v1/qr/orders/order-1/cancel',
      expect.objectContaining({
        method: 'POST',
        body: JSON.stringify({ reason: '고객 변심' }),
      }),
    )
  })

  it('reports a rejected non-JSON response without exposing a parser error', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({
      ok: false,
      status: 403,
      json: async () => {
        throw new SyntaxError('Unexpected token')
      },
    }))

    await expect(openQrSession('qr-token')).rejects.toThrow(
      '서버 요청이 거부되었습니다. (403)',
    )
  })
})

function response(data: unknown) {
  return {
    ok: true,
    json: async () => ({
      success: true,
      data,
      error: null,
    }),
  }
}

import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { cleanup, render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import App from './App'
import type { SellerOrder, SellerProduct } from './types'

const realtime = vi.hoisted(() => ({
  connect: vi.fn(),
  disconnect: vi.fn(),
}))

vi.mock('./services/realtime', () => ({
  connectSellerRealtime: realtime.connect,
}))

vi.mock('qrcode', () => ({
  default: {
    toDataURL: vi.fn().mockResolvedValue('data:image/png;base64,test'),
  },
}))

function order(storeId: number, storeName: string): SellerOrder {
  return {
    orderPublicId: `order-store-${storeId}`,
    storeId,
    storeName,
    orderType: 'TAKEOUT',
    status: 'PLACED',
    subtotalAmount: 5000,
    discountAmount: 0,
    taxAmount: 0,
    serviceFeeAmount: 0,
    totalAmount: 5000,
    expiresAt: '2099-01-01T00:00:00Z',
    version: 1,
    items: [
      {
        orderItemId: storeId,
        productId: storeId,
        productName: `${storeName} 주문 상품`,
        productImageUrl: null,
        unitPrice: 5000,
        quantity: 1,
        itemTotalPrice: 5000,
        options: [],
      },
    ],
    statusHistory: [
      {
        previousStatus: 'CREATED',
        currentStatus: 'PLACED',
        actorType: 'CUSTOMER',
        actorId: null,
        reason: null,
        changedAt: '2026-08-07T00:00:00Z',
      },
    ],
  }
}

function product(storeId: number, name: string): SellerProduct {
  return {
    productId: storeId,
    categoryId: storeId,
    categoryName: '메뉴',
    name,
    description: null,
    imageUrl: null,
    basePrice: 5000,
    status: 'ACTIVE',
    soldOut: false,
    availableForQr: true,
    salesStartAt: null,
    salesEndAt: null,
    qrWebEnabled: true,
    customerAppEnabled: true,
  }
}

describe('로그인 후 스토어 전환', () => {
  beforeEach(() => {
    window.localStorage.clear()
    window.sessionStorage.clear()
    window.sessionStorage.setItem(
      'popq:seller:connection',
      JSON.stringify({
        storeId: 1,
        storeName: '첫 번째 스토어',
        accessToken: 'seller-token',
        user: {
          userId: 10,
          email: 'seller@popq.test',
          name: '판매자',
          role: 'SELLER',
          status: 'ACTIVE',
        },
      }),
    )
    realtime.connect.mockReset()
    realtime.disconnect.mockReset()
    realtime.connect.mockReturnValue(realtime.disconnect)
  })

  afterEach(() => {
    cleanup()
    vi.restoreAllMocks()
  })

  it('계정 메뉴에서 스토어를 바꾸면 주문, STOMP, 상품 범위를 함께 교체한다', async () => {
    const stores = [
      {
        storeId: 1,
        storeType: 'LOCAL_STORE',
        name: '첫 번째 스토어',
        description: null,
        status: 'ACTIVE',
        businessStatus: 'OPEN',
        myRole: 'OWNER',
      },
      {
        storeId: 2,
        storeType: 'LOCAL_STORE',
        name: '두 번째 스토어',
        description: null,
        status: 'ACTIVE',
        businessStatus: 'PRE_OPEN',
        myRole: 'MANAGER',
      },
    ]
    const products = new Map([
      [1, [product(1, '첫 번째 스토어 상품')]],
      [2, [product(2, '두 번째 스토어 상품')]],
    ])
    vi.spyOn(window, 'fetch').mockImplementation(async (input) => {
      const path = String(input)
      let data: unknown = []
      if (path === '/api/v1/seller/stores') {
        data = stores
      } else {
        const storeId = Number(path.match(/stores\/(\d+)/)?.[1])
        if (path.endsWith('/orders')) data = [order(storeId, stores[storeId - 1].name)]
        if (path.endsWith('/payment')) {
          data = {
            orderPublicId: `order-store-${storeId}`,
            paymentStatus: 'PAID',
            paymentMethod: 'CARD',
            approvedAmount: 5000,
            refundedAmount: 0,
            refundableAmount: 5000,
            refunds: [],
          }
        }
        if (path.endsWith('/products')) data = products.get(storeId)
        if (path.endsWith('/categories')) {
          data = [{ categoryId: storeId, name: '메뉴', displayOrder: 1, status: 'ACTIVE' }]
        }
      }
      return new Response(JSON.stringify({ success: true, data }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      })
    })

    const user = userEvent.setup()
    render(<App />)

    expect(
      (await screen.findAllByText('첫 번째 스토어 주문 상품')).length,
    ).toBeGreaterThan(0)
    await user.click(screen.getByRole('button', { name: /상품 관리/ }))
    expect(await screen.findByText('첫 번째 스토어 상품')).toBeVisible()

    await user.click(screen.getByRole('button', { name: '계정 설정' }))
    expect(
      await screen.findByRole('button', { name: '첫 번째 스토어 현재 스토어' }),
    ).toBeDisabled()
    await user.click(
      screen.getByRole('button', { name: '두 번째 스토어로 전환' }),
    )

    expect(screen.queryByText('첫 번째 스토어 상품')).not.toBeInTheDocument()
    expect(await screen.findByText('두 번째 스토어 상품')).toBeVisible()
    await user.click(screen.getByRole('button', { name: /주문 운영/ }))
    expect(
      (await screen.findAllByText('두 번째 스토어 주문 상품')).length,
    ).toBeGreaterThan(0)
    expect(screen.queryAllByText('첫 번째 스토어 주문 상품')).toHaveLength(0)

    await waitFor(() => {
      expect(realtime.connect).toHaveBeenCalledTimes(2)
      expect(realtime.disconnect).toHaveBeenCalled()
    })
    expect(realtime.connect.mock.calls[0][0]).toMatchObject({ storeId: 1 })
    expect(realtime.connect.mock.calls[1][0]).toMatchObject({ storeId: 2 })
    expect(
      JSON.parse(window.sessionStorage.getItem('popq:seller:connection') ?? '{}'),
    ).toMatchObject({ storeId: 2, storeName: '두 번째 스토어' })
  })
})

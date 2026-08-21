import { cleanup, render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import App from './App'
import { createDemoOrder } from './data/demo'

vi.mock('./services/realtime', () => ({
  connectOrderRealtime: () => () => undefined,
}))

describe('POPQ QR order demo', () => {
  beforeEach(() => {
    window.localStorage.clear()
    window.sessionStorage.clear()
    window.history.replaceState({}, '', '/')
    vi.restoreAllMocks()
  })

  afterEach(() => {
    cleanup()
    vi.unstubAllGlobals()
  })

  it('adds a configured product and completes a demo payment', async () => {
    const user = userEvent.setup()
    render(<App />)

    expect(
      screen.getByRole('heading', { name: /빠르게 고르고/ }),
    ).toBeInTheDocument()

    await user.click(
      screen.getByRole('button', { name: /블랙 세서미 크림 라떼/ }),
    )
    expect(
      screen.getByRole('dialog', {
        name: /블랙 세서미 크림 라떼 옵션 선택/,
      }),
    ).toBeInTheDocument()

    await user.click(screen.getByRole('button', { name: /6,800원 담기/ }))
    await user.click(screen.getByRole('button', { name: /장바구니 보기/ }))
    expect(
      screen.getByRole('heading', { name: '장바구니' }),
    ).toBeInTheDocument()

    await user.click(screen.getByRole('button', { name: /결제하기/ }))
    await waitFor(() =>
      expect(
        screen.getByRole('heading', { name: '주문이 전달됐어요' }),
      ).toBeInTheDocument(),
    )
  })

  it('switches to dark mode and restores the preference', async () => {
    const user = userEvent.setup()
    const firstRender = render(<App />)

    await user.click(screen.getByRole('button', { name: '다크 모드로 전환' }))
    expect(document.documentElement).toHaveAttribute('data-theme', 'dark')
    expect(window.localStorage.getItem('popq.customer.web.theme.preference.v1')).toBe('dark')

    firstRender.unmount()
    render(<App />)

    expect(screen.getByRole('button', { name: '기본 모드로 전환' })).toHaveAttribute(
      'aria-pressed',
      'true',
    )
  })

  it('restores the cart after remounting', async () => {
    const user = userEvent.setup()
    const firstRender = render(<App />)

    await user.click(
      screen.getByRole('button', { name: /블랙 세서미 크림 라떼/ }),
    )
    await user.click(screen.getByRole('button', { name: /6,800원 담기/ }))
    firstRender.unmount()

    render(<App />)
    const cartButton = screen.getByRole('button', { name: '장바구니 1개' })
    expect(cartButton.querySelector('.cart-icon')).toBeInTheDocument()
    const cartCount = cartButton.querySelector('.cart-count')
    expect(cartCount).toHaveTextContent('1')
  })

  it('restores and cancels a placed demo order', async () => {
    const user = userEvent.setup()
    const firstRender = render(<App />)

    await user.click(
      screen.getByRole('button', { name: /블랙 세서미 크림 라떼/ }),
    )
    await user.click(screen.getByRole('button', { name: /6,800원 담기/ }))
    await user.click(screen.getByRole('button', { name: /장바구니 보기/ }))
    await user.click(screen.getByRole('button', { name: /결제하기/ }))
    await screen.findByRole('heading', { name: '주문이 전달됐어요' })
    firstRender.unmount()

    render(<App />)
    expect(
      screen.getByRole('heading', { name: '주문이 전달됐어요' }),
    ).toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: '주문 취소' }))
    expect(
      screen.getByRole('heading', { name: '주문이 취소됐어요' }),
    ).toBeInTheDocument()
    expect(
      screen.getByRole('button', { name: '새 주문 시작하기' }),
    ).toBeInTheDocument()
  })

  it('opens the QR menu first and exposes a stored active order as a shortcut', async () => {
    const user = userEvent.setup()
    const activeOrder = {
      ...createDemoOrder(6800, 'DINE_IN'),
      orderPublicId: 'order-active-1234',
      status: 'PREPARING' as const,
      version: 3,
    }
    window.localStorage.setItem(
      'popq:order:qr-token',
      JSON.stringify(activeOrder),
    )
    window.history.replaceState({}, '', '/q/qr-token')
    vi.stubGlobal(
      'fetch',
      vi.fn(async (path: string) => {
        if (path.endsWith('/sessions')) {
          return response({
            storeId: 1,
            storeName: '성수 커피 연구소',
            storeType: 'LOCAL_STORE',
            businessStatus: 'OPEN',
            storeTableId: 10,
            tableName: '테이블 10',
            sessionExpiresAt: '2026-08-10T12:00:00Z',
          })
        }
        if (path === '/api/v1/qr/products') return response([])
        if (path.includes('/sync')) {
          return response({
            refreshRequired: false,
            serverVersion: activeOrder.version,
            order: null,
          })
        }
        throw new Error(`Unexpected request: ${path}`)
      }),
    )

    render(<App />)

    expect(
      await screen.findByRole('heading', { name: /빠르게 고르고/ }),
    ).toBeInTheDocument()
    expect(
      screen.queryByRole('heading', { name: '주문을 준비 중이에요' }),
    ).not.toBeInTheDocument()
    expect(screen.getByRole('region', { name: '진행 중 주문' })).toHaveTextContent(
      '주문을 준비 중이에요',
    )

    await user.click(screen.getByRole('button', { name: /주문 현황 보기/ }))

    expect(
      screen.getByRole('heading', { name: '주문을 준비 중이에요' }),
    ).toBeInTheDocument()
  })

  it('clears a stored order that the current QR session cannot access', async () => {
    const staleOrder = {
      ...createDemoOrder(6800, 'DINE_IN'),
      orderPublicId: 'order-stale-session',
      status: 'PLACED' as const,
      version: 1,
    }
    window.localStorage.setItem(
      'popq:order:qr-token',
      JSON.stringify(staleOrder),
    )
    window.history.replaceState({}, '', '/q/qr-token')
    vi.stubGlobal(
      'fetch',
      vi.fn(async (path: string) => {
        if (path.endsWith('/sessions')) {
          return response({
            storeId: 1,
            storeName: '성수 커피 연구소',
            storeType: 'LOCAL_STORE',
            businessStatus: 'OPEN',
            storeTableId: 10,
            tableName: '테이블 10',
            sessionExpiresAt: '2026-08-10T12:00:00Z',
          })
        }
        if (path === '/api/v1/qr/products') return response([])
        if (path.includes('/sync')) {
          return errorResponse(403, '주문 조회 권한이 없습니다.')
        }
        throw new Error(`Unexpected request: ${path}`)
      }),
    )

    render(<App />)

    expect(
      await screen.findByRole('heading', { name: /빠르게 고르고/ }),
    ).toBeInTheDocument()
    expect(
      screen.queryByRole('region', { name: '진행 중 주문' }),
    ).not.toBeInTheDocument()
    await waitFor(() =>
      expect(window.localStorage.getItem('popq:order:qr-token')).toBeNull(),
    )
  })

  it('clears a terminal order when the QR menu is opened again', async () => {
    const completedOrder = {
      ...createDemoOrder(6800, 'DINE_IN'),
      orderPublicId: 'order-completed-1234',
      status: 'COMPLETED' as const,
      version: 5,
    }
    window.localStorage.setItem(
      'popq:order:qr-token',
      JSON.stringify(completedOrder),
    )
    window.history.replaceState({}, '', '/q/qr-token')
    vi.stubGlobal(
      'fetch',
      vi.fn(async (path: string) => {
        if (path.endsWith('/sessions')) {
          return response({
            storeId: 1,
            storeName: '성수 커피 연구소',
            storeType: 'LOCAL_STORE',
            businessStatus: 'OPEN',
            storeTableId: 10,
            tableName: '테이블 10',
            sessionExpiresAt: '2026-08-10T12:00:00Z',
          })
        }
        if (path === '/api/v1/qr/products') return response([])
        throw new Error(`Unexpected request: ${path}`)
      }),
    )

    render(<App />)

    expect(
      await screen.findByRole('heading', { name: /빠르게 고르고/ }),
    ).toBeInTheDocument()
    expect(
      screen.queryByRole('region', { name: '진행 중 주문' }),
    ).not.toBeInTheDocument()
    await waitFor(() =>
      expect(window.localStorage.getItem('popq:order:qr-token')).toBeNull(),
    )
  })

  it('filters categories and prevents selecting a sold-out product', async () => {
    const user = userEvent.setup()
    render(<App />)

    await user.click(screen.getByRole('button', { name: '디저트' }))
    expect(
      screen.getByRole('button', { name: /솔티드 카라멜 휘낭시에/ }),
    ).toBeInTheDocument()
    expect(
      screen.getByRole('button', { name: /피스타치오 티라미수/ }),
    ).toBeDisabled()
    expect(
      screen.queryByRole('button', { name: /성수 블렌드 아메리카노/ }),
    ).not.toBeInTheDocument()
  })

  it('confirms a Toss return with the stored guest order', async () => {
    const created = {
      ...createDemoOrder(5000, 'TAKEOUT'),
      orderPublicId: 'order-123456',
      status: 'CREATED' as const,
      version: 0,
    }
    const placed = {
      ...created,
      status: 'PLACED' as const,
      version: 1,
    }
    window.sessionStorage.setItem(
      'popq:checkout:qr-token',
      JSON.stringify({
        orderKey: 'order-idempotency-key',
        paymentKey: 'payment-idempotency-key',
        order: created,
      }),
    )
    window.history.replaceState(
      {},
      '',
      '/q/qr-token?payment=success&paymentKey=toss-payment-key'
        + '&orderId=order-123456&amount=5000',
    )
    const fetchMock = vi.fn(async (path: string, init?: RequestInit) => {
      if (path.endsWith('/sessions')) {
        return response({
          storeId: 1,
          storeName: '성수 커피 연구소',
          storeType: 'LOCAL_STORE',
          businessStatus: 'OPEN',
          storeTableId: null,
          tableName: null,
          sessionExpiresAt: '2026-08-05T12:00:00Z',
        })
      }
      if (path === '/api/v1/qr/products') return response([])
      if (path.includes('/payments')) {
        expect(JSON.parse(init?.body as string)).toMatchObject({
          idempotencyKey: 'payment-idempotency-key',
          paymentKey: 'toss-payment-key',
        })
        return response({ status: 'PAID' })
      }
      if (path.includes('/sync')) {
        return response({
          refreshRequired: true,
          serverVersion: 1,
          order: placed,
        })
      }
      throw new Error(`Unexpected request: ${path}`)
    })
    vi.stubGlobal('fetch', fetchMock)

    render(<App />)

    expect(
      await screen.findByRole('heading', { name: '주문이 전달됐어요' }),
    ).toBeInTheDocument()
    expect(window.location.pathname).toBe('/q/qr-token')
    expect(window.location.search).toBe('')
    expect(window.sessionStorage.getItem('popq:checkout:qr-token')).toBeNull()
  })

  it('moves to order tracking when sync fails after payment approval', async () => {
    const created = {
      ...createDemoOrder(5000, 'TAKEOUT'),
      orderPublicId: 'order-sync-failure',
      status: 'CREATED' as const,
      version: 0,
    }
    window.sessionStorage.setItem(
      'popq:checkout:qr-token',
      JSON.stringify({
        orderKey: 'order-idempotency-key',
        paymentKey: 'payment-idempotency-key',
        order: created,
      }),
    )
    window.history.replaceState(
      {},
      '',
      '/q/qr-token?payment=success&paymentKey=toss-payment-key'
        + '&orderId=order-sync-failure&amount=5000',
    )
    const fetchMock = vi.fn(async (path: string) => {
      if (path.endsWith('/sessions')) {
        return response({
          storeId: 1,
          storeName: '성수 커피 연구소',
          storeType: 'LOCAL_STORE',
          businessStatus: 'OPEN',
          storeTableId: null,
          tableName: null,
          sessionExpiresAt: '2026-08-05T12:00:00Z',
        })
      }
      if (path === '/api/v1/qr/products') return response([])
      if (path.includes('/payments')) return response({ status: 'PAID' })
      if (path.includes('/sync')) {
        throw new TypeError('네트워크 연결 실패')
      }
      throw new Error(`Unexpected request: ${path}`)
    })
    vi.stubGlobal('fetch', fetchMock)

    render(<App />)

    expect(
      await screen.findByRole('heading', { name: '주문이 전달됐어요' }),
    ).toBeInTheDocument()
    expect(screen.queryByText(/주문 조회 권한이 없습니다/)).not.toBeInTheDocument()
    expect(window.location.search).toBe('')
    expect(window.sessionStorage.getItem('popq:checkout:qr-token')).toBeNull()
  })

  it('clears a paid order when the current QR session has no access', async () => {
    const created = {
      ...createDemoOrder(5000, 'TAKEOUT'),
      orderPublicId: 'order-session-mismatch',
      status: 'CREATED' as const,
      version: 0,
    }
    window.sessionStorage.setItem(
      'popq:checkout:qr-token',
      JSON.stringify({
        orderKey: 'order-idempotency-key',
        paymentKey: 'payment-idempotency-key',
        order: created,
      }),
    )
    window.history.replaceState(
      {},
      '',
      '/q/qr-token?payment=success&paymentKey=toss-payment-key'
        + '&orderId=order-session-mismatch&amount=5000',
    )
    vi.stubGlobal(
      'fetch',
      vi.fn(async (path: string) => {
        if (path.endsWith('/sessions')) {
          return response({
            storeId: 1,
            storeName: '성수 커피 연구소',
            storeType: 'LOCAL_STORE',
            businessStatus: 'OPEN',
            storeTableId: null,
            tableName: null,
            sessionExpiresAt: '2026-08-05T12:00:00Z',
          })
        }
        if (path === '/api/v1/qr/products') return response([])
        if (path.includes('/payments')) return response({ status: 'PAID' })
        if (path.includes('/sync')) {
          return errorResponse(403, '주문 조회 권한이 없습니다.')
        }
        throw new Error(`Unexpected request: ${path}`)
      }),
    )

    render(<App />)

    expect(
      await screen.findByRole('heading', { name: /빠르게 고르고/ }),
    ).toBeInTheDocument()
    expect(screen.getByRole('alert')).toHaveTextContent(
      '이전 QR 세션의 주문 정보가 정리되었습니다.',
    )
    expect(window.location.search).toBe('')
    expect(window.localStorage.getItem('popq:order:qr-token')).toBeNull()
  })

  it('blocks duplicate checkout and offers confirmation retry after a return error', async () => {
    const user = userEvent.setup()
    const created = {
      ...createDemoOrder(5000, 'TAKEOUT'),
      orderPublicId: 'order-confirmation-retry',
      status: 'CREATED' as const,
      version: 0,
    }
    window.sessionStorage.setItem(
      'popq:checkout:qr-token',
      JSON.stringify({
        orderKey: 'order-idempotency-key',
        paymentKey: 'payment-idempotency-key',
        order: created,
      }),
    )
    window.history.replaceState(
      {},
      '',
      '/q/qr-token?payment=success&paymentKey=toss-payment-key'
        + '&orderId=order-confirmation-retry&amount=5000',
    )
    let confirmationAttempts = 0
    const fetchMock = vi.fn(async (path: string) => {
      if (path.endsWith('/sessions')) {
        return response({
          storeId: 1,
          storeName: '성수 커피 연구소',
          storeType: 'LOCAL_STORE',
          businessStatus: 'OPEN',
          storeTableId: null,
          tableName: null,
          sessionExpiresAt: '2026-08-05T12:00:00Z',
        })
      }
      if (path === '/api/v1/qr/products') return response([])
      if (path.includes('/payments')) {
        confirmationAttempts += 1
        return errorResponse(403, '주문 조회 권한이 없습니다.')
      }
      throw new Error(`Unexpected request: ${path}`)
    })
    vi.stubGlobal('fetch', fetchMock)

    render(<App />)

    expect(
      await screen.findByRole('heading', { name: '결제 결과 확인이 필요해요' }),
    ).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: /결제하기/ })).not.toBeInTheDocument()

    await user.click(screen.getByRole('button', { name: '결제 결과 다시 확인하기' }))
    await waitFor(() => expect(confirmationAttempts).toBe(2))
  })
})

function response(data: unknown) {
  return {
    ok: true,
    json: async () => ({ success: true, data, error: null }),
  }
}

function errorResponse(status: number, message: string) {
  return {
    ok: false,
    status,
    json: async () => ({
      success: false,
      data: null,
      error: { code: 'ORDER_ACCESS_DENIED', message },
    }),
  }
}

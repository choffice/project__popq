import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, render, screen } from '@testing-library/react'
import { SalesAnalytics } from './SalesAnalytics'

describe('매출 분석', () => {
  afterEach(() => {
    cleanup()
    vi.restoreAllMocks()
  })

  it('상세 내역 필드가 없는 이전 API 응답도 빈 내역으로 표시한다', async () => {
    vi.spyOn(window, 'fetch').mockResolvedValue(
      new Response(
        JSON.stringify({
          success: true,
          data: {
            from: '2026-08-04',
            to: '2026-08-10',
            grossSales: 120000,
            netSales: 117000,
            refundedAmount: 3000,
            refundCount: 1,
            canceledOrderCount: 0,
            canceledAmount: 0,
            completedOrderCount: 10,
            averageOrderAmount: 12000,
            dineInSales: 70000,
            takeoutSales: 47000,
            dailySales: [
              { date: '2026-08-10', sales: 117000, orderCount: 10 },
            ],
            topProducts: [],
          },
        }),
        { status: 200, headers: { 'Content-Type': 'application/json' } },
      ),
    )

    render(
      <SalesAnalytics
        connection={{ storeId: 7, accessToken: 'seller-token' }}
        onError={vi.fn()}
      />,
    )

    expect(await screen.findByText('선택한 기간에 완료된 주문이 없습니다.')).toBeVisible()
    expect(screen.getByRole('tab', { name: '주문 내역 0' })).toBeVisible()
    expect(screen.getByRole('tab', { name: '환불 내역 0' })).toBeVisible()
    expect(screen.getByRole('tab', { name: '취소·거절 0' })).toBeVisible()
  })
})

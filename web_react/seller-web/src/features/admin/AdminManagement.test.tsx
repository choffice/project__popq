import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { AdminManagement } from './AdminManagement'

describe('기본 관리자 운영', () => {
  afterEach(() => {
    cleanup()
  })

  it('사용자 상태를 정지하고 다시 활성화한다', async () => {
    const user = userEvent.setup()
    render(<AdminManagement connection={null} onError={vi.fn()} />)

    expect(
      screen.getByRole('heading', { name: '플랫폼 운영 현황' }),
    ).toBeVisible()
    const sellerRow = screen
      .getByText('seller@seongsu.test')
      .closest('article')
    expect(sellerRow).not.toBeNull()
    await user.click(
      within(sellerRow!).getByRole('button', { name: '이용 정지' }),
    )

    expect(within(sellerRow!).getByText('정지')).toBeVisible()
    await user.click(
      within(sellerRow!).getByRole('button', { name: '활성화' }),
    )
    expect(within(sellerRow!).getByText('활성')).toBeVisible()
  })

  it('판매자 인증과 스토어 운영 상태를 변경한다', async () => {
    const user = userEvent.setup()
    render(<AdminManagement connection={null} onError={vi.fn()} />)

    await user.click(screen.getByRole('tab', { name: '판매자 인증' }))
    expect(screen.getByText('여름 마켓')).toBeVisible()
    await user.click(screen.getAllByRole('button', { name: '승인' })[1])
    expect(screen.getAllByText('인증').length).toBeGreaterThan(1)

    await user.click(screen.getByRole('tab', { name: '스토어' }))
    await user.click(screen.getByRole('button', { name: '재활성화' }))
    expect(screen.getByText('서울 여름 마켓')).toBeVisible()
    expect(screen.queryByRole('button', { name: '재활성화' })).not.toBeInTheDocument()
  })
})

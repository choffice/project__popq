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
      screen.getByRole('heading', { name: '구매자 회원 관리' }),
    ).toBeVisible()
    const customerRow = (await screen
      .findByText('guest@example.com'))
      .closest('article')
    expect(customerRow).not.toBeNull()
    await user.click(
      within(customerRow!).getByRole('button', { name: '활성화' }),
    )
    let dialog = screen.getByRole('dialog')
    await user.type(within(dialog).getByLabelText('변경 사유'), '테스트 상태 변경')
    await user.click(within(dialog).getByRole('button', { name: '활성화' }))

    expect(await within(customerRow!).findByText('활성')).toBeVisible()
    await user.click(
      within(customerRow!).getByRole('button', { name: '이용 정지' }),
    )
    dialog = screen.getByRole('dialog')
    await user.type(within(dialog).getByLabelText('변경 사유'), '테스트 상태 변경')
    await user.click(within(dialog).getByRole('button', { name: '이용 정지' }))
    expect(await within(customerRow!).findByText('이용정지')).toBeVisible()
  })

  it('판매자 인증과 스토어 운영 상태를 변경한다', async () => {
    const user = userEvent.setup()
    const { rerender } = render(
      <AdminManagement connection={null} section="sellers" onError={vi.fn()} />,
    )

    expect(await screen.findByText('여름 마켓')).toBeVisible()
    await user.click(screen.getAllByRole('button', { name: '승인' })[1])
    let dialog = screen.getByRole('dialog')
    await user.type(within(dialog).getByLabelText('변경 사유'), '테스트 상태 변경')
    await user.click(within(dialog).getByRole('button', { name: '승인' }))
    expect(screen.getAllByText('인증').length).toBeGreaterThan(1)

    rerender(
      <AdminManagement connection={null} section="stores" onError={vi.fn()} />,
    )
    const storeRow = (await screen.findByText('서울 여름 마켓')).closest('article')
    expect(storeRow).not.toBeNull()
    await user.click(within(storeRow!).getByRole('button', { name: '재활성화' }))
    dialog = screen.getByRole('dialog')
    await user.type(within(dialog).getByLabelText('변경 사유'), '테스트 상태 변경')
    await user.click(within(dialog).getByRole('button', { name: '재활성화' }))
    expect(screen.getByText('서울 여름 마켓')).toBeVisible()
    expect(within(storeRow!).queryByRole('button', { name: '재활성화' })).not.toBeInTheDocument()
  })
})

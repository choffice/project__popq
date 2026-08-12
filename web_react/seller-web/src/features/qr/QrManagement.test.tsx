import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { QrManagement } from './QrManagement'

function jsonResponse(data: unknown) {
  return new Response(JSON.stringify({ success: true, data }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  })
}

describe('QR 관리', () => {
  afterEach(() => {
    cleanup()
    vi.restoreAllMocks()
  })

  it('테이블이 없으면 QR 발급 화면에서 테이블을 추가하고 계속한다', async () => {
    const fetchMock = vi.spyOn(window, 'fetch').mockImplementation(
      async (input, init) => {
        const path = String(input)
        if (path.endsWith('/qr-codes?includeArchived=true')) {
          return jsonResponse([])
        }
        if (path.endsWith('/tables') && init?.method === 'POST') {
          return jsonResponse({
            storeTableId: 41,
            tableCode: 'TABLE-01',
            name: '테이블 1',
            status: 'ACTIVE',
          })
        }
        if (path.endsWith('/tables')) {
          return jsonResponse([])
        }
        throw new Error(`예상하지 않은 요청: ${path}`)
      },
    )
    const user = userEvent.setup()

    render(
      <QrManagement
        connection={{ storeId: 7, accessToken: 'seller-token' }}
        storeRole="OWNER"
        onError={vi.fn()}
      />,
    )

    expect(await screen.findByText('현재 관리 중인 QR이 없습니다.')).toBeVisible()
    await user.click(screen.getByRole('button', { name: /새 QR 발급/ }))
    const dialog = screen.getByRole('dialog', { name: '새 QR 발급' })

    expect(within(dialog).getByText('먼저 테이블을 추가해 주세요')).toBeVisible()
    await user.click(within(dialog).getByRole('button', { name: /테이블 추가/ }))
    await user.type(within(dialog).getByLabelText('테이블 코드'), 'table-01')
    await user.type(within(dialog).getByLabelText('표시 이름'), '테이블 1')
    await user.click(
      within(dialog).getByRole('button', {
        name: '추가하고 QR 발급 계속하기',
      }),
    )

    expect(
      await within(dialog).findByText(
        '테이블 1 테이블이 추가되어 연결 테이블로 선택되었습니다.',
      ),
    ).toBeVisible()
    expect(within(dialog).getByRole('combobox', { name: '연결 테이블' })).toHaveValue('41')
    expect(within(dialog).getByRole('button', { name: 'QR 발급하기' })).toBeEnabled()
    expect(fetchMock).toHaveBeenCalledWith(
      '/api/v1/seller/stores/7/tables',
      expect.objectContaining({
        method: 'POST',
        body: JSON.stringify({ tableCode: 'TABLE-01', name: '테이블 1' }),
      }),
    )
  })
})

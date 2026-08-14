import { cleanup, render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { SupportManagement } from './SupportManagement'

const apiMocks = vi.hoisted(() => ({
  changeAdminSupportInquiryStatus: vi.fn(),
  getAdminSupportInquiries: vi.fn(),
  getAdminSupportInquiry: vi.fn(),
  sendAdminSupportAnswer: vi.fn(),
}))

vi.mock('../../services/api', () => apiMocks)

const connection = { storeId: null, accessToken: 'admin-token' }
const inquiry = {
  supportInquiryId: 3,
  customerUserId: 11,
  customerName: '문의 고객',
  customerEmail: 'customer@example.com',
  category: 'APP' as const,
  title: '앱 이용 문의',
  status: 'RECEIVED' as const,
  unreadMessageCount: 1,
  answeredAt: null,
  closedAt: null,
  createdAt: '2026-08-13T00:00:00Z',
  updatedAt: '2026-08-13T00:00:00Z',
}
const detail = {
  inquiry,
  messages: [{
    supportInquiryMessageId: 31,
    senderUserId: 11,
    senderName: '문의 고객',
    senderType: 'CUSTOMER' as const,
    content: '문의 내용입니다.',
    read: false,
    readAt: null,
    createdAt: '2026-08-13T00:00:00Z',
  }],
}

describe('구매자 앱 문의 관리', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    apiMocks.getAdminSupportInquiries.mockResolvedValue([inquiry])
    apiMocks.getAdminSupportInquiry.mockResolvedValue(detail)
    apiMocks.sendAdminSupportAnswer.mockResolvedValue({
      inquiry: { ...inquiry, status: 'ANSWERED' },
      messages: [...detail.messages, { ...detail.messages[0], supportInquiryMessageId: 32, senderType: 'ADMIN', content: '관리자 답변' }],
    })
    apiMocks.changeAdminSupportInquiryStatus.mockResolvedValue({ ...inquiry, status: 'CLOSED' })
  })

  afterEach(cleanup)

  it('구매자 문의를 조회하고 답변과 상태 변경을 처리한다', async () => {
    const user = userEvent.setup()
    render(<SupportManagement connection={connection} onError={vi.fn()} onUnreadChange={vi.fn()} />)

    expect(await screen.findByText('문의 내용입니다.')).toBeInTheDocument()
    await user.type(screen.getByPlaceholderText('고객에게 전달할 답변을 입력하세요.'), ' 관리자 답변 ')
    await user.click(screen.getByRole('button', { name: '답변 등록' }))

    await waitFor(() => expect(apiMocks.sendAdminSupportAnswer).toHaveBeenCalledWith(connection, 3, ' 관리자 답변 '))
    await user.selectOptions(screen.getByLabelText('문의 처리 상태'), 'CLOSED')
    await waitFor(() => expect(apiMocks.changeAdminSupportInquiryStatus).toHaveBeenCalledWith(connection, 3, 'CLOSED'))
  })
})

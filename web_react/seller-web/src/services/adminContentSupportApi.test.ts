import { afterEach, describe, expect, it, vi } from 'vitest'
import {
  changeAdminSupportInquiryStatus,
  getAdminSupportInquiries,
  getAdminSupportTickets,
  replyAdminSupportTicket,
  saveAdminPlatformAnnouncement,
  sendAdminSupportAnswer,
} from './api'

const connection = { storeId: null, accessToken: 'admin-token' }

describe('관리자 공지·문의 API 계약', () => {
  afterEach(() => vi.restoreAllMocks())

  it('플랫폼 공지 작성 요청에서 서버 DTO 필드만 전송한다', async () => {
    const fetchMock = vi.spyOn(window, 'fetch').mockResolvedValue(response({ platformAnnouncementId: 9 }))
    await saveAdminPlatformAnnouncement(connection, {
      audience: 'ALL',
      title: '점검 안내',
      content: '점검 내용',
      publishStartAt: null,
      publishEndAt: null,
    })

    expect(fetchMock).toHaveBeenCalledWith(
      '/api/v1/admin/content/announcements',
      expect.objectContaining({
        method: 'POST',
        body: JSON.stringify({
          audience: 'ALL', title: '점검 안내', content: '점검 내용', publishStartAt: null, publishEndAt: null,
        }),
      }),
    )
  })

  it('구매자 기존 문의와 통합 문의를 각각 올바른 API로 처리한다', async () => {
    const fetchMock = vi.spyOn(window, 'fetch').mockImplementation(async () => response({ content: [] }))

    await getAdminSupportInquiries(connection, 'RECEIVED')
    await sendAdminSupportAnswer(connection, 3, ' 답변입니다. ')
    await changeAdminSupportInquiryStatus(connection, 3, 'ANSWERED')
    await getAdminSupportTickets(connection, { page: 0, size: 20, requesterType: 'SELLER' })
    await replyAdminSupportTicket(connection, 7, '판매자 답변')

    expect(fetchMock).toHaveBeenNthCalledWith(1, '/api/v1/admin/support/inquiries?status=RECEIVED', expect.any(Object))
    expect(fetchMock).toHaveBeenNthCalledWith(2, '/api/v1/admin/support/inquiries/3/messages', expect.objectContaining({ method: 'POST', body: JSON.stringify({ content: '답변입니다.' }) }))
    expect(fetchMock).toHaveBeenNthCalledWith(3, '/api/v1/admin/support/inquiries/3/status', expect.objectContaining({ method: 'PATCH', body: JSON.stringify({ status: 'ANSWERED' }) }))
    expect(fetchMock).toHaveBeenNthCalledWith(4, '/api/v1/admin/support/tickets?page=0&size=20&requesterType=SELLER', expect.any(Object))
    expect(fetchMock).toHaveBeenNthCalledWith(5, '/api/v1/admin/support/tickets/7/messages', expect.objectContaining({ method: 'POST', body: JSON.stringify({ content: '판매자 답변' }) }))
  })
})

function response(data: unknown) {
  return new Response(JSON.stringify({ success: true, data }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  })
}

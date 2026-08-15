import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { AdminContentManagement } from './AdminContentManagement'

const apiMocks = vi.hoisted(() => ({
  getAdminFaqs: vi.fn(),
  getAdminPlatformAnnouncements: vi.fn(),
  saveAdminFaq: vi.fn(),
  saveAdminPlatformAnnouncement: vi.fn(),
  updateAdminFaqStatus: vi.fn(),
  updateAdminPlatformAnnouncementStatus: vi.fn(),
}))

vi.mock('../../services/api', () => apiMocks)

const connection = { storeId: null, accessToken: 'admin-token' }
const emptyPage = {
  content: [], page: 0, size: 20, totalElements: 0, totalPages: 0, first: true, last: true,
}

describe('관리자 플랫폼 공지 작성', () => {
  afterEach(cleanup)

  beforeEach(() => {
    vi.clearAllMocks()
    apiMocks.getAdminPlatformAnnouncements.mockResolvedValue(emptyPage)
    apiMocks.getAdminFaqs.mockResolvedValue(emptyPage)
    apiMocks.saveAdminPlatformAnnouncement.mockResolvedValue({ platformAnnouncementId: 31 })
  })

  it('입력한 공지를 API로 저장하고 성공 상태를 안내한다', async () => {
    const user = userEvent.setup()
    render(<AdminContentManagement connection={connection} kind="announcements" onError={vi.fn()} />)

    await screen.findByText('등록된 콘텐츠가 없습니다.')
    await user.click(screen.getByRole('button', { name: '+ 새 공지' }))
    fireEvent.change(screen.getByLabelText('제목'), { target: { value: '서비스 점검 안내' } })
    fireEvent.change(screen.getByLabelText('내용'), { target: { value: '새벽 시간에 점검합니다.' } })
    fireEvent.change(screen.getByLabelText('게시 시작'), { target: { value: '2026-08-13T09:00' } })
    fireEvent.change(screen.getByLabelText('게시 종료'), { target: { value: '2026-08-13T10:00' } })
    await user.click(screen.getByRole('button', { name: '저장' }))

    await waitFor(() => expect(apiMocks.saveAdminPlatformAnnouncement).toHaveBeenCalledTimes(1))
    expect(apiMocks.saveAdminPlatformAnnouncement).toHaveBeenCalledWith(
      connection,
      expect.objectContaining({
        audience: 'ALL',
        title: '서비스 점검 안내',
        content: '새벽 시간에 점검합니다.',
        publishStartAt: new Date('2026-08-13T09:00').toISOString(),
        publishEndAt: new Date('2026-08-13T10:00').toISOString(),
      }),
    )
    expect(await screen.findByRole('status')).toHaveTextContent('공지가 초안으로 저장되었습니다.')
  })

  it('종료 시각이 시작 시각보다 빠르면 모달 안에서 오류를 보여준다', async () => {
    const user = userEvent.setup()
    render(<AdminContentManagement connection={connection} kind="announcements" onError={vi.fn()} />)

    await screen.findByText('등록된 콘텐츠가 없습니다.')
    await user.click(screen.getByRole('button', { name: '+ 새 공지' }))
    fireEvent.change(screen.getByLabelText('제목'), { target: { value: '기간 오류 확인' } })
    fireEvent.change(screen.getByLabelText('내용'), { target: { value: '기간을 확인합니다.' } })
    fireEvent.change(screen.getByLabelText('게시 시작'), { target: { value: '2026-08-13T10:00' } })
    fireEvent.change(screen.getByLabelText('게시 종료'), { target: { value: '2026-08-13T09:00' } })
    await user.click(screen.getByRole('button', { name: '저장' }))

    expect(await screen.findByRole('alert')).toHaveTextContent('게시 종료 시각은 시작 시각보다 뒤여야 합니다.')
    expect(apiMocks.saveAdminPlatformAnnouncement).not.toHaveBeenCalled()
  })
})

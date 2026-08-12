import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { cleanup, render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import App from './App'

vi.mock('qrcode', () => ({
  default: {
    toDataURL: vi.fn().mockResolvedValue('data:image/png;base64,demo'),
  },
}))

describe('판매자 주문 운영', () => {
  beforeEach(() => {
    window.localStorage.clear()
    window.sessionStorage.clear()
    window.sessionStorage.setItem('popq:seller:demo', 'true')
  })

  afterEach(() => {
    cleanup()
    vi.restoreAllMocks()
  })

  it('진행 주문을 상태별 보드와 운영 지표로 보여준다', () => {
    render(<App />)

    expect(screen.getByRole('heading', { name: '주문 보드' })).toBeVisible()
    expect(screen.getByText('진행 주문')).toBeVisible()
    expect(screen.getByText('신규 접수')).toBeVisible()
    expect(screen.getByRole('button', { name: '주문 0042 상세 보기' })).toBeVisible()
    expect(screen.getByRole('button', { name: '주문 0038 상세 보기' })).toBeVisible()
  })

  it('신규 주문을 접수하고 다음 처리 단계까지 이어간다', async () => {
    const user = userEvent.setup()
    render(<App />)

    await user.click(screen.getByRole('button', { name: '주문 접수' }))
    const dialog = screen.getByRole('dialog', { name: '준비시간 선택' })
    await user.click(within(dialog).getByRole('radio', { name: '15분' }))
    await user.click(within(dialog).getByRole('button', { name: '주문 접수' }))

    expect(screen.getByText('접수 완료')).toBeVisible()
    expect(
      screen.getByRole('button', { name: '준비 시작' }),
    ).toBeVisible()
  })

  it('주문 거절 사유를 입력한 뒤 주문을 거절한다', async () => {
    const user = userEvent.setup()
    render(<App />)

    await user.click(screen.getByRole('button', { name: '주문 거절' }))
    const dialog = screen.getByRole('dialog', { name: '주문 거절 사유' })
    const confirm = within(dialog).getByRole('button', { name: '주문 거절 확정' })
    expect(confirm).toBeDisabled()
    await user.type(within(dialog).getByLabelText('고객 안내 사유'), '재료가 모두 소진되었습니다.')
    await user.click(confirm)

    expect(screen.getAllByText('주문 거절').length).toBeGreaterThan(0)
    expect(screen.getByText('재료가 모두 소진되었습니다.')).toBeVisible()
  })

  it('완료 필터에서 종료된 주문만 조회한다', async () => {
    const user = userEvent.setup()
    render(<App />)

    await user.click(screen.getByRole('button', { name: '완료' }))

    expect(screen.getByRole('button', { name: '주문 0037 상세 보기' })).toBeVisible()
    expect(
      screen.queryByRole('button', { name: '주문 0042 상세 보기' }),
    ).not.toBeInTheDocument()
  })

  it('완료 주문의 결제 정보를 확인하고 전액 환불한다', async () => {
    const user = userEvent.setup()
    render(<App />)

    await user.click(screen.getByRole('button', { name: '완료' }))
    await user.click(
      screen.getByRole('button', { name: '주문 0037 상세 보기' }),
    )
    await user.click(
      await screen.findByRole('button', { name: '전액 환불' }),
    )
    await user.type(screen.getByLabelText('환불 사유'), '고객 요청 환불')
    await user.click(
      screen.getByRole('button', { name: '전액 환불 확정' }),
    )

    expect(await screen.findByText('환불 완료')).toBeVisible()
    expect(screen.getByText('고객 요청 환불')).toBeVisible()
  })

  it('계정 설정에서 데모 세션을 종료할 수 있다', async () => {
    const user = userEvent.setup()
    render(<App />)

    await user.click(screen.getByRole('button', { name: '계정 설정' }))

    expect(screen.getByRole('dialog', { name: '판매자 계정' })).toBeVisible()
    expect(
      screen.getByRole('button', { name: '로그인 화면으로 이동' }),
    ).toBeVisible()
  })

  it('상품의 품절과 QR 판매 상태를 즉시 변경한다', async () => {
    const user = userEvent.setup()
    render(<App />)

    await user.click(screen.getByRole('button', { name: /상품 관리/ }))
    expect(
      screen.getByRole('heading', { name: '상품 판매 상태' }),
    ).toBeVisible()

    const soldOutSwitch = screen.getByRole('switch', {
      name: '블랙 세서미 크림 라떼 품절 설정',
    })
    expect(soldOutSwitch).toHaveAttribute('aria-checked', 'true')
    await user.click(soldOutSwitch)
    expect(soldOutSwitch).toHaveAttribute('aria-checked', 'false')

    const qrSwitch = screen.getByRole('switch', {
      name: '블랙 세서미 크림 라떼 QR 판매 설정',
    })
    await user.click(qrSwitch)
    expect(qrSwitch).toHaveAttribute('aria-checked', 'false')
  })

  it('테이블용 주문 QR을 발급하고 이미지 저장을 제공한다', async () => {
    const user = userEvent.setup()
    render(<App />)

    await user.click(screen.getByRole('button', { name: /QR 관리/ }))
    await user.click(screen.getByRole('button', { name: /새 QR 발급/ }))
    expect(screen.getByRole('dialog', { name: '새 QR 발급' })).toBeVisible()

    await user.click(screen.getByRole('button', { name: 'QR 발급하기' }))

    expect(
      await screen.findByRole('dialog', { name: 'QR 발급 완료' }),
    ).toBeVisible()
    expect(
      screen.getByRole('link', { name: 'QR 이미지 저장' }),
    ).toHaveAttribute('download')
  })

  it('기존 QR을 보관함에서 다시 확인하고 저장할 수 있다', async () => {
    const user = userEvent.setup()
    render(<App />)

    await user.click(screen.getByRole('button', { name: /QR 관리/ }))
    await user.click(screen.getAllByRole('button', { name: 'QR 보기' })[0])

    expect(
      await screen.findByRole('dialog', { name: 'QR 보관함' }),
    ).toBeVisible()
    expect(
      screen.getByRole('link', { name: 'QR 이미지 저장' }),
    ).toHaveAttribute('download', 'popq-qr-71.png')
    expect(screen.getByRole('button', { name: 'SVG 저장' })).toBeVisible()
    expect(screen.getByRole('button', { name: '인쇄' })).toBeVisible()
    expect(screen.getByRole('link', { name: 'QR 테스트' })).toHaveAttribute(
      'target',
      '_blank',
    )
  })

  it('폐기된 QR을 현재 목록에서 제거하고 폐기함에서 복원한다', async () => {
    vi.spyOn(window, 'confirm').mockReturnValue(true)
    const user = userEvent.setup()
    render(<App />)

    await user.click(screen.getByRole('button', { name: /QR 관리/ }))
    await user.click(screen.getAllByRole('button', { name: '폐기' })[0])
    await user.click(
      await screen.findByRole('button', { name: '목록에서 제거' }),
    )

    expect(
      screen.queryByRole('button', { name: '목록에서 제거' }),
    ).not.toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: /폐기함/ }))
    expect(
      screen.getByRole('button', { name: '목록으로 복원' }),
    ).toBeVisible()

    await user.click(screen.getByRole('button', { name: '목록으로 복원' }))
    expect(screen.getByText('폐기함이 비어 있습니다.')).toBeVisible()
  })

  it('완료 주문 기반 매출과 인기 상품을 기간별로 조회한다', async () => {
    const user = userEvent.setup()
    render(<App />)

    await user.click(screen.getByRole('button', { name: /매출 분석/ }))

    expect(screen.getByRole('heading', { name: '매출 흐름' })).toBeVisible()
    expect(screen.getAllByText('순매출').length).toBeGreaterThan(0)
    expect(screen.getByRole('heading', { name: '인기 상품' })).toBeVisible()
    expect(screen.getByRole('heading', { name: '매출 상세 내역' })).toBeVisible()
    expect(screen.getByRole('tab', { name: /주문 내역/ })).toHaveAttribute(
      'aria-selected',
      'true',
    )
    expect(screen.getAllByText(/블랙 세서미 크림 라떼/).length).toBeGreaterThan(0)

    await user.click(screen.getByRole('tab', { name: /환불 내역/ }))
    expect(screen.getByText('일부 메뉴 누락')).toBeVisible()
    await user.click(screen.getByRole('tab', { name: /취소·거절/ }))
    expect(screen.getByText('고객 주문 취소')).toBeVisible()

    await user.click(screen.getByRole('button', { name: '최근 30일' }))
    expect(
      screen.getByRole('button', { name: '최근 30일' }),
    ).toHaveClass('active')
  })

  it('스토어 영업 상태를 변경하고 새 테이블을 추가한다', async () => {
    const user = userEvent.setup()
    render(<App />)

    await user.click(screen.getByRole('button', { name: /스토어 설정/ }))
    await user.click(screen.getByRole('radio', { name: /영업 종료/ }))
    expect(
      screen.getByRole('button', { name: '영업 종료' }),
    ).toBeVisible()

    await user.click(screen.getByRole('button', { name: /테이블 추가/ }))
    await user.type(screen.getByLabelText('테이블 코드'), 'WINDOW-08')
    await user.type(screen.getByLabelText('표시 이름'), 'Window 08')
    await user.click(
      screen.getByRole('button', { name: '테이블 추가하기' }),
    )

    expect(await screen.findByText('Window 08')).toBeVisible()
  })

  it('공지 초안을 작성하고 게시한다', async () => {
    const user = userEvent.setup()
    render(<App />)

    await user.click(screen.getByRole('button', { name: /공지사항/ }))
    await user.click(screen.getByRole('button', { name: '+ 새 공지' }))
    await user.type(screen.getByLabelText('제목'), '임시 휴무 안내')
    await user.type(screen.getByLabelText('내용'), '8월 10일은 쉽니다.')
    await user.click(screen.getByRole('button', { name: '초안 저장' }))

    expect(await screen.findByText('임시 휴무 안내')).toBeVisible()
    await user.click(screen.getAllByRole('button', { name: '게시' })[0])
    expect(screen.getAllByText('게시 중').length).toBeGreaterThan(0)
  })

  it('주문 대화를 열고 고객에게 메시지를 보낸다', async () => {
    const user = userEvent.setup()
    render(<App />)

    await user.click(screen.getByRole('button', { name: /고객 문의/ }))
    expect(await screen.findByRole('heading', { name: '김고객' })).toBeVisible()
    const input = screen.getByPlaceholderText('고객에게 보낼 메시지를 입력하세요.')
    await user.type(input, '요청하신 포크를 함께 드릴게요.')
    await user.click(screen.getByRole('button', { name: '전송' }))

    expect(await screen.findByText('요청하신 포크를 함께 드릴게요.')).toBeVisible()
  })

  it('리뷰에 판매자 답글을 작성한다', async () => {
    const user = userEvent.setup()
    render(<App />)

    await user.click(screen.getByRole('button', { name: /리뷰 관리/ }))
    expect(await screen.findByRole('heading', { name: '리뷰 관리', level: 1 })).toBeVisible()
    await user.click(screen.getByRole('button', { name: '답글 작성' }))
    const dialog = screen.getByRole('dialog', { name: '답글 작성' })
    await user.type(within(dialog).getByLabelText('답글'), '소중한 리뷰 감사합니다.')
    await user.click(within(dialog).getByRole('button', { name: '답글 저장' }))

    expect(await screen.findByText('소중한 리뷰 감사합니다.')).toBeVisible()
  })

  it('공지 저장과 동시에 관심 고객에게 알리도록 설정한다', async () => {
    const user = userEvent.setup()
    render(<App />)

    await user.click(screen.getByRole('button', { name: /공지사항/ }))
    await user.click(screen.getByRole('button', { name: '+ 새 공지' }))
    const dialog = screen.getByRole('dialog')
    await user.type(within(dialog).getByLabelText('제목'), '신메뉴 안내')
    await user.type(within(dialog).getByLabelText('내용'), '오늘부터 신메뉴를 판매합니다.')
    await user.click(within(dialog).getByRole('checkbox', { name: '찜한 고객에게 알림 보내기' }))
    await user.click(within(dialog).getByRole('button', { name: '게시하고 알림 보내기' }))

    expect(await screen.findByText('신메뉴 안내')).toBeVisible()
    expect(screen.getAllByText('게시 중').length).toBeGreaterThan(0)
  })

  it('완료 주문의 환불 가능 금액을 전액 환불한다', async () => {
    const user = userEvent.setup()
    render(<App />)

    await user.click(screen.getByRole('button', { name: '완료' }))
    await user.click(screen.getByRole('button', { name: '주문 0037 상세 보기' }))
    await user.click(await screen.findByRole('button', { name: '전액 환불' }))
    await user.type(screen.getByLabelText('환불 사유'), '주문 전체 환불')
    await user.click(screen.getByRole('button', { name: '전액 환불 확정' }))

    expect(await screen.findByText('환불 완료')).toBeVisible()
    expect(screen.getAllByText('주문 전체 환불').length).toBeGreaterThan(0)
  })

  it('판매자 세션에는 관리자 메뉴를 노출하지 않는다', () => {
    render(<App />)

    expect(screen.queryByRole('button', { name: /관리자/ })).not.toBeInTheDocument()
  })

  it('관리자 세션에는 관리자 화면만 노출하고 스토어 API를 호출하지 않는다', async () => {
    window.sessionStorage.clear()
    window.sessionStorage.setItem(
      'popq:seller:connection',
      JSON.stringify({
        storeId: null,
        accessToken: 'admin-token',
        user: {
          userId: 99,
          email: 'admin@popq.test',
          name: 'POPQ 관리자',
          role: 'ADMIN',
          status: 'ACTIVE',
        },
      }),
    )
    const fetchMock = vi.spyOn(window, 'fetch').mockImplementation(
      async (input) => {
        const path = String(input)
        const data = path.endsWith('/overview')
          ? {
              totalUsers: 1,
              activeUsers: 1,
              totalSellers: 0,
              pendingSellers: 0,
              totalStores: 0,
              activeStores: 0,
              suspendedStores: 0,
            }
          : []
        return new Response(JSON.stringify({ success: true, data }), {
          status: 200,
          headers: { 'Content-Type': 'application/json' },
        })
      },
    )

    render(<App />)

    expect(
      await screen.findByRole('heading', { name: '플랫폼 운영 현황' }),
    ).toBeVisible()
    expect(screen.getByRole('navigation', { name: '관리자 메뉴' })).toBeVisible()
    expect(screen.queryByRole('button', { name: /주문 운영/ })).not.toBeInTheDocument()
    expect(screen.queryByRole('button', { name: /상품 관리/ })).not.toBeInTheDocument()
    expect(
      fetchMock.mock.calls.some(([input]) => String(input).includes('/seller/stores/')),
    ).toBe(false)
  })
  it('switches to dark mode and restores the preference', async () => {
    const user = userEvent.setup()
    const firstRender = render(<App />)

    await user.click(screen.getByRole('button', { name: '다크 모드로 전환' }))
    expect(document.documentElement).toHaveAttribute('data-theme', 'dark')
    expect(window.localStorage.getItem('popq.seller.web.theme.preference.v1')).toBe('dark')

    firstRender.unmount()
    render(<App />)

    expect(screen.getByRole('button', { name: '기본 모드로 전환' })).toHaveAttribute(
      'aria-pressed',
      'true',
    )
  })
})

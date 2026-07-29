import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { cleanup, render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import App from './App'

vi.mock('qrcode', () => ({
  default: {
    toDataURL: vi.fn().mockResolvedValue('data:image/png;base64,demo'),
  },
}))

describe('판매자 주문 운영', () => {
  beforeEach(() => {
    window.sessionStorage.clear()
  })

  afterEach(() => {
    cleanup()
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

    expect(screen.getByText('접수 완료')).toBeVisible()
    expect(
      screen.getByRole('button', { name: '준비 시작' }),
    ).toBeVisible()
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

  it('연결 설정에서 데모와 실제 백엔드 모드를 안내한다', async () => {
    const user = userEvent.setup()
    render(<App />)

    await user.click(screen.getByRole('button', { name: '연결 설정' }))

    expect(screen.getByRole('dialog', { name: '백엔드 연결' })).toBeVisible()
    expect(
      screen.getByRole('button', { name: '실제 백엔드 연결' }),
    ).toBeVisible()
    expect(
      screen.getByRole('button', { name: '데모 데이터 사용' }),
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

  it('완료 주문 기반 매출과 인기 상품을 기간별로 조회한다', async () => {
    const user = userEvent.setup()
    render(<App />)

    await user.click(screen.getByRole('button', { name: /매출 분석/ }))

    expect(screen.getByRole('heading', { name: '매출 흐름' })).toBeVisible()
    expect(screen.getByText('순매출')).toBeVisible()
    expect(screen.getByRole('heading', { name: '인기 상품' })).toBeVisible()
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

  it('판매자 웹 내부의 관리자 운영 화면으로 이동한다', async () => {
    const user = userEvent.setup()
    render(<App />)

    await user.click(screen.getByRole('button', { name: /관리자/ }))

    expect(
      screen.getByRole('heading', { name: '플랫폼 운영 현황' }),
    ).toBeVisible()
    expect(screen.getByRole('tab', { name: '판매자 인증' })).toBeVisible()
    expect(screen.getByRole('tab', { name: '스토어' })).toBeVisible()
  })
})

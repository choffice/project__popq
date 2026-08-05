import { cleanup, render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import App from './App'

describe('POPQ QR order demo', () => {
  beforeEach(() => {
    window.localStorage.clear()
    window.sessionStorage.clear()
    window.history.replaceState({}, '', '/')
  })

  afterEach(() => {
    cleanup()
  })

  it('adds a configured product and completes a demo payment', async () => {
    const user = userEvent.setup()
    render(<App />)

    expect(
      screen.getByRole('heading', { name: /오늘의 한 잔/ }),
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
    expect(
      screen.getByRole('button', { name: '장바구니 1개' }),
    ).toBeInTheDocument()
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
})

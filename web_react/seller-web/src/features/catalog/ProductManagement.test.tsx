import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { ProductManagement } from './ProductManagement'

describe('판매자 상품 관리', () => {
  afterEach(() => {
    cleanup()
  })

  it('카테고리와 기본 상품을 차례로 생성한다', async () => {
    const user = userEvent.setup()
    render(<ProductManagement connection={null} onError={vi.fn()} />)

    await user.click(screen.getByRole('button', { name: '+ 카테고리' }))
    expect(
      screen.getByRole('dialog', { name: '카테고리 추가' }),
    ).toBeVisible()

    await user.type(screen.getByLabelText('카테고리 이름'), '시즌 메뉴')
    await user.click(
      screen.getByRole('button', { name: '카테고리 추가하기' }),
    )
    expect(
      screen.getByRole('button', { name: '시즌 메뉴' }),
    ).toBeVisible()

    await user.click(screen.getByRole('button', { name: '+ 새 상품' }))
    await user.selectOptions(screen.getByLabelText('카테고리'), '4')
    await user.type(screen.getByLabelText('상품 이름'), '수박 소다')
    await user.type(screen.getByLabelText('상품 설명'), '여름 한정 탄산 음료')
    await user.type(screen.getByLabelText('판매가'), '7200')
    await user.click(
      screen.getByRole('button', { name: '상품 생성하기' }),
    )

    const createdRow = screen.getByText('수박 소다').closest('article')
    expect(createdRow).not.toBeNull()
    expect(within(createdRow!).getByText('7,200원')).toBeVisible()
  })

  it('옵션을 추가해 저장하고 다시 열었을 때 유지한다', async () => {
    const user = userEvent.setup()
    render(<ProductManagement connection={null} onError={vi.fn()} />)

    await user.click(screen.getAllByRole('button', { name: '옵션 편집' })[0])
    expect(screen.getByText('OPTION BUILDER')).toBeVisible()

    await user.click(screen.getByRole('button', { name: '+ 옵션 추가' }))
    await user.type(
      screen.getByLabelText('1번 그룹 3번 옵션 이름'),
      '휘핑 추가',
    )
    await user.type(
      screen.getByLabelText('1번 그룹 3번 추가 금액'),
      '500',
    )
    await user.click(screen.getByRole('button', { name: '옵션 저장' }))

    expect(screen.queryByText('OPTION BUILDER')).not.toBeInTheDocument()

    await user.click(screen.getAllByRole('button', { name: '옵션 편집' })[0])
    expect(screen.getByDisplayValue('휘핑 추가')).toBeVisible()
  })
})

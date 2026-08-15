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
    await user.upload(
      screen.getByLabelText('상품 이미지'),
      new File([new Uint8Array([137, 80, 78, 71])], 'watermelon.png', {
        type: 'image/png',
      }),
    )
    expect(
      await screen.findByRole('img', { name: '상품 이미지 미리보기' }),
    ).toBeVisible()
    await user.click(
      screen.getByRole('button', { name: '상품 생성하기' }),
    )

    const createdRow = screen.getByText('수박 소다').closest('article')
    expect(createdRow).not.toBeNull()
    expect(within(createdRow!).getByText('7,200원')).toBeVisible()
    expect(createdRow!.querySelector('img')).not.toBeNull()
  })

  it('상품의 이미지·이름·가격을 편집하고 삭제한다', async () => {
    const user = userEvent.setup()
    render(<ProductManagement connection={null} onError={vi.fn()} />)

    await user.click(
      screen.getByRole('button', {
        name: '블랙 세서미 크림 라떼 상품 편집',
      }),
    )
    expect(screen.getByRole('dialog', { name: '상품 편집' })).toBeVisible()

    const nameInput = screen.getByLabelText('상품 이름')
    const priceInput = screen.getByLabelText('판매가')
    await user.clear(nameInput)
    await user.type(nameInput, '흑임자 크림 라떼')
    await user.clear(priceInput)
    await user.type(priceInput, '7500')
    await user.upload(
      screen.getByLabelText('상품 이미지'),
      new File([new Uint8Array([255, 216, 255])], 'latte.jpg', {
        type: 'image/jpeg',
      }),
    )
    await user.click(screen.getByRole('button', { name: '변경사항 저장' }))

    const updatedRow = screen.getByText('흑임자 크림 라떼').closest('article')
    expect(updatedRow).not.toBeNull()
    expect(within(updatedRow!).getByText('7,500원')).toBeVisible()
    expect(updatedRow!.querySelector('img')).not.toBeNull()

    await user.click(
      screen.getByRole('button', { name: '흑임자 크림 라떼 상품 편집' }),
    )
    await user.click(screen.getByRole('button', { name: '상품 삭제' }))
    await user.click(screen.getByRole('button', { name: '삭제 확인' }))

    expect(screen.queryByText('흑임자 크림 라떼')).not.toBeInTheDocument()
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
    const minimum = screen.getAllByLabelText('최소 선택')[0]
    const maximum = screen.getAllByLabelText('최대 선택')[0]
    await user.clear(minimum)
    await user.type(minimum, '1')
    await user.clear(maximum)
    await user.type(maximum, '2')
    await user.click(screen.getByRole('button', { name: '옵션 저장' }))

    expect(screen.queryByText('OPTION BUILDER')).not.toBeInTheDocument()

    await user.click(screen.getAllByRole('button', { name: '옵션 편집' })[0])
    expect(screen.getByDisplayValue('휘핑 추가')).toBeVisible()
    expect(screen.getAllByLabelText('최소 선택')[0]).toHaveValue('1')
    expect(screen.getAllByLabelText('최대 선택')[0]).toHaveValue('2')
  })
})

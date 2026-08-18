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

  it('빈 카테고리의 이름을 수정하고 삭제한다', async () => {
    const user = userEvent.setup()
    render(<ProductManagement connection={null} onError={vi.fn()} />)

    await user.click(screen.getByRole('button', { name: '+ 카테고리' }))
    await user.type(screen.getByLabelText('카테고리 이름'), '임시 메뉴')
    await user.click(screen.getByRole('button', { name: '카테고리 추가하기' }))

    await user.click(
      screen.getByRole('button', { name: '임시 메뉴 카테고리 수정' }),
    )
    expect(screen.getByRole('dialog', { name: '카테고리 수정' })).toBeVisible()
    const categoryName = screen.getByLabelText('카테고리 이름')
    await user.clear(categoryName)
    await user.type(categoryName, '여름 메뉴')
    await user.click(screen.getByRole('button', { name: '변경사항 저장' }))

    expect(screen.getByRole('button', { name: '여름 메뉴' })).toBeVisible()
    expect(
      screen.getByRole('button', { name: '여름 메뉴 카테고리 수정' }),
    ).toBeVisible()

    await user.click(
      screen.getByRole('button', { name: '여름 메뉴 카테고리 수정' }),
    )
    await user.click(screen.getByRole('button', { name: '카테고리 삭제' }))
    expect(screen.getByText('“여름 메뉴” 카테고리를 삭제할까요?')).toBeVisible()
    await user.click(screen.getByRole('button', { name: '삭제 확인' }))

    expect(screen.queryByRole('button', { name: '여름 메뉴' })).not.toBeInTheDocument()
  })

  it('상품이 연결된 카테고리는 삭제를 막고 안내한다', async () => {
    const user = userEvent.setup()
    render(<ProductManagement connection={null} onError={vi.fn()} />)

    await user.click(
      screen.getByRole('button', { name: '시그니처 카테고리 수정' }),
    )

    expect(
      screen.getByText(
        '이 카테고리에 등록된 상품이 있습니다. 상품을 먼저 삭제하거나 다른 카테고리로 옮겨 주세요.',
      ),
    ).toBeVisible()
    expect(
      screen.queryByRole('button', { name: '카테고리 삭제' }),
    ).not.toBeInTheDocument()
  })

  it('옵션을 추가해 저장하고 다시 열었을 때 유지한다', async () => {
    const user = userEvent.setup()
    render(<ProductManagement connection={null} onError={vi.fn()} />)

    await user.click(screen.getAllByRole('button', { name: '옵션 편집' })[0])
    expect(screen.getByText('OPTION BUILDER')).toBeVisible()

    expect(screen.queryByText('최소 선택')).not.toBeInTheDocument()
    expect(screen.getByText('기존 공용 옵션을 선택하거나 새 이름을 입력하세요.')).toBeVisible()

    await user.click(screen.getByRole('button', { name: '+ 옵션 항목 추가' }))
    await user.type(
      screen.getByLabelText('1번 그룹 3번 옵션 이름'),
      '휘핑 추가',
    )
    await user.type(
      screen.getByLabelText('1번 그룹 3번 추가 금액'),
      '500',
    )
    const maximum = screen.getByLabelText('1번 그룹 최대 선택 수')
    await user.clear(maximum)
    await user.type(maximum, '2')
    await user.click(screen.getByRole('button', { name: '저장' }))

    expect(screen.queryByText('OPTION BUILDER')).not.toBeInTheDocument()

    await user.click(screen.getAllByRole('button', { name: '옵션 편집' })[0])
    expect(screen.getByDisplayValue('휘핑 추가')).toBeVisible()
    expect(screen.getByLabelText('1번 그룹 최대 선택 수')).toHaveValue('2')
  })

  it('공용 옵션 변경 내용을 연결된 상품에 일괄 적용한다', async () => {
    const user = userEvent.setup()
    render(<ProductManagement connection={null} onError={vi.fn()} />)

    await user.click(screen.getAllByRole('button', { name: '옵션 편집' })[0])
    const firstOption = screen.getByLabelText('1번 그룹 1번 옵션 이름')
    await user.clear(firstOption)
    await user.type(firstOption, '차갑게')

    await user.click(
      screen.getByRole('button', { name: '동일 그룹에 변경사항 일괄 적용' }),
    )
    const confirmation = await screen.findByRole('alertdialog', {
      name: '동일 옵션 그룹을 일괄 변경할까요?',
    })
    expect(within(confirmation).getByText(/동일 옵션이 적용된 메뉴들이 4개/)).toBeVisible()
    await user.click(within(confirmation).getByRole('button', { name: '일괄 적용' }))

    expect(
      screen.queryByRole('alertdialog', {
        name: '동일 옵션 그룹을 일괄 변경할까요?',
      }),
    ).not.toBeInTheDocument()
    expect(
      screen.queryByRole('button', { name: '동일 그룹에 변경사항 일괄 적용' }),
    ).not.toBeInTheDocument()
  })

  it('연결된 공용 옵션은 다른 상품 사용 여부를 확인한 뒤 현재 상품에서만 삭제한다', async () => {
    const user = userEvent.setup()
    render(<ProductManagement connection={null} onError={vi.fn()} />)

    await user.click(screen.getAllByRole('button', { name: '옵션 편집' })[0])
    await user.click(screen.getByRole('button', { name: '옵션 그룹 1 삭제' }))

    const confirmation = await screen.findByRole('alertdialog', {
      name: '옵션 그룹을 삭제할까요?',
    })
    expect(within(confirmation).getByText(/다른 메뉴 3개에서도 사용 중/)).toBeVisible()
    expect(
      within(confirmation).queryByRole('button', { name: '공용 옵션도 삭제' }),
    ).not.toBeInTheDocument()
    await user.click(
      within(confirmation).getByRole('button', { name: '현재 메뉴에서만 삭제' }),
    )
    expect(screen.getByText('옵션 그룹이 없습니다. 아래 버튼으로 추가하세요.')).toBeVisible()
  })
})

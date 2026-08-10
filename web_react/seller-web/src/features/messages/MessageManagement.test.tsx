import { cleanup, render, screen } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { MessageManagement } from './MessageManagement'

describe('고객 문의 주문 정보', () => {
  afterEach(() => {
    cleanup()
  })

  it('내부 주문 코드 대신 짧은 주문번호와 한글 상태를 표시한다', async () => {
    render(
      <MessageManagement
        connection={null}
        onError={vi.fn()}
        onUnreadChange={vi.fn()}
      />,
    )

    expect(await screen.findByText('포장 주문 #1001')).toBeVisible()
    expect(screen.getByText('준비 중')).toBeVisible()
    expect(screen.queryByText(/DEMO-ORDER-1001/)).not.toBeInTheDocument()
    expect(screen.queryByText(/PREPARING/)).not.toBeInTheDocument()
  })

  it('대화 내용을 발신자별 말풍선 구조로 표시한다', async () => {
    const { container } = render(
      <MessageManagement
        connection={null}
        onError={vi.fn()}
        onUnreadChange={vi.fn()}
      />,
    )

    expect(await screen.findByRole('log', { name: '김고객님과의 대화' })).toBeVisible()
    expect(container.querySelector('.message-row.customer .message-bubble')).toHaveTextContent(
      '포크 하나 더 부탁드려요.',
    )
    expect(screen.getByRole('textbox', { name: '고객에게 보낼 메시지' })).toBeVisible()
  })
})

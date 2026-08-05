import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { SellerAuth } from './SellerAuth'

describe('판매자 웹 인증', () => {
  afterEach(() => {
    cleanup()
    vi.restoreAllMocks()
  })

  it('판매자 앱과 같은 회원가입 계약을 사용한다', async () => {
    const user = userEvent.setup()
    const fetchMock = vi.spyOn(window, 'fetch').mockResolvedValue(
      new Response(
        JSON.stringify({
          success: true,
          data: {
            accessToken: 'signup-token',
            tokenType: 'Bearer',
            expiresIn: 3600,
            user: {
              userId: 8,
              email: 'new-seller@popq.test',
              name: '신규 판매자',
              role: 'SELLER',
              status: 'ACTIVE',
            },
          },
        }),
        { status: 201, headers: { 'Content-Type': 'application/json' } },
      ),
    )

    render(<SellerAuth onAuthenticated={vi.fn()} onUseDemo={vi.fn()} />)
    await user.click(screen.getByRole('tab', { name: '회원가입' }))
    await user.type(screen.getByLabelText('이메일'), 'new-seller@popq.test')
    await user.type(screen.getByLabelText('이름 (대표자명)'), '신규 판매자')
    await user.type(screen.getByLabelText('휴대전화 번호'), '010-1234-5678')
    await user.type(screen.getByLabelText('비밀번호'), 'password1')
    await user.type(screen.getByLabelText('비밀번호 확인'), 'password1')
    await user.click(
      screen.getByRole('checkbox', {
        name: '개인정보 수집 및 이용에 동의합니다.',
      }),
    )
    await user.click(screen.getByRole('button', { name: '회원가입' }))

    expect(fetchMock).toHaveBeenCalledWith(
      '/api/v1/auth/signup',
      expect.objectContaining({
        method: 'POST',
        body: JSON.stringify({
          email: 'new-seller@popq.test',
          password: 'password1',
          name: '신규 판매자',
          phone: '010-1234-5678',
          role: 'SELLER',
        }),
      }),
    )
    expect(
      await screen.findByText('회원가입이 완료되었습니다. 로그인해 주세요.'),
    ).toBeVisible()
  })

  it('로그인 후 계정 소유 매장을 자동 선택한다', async () => {
    const user = userEvent.setup()
    const onAuthenticated = vi.fn()
    const fetchMock = vi.spyOn(window, 'fetch')
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            success: true,
            data: {
              accessToken: 'seller-token',
              tokenType: 'Bearer',
              expiresIn: 3600,
              user: {
                userId: 1,
                email: 'seller@popq.test',
                name: 'POPQ 판매자',
                role: 'SELLER',
                status: 'ACTIVE',
              },
            },
          }),
          { status: 200, headers: { 'Content-Type': 'application/json' } },
        ),
      )
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            success: true,
            data: [
              {
                storeId: 7,
                storeType: 'LOCAL_STORE',
                name: '성수 라운지',
                description: null,
                status: 'ACTIVE',
                businessStatus: 'OPEN',
                myRole: 'OWNER',
              },
            ],
          }),
          { status: 200, headers: { 'Content-Type': 'application/json' } },
        ),
      )

    render(
      <SellerAuth onAuthenticated={onAuthenticated} onUseDemo={vi.fn()} />,
    )
    await user.type(screen.getByLabelText('이메일'), 'seller@popq.test')
    await user.type(screen.getByLabelText('비밀번호'), 'password1')
    await user.click(screen.getByRole('button', { name: '로그인' }))

    expect(fetchMock).toHaveBeenNthCalledWith(
      1,
      '/api/v1/auth/login',
      expect.objectContaining({
        method: 'POST',
        body: JSON.stringify({
          email: 'seller@popq.test',
          password: 'password1',
        }),
      }),
    )
    expect(fetchMock).toHaveBeenNthCalledWith(
      2,
      '/api/v1/seller/stores',
      expect.objectContaining({
        headers: expect.objectContaining({
          Authorization: 'Bearer seller-token',
        }),
      }),
    )
    expect(onAuthenticated).toHaveBeenCalledWith(
      expect.objectContaining({
        storeId: 7,
        accessToken: 'seller-token',
        storeName: '성수 라운지',
      }),
    )
  })
})

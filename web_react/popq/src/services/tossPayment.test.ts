import { beforeEach, describe, expect, it, vi } from 'vitest'
import {
  clearTossPaymentReturn,
  readTossPaymentReturn,
  requestTossPayment,
} from './tossPayment'

describe('Toss payment browser flow', () => {
  beforeEach(() => {
    window.sessionStorage.clear()
    window.history.replaceState({}, '', '/q/qr-token')
    delete window.TossPayments
  })

  it('requests card authentication with server-confirmed order values', async () => {
    const requestPayment = vi.fn().mockResolvedValue(undefined)
    const payment = vi.fn(() => ({ requestPayment }))
    window.TossPayments = vi.fn(() => ({ payment }))

    await requestTossPayment({
      clientKey: 'test-client-key',
      orderId: 'order-123456',
      orderName: '아메리카노 외 1건',
      amount: 6800,
    })

    expect(requestPayment).toHaveBeenCalledWith(
      expect.objectContaining({
        method: 'CARD',
        orderId: 'order-123456',
        orderName: '아메리카노 외 1건',
        amount: { currency: 'KRW', value: 6800 },
        windowTarget: 'self',
      }),
    )
    const request = requestPayment.mock.calls[0][0]
    expect(new URL(request.successUrl).pathname).toBe('/q/qr-token')
    expect(new URL(request.successUrl).searchParams.get('payment')).toBe('success')
    expect(new URL(request.failUrl).searchParams.get('payment')).toBe('fail')
  })

  it('parses and clears the payment authentication result', () => {
    expect(
      readTossPaymentReturn(
        '?payment=success&paymentKey=pay-key&orderId=order-1&amount=5000',
      ),
    ).toEqual({
      status: 'success',
      paymentKey: 'pay-key',
      orderId: 'order-1',
      amount: 5000,
    })

    window.history.replaceState(
      {},
      '',
      '/q/qr-token?payment=fail&code=USER_CANCEL&message=cancelled',
    )
    clearTossPaymentReturn()

    expect(window.location.pathname).toBe('/q/qr-token')
    expect(window.location.search).toBe('')
  })

  it('rejects a malformed success result before server approval', () => {
    expect(
      readTossPaymentReturn(
        '?payment=success&paymentKey=pay-key&orderId=order-1&amount=invalid',
      ),
    ).toEqual({
      status: 'fail',
      code: 'INVALID_PAYMENT_RESULT',
      message: '결제 인증 결과가 올바르지 않습니다.',
    })
    expect(
      readTossPaymentReturn(
        '?payment=success&paymentKey=pay-key&orderId=order-1',
      ),
    ).toMatchObject({ status: 'fail', code: 'INVALID_PAYMENT_RESULT' })
  })
})

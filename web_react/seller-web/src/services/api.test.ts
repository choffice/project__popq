import { afterEach, describe, expect, it, vi } from 'vitest'
import {
  archiveQrCode,
  changeQrStatus,
  changeStoreBusinessStatus,
  createSellerCategory,
  createSellerProduct,
  deleteSellerProduct,
  createStoreTable,
  getSellerPaymentSummary,
  getSellerProductDetail,
  getSalesSummary,
  getSellerOrders,
  getQrCodeDetail,
  getQrCodes,
  getAdminOverview,
  getAdminSellers,
  getAdminStores,
  getAdminUsers,
  issueQrCode,
  reissueQrCode,
  restoreQrCode,
  replaceProductOptions,
  refundSellerOrder,
  transitionSellerOrder,
  updateProductAvailability,
  updateSellerProduct,
  uploadSellerProductImage,
  updateAdminSellerVerification,
  updateAdminStoreStatus,
  updateAdminUserStatus,
} from './api'
import type { SellerProduct } from '../types'

const connection = {
  storeId: 7,
  accessToken: 'seller-access-token',
}

describe('판매자 주문 API 계약', () => {
  afterEach(() => {
    vi.restoreAllMocks()
  })

  it('스토어 주문 목록에 판매자 토큰과 상태 필터를 전달한다', async () => {
    const fetchMock = vi.spyOn(window, 'fetch').mockResolvedValue(
      new Response(JSON.stringify({ success: true, data: [] }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      }),
    )

    await getSellerOrders(connection, 'PLACED')

    expect(fetchMock).toHaveBeenCalledWith(
      '/api/v1/seller/stores/7/orders?status=PLACED',
      expect.objectContaining({
        headers: expect.objectContaining({
          Authorization: 'Bearer seller-access-token',
        }),
      }),
    )
  })

  it('주문 접수 시 준비시간과 사업장 기본값 본문을 사용한다', async () => {
    const fetchMock = vi.spyOn(window, 'fetch').mockResolvedValue(
      new Response(
        JSON.stringify({
          success: true,
          data: { orderPublicId: 'order-1', status: 'ACCEPTED' },
        }),
        {
          status: 200,
          headers: { 'Content-Type': 'application/json' },
        },
      ),
    )

    await transitionSellerOrder(
      connection,
      'order-1',
      'accept',
      {
        reason: '주문 접수',
        preparationMinutes: 15,
        applyAsStoreDefault: true,
      },
    )

    expect(fetchMock).toHaveBeenCalledWith(
      '/api/v1/seller/stores/7/orders/order-1/accept',
      expect.objectContaining({
        method: 'POST',
        body: JSON.stringify({
          preparationMinutes: 15,
          applyAsStoreDefault: true,
          reason: '주문 접수',
        }),
      }),
    )
  })

  it('결제 요약 조회와 판매자 환불 계약을 사용한다', async () => {
    const fetchMock = vi.spyOn(window, 'fetch').mockImplementation(
      async () =>
        new Response(
          JSON.stringify({
            success: true,
            data: {
              orderPublicId: 'order-1',
              paymentStatus: 'REFUNDED',
              refundableAmount: 0,
              refunds: [],
            },
          }),
          { status: 200, headers: { 'Content-Type': 'application/json' } },
        ),
    )

    await getSellerPaymentSummary(connection, 'order-1')
    await refundSellerOrder(connection, 'order-1', 12500, '고객 요청')

    expect(fetchMock).toHaveBeenNthCalledWith(
      1,
      '/api/v1/seller/stores/7/orders/order-1/payment',
      expect.any(Object),
    )
    expect(fetchMock).toHaveBeenNthCalledWith(
      2,
      '/api/v1/seller/stores/7/orders/order-1/refunds',
      expect.objectContaining({
        method: 'POST',
        body: JSON.stringify({ amount: 12500, reason: '고객 요청' }),
      }),
    )
  })

  it('관리자 목록과 상태 변경 계약을 사용한다', async () => {
    const fetchMock = vi.spyOn(window, 'fetch').mockImplementation(
      async () =>
        new Response(JSON.stringify({ success: true, data: [] }), {
          status: 200,
          headers: { 'Content-Type': 'application/json' },
        }),
    )

    await getAdminOverview(connection)
    await getAdminUsers(connection)
    await getAdminSellers(connection)
    await getAdminStores(connection)
    await updateAdminUserStatus(connection, 9, 'SUSPENDED')
    await updateAdminSellerVerification(connection, 3, 'VERIFIED')
    await updateAdminStoreStatus(connection, 5, 'SUSPENDED')

    expect(fetchMock).toHaveBeenNthCalledWith(
      1,
      '/api/v1/admin/overview',
      expect.any(Object),
    )
    expect(fetchMock).toHaveBeenNthCalledWith(
      5,
      '/api/v1/admin/users/9/status',
      expect.objectContaining({
        method: 'PATCH',
        body: JSON.stringify({ status: 'SUSPENDED' }),
      }),
    )
    expect(fetchMock).toHaveBeenNthCalledWith(
      6,
      '/api/v1/admin/sellers/3/verification',
      expect.objectContaining({
        method: 'PATCH',
        body: JSON.stringify({ verificationStatus: 'VERIFIED' }),
      }),
    )
    expect(fetchMock).toHaveBeenNthCalledWith(
      7,
      '/api/v1/admin/stores/5/status',
      expect.objectContaining({
        method: 'PATCH',
        body: JSON.stringify({ status: 'SUSPENDED' }),
      }),
    )
  })

  it('상품 판매 상태 전체 계약을 보존해 변경한다', async () => {
    const product: SellerProduct = {
      productId: 101,
      categoryId: 1,
      categoryName: '시그니처',
      name: '라떼',
      description: null,
      imageUrl: null,
      basePrice: 6800,
      status: 'ACTIVE',
      soldOut: false,
      availableForQr: true,
      salesStartAt: null,
      salesEndAt: null,
      qrWebEnabled: true,
      customerAppEnabled: true,
    }
    const fetchMock = vi.spyOn(window, 'fetch').mockResolvedValue(
      new Response(
        JSON.stringify({
          success: true,
          data: { product: { ...product, soldOut: true } },
        }),
        { status: 200, headers: { 'Content-Type': 'application/json' } },
      ),
    )

    await updateProductAvailability(connection, product, { soldOut: true })

    expect(fetchMock).toHaveBeenCalledWith(
      '/api/v1/seller/stores/7/products/101/availability',
      expect.objectContaining({
        method: 'PATCH',
        body: JSON.stringify({
          soldOut: true,
          salesStartAt: null,
          salesEndAt: null,
          qrWebEnabled: true,
          customerAppEnabled: true,
        }),
      }),
    )
  })

  it('카테고리와 상품 생성 계약을 사용한다', async () => {
    const fetchMock = vi.spyOn(window, 'fetch').mockImplementation(
      async () =>
        new Response(
          JSON.stringify({
            success: true,
            data: { categoryId: 9, name: '시즌 메뉴' },
          }),
          { status: 200, headers: { 'Content-Type': 'application/json' } },
        ),
    )

    await createSellerCategory(connection, '시즌 메뉴', 3)
    await createSellerProduct(connection, {
      categoryId: 9,
      name: '수박 소다',
      description: '여름 한정',
      imageUrl: null,
      basePrice: 7200,
    })

    expect(fetchMock).toHaveBeenNthCalledWith(
      1,
      '/api/v1/seller/stores/7/categories',
      expect.objectContaining({
        method: 'POST',
        body: JSON.stringify({ name: '시즌 메뉴', displayOrder: 3 }),
      }),
    )
    expect(fetchMock).toHaveBeenNthCalledWith(
      2,
      '/api/v1/seller/stores/7/products',
      expect.objectContaining({
        method: 'POST',
        body: JSON.stringify({
          categoryId: 9,
          name: '수박 소다',
          description: '여름 한정',
          imageUrl: null,
          basePrice: 7200,
        }),
      }),
    )
  })

  it('상품 기본정보 수정·삭제와 이미지 업로드 계약을 사용한다', async () => {
    const fetchMock = vi.spyOn(window, 'fetch').mockImplementation(
      async (_path, init) => {
        const data = init?.body instanceof FormData
          ? { imageUrl: 'http://localhost:8082/uploads/store-images/menu.jpg' }
          : true
        return new Response(JSON.stringify({ success: true, data }), {
          status: 200,
          headers: { 'Content-Type': 'application/json' },
        })
      },
    )
    const payload = {
      categoryId: 2,
      name: '흑임자 라떼',
      description: '수정한 설명',
      imageUrl: 'https://example.test/latte.jpg',
      basePrice: 7500,
    }
    const image = new File([new Uint8Array([255, 216, 255])], 'latte.jpg', {
      type: 'image/jpeg',
    })

    await updateSellerProduct(connection, 101, payload)
    await deleteSellerProduct(connection, 101)
    await uploadSellerProductImage(connection, image)

    expect(fetchMock).toHaveBeenNthCalledWith(
      1,
      '/api/v1/seller/stores/7/products/101',
      expect.objectContaining({
        method: 'PATCH',
        body: JSON.stringify(payload),
      }),
    )
    expect(fetchMock).toHaveBeenNthCalledWith(
      2,
      '/api/v1/seller/stores/7/products/101',
      expect.objectContaining({ method: 'DELETE' }),
    )
    expect(fetchMock).toHaveBeenNthCalledWith(
      3,
      '/api/v1/seller/store-images',
      expect.objectContaining({
        method: 'POST',
        headers: { Authorization: 'Bearer seller-access-token' },
        body: expect.any(FormData),
      }),
    )
  })

  it('상품 상세 조회 후 옵션 전체 교체 계약을 사용한다', async () => {
    const fetchMock = vi.spyOn(window, 'fetch').mockImplementation(
      async () =>
        new Response(
          JSON.stringify({
            success: true,
            data: { product: { productId: 101 }, optionGroups: [] },
          }),
          { status: 200, headers: { 'Content-Type': 'application/json' } },
        ),
    )
    const groups = [
      {
        name: '온도',
        minSelect: 1,
        maxSelect: 1,
        required: true,
        displayOrder: 0,
        options: [
          { name: 'ICE', additionalPrice: 0, displayOrder: 0 },
          { name: 'HOT', additionalPrice: 0, displayOrder: 1 },
        ],
      },
    ]

    await getSellerProductDetail(connection, 101)
    await replaceProductOptions(connection, 101, groups)

    expect(fetchMock).toHaveBeenNthCalledWith(
      1,
      '/api/v1/seller/stores/7/products/101',
      expect.any(Object),
    )
    expect(fetchMock).toHaveBeenNthCalledWith(
      2,
      '/api/v1/seller/stores/7/products/101/options',
      expect.objectContaining({
        method: 'PUT',
        body: JSON.stringify({ groups }),
      }),
    )
  })

  it('QR 발급·보관함 조회·재발급·상태 변경 계약을 사용한다', async () => {
    const fetchMock = vi.spyOn(window, 'fetch').mockImplementation(
      async () =>
        new Response(
          JSON.stringify({
            success: true,
            data: { qrCodeId: 71, status: 'ACTIVE' },
          }),
          { status: 200, headers: { 'Content-Type': 'application/json' } },
        ),
    )

    await issueQrCode(connection, 9, null)
    await getQrCodes(connection, true)
    await getQrCodeDetail(connection, 71)
    await reissueQrCode(connection, 71, '2027-01-01T00:00:00Z')
    await changeQrStatus(connection, 71, 'deactivate')
    await archiveQrCode(connection, 71)
    await restoreQrCode(connection, 71)

    expect(fetchMock).toHaveBeenNthCalledWith(
      1,
      '/api/v1/seller/stores/7/qr-codes',
      expect.objectContaining({
        method: 'POST',
        body: JSON.stringify({ storeTableId: 9, expiresAt: null }),
      }),
    )
    expect(fetchMock).toHaveBeenNthCalledWith(
      2,
      '/api/v1/seller/stores/7/qr-codes?includeArchived=true',
      expect.any(Object),
    )
    expect(fetchMock).toHaveBeenNthCalledWith(
      3,
      '/api/v1/seller/stores/7/qr-codes/71',
      expect.any(Object),
    )
    expect(fetchMock).toHaveBeenNthCalledWith(
      4,
      '/api/v1/seller/stores/7/qr-codes/71/reissue',
      expect.objectContaining({
        method: 'POST',
        body: JSON.stringify({ expiresAt: '2027-01-01T00:00:00Z' }),
      }),
    )
    expect(fetchMock).toHaveBeenNthCalledWith(
      5,
      '/api/v1/seller/stores/7/qr-codes/71/deactivate',
      expect.objectContaining({ method: 'POST' }),
    )
    expect(fetchMock).toHaveBeenNthCalledWith(
      6,
      '/api/v1/seller/stores/7/qr-codes/71/archive',
      expect.objectContaining({ method: 'POST' }),
    )
    expect(fetchMock).toHaveBeenNthCalledWith(
      7,
      '/api/v1/seller/stores/7/qr-codes/71/restore',
      expect.objectContaining({ method: 'POST' }),
    )
  })

  it('매출 기간 조회 계약을 사용한다', async () => {
    const fetchMock = vi.spyOn(window, 'fetch').mockResolvedValue(
      new Response(
        JSON.stringify({
          success: true,
          data: { from: '2026-07-23', to: '2026-07-29' },
        }),
        { status: 200, headers: { 'Content-Type': 'application/json' } },
      ),
    )

    await getSalesSummary(connection, '2026-07-23', '2026-07-29')

    expect(fetchMock).toHaveBeenCalledWith(
      '/api/v1/seller/stores/7/analytics/sales?from=2026-07-23&to=2026-07-29',
      expect.any(Object),
    )
  })

  it('영업 상태 변경과 테이블 생성 계약을 사용한다', async () => {
    const fetchMock = vi.spyOn(window, 'fetch').mockImplementation(
      async () =>
        new Response(
          JSON.stringify({ success: true, data: { storeId: 7 } }),
          { status: 200, headers: { 'Content-Type': 'application/json' } },
        ),
    )

    await changeStoreBusinessStatus(connection, 'CLOSED')
    await createStoreTable(connection, 'WINDOW-08', 'Window 08')

    expect(fetchMock).toHaveBeenNthCalledWith(
      1,
      '/api/v1/seller/stores/7/business-status',
      expect.objectContaining({
        method: 'PATCH',
        body: JSON.stringify({ businessStatus: 'CLOSED' }),
      }),
    )
    expect(fetchMock).toHaveBeenNthCalledWith(
      2,
      '/api/v1/seller/stores/7/tables',
      expect.objectContaining({
        method: 'POST',
        body: JSON.stringify({
          tableCode: 'WINDOW-08',
          name: 'Window 08',
        }),
      }),
    )
  })
})

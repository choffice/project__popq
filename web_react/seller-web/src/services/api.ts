import type {
  AdminOverview,
  AdminSeller,
  AdminStore,
  AdminUser,
  ApiEnvelope,
  BusinessStatus,
  OrderStatus,
  ProductDetail,
  ProductOptionGroupInput,
  QrCodeDetail,
  QrCodeSummary,
  QrIssued,
  SalesSummary,
  SellerCategory,
  SellerConnection,
  SellerAuthResult,
  SellerOrder,
  SellerPaymentSummary,
  SellerProduct,
  StoreSummary,
  StoreTable,
} from '../types'

type TransitionAction =
  | 'accept'
  | 'reject'
  | 'prepare'
  | 'ready'
  | 'complete'

async function publicRequest<T>(path: string, init: RequestInit): Promise<T> {
  const response = await fetch(path, {
    ...init,
    headers: {
      'Content-Type': 'application/json',
      ...init.headers,
    },
  })
  const envelope = (await response.json()) as ApiEnvelope<T>
  if (!response.ok || !envelope.success) {
    throw new Error(envelope.error?.message ?? '요청을 처리하지 못했습니다.')
  }
  return envelope.data
}

export function loginSeller(email: string, password: string) {
  return publicRequest<SellerAuthResult>('/api/v1/auth/login', {
    method: 'POST',
    body: JSON.stringify({ email, password }),
  })
}

export function signUpSeller(payload: {
  email: string
  password: string
  name: string
  phone: string
}) {
  return publicRequest<SellerAuthResult>('/api/v1/auth/signup', {
    method: 'POST',
    body: JSON.stringify({ ...payload, role: 'SELLER' }),
  })
}

async function request<T>(
  path: string,
  connection: SellerConnection,
  init?: RequestInit,
): Promise<T> {
  const response = await fetch(path, {
    ...init,
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${connection.accessToken}`,
      ...init?.headers,
    },
  })
  const envelope = (await response.json()) as ApiEnvelope<T>
  if (!response.ok || !envelope.success) {
    throw new Error(envelope.error?.message ?? '요청을 처리하지 못했습니다.')
  }
  return envelope.data
}

function orderPath(connection: SellerConnection) {
  return `/api/v1/seller/stores/${connection.storeId}/orders`
}

function adminPath(path: string) {
  return `/api/v1/admin${path}`
}

export function getAdminOverview(connection: SellerConnection) {
  return request<AdminOverview>(adminPath('/overview'), connection)
}

export function getAdminUsers(connection: SellerConnection) {
  return request<AdminUser[]>(adminPath('/users'), connection)
}

export function getAdminSellers(connection: SellerConnection) {
  return request<AdminSeller[]>(adminPath('/sellers'), connection)
}

export function getAdminStores(connection: SellerConnection) {
  return request<AdminStore[]>(adminPath('/stores'), connection)
}

export function updateAdminUserStatus(
  connection: SellerConnection,
  userId: number,
  status: AdminUser['status'],
) {
  return request<AdminUser>(
    adminPath(`/users/${userId}/status`),
    connection,
    {
      method: 'PATCH',
      body: JSON.stringify({ status }),
    },
  )
}

export function updateAdminSellerVerification(
  connection: SellerConnection,
  sellerProfileId: number,
  verificationStatus: AdminSeller['verificationStatus'],
) {
  return request<AdminSeller>(
    adminPath(`/sellers/${sellerProfileId}/verification`),
    connection,
    {
      method: 'PATCH',
      body: JSON.stringify({ verificationStatus }),
    },
  )
}

export function updateAdminStoreStatus(
  connection: SellerConnection,
  storeId: number,
  status: AdminStore['status'],
) {
  return request<AdminStore>(
    adminPath(`/stores/${storeId}/status`),
    connection,
    {
      method: 'PATCH',
      body: JSON.stringify({ status }),
    },
  )
}

export function getSellerOrders(
  connection: SellerConnection,
  status?: OrderStatus,
) {
  const query = status ? `?status=${status}` : ''
  return request<SellerOrder[]>(
    `${orderPath(connection)}${query}`,
    connection,
  )
}

export function transitionSellerOrder(
  connection: SellerConnection,
  orderPublicId: string,
  action: TransitionAction,
  reason?: string,
) {
  return request<SellerOrder>(
    `${orderPath(connection)}/${orderPublicId}/${action}`,
    connection,
    {
      method: 'POST',
      body: JSON.stringify(reason ? { reason } : {}),
    },
  )
}

export function getSellerPaymentSummary(
  connection: SellerConnection,
  orderPublicId: string,
) {
  return request<SellerPaymentSummary>(
    `${orderPath(connection)}/${orderPublicId}/payment`,
    connection,
  )
}

export function refundSellerOrder(
  connection: SellerConnection,
  orderPublicId: string,
  amount: number,
  reason: string,
) {
  return request<SellerPaymentSummary>(
    `${orderPath(connection)}/${orderPublicId}/refunds`,
    connection,
    {
      method: 'POST',
      body: JSON.stringify({ amount, reason }),
    },
  )
}

export function syncSellerOrder(
  connection: SellerConnection,
  orderPublicId: string,
  knownVersion: number,
) {
  return request<{
    refreshRequired: boolean
    serverVersion: number
    order: SellerOrder | null
  }>(
    `${orderPath(connection)}/${orderPublicId}/sync?knownVersion=${knownVersion}`,
    connection,
  )
}

function storePath(connection: SellerConnection) {
  return `/api/v1/seller/stores/${connection.storeId}`
}

export function getSellerProducts(connection: SellerConnection) {
  return request<SellerProduct[]>(
    `${storePath(connection)}/products`,
    connection,
  )
}

export function getSellerCategories(connection: SellerConnection) {
  return request<SellerCategory[]>(
    `${storePath(connection)}/categories`,
    connection,
  )
}

export function createSellerCategory(
  connection: SellerConnection,
  name: string,
  displayOrder: number,
) {
  return request<SellerCategory>(
    `${storePath(connection)}/categories`,
    connection,
    {
      method: 'POST',
      body: JSON.stringify({ name, displayOrder }),
    },
  )
}

export function createSellerProduct(
  connection: SellerConnection,
  payload: {
    categoryId: number
    name: string
    description: string | null
    imageUrl: string | null
    basePrice: number
  },
) {
  return request<ProductDetail>(
    `${storePath(connection)}/products`,
    connection,
    {
      method: 'POST',
      body: JSON.stringify(payload),
    },
  )
}

export function getSellerProductDetail(
  connection: SellerConnection,
  productId: number,
) {
  return request<ProductDetail>(
    `${storePath(connection)}/products/${productId}`,
    connection,
  )
}

export function replaceProductOptions(
  connection: SellerConnection,
  productId: number,
  groups: ProductOptionGroupInput[],
) {
  return request<ProductDetail>(
    `${storePath(connection)}/products/${productId}/options`,
    connection,
    {
      method: 'PUT',
      body: JSON.stringify({ groups }),
    },
  )
}

export function updateProductAvailability(
  connection: SellerConnection,
  product: SellerProduct,
  changes: Partial<
    Pick<
      SellerProduct,
      | 'soldOut'
      | 'salesStartAt'
      | 'salesEndAt'
      | 'qrWebEnabled'
      | 'customerAppEnabled'
    >
  >,
) {
  return request<ProductDetail>(
    `${storePath(connection)}/products/${product.productId}/availability`,
    connection,
    {
      method: 'PATCH',
      body: JSON.stringify({
        soldOut: changes.soldOut ?? product.soldOut,
        salesStartAt: changes.salesStartAt ?? product.salesStartAt,
        salesEndAt: changes.salesEndAt ?? product.salesEndAt,
        qrWebEnabled: changes.qrWebEnabled ?? product.qrWebEnabled,
        customerAppEnabled:
          changes.customerAppEnabled ?? product.customerAppEnabled,
      }),
    },
  )
}

export function getStoreTables(connection: SellerConnection) {
  return request<StoreTable[]>(
    `${storePath(connection)}/tables`,
    connection,
  )
}

export function getQrCodes(
  connection: SellerConnection,
  includeArchived = false,
) {
  const query = includeArchived ? '?includeArchived=true' : ''
  return request<QrCodeSummary[]>(
    `${storePath(connection)}/qr-codes${query}`,
    connection,
  )
}

export function getQrCodeDetail(
  connection: SellerConnection,
  qrCodeId: number,
) {
  return request<QrCodeDetail>(
    `${storePath(connection)}/qr-codes/${qrCodeId}`,
    connection,
  )
}

export function issueQrCode(
  connection: SellerConnection,
  storeTableId: number | null,
  expiresAt: string | null,
) {
  return request<QrIssued>(
    `${storePath(connection)}/qr-codes`,
    connection,
    {
      method: 'POST',
      body: JSON.stringify({ storeTableId, expiresAt }),
    },
  )
}

export function changeQrStatus(
  connection: SellerConnection,
  qrCodeId: number,
  action: 'activate' | 'deactivate' | 'revoke',
) {
  return request<QrCodeSummary>(
    `${storePath(connection)}/qr-codes/${qrCodeId}/${action}`,
    connection,
    { method: 'POST' },
  )
}

export function reissueQrCode(
  connection: SellerConnection,
  qrCodeId: number,
  expiresAt: string | null,
) {
  return request<QrIssued>(
    `${storePath(connection)}/qr-codes/${qrCodeId}/reissue`,
    connection,
    {
      method: 'POST',
      body: JSON.stringify({ expiresAt }),
    },
  )
}

export function archiveQrCode(
  connection: SellerConnection,
  qrCodeId: number,
) {
  return request<QrCodeSummary>(
    `${storePath(connection)}/qr-codes/${qrCodeId}/archive`,
    connection,
    { method: 'POST' },
  )
}

export function restoreQrCode(
  connection: SellerConnection,
  qrCodeId: number,
) {
  return request<QrCodeSummary>(
    `${storePath(connection)}/qr-codes/${qrCodeId}/restore`,
    connection,
    { method: 'POST' },
  )
}

export function getSalesSummary(
  connection: SellerConnection,
  from: string,
  to: string,
) {
  const query = new URLSearchParams({ from, to })
  return request<SalesSummary>(
    `${storePath(connection)}/analytics/sales?${query.toString()}`,
    connection,
  )
}

export function getSellerStores(connection: SellerConnection) {
  return request<StoreSummary[]>('/api/v1/seller/stores', connection)
}

export function changeStoreBusinessStatus(
  connection: SellerConnection,
  businessStatus: BusinessStatus,
) {
  return request<StoreSummary>(
    `${storePath(connection)}/business-status`,
    connection,
    {
      method: 'PATCH',
      body: JSON.stringify({ businessStatus }),
    },
  )
}

export function createStoreTable(
  connection: SellerConnection,
  tableCode: string,
  name: string,
) {
  return request<StoreTable>(
    `${storePath(connection)}/tables`,
    connection,
    {
      method: 'POST',
      body: JSON.stringify({ tableCode, name }),
    },
  )
}

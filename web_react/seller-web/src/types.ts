export type OrderStatus =
  | 'CREATED'
  | 'PLACED'
  | 'ACCEPTED'
  | 'PREPARING'
  | 'READY'
  | 'COMPLETED'
  | 'CANCELED'
  | 'REJECTED'
  | 'EXPIRED'

export type OrderType = 'DINE_IN' | 'TAKEOUT'

export type OrderItemOption = {
  productOptionId: number
  optionGroupName: string
  optionName: string
  optionPrice: number
}

export type OrderItem = {
  orderItemId: number
  productId: number
  productName: string
  productImageUrl: string | null
  unitPrice: number
  quantity: number
  itemTotalPrice: number
  options: OrderItemOption[]
}

export type OrderStatusHistory = {
  previousStatus: OrderStatus | null
  currentStatus: OrderStatus
  actorType: string
  actorId: number | null
  reason: string | null
  changedAt: string
}

export type SellerOrder = {
  orderPublicId: string
  storeId: number
  storeName: string
  orderType: OrderType
  status: OrderStatus
  subtotalAmount: number
  discountAmount: number
  taxAmount: number
  serviceFeeAmount: number
  totalAmount: number
  expiresAt: string
  version: number
  items: OrderItem[]
  statusHistory: OrderStatusHistory[]
}

export type PaymentStatus =
  | 'READY'
  | 'IN_PROGRESS'
  | 'PAID'
  | 'FAILED'
  | 'CANCELED'
  | 'PARTIALLY_REFUNDED'
  | 'REFUNDED'

export type RefundStatus = 'REQUESTED' | 'PROCESSING' | 'SUCCEEDED' | 'FAILED'

export type SellerPaymentSummary = {
  orderPublicId: string
  paymentStatus: PaymentStatus
  paymentMethod: string
  approvedAmount: number
  refundedAmount: number
  refundableAmount: number
  refunds: {
    refundId: number
    amount: number
    reason: string
    requesterType: 'GUEST' | 'SELLER' | 'ADMIN'
    status: RefundStatus
    requestedAt: string
    completedAt: string | null
    failureCode: string | null
    failureMessage: string | null
  }[]
}

export type OrderRealtimeEvent = {
  eventId: string
  eventType: string
  orderPublicId: string
  storeId: number
  previousStatus: OrderStatus
  currentStatus: OrderStatus
  occurredAt: string
  version: number
}

export type ApiEnvelope<T> = {
  success: boolean
  data: T
  error?: {
    code: string
    message: string
  }
}

export type SellerAuthUser = {
  userId: number
  email: string
  name: string
  role: 'CUSTOMER' | 'SELLER' | 'ADMIN'
  status: 'ACTIVE' | 'SUSPENDED' | 'WITHDRAWN'
}

export type SellerAuthResult = {
  accessToken: string
  tokenType: string
  expiresIn: number
  user: SellerAuthUser
}

export type SellerConnection = {
  storeId: number
  accessToken: string
  storeName?: string
  user?: SellerAuthUser
}

export type SellerProduct = {
  productId: number
  categoryId: number
  categoryName: string
  name: string
  description: string | null
  imageUrl: string | null
  basePrice: number
  status: 'ACTIVE' | 'INACTIVE'
  soldOut: boolean
  availableForQr: boolean
  salesStartAt: string | null
  salesEndAt: string | null
  qrWebEnabled: boolean
  customerAppEnabled: boolean
}

export type SellerCategory = {
  categoryId: number
  name: string
  displayOrder: number
  status: 'ACTIVE' | 'INACTIVE'
}

export type ProductOption = {
  optionId: number
  name: string
  additionalPrice: number
  displayOrder: number
}

export type ProductOptionGroup = {
  optionGroupId: number
  name: string
  minSelect: number
  maxSelect: number
  required: boolean
  displayOrder: number
  options: ProductOption[]
}

export type ProductOptionGroupInput = {
  name: string
  minSelect: number
  maxSelect: number
  required: boolean
  displayOrder: number
  options: {
    name: string
    additionalPrice: number
    displayOrder: number
  }[]
}

export type ProductDetail = {
  product: SellerProduct
  availability: {
    soldOut: boolean
    salesStartAt: string | null
    salesEndAt: string | null
    qrWebEnabled: boolean
    customerAppEnabled: boolean
  }
  optionGroups: ProductOptionGroup[]
}

export type StoreTable = {
  storeTableId: number
  tableCode: string
  name: string
  status: 'ACTIVE' | 'INACTIVE'
}

export type QrCodeStatus = 'ACTIVE' | 'INACTIVE' | 'REVOKED' | 'EXPIRED'

export type QrCodeSummary = {
  qrCodeId: number
  storeTableId: number | null
  tableName: string | null
  status: QrCodeStatus
  expiresAt: string | null
  createdAt: string
  recoverable: boolean
  archived: boolean
}

export type QrIssued = {
  qrCodeId: number
  storeId: number
  storeTableId: number | null
  token: string
  publicUrl: string
  status: QrCodeStatus
  expiresAt: string | null
}

export type QrCodeDetail = {
  qrCodeId: number
  storeId: number
  storeTableId: number | null
  tableName: string | null
  status: QrCodeStatus
  expiresAt: string | null
  createdAt: string
  publicUrl: string
}

export type SalesSummary = {
  from: string
  to: string
  netSales: number
  completedOrderCount: number
  averageOrderAmount: number
  dineInSales: number
  takeoutSales: number
  dailySales: {
    date: string
    sales: number
    orderCount: number
  }[]
  topProducts: {
    productName: string
    quantity: number
    sales: number
  }[]
}

export type BusinessStatus = 'PRE_OPEN' | 'OPEN' | 'CLOSED'

export type StoreSummary = {
  storeId: number
  storeType: 'LOCAL_STORE' | 'EVENT_COMMERCE'
  name: string
  description: string | null
  status: 'ACTIVE' | 'SUSPENDED' | 'CLOSED'
  businessStatus: BusinessStatus
  myRole: 'OWNER' | 'MANAGER' | 'STAFF'
}

export type AdminOverview = {
  totalUsers: number
  activeUsers: number
  sellerProfiles: number
  pendingSellers: number
  totalStores: number
  activeStores: number
  suspendedStores: number
}

export type AdminUser = {
  userId: number
  email: string
  name: string
  role: 'CUSTOMER' | 'SELLER' | 'ADMIN'
  status: 'ACTIVE' | 'SUSPENDED' | 'WITHDRAWN'
  createdAt: string
}

export type AdminSeller = {
  sellerProfileId: number
  userId: number
  email: string
  name: string
  businessName: string | null
  businessRegistrationNumber: string | null
  verificationStatus: 'PENDING' | 'VERIFIED' | 'REJECTED'
  userStatus: 'ACTIVE' | 'SUSPENDED' | 'WITHDRAWN'
  createdAt: string
}

export type AdminStore = {
  storeId: number
  storeType: 'LOCAL_STORE' | 'EVENT_COMMERCE'
  name: string
  status: 'ACTIVE' | 'SUSPENDED' | 'CLOSED'
  businessStatus: BusinessStatus
  createdAt: string
}

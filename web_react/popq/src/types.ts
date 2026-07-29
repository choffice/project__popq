export type OrderType = 'DINE_IN' | 'TAKEOUT' | 'PICKUP'

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

export interface QrContext {
  storeId: number
  storeName: string
  storeType: string
  businessStatus: string
  storeTableId: number | null
  tableName: string | null
  sessionExpiresAt: string
}

export interface ProductSummary {
  productId: number
  categoryId: number
  categoryName: string
  name: string
  description: string | null
  imageUrl: string | null
  basePrice: number
  status: string
  soldOut: boolean
  availableForQr: boolean
  visual?: string
  badge?: string
}

export interface ProductOption {
  optionId: number
  name: string
  additionalPrice: number
  displayOrder: number
}

export interface ProductOptionGroup {
  optionGroupId: number
  name: string
  minSelect: number
  maxSelect: number
  required: boolean
  displayOrder: number
  options: ProductOption[]
}

export interface ProductDetail {
  product: ProductSummary
  availability: {
    soldOut: boolean
    salesStartAt: string | null
    salesEndAt: string | null
    qrWebEnabled: boolean
    customerAppEnabled: boolean
  }
  optionGroups: ProductOptionGroup[]
}

export interface CartItem {
  cartId: string
  product: ProductSummary
  quantity: number
  options: ProductOption[]
}

export interface OrderResponse {
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
  items: Array<{
    orderItemId: number
    productId: number
    productName: string
    productImageUrl: string | null
    unitPrice: number
    quantity: number
    itemTotalPrice: number
    options: Array<{
      productOptionId: number
      optionGroupName: string
      optionName: string
      optionPrice: number
    }>
  }>
  statusHistory: Array<{
    previousStatus: OrderStatus | null
    currentStatus: OrderStatus
    actorType: string
    actorId: number | null
    reason: string | null
    changedAt: string
  }>
}

export interface OrderRealtimeEvent {
  eventId: string
  eventType: string
  orderPublicId: string
  storeId: number
  guestSessionId: number
  previousStatus: OrderStatus
  currentStatus: OrderStatus
  occurredAt: string
  version: number
}

export interface OrderSyncResponse {
  refreshRequired: boolean
  serverVersion: number
  order: OrderResponse | null
}

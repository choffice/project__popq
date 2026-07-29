import type {
  OrderItem,
  OrderStatus,
  OrderStatusHistory,
  OrderType,
  QrCodeSummary,
  SalesSummary,
  SellerCategory,
  SellerProduct,
  SellerOrder,
  StoreSummary,
  StoreTable,
} from '../types'

const now = new Date('2026-07-29T04:20:00Z')

function item(
  id: number,
  name: string,
  price: number,
  quantity = 1,
  optionName?: string,
): OrderItem {
  return {
    orderItemId: id,
    productId: 100 + id,
    productName: name,
    productImageUrl: null,
    unitPrice: price,
    quantity,
    itemTotalPrice: price * quantity,
    options: optionName
      ? [
          {
            productOptionId: 1000 + id,
            optionGroupName: '옵션',
            optionName,
            optionPrice: 0,
          },
        ]
      : [],
  }
}

function minutesAgo(minutes: number) {
  return new Date(now.getTime() - minutes * 60_000).toISOString()
}

function history(
  status: OrderStatus,
  minutes: number,
): OrderStatusHistory[] {
  return [
    {
      previousStatus: 'CREATED',
      currentStatus: status,
      actorType: status === 'PLACED' ? 'SYSTEM' : 'SELLER',
      actorId: status === 'PLACED' ? null : 1,
      reason: status === 'PLACED' ? '테스트 결제 승인' : '판매자 상태 변경',
      changedAt: minutesAgo(minutes),
    },
  ]
}

function order(
  id: string,
  status: OrderStatus,
  orderType: OrderType,
  minutes: number,
  items: OrderItem[],
): SellerOrder {
  const totalAmount = items.reduce(
    (total, current) => total + current.itemTotalPrice,
    0,
  )
  return {
    orderPublicId: id,
    storeId: 1,
    storeName: '성수 라운지',
    orderType,
    status,
    subtotalAmount: totalAmount,
    discountAmount: 0,
    taxAmount: 0,
    serviceFeeAmount: 0,
    totalAmount,
    expiresAt: new Date(now.getTime() + 15 * 60_000).toISOString(),
    version: status === 'PLACED' ? 1 : 2,
    items,
    statusHistory: history(status, minutes),
  }
}

export const demoOrders: SellerOrder[] = [
  order(
    'e82b3f1a-9d55-4ace-b7f6-000000000042',
    'PLACED',
    'DINE_IN',
    3,
    [
      item(1, '블랙 세서미 크림 라떼', 6800, 2, 'ICE'),
      item(2, '솔티드 카라멜 휘낭시에', 3900),
    ],
  ),
  order(
    '44bc9d20-7c0a-4541-bff4-000000000041',
    'PLACED',
    'TAKEOUT',
    7,
    [item(3, '제주 말차 클라우드', 7200, 1, 'HOT')],
  ),
  order(
    '838afef5-4f6d-4ee7-bfe7-000000000040',
    'ACCEPTED',
    'DINE_IN',
    10,
    [item(4, '성수 블렌드 아메리카노', 4800, 2, 'ICE')],
  ),
  order(
    '78acbd69-cc23-432c-a96a-000000000039',
    'PREPARING',
    'DINE_IN',
    14,
    [
      item(5, '바닐라 빈 플랫화이트', 6200, 1, 'HOT'),
      item(6, '피스타치오 티라미수', 7600),
    ],
  ),
  order(
    'a5cf6899-4c75-4968-bb32-000000000038',
    'READY',
    'TAKEOUT',
    18,
    [item(7, '블랙 세서미 크림 라떼', 6800, 1, 'ICE')],
  ),
  order(
    '42c01960-e773-4f9f-8c9a-000000000037',
    'COMPLETED',
    'DINE_IN',
    28,
    [item(8, '제주 말차 클라우드', 7200, 2, 'ICE')],
  ),
]

export function freshDemoOrders() {
  return structuredClone(demoOrders)
}

export const demoProducts: SellerProduct[] = [
  {
    productId: 101,
    categoryId: 1,
    categoryName: '시그니처',
    name: '블랙 세서미 크림 라떼',
    description: '고소한 흑임자 크림과 진한 에스프레소',
    imageUrl: null,
    basePrice: 6800,
    status: 'ACTIVE',
    soldOut: false,
    availableForQr: true,
    salesStartAt: null,
    salesEndAt: null,
    qrWebEnabled: true,
    customerAppEnabled: true,
  },
  {
    productId: 102,
    categoryId: 1,
    categoryName: '시그니처',
    name: '제주 말차 클라우드',
    description: '쌉싸름한 제주 말차와 부드러운 밀크 폼',
    imageUrl: null,
    basePrice: 7200,
    status: 'ACTIVE',
    soldOut: false,
    availableForQr: true,
    salesStartAt: null,
    salesEndAt: null,
    qrWebEnabled: true,
    customerAppEnabled: true,
  },
  {
    productId: 201,
    categoryId: 2,
    categoryName: '커피',
    name: '성수 블렌드 아메리카노',
    description: '다크 초콜릿과 견과의 긴 여운',
    imageUrl: null,
    basePrice: 4800,
    status: 'ACTIVE',
    soldOut: false,
    availableForQr: false,
    salesStartAt: null,
    salesEndAt: null,
    qrWebEnabled: false,
    customerAppEnabled: true,
  },
  {
    productId: 202,
    categoryId: 2,
    categoryName: '커피',
    name: '바닐라 빈 플랫화이트',
    description: '마다가스카르 바닐라 빈과 리스트레토',
    imageUrl: null,
    basePrice: 6200,
    status: 'ACTIVE',
    soldOut: true,
    availableForQr: false,
    salesStartAt: null,
    salesEndAt: null,
    qrWebEnabled: true,
    customerAppEnabled: true,
  },
  {
    productId: 301,
    categoryId: 3,
    categoryName: '디저트',
    name: '솔티드 카라멜 휘낭시에',
    description: '겉은 바삭하고 속은 촉촉한 오늘의 베이크',
    imageUrl: null,
    basePrice: 3900,
    status: 'ACTIVE',
    soldOut: false,
    availableForQr: true,
    salesStartAt: null,
    salesEndAt: null,
    qrWebEnabled: true,
    customerAppEnabled: true,
  },
]

export const demoCategories: SellerCategory[] = [
  { categoryId: 1, name: '시그니처', displayOrder: 0, status: 'ACTIVE' },
  { categoryId: 2, name: '커피', displayOrder: 1, status: 'ACTIVE' },
  { categoryId: 3, name: '디저트', displayOrder: 2, status: 'ACTIVE' },
]

export const demoTables: StoreTable[] = [
  { storeTableId: 7, tableCode: 'WINDOW-07', name: 'Window 07', status: 'ACTIVE' },
  { storeTableId: 8, tableCode: 'BAR-01', name: 'Bar 01', status: 'ACTIVE' },
  { storeTableId: 9, tableCode: 'TERRACE-02', name: 'Terrace 02', status: 'ACTIVE' },
]

export const demoQrCodes: QrCodeSummary[] = [
  {
    qrCodeId: 71,
    storeTableId: 7,
    tableName: 'Window 07',
    status: 'ACTIVE',
    expiresAt: '2027-07-29T14:59:59Z',
    createdAt: '2026-07-01T03:00:00Z',
  },
  {
    qrCodeId: 72,
    storeTableId: 8,
    tableName: 'Bar 01',
    status: 'ACTIVE',
    expiresAt: null,
    createdAt: '2026-07-04T03:00:00Z',
  },
  {
    qrCodeId: 73,
    storeTableId: 9,
    tableName: 'Terrace 02',
    status: 'INACTIVE',
    expiresAt: '2026-12-31T14:59:59Z',
    createdAt: '2026-07-08T03:00:00Z',
  },
]

export function freshDemoProducts() {
  return structuredClone(demoProducts)
}

export function freshDemoCategories() {
  return structuredClone(demoCategories)
}

export function createDemoProductDetail(product: SellerProduct) {
  const hasTemperature = product.categoryName !== '디저트'
  return {
    product: structuredClone(product),
    availability: {
      soldOut: product.soldOut,
      salesStartAt: product.salesStartAt,
      salesEndAt: product.salesEndAt,
      qrWebEnabled: product.qrWebEnabled,
      customerAppEnabled: product.customerAppEnabled,
    },
    optionGroups: hasTemperature
      ? [
          {
            optionGroupId: product.productId * 10,
            name: '온도',
            minSelect: 1,
            maxSelect: 1,
            required: true,
            displayOrder: 0,
            options: [
              {
                optionId: product.productId * 100 + 1,
                name: 'ICE',
                additionalPrice: 0,
                displayOrder: 0,
              },
              {
                optionId: product.productId * 100 + 2,
                name: 'HOT',
                additionalPrice: 0,
                displayOrder: 1,
              },
            ],
          },
        ]
      : [],
  }
}

export function freshDemoTables() {
  return structuredClone(demoTables)
}

export function freshDemoQrCodes() {
  return structuredClone(demoQrCodes)
}

export const demoStore: StoreSummary = {
  storeId: 1,
  storeType: 'LOCAL_STORE',
  name: '성수 라운지',
  description: '커피와 디저트를 편안하게 즐기는 성수동 라운지',
  status: 'ACTIVE',
  businessStatus: 'OPEN',
  myRole: 'OWNER',
}

export function createDemoSalesSummary(days: 7 | 30): SalesSummary {
  const end = new Date()
  const start = new Date(end)
  start.setDate(end.getDate() - days + 1)
  const pattern = [128000, 176500, 143000, 221500, 198000, 267500, 239000]
  const dailySales = Array.from({ length: days }, (_, index) => {
    const date = new Date(start)
    date.setDate(start.getDate() + index)
    const sales =
      pattern[index % pattern.length] +
      Math.floor(index / pattern.length) * 8500
    return {
      date: date.toISOString().slice(0, 10),
      sales,
      orderCount: Math.round(sales / 11000),
    }
  })
  const netSales = dailySales.reduce((sum, day) => sum + day.sales, 0)
  const completedOrderCount = dailySales.reduce(
    (sum, day) => sum + day.orderCount,
    0,
  )
  return {
    from: dailySales[0].date,
    to: dailySales.at(-1)!.date,
    netSales,
    completedOrderCount,
    averageOrderAmount: Math.round(netSales / completedOrderCount),
    dineInSales: Math.round(netSales * 0.68),
    takeoutSales: Math.round(netSales * 0.32),
    dailySales,
    topProducts: [
      { productName: '블랙 세서미 크림 라떼', quantity: days * 8, sales: days * 54400 },
      { productName: '제주 말차 클라우드', quantity: days * 6, sales: days * 43200 },
      { productName: '성수 블렌드 아메리카노', quantity: days * 7, sales: days * 33600 },
      { productName: '솔티드 카라멜 휘낭시에', quantity: days * 5, sales: days * 19500 },
    ],
  }
}

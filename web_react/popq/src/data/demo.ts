import type {
  OrderResponse,
  ProductDetail,
  ProductSummary,
  QrContext,
} from '../types'

export const demoContext: QrContext = {
  storeId: 1,
  storeName: '성수 라운지',
  storeType: 'LOCAL_STORE',
  businessStatus: 'OPEN',
  storeTableId: 7,
  tableName: 'Window 07',
  sessionExpiresAt: '2026-07-29T23:59:59Z',
}

export const demoProducts: ProductSummary[] = [
  {
    productId: 101,
    categoryId: 1,
    categoryName: '시그니처',
    name: '블랙 세서미 크림 라떼',
    description: '고소한 흑임자 크림과 진한 에스프레소의 균형',
    imageUrl: null,
    basePrice: 6800,
    status: 'ACTIVE',
    soldOut: false,
    availableForQr: true,
    visual: 'sesame',
    badge: 'BEST',
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
    visual: 'matcha',
    badge: 'NEW',
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
    availableForQr: true,
    visual: 'americano',
  },
  {
    productId: 202,
    categoryId: 2,
    categoryName: '커피',
    name: '바닐라 빈 플랫화이트',
    description: '마다가스카르 바닐라 빈과 진한 리스트레토',
    imageUrl: null,
    basePrice: 6200,
    status: 'ACTIVE',
    soldOut: false,
    availableForQr: true,
    visual: 'vanilla',
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
    visual: 'financier',
  },
  {
    productId: 302,
    categoryId: 3,
    categoryName: '디저트',
    name: '피스타치오 티라미수',
    description: '피스타치오 크림을 겹겹이 올린 시즌 디저트',
    imageUrl: null,
    basePrice: 7600,
    status: 'ACTIVE',
    soldOut: true,
    availableForQr: false,
    visual: 'tiramisu',
  },
]

export function demoProductDetail(product: ProductSummary): ProductDetail {
  const temperature = {
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
  }
  const shot = {
    optionGroupId: product.productId * 10 + 1,
    name: '샷 추가',
    minSelect: 0,
    maxSelect: 1,
    required: false,
    displayOrder: 1,
    options: [
      {
        optionId: product.productId * 100 + 3,
        name: '기본',
        additionalPrice: 0,
        displayOrder: 0,
      },
      {
        optionId: product.productId * 100 + 4,
        name: '에스프레소 샷 추가',
        additionalPrice: 700,
        displayOrder: 1,
      },
    ],
  }
  return {
    product,
    availability: {
      soldOut: product.soldOut,
      salesStartAt: null,
      salesEndAt: null,
      qrWebEnabled: true,
      customerAppEnabled: true,
    },
    optionGroups:
      product.categoryName === '디저트' ? [] : [temperature, shot],
  }
}

export function createDemoOrder(
  totalAmount: number,
  orderType: OrderResponse['orderType'],
): OrderResponse {
  return {
    orderPublicId: `demo-${crypto.randomUUID()}`,
    storeId: demoContext.storeId,
    storeName: demoContext.storeName,
    orderType,
    status: 'PLACED',
    subtotalAmount: totalAmount,
    discountAmount: 0,
    taxAmount: 0,
    serviceFeeAmount: 0,
    totalAmount,
    expiresAt: new Date(Date.now() + 15 * 60_000).toISOString(),
    version: 1,
    items: [],
    statusHistory: [
      {
        previousStatus: null,
        currentStatus: 'CREATED',
        actorType: 'GUEST',
        actorId: 1,
        reason: null,
        changedAt: new Date().toISOString(),
      },
      {
        previousStatus: 'CREATED',
        currentStatus: 'PLACED',
        actorType: 'SYSTEM',
        actorId: null,
        reason: '테스트 결제 승인',
        changedAt: new Date().toISOString(),
      },
    ],
  }
}

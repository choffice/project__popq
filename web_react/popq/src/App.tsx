import { useEffect, useMemo, useRef, useState } from 'react'
import './App.css'
import {
  createDemoOrder,
  demoContext,
  demoProductDetail,
  demoProducts,
} from './data/demo'
import {
  cancelOrder,
  confirmPayment,
  createOrder,
  getProductDetail,
  getProducts,
  openQrSession,
  syncOrder,
} from './services/api'
import { connectOrderRealtime } from './services/realtime'
import {
  clearTossPaymentReturn,
  readTossPaymentReturn,
  requestTossPayment,
} from './services/tossPayment'
import { useThemePreference } from './theme'
import { createClientId } from './utils/clientId'
import type {
  CartItem,
  OrderRealtimeEvent,
  OrderResponse,
  OrderStatus,
  OrderType,
  ProductDetail,
  ProductOption,
  ProductSummary,
  QrContext,
} from './types'

type Screen = 'menu' | 'cart' | 'tracking'
type CheckoutAttempt = {
  orderKey: string
  paymentKey: string
  order?: OrderResponse
}

const STATUS_SEQUENCE: OrderStatus[] = [
  'PLACED',
  'ACCEPTED',
  'PREPARING',
  'READY',
  'COMPLETED',
]

const STATUS_COPY: Record<
  OrderStatus,
  { title: string; description: string }
> = {
  CREATED: {
    title: '주문을 확인하고 있어요',
    description: '결제가 완료되면 매장으로 주문이 전달됩니다.',
  },
  PLACED: {
    title: '주문이 전달됐어요',
    description: '매장에서 주문을 확인하고 있습니다.',
  },
  ACCEPTED: {
    title: '주문을 접수했어요',
    description: '잠시 후 정성껏 준비를 시작합니다.',
  },
  PREPARING: {
    title: '맛있게 준비 중이에요',
    description: '완성까지 조금만 기다려 주세요.',
  },
  READY: {
    title: '주문이 준비됐어요',
    description: '픽업대에서 주문 번호를 확인해 주세요.',
  },
  COMPLETED: {
    title: '이용해 주셔서 고마워요',
    description: '오늘의 메뉴가 즐거운 순간이었길 바랍니다.',
  },
  CANCELED: {
    title: '주문이 취소됐어요',
    description: '결제 취소 내역은 잠시 후 확인할 수 있습니다.',
  },
  REJECTED: {
    title: '주문을 준비할 수 없어요',
    description: '결제 금액은 자동으로 취소됩니다.',
  },
  EXPIRED: {
    title: '결제 시간이 지났어요',
    description: '메뉴를 다시 담아 주문해 주세요.',
  },
}

function money(value: number) {
  return `${value.toLocaleString('ko-KR')}원`
}

function findQrToken() {
  const match = window.location.pathname.match(/^\/q\/([^/]+)$/)
  return match ? decodeURIComponent(match[1]) : null
}

function itemPrice(item: CartItem) {
  const optionPrice = item.options.reduce(
    (total, option) => total + option.additionalPrice,
    0,
  )
  return (item.product.basePrice + optionPrice) * item.quantity
}

function orderName(order: OrderResponse) {
  const first = order.items[0]?.productName ?? 'POPQ 주문'
  return order.items.length > 1 ? `${first} 외 ${order.items.length - 1}건` : first
}

function readStored<T>(storage: Storage, key: string, fallback: T): T {
  try {
    const value = storage.getItem(key)
    return value ? (JSON.parse(value) as T) : fallback
  } catch {
    return fallback
  }
}

function persistStored(storage: Storage, key: string, value: unknown) {
  try {
    if (value === null) storage.removeItem(key)
    else storage.setItem(key, JSON.stringify(value))
  } catch {
    // Private browsing or storage quota errors must not block ordering.
  }
}

function App() {
  const { theme, toggleTheme } = useThemePreference()
  const qrToken = findQrToken()
  const initialScope = qrToken ?? 'demo'
  const [isDemo, setIsDemo] = useState(!qrToken)
  const [context, setContext] = useState<QrContext | null>(
    qrToken ? null : demoContext,
  )
  const [products, setProducts] = useState<ProductSummary[]>(
    qrToken ? [] : demoProducts,
  )
  const [screen, setScreen] = useState<Screen>(() =>
    readStored<OrderResponse | null>(
      window.localStorage,
      `popq:order:${initialScope}`,
      null,
    )
      ? 'tracking'
      : 'menu',
  )
  const [category, setCategory] = useState('전체')
  const [selectedDetail, setSelectedDetail] =
    useState<ProductDetail | null>(null)
  const [selectedOptions, setSelectedOptions] = useState<
    Record<number, number[]>
  >({})
  const [quantity, setQuantity] = useState(1)
  const [cart, setCart] = useState<CartItem[]>(() =>
    readStored(window.localStorage, `popq:cart:${initialScope}`, []),
  )
  const [orderType, setOrderType] = useState<OrderType>(
    demoContext.storeTableId ? 'DINE_IN' : 'TAKEOUT',
  )
  const [order, setOrder] = useState<OrderResponse | null>(() =>
    readStored(
      window.localStorage,
      `popq:order:${initialScope}`,
      null,
    ),
  )
  const [checkoutAttempt, setCheckoutAttempt] =
    useState<CheckoutAttempt | null>(() =>
      readStored(
        window.sessionStorage,
        `popq:checkout:${initialScope}`,
        null,
      ),
    )
  const orderRef = useRef<OrderResponse | null>(null)
  const [loading, setLoading] = useState(Boolean(qrToken))
  const [processing, setProcessing] = useState(false)
  const [connected, setConnected] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [paymentReturn] = useState(() =>
    readTossPaymentReturn(window.location.search),
  )
  const paymentReturnHandled = useRef(false)
  const trackedOrderPublicId = order?.orderPublicId
  const storageScope = isDemo ? 'demo' : (qrToken ?? 'demo')
  const cartStorageKey = `popq:cart:${storageScope}`
  const orderStorageKey = `popq:order:${storageScope}`
  const checkoutStorageKey = `popq:checkout:${storageScope}`

  useEffect(() => {
    orderRef.current = order
  }, [order])

  useEffect(() => {
    persistStored(window.localStorage, cartStorageKey, cart)
  }, [cart, cartStorageKey])

  useEffect(() => {
    persistStored(window.localStorage, orderStorageKey, order)
  }, [order, orderStorageKey])

  useEffect(() => {
    persistStored(
      window.sessionStorage,
      checkoutStorageKey,
      checkoutAttempt,
    )
  }, [checkoutAttempt, checkoutStorageKey])

  useEffect(() => {
    if (
      !paymentReturn ||
      !qrToken ||
      isDemo ||
      paymentReturnHandled.current
    ) {
      return
    }
    const paymentResult = paymentReturn
    paymentReturnHandled.current = true
    setProcessing(true)
    setScreen('cart')
    setError(null)

    async function finishPayment() {
      if (paymentResult.status === 'fail') {
        clearTossPaymentReturn()
        throw new Error(paymentResult.message)
      }

      const pendingOrder = checkoutAttempt?.order
      if (!pendingOrder || !checkoutAttempt) {
        clearTossPaymentReturn()
        throw new Error('진행 중인 주문 정보를 찾지 못했습니다. 다시 주문해 주세요.')
      }
      if (
        paymentResult.orderId !== pendingOrder.orderPublicId ||
        paymentResult.amount !== pendingOrder.totalAmount
      ) {
        clearTossPaymentReturn()
        throw new Error('결제 인증 정보가 주문 정보와 일치하지 않습니다.')
      }

      await confirmPayment(
        pendingOrder.orderPublicId,
        checkoutAttempt.paymentKey,
        paymentResult.paymentKey,
      )
      const synced = await syncOrder(
        pendingOrder.orderPublicId,
        pendingOrder.version,
      )
      setOrder(synced.order ?? pendingOrder)
      setCart([])
      setCheckoutAttempt(null)
      setScreen('tracking')
      clearTossPaymentReturn()
    }

    void finishPayment()
      .catch((caught) => {
        setError(
          caught instanceof Error ? caught.message : '결제를 완료하지 못했습니다.',
        )
      })
      .finally(() => setProcessing(false))
  }, [checkoutAttempt, isDemo, paymentReturn, qrToken])

  useEffect(() => {
    if (!selectedDetail) return
    function closeOnEscape(event: KeyboardEvent) {
      if (event.key === 'Escape') setSelectedDetail(null)
    }
    window.addEventListener('keydown', closeOnEscape)
    return () => window.removeEventListener('keydown', closeOnEscape)
  }, [selectedDetail])

  useEffect(() => {
    if (!qrToken || isDemo) return
    let active = true
    async function loadLiveStore() {
      try {
        const opened = await openQrSession(qrToken as string)
        const menu = await getProducts()
        if (!active) return
        setContext(opened)
        setProducts(menu)
        setOrderType(opened.storeTableId ? 'DINE_IN' : 'TAKEOUT')
      } catch (caught) {
        if (active) {
          setError(
            caught instanceof Error
              ? caught.message
              : 'QR 메뉴를 불러오지 못했습니다.',
          )
        }
      } finally {
        if (active) setLoading(false)
      }
    }
    void loadLiveStore()
    return () => {
      active = false
    }
  }, [isDemo, qrToken])

  useEffect(() => {
    if (isDemo || screen !== 'tracking' || !trackedOrderPublicId) return
    const orderPublicId = trackedOrderPublicId

    async function recover() {
      const current = orderRef.current
      if (!current) return
      try {
        const synced = await syncOrder(orderPublicId, current.version)
        if (synced.refreshRequired && synced.order) setOrder(synced.order)
      } catch {
        setConnected(false)
      }
    }

    async function handleEvent(event: OrderRealtimeEvent) {
      const current = orderRef.current
      if (!current || event.version <= current.version) return
      if (event.version > current.version + 1) {
        await recover()
        return
      }
      setOrder({
        ...current,
        status: event.currentStatus,
        version: event.version,
        statusHistory: [
          ...current.statusHistory,
          {
            previousStatus: event.previousStatus,
            currentStatus: event.currentStatus,
            actorType: 'REALTIME',
            actorId: null,
            reason: null,
            changedAt: event.occurredAt,
          },
        ],
      })
    }

    return connectOrderRealtime(
      orderPublicId,
      (event) => void handleEvent(event),
      (nextConnected) => {
        setConnected(nextConnected)
        if (nextConnected) void recover()
      },
    )
  }, [isDemo, screen, trackedOrderPublicId])

  const categories = useMemo(
    () => ['전체', ...new Set(products.map((product) => product.categoryName))],
    [products],
  )
  const visibleProducts =
    category === '전체'
      ? products
      : products.filter((product) => product.categoryName === category)
  const cartCount = cart.reduce((total, item) => total + item.quantity, 0)
  const cartTotal = cart.reduce((total, item) => total + itemPrice(item), 0)
  const hasOrderShortcut = Boolean(order && screen === 'menu' && cartCount === 0)

  async function openProduct(product: ProductSummary) {
    if (!product.availableForQr) return
    setError(null)
    try {
      const detail = isDemo
        ? demoProductDetail(product)
        : await getProductDetail(product.productId)
      const defaults: Record<number, number[]> = {}
      detail.optionGroups.forEach((group) => {
        if (group.minSelect > 0 && group.options[0]) {
          defaults[group.optionGroupId] = [group.options[0].optionId]
        }
      })
      setSelectedDetail(detail)
      setSelectedOptions(defaults)
      setQuantity(1)
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : '상품을 불러오지 못했습니다.')
    }
  }

  function toggleOption(
    groupId: number,
    maxSelect: number,
    optionId: number,
  ) {
    setSelectedOptions((current) => {
      const selected = current[groupId] ?? []
      if (selected.includes(optionId)) {
        return {
          ...current,
          [groupId]: selected.filter((id) => id !== optionId),
        }
      }
      return {
        ...current,
        [groupId]:
          maxSelect === 1
            ? [optionId]
            : [...selected, optionId].slice(-maxSelect),
      }
    })
  }

  function addToCart() {
    if (!selectedDetail) return
    const valid = selectedDetail.optionGroups.every((group) => {
      const count = selectedOptions[group.optionGroupId]?.length ?? 0
      return count >= group.minSelect && count <= group.maxSelect
    })
    if (!valid) {
      setError('필수 옵션을 선택해 주세요.')
      return
    }
    const options = selectedDetail.optionGroups.flatMap((group) =>
      group.options.filter((option) =>
        selectedOptions[group.optionGroupId]?.includes(option.optionId),
      ),
    )
    setCart((current) => [
      ...current,
      {
        cartId: createClientId(),
        product: selectedDetail.product,
        quantity,
        options,
      },
    ])
    setCheckoutAttempt(null)
    setSelectedDetail(null)
    setError(null)
  }

  function changeCartQuantity(cartId: string, delta: number) {
    setCheckoutAttempt(null)
    setCart((current) =>
      current.flatMap((item) => {
        if (item.cartId !== cartId) return [item]
        const nextQuantity = item.quantity + delta
        return nextQuantity > 0 ? [{ ...item, quantity: nextQuantity }] : []
      }),
    )
  }

  async function checkout() {
    if (!cart.length) return
    setProcessing(true)
    setError(null)
    const attempt = checkoutAttempt ?? {
      orderKey: `order_${createClientId()}`,
      paymentKey: `payment_${createClientId()}`,
    }
    if (!checkoutAttempt) setCheckoutAttempt(attempt)
    try {
      if (isDemo) {
        await new Promise((resolve) => window.setTimeout(resolve, 650))
        setOrder(createDemoOrder(cartTotal, orderType))
      } else {
        const created =
          attempt.order ??
          (await createOrder(
            cart,
            orderType,
            attempt.orderKey,
          ))
        const preparedAttempt = { ...attempt, order: created }
        setCheckoutAttempt(preparedAttempt)
        persistStored(
          window.sessionStorage,
          checkoutStorageKey,
          preparedAttempt,
        )
        await requestTossPayment({
          clientKey: import.meta.env.VITE_POPQ_TOSS_CLIENT_KEY ?? '',
          orderId: created.orderPublicId,
          orderName: orderName(created),
          amount: created.totalAmount,
        })
        return
      }
      setCart([])
      setCheckoutAttempt(null)
      setScreen('tracking')
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : '주문에 실패했습니다.')
    } finally {
      setProcessing(false)
    }
  }

  function advanceDemoOrder() {
    if (!order || !isDemo) return
    const currentIndex = STATUS_SEQUENCE.indexOf(order.status)
    if (currentIndex < 0) return
    const next = STATUS_SEQUENCE[Math.min(currentIndex + 1, STATUS_SEQUENCE.length - 1)]
    if (!next || next === order.status) return
    setOrder({
      ...order,
      status: next,
      version: order.version + 1,
      statusHistory: [
        ...order.statusHistory,
        {
          previousStatus: order.status,
          currentStatus: next,
          actorType: 'SELLER',
          actorId: 1,
          reason: '데모 상태 진행',
          changedAt: new Date().toISOString(),
        },
      ],
    })
  }

  async function cancelCurrentOrder() {
    if (!order || order.status !== 'PLACED') return
    setProcessing(true)
    setError(null)
    try {
      if (isDemo) {
        setOrder({
          ...order,
          status: 'CANCELED',
          version: order.version + 1,
          statusHistory: [
            ...order.statusHistory,
            {
              previousStatus: order.status,
              currentStatus: 'CANCELED',
              actorType: 'GUEST',
              actorId: 1,
              reason: '고객 주문 취소',
              changedAt: new Date().toISOString(),
            },
          ],
        })
      } else {
        setOrder(await cancelOrder(order.orderPublicId))
      }
    } catch (caught) {
      setError(
        caught instanceof Error ? caught.message : '주문을 취소하지 못했습니다.',
      )
    } finally {
      setProcessing(false)
    }
  }

  function startNewOrder() {
    setOrder(null)
    setCategory('전체')
    setScreen('menu')
  }

  function useDemo() {
    setIsDemo(true)
    setContext(demoContext)
    setProducts(demoProducts)
    setOrderType('DINE_IN')
    setError(null)
    setLoading(false)
  }

  if (loading) {
    return (
      <main className="loading-screen">
        <div className="brand-mark">P</div>
        <p>테이블을 확인하고 있어요</p>
        <span className="loading-line" />
      </main>
    )
  }

  if (!context) {
    return (
      <main className="error-screen">
        <div className="error-orbit">!</div>
        <p className="eyebrow">POPQ QR ORDER</p>
        <h1>메뉴를 열 수 없어요</h1>
        <p>{error ?? '유효한 QR인지 다시 확인해 주세요.'}</p>
        <button className="primary-button" onClick={useDemo}>
          데모 메뉴 둘러보기
        </button>
      </main>
    )
  }

  return (
    <div className="app-shell">
      <header className="topbar">
        <button
          className="icon-button"
          aria-label="이전 화면"
          onClick={() => setScreen(screen === 'menu' ? 'menu' : 'menu')}
        >
          {screen === 'menu' ? 'P' : '←'}
        </button>
        <div className="store-heading">
          <strong>{context.storeName}</strong>
          <span>
            {context.tableName ?? 'Pickup'} · {isDemo ? 'Demo' : 'Live'}
          </span>
        </div>
        <div className="topbar-tools">
          <button
            className="icon-button theme-toggle"
            type="button"
            aria-label={theme === 'dark' ? '기본 모드로 전환' : '다크 모드로 전환'}
            aria-pressed={theme === 'dark'}
            onClick={toggleTheme}
          >
            <span aria-hidden="true">{theme === 'dark' ? '☀' : '☾'}</span>
          </button>
          <button
          className="icon-button bag-button"
          aria-label={
            hasOrderShortcut
              ? '진행 중 주문 보기'
              : `장바구니 ${cartCount}개`
          }
          onClick={() => setScreen(hasOrderShortcut ? 'tracking' : 'cart')}
        >
          {hasOrderShortcut ? '◎' : '◒'}
          {cartCount > 0 && <span>{cartCount}</span>}
          </button>
        </div>
      </header>

      {error && (
        <div className="toast" role="alert">
          <span>{error}</span>
          <button onClick={() => setError(null)}>닫기</button>
        </div>
      )}

      {screen === 'menu' && (
        <main>
          <section className="hero-panel">
            <div>
              <p className="eyebrow">ORDER AT YOUR PACE</p>
              <h1>
                오늘의 한 잔,
                <br />
                가볍게 골라보세요.
              </h1>
              <p className="hero-copy">
                QR로 주문하고 자리에서 편하게 기다리세요.
              </p>
            </div>
            <div className="hero-art" aria-hidden="true">
              <span className="hero-ring" />
              <span className="hero-cup" />
              <span className="hero-bean one" />
              <span className="hero-bean two" />
            </div>
          </section>

          {isDemo && (
            <div className="demo-note">
              <span>DEMO</span>
              백엔드 없이 전체 주문 흐름을 체험할 수 있어요.
            </div>
          )}

          <nav className="category-tabs" aria-label="메뉴 카테고리">
            {categories.map((item) => (
              <button
                key={item}
                className={category === item ? 'active' : ''}
                onClick={() => setCategory(item)}
              >
                {item}
              </button>
            ))}
          </nav>

          <section className="menu-section">
            <div className="section-heading">
              <div>
                <p className="eyebrow">CURATED MENU</p>
                <h2>{category === '전체' ? '모든 메뉴' : category}</h2>
              </div>
              <span>{visibleProducts.length} items</span>
            </div>
            <div className="product-grid">
              {visibleProducts.map((product, index) => (
                <button
                  className="product-card"
                  key={product.productId}
                  disabled={!product.availableForQr}
                  onClick={() => void openProduct(product)}
                >
                  <div
                    className={`product-visual ${product.visual ?? `tone-${index % 4}`}`}
                  >
                    {product.imageUrl ? (
                      <img src={product.imageUrl} alt="" />
                    ) : (
                      <>
                        <span className="visual-disc" />
                        <span className="visual-cup" />
                      </>
                    )}
                    {product.badge && <b>{product.badge}</b>}
                    {!product.availableForQr && (
                      <span className="sold-out">SOLD OUT</span>
                    )}
                  </div>
                  <div className="product-copy">
                    <span>{product.categoryName}</span>
                    <h3>{product.name}</h3>
                    <p>{product.description}</p>
                    <strong>{money(product.basePrice)}</strong>
                  </div>
                </button>
              ))}
            </div>
          </section>
        </main>
      )}

      {screen === 'cart' && (
        <main className="page-content cart-page">
          <p className="eyebrow">YOUR SELECTION</p>
          <h1>장바구니</h1>
          <div className="order-type">
            {context.storeTableId && (
              <button
                className={orderType === 'DINE_IN' ? 'active' : ''}
                onClick={() => {
                  setOrderType('DINE_IN')
                  setCheckoutAttempt(null)
                }}
              >
                매장에서
              </button>
            )}
            <button
              className={orderType === 'TAKEOUT' ? 'active' : ''}
              onClick={() => {
                setOrderType('TAKEOUT')
                setCheckoutAttempt(null)
              }}
            >
              포장해서
            </button>
          </div>
          {cart.length === 0 ? (
            <div className="empty-state">
              <div className="empty-cup" />
              <h2>아직 담긴 메뉴가 없어요</h2>
              <p>오늘 마음에 드는 한 잔을 골라보세요.</p>
              <button className="secondary-button" onClick={() => setScreen('menu')}>
                메뉴 보러 가기
              </button>
            </div>
          ) : (
            <>
              <div className="cart-list">
                {cart.map((item) => (
                  <article className="cart-item" key={item.cartId}>
                    <div className={`cart-thumb ${item.product.visual ?? ''}`}>
                      <span />
                    </div>
                    <div className="cart-item-copy">
                      <h3>{item.product.name}</h3>
                      <p>
                        {item.options.map((option) => option.name).join(' · ') ||
                          '기본 옵션'}
                      </p>
                      <strong>{money(itemPrice(item))}</strong>
                    </div>
                    <div className="stepper">
                      <button
                        aria-label="수량 줄이기"
                        onClick={() => changeCartQuantity(item.cartId, -1)}
                      >
                        −
                      </button>
                      <span>{item.quantity}</span>
                      <button
                        aria-label="수량 늘리기"
                        onClick={() => changeCartQuantity(item.cartId, 1)}
                      >
                        +
                      </button>
                    </div>
                  </article>
                ))}
              </div>
              <button className="add-more" onClick={() => setScreen('menu')}>
                + 메뉴 더 담기
              </button>
              <section className="price-summary">
                <div>
                  <span>상품 금액</span>
                  <span>{money(cartTotal)}</span>
                </div>
                <div>
                  <span>할인</span>
                  <span>0원</span>
                </div>
                <div className="total">
                  <strong>결제할 금액</strong>
                  <strong>{money(cartTotal)}</strong>
                </div>
              </section>
              <button
                className="primary-button checkout-button"
                disabled={processing}
                onClick={() => void checkout()}
              >
                {processing ? '주문을 전송하는 중…' : `${money(cartTotal)} 결제하기`}
              </button>
            </>
          )}
        </main>
      )}

      {screen === 'tracking' && order && (
        <main className="page-content tracking-page">
          <div className="tracking-hero">
            <p className="eyebrow">ORDER STATUS</p>
            <span className={`connection ${connected || isDemo ? 'on' : ''}`}>
              <i />
              {isDemo ? 'Demo live' : connected ? '실시간 연결됨' : '재연결 중'}
            </span>
            <div className={`status-orb status-${order.status.toLowerCase()}`}>
              <span>{order.status === 'COMPLETED' ? '✓' : order.version}</span>
            </div>
            <h1>{STATUS_COPY[order.status].title}</h1>
            <p>{STATUS_COPY[order.status].description}</p>
            <div className="order-number">
              ORDER <strong>{order.orderPublicId.slice(-8).toUpperCase()}</strong>
            </div>
          </div>

          <ol className="status-timeline">
            {STATUS_SEQUENCE.map((status, index) => {
              const currentIndex = STATUS_SEQUENCE.indexOf(order.status)
              const complete = currentIndex >= index
              return (
                <li className={complete ? 'complete' : ''} key={status}>
                  <span>{complete ? '✓' : index + 1}</span>
                  <div>
                    <strong>{STATUS_COPY[status].title}</strong>
                    <p>{status === order.status ? '현재 상태' : STATUS_COPY[status].description}</p>
                  </div>
                </li>
              )
            })}
          </ol>

          <div className="tracking-card">
            <span>{order.orderType === 'DINE_IN' ? '이용 위치' : '수령 방법'}</span>
            <strong>
              {order.orderType === 'DINE_IN'
                ? context.tableName
                : '매장 픽업대'}
            </strong>
            <span>결제 금액</span>
            <strong>{money(order.totalAmount)}</strong>
          </div>

          {isDemo &&
            STATUS_SEQUENCE.includes(order.status) &&
            order.status !== 'COMPLETED' && (
            <button className="primary-button" onClick={advanceDemoOrder}>
              데모 상태 다음으로
            </button>
          )}
          {order.status === 'PLACED' && (
            <button
              className="cancel-button"
              disabled={processing}
              onClick={() => void cancelCurrentOrder()}
            >
              {processing ? '취소 처리 중…' : '주문 취소'}
            </button>
          )}
          {['COMPLETED', 'CANCELED', 'REJECTED', 'EXPIRED'].includes(
            order.status,
          ) && (
            <button className="primary-button" onClick={startNewOrder}>
              새 주문 시작하기
            </button>
          )}
          <button className="text-button" onClick={() => setScreen('menu')}>
            메뉴로 돌아가기
          </button>
        </main>
      )}

      {screen === 'menu' && cartCount > 0 && (
        <button className="floating-cart" onClick={() => setScreen('cart')}>
          <span>{cartCount}</span>
          <strong>장바구니 보기</strong>
          <b>{money(cartTotal)}</b>
        </button>
      )}

      {selectedDetail && (
        <div className="sheet-backdrop" role="presentation">
          <section
            className="product-sheet"
            role="dialog"
            aria-modal="true"
            aria-label={`${selectedDetail.product.name} 옵션 선택`}
          >
            <button
              className="sheet-close"
              aria-label="닫기"
              onClick={() => setSelectedDetail(null)}
            >
              ×
            </button>
            <div
              className={`sheet-visual ${selectedDetail.product.visual ?? ''}`}
            >
              <span className="visual-disc" />
              <span className="visual-cup" />
            </div>
            <div className="sheet-content">
              <p className="eyebrow">{selectedDetail.product.categoryName}</p>
              <h2>{selectedDetail.product.name}</h2>
              <p className="sheet-description">
                {selectedDetail.product.description}
              </p>
              <strong className="sheet-price">
                {money(selectedDetail.product.basePrice)}
              </strong>

              {selectedDetail.optionGroups.map((group) => (
                <fieldset key={group.optionGroupId}>
                  <legend>
                    {group.name}
                    <span>{group.required ? '필수' : '선택'}</span>
                  </legend>
                  {group.options.map((option) => {
                    const checked = selectedOptions[group.optionGroupId]?.includes(
                      option.optionId,
                    )
                    return (
                      <label className="option-row" key={option.optionId}>
                        <input
                          type={group.maxSelect === 1 ? 'radio' : 'checkbox'}
                          name={`group-${group.optionGroupId}`}
                          checked={checked}
                          onChange={() =>
                            toggleOption(
                              group.optionGroupId,
                              group.maxSelect,
                              option.optionId,
                            )
                          }
                        />
                        <span>{option.name}</span>
                        <b>
                          {option.additionalPrice
                            ? `+${money(option.additionalPrice)}`
                            : '추가금 없음'}
                        </b>
                      </label>
                    )
                  })}
                </fieldset>
              ))}

              <div className="sheet-action">
                <div className="stepper large">
                  <button
                    aria-label="수량 줄이기"
                    onClick={() => setQuantity((value) => Math.max(1, value - 1))}
                  >
                    −
                  </button>
                  <span>{quantity}</span>
                  <button
                    aria-label="수량 늘리기"
                    onClick={() => setQuantity((value) => Math.min(99, value + 1))}
                  >
                    +
                  </button>
                </div>
                <button className="primary-button" onClick={addToCart}>
                  {money(
                    (selectedDetail.product.basePrice +
                      selectedDetail.optionGroups
                        .flatMap((group) => group.options)
                        .filter((option: ProductOption) =>
                          Object.values(selectedOptions)
                            .flat()
                            .includes(option.optionId),
                        )
                        .reduce(
                          (total, option) => total + option.additionalPrice,
                          0,
                        )) *
                      quantity,
                  )}{' '}
                  담기
                </button>
              </div>
            </div>
          </section>
        </div>
      )}
    </div>
  )
}

export default App

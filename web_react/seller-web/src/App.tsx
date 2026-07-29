import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import './App.css'
import { freshDemoOrders } from './data/demo'
import {
  getSellerPaymentSummary,
  getSellerOrders,
  refundSellerOrder,
  transitionSellerOrder,
} from './services/api'
import { connectSellerRealtime } from './services/realtime'
import { ProductManagement } from './features/catalog/ProductManagement'
import { QrManagement } from './features/qr/QrManagement'
import { SalesAnalytics } from './features/analytics/SalesAnalytics'
import { StoreSettings } from './features/store/StoreSettings'
import { AdminManagement } from './features/admin/AdminManagement'
import type {
  BusinessStatus,
  OrderRealtimeEvent,
  OrderStatus,
  SellerConnection,
  SellerOrder,
  SellerPaymentSummary,
} from './types'

type OrderFilter = 'ACTIVE' | OrderStatus
type SellerView =
  | 'orders'
  | 'products'
  | 'qr'
  | 'analytics'
  | 'settings'
  | 'admin'
type TransitionAction =
  | 'accept'
  | 'reject'
  | 'prepare'
  | 'ready'
  | 'complete'

const CONNECTION_KEY = 'popq:seller:connection'

const STATUS_COPY: Record<
  OrderStatus,
  { label: string; short: string }
> = {
  CREATED: { label: '결제 대기', short: '대기' },
  PLACED: { label: '신규 주문', short: '신규' },
  ACCEPTED: { label: '접수 완료', short: '접수' },
  PREPARING: { label: '준비 중', short: '준비' },
  READY: { label: '픽업 대기', short: '픽업' },
  COMPLETED: { label: '완료', short: '완료' },
  CANCELED: { label: '고객 취소', short: '취소' },
  REJECTED: { label: '주문 거절', short: '거절' },
  EXPIRED: { label: '시간 만료', short: '만료' },
}

const LANES: {
  title: string
  description: string
  statuses: OrderStatus[]
  tone: string
}[] = [
  {
    title: '새 주문',
    description: '결제 완료 · 접수 필요',
    statuses: ['PLACED'],
    tone: 'new',
  },
  {
    title: '준비 중',
    description: '접수부터 제조까지',
    statuses: ['ACCEPTED', 'PREPARING'],
    tone: 'making',
  },
  {
    title: '전달 대기',
    description: '픽업 또는 테이블 전달',
    statuses: ['READY'],
    tone: 'ready',
  },
]

const ACTIONS: Partial<
  Record<
    OrderStatus,
    {
      primary: { action: TransitionAction; label: string }
      secondary?: { action: TransitionAction; label: string }
    }
  >
> = {
  PLACED: {
    primary: { action: 'accept', label: '주문 접수' },
    secondary: { action: 'reject', label: '주문 거절' },
  },
  ACCEPTED: {
    primary: { action: 'prepare', label: '준비 시작' },
  },
  PREPARING: {
    primary: { action: 'ready', label: '준비 완료' },
  },
  READY: {
    primary: { action: 'complete', label: '전달 완료' },
  },
}

const TARGET_STATUS: Record<TransitionAction, OrderStatus> = {
  accept: 'ACCEPTED',
  reject: 'REJECTED',
  prepare: 'PREPARING',
  ready: 'READY',
  complete: 'COMPLETED',
}

const VIEW_COPY: Record<
  SellerView,
  { eyebrow: string; title: string }
> = {
  orders: { eyebrow: 'LIVE ORDER DESK', title: '오늘의 주문 운영' },
  products: { eyebrow: 'CATALOG CONTROL', title: '상품 관리' },
  qr: { eyebrow: 'TABLE ACCESS', title: 'QR 관리' },
  analytics: { eyebrow: 'SALES PULSE', title: '매출 분석' },
  settings: { eyebrow: 'STORE OPERATIONS', title: '스토어 설정' },
  admin: { eyebrow: 'PLATFORM CONTROL', title: '관리자 운영' },
}

function money(value: number) {
  return `${value.toLocaleString('ko-KR')}원`
}

function shortOrderId(orderPublicId: string) {
  return orderPublicId.slice(-4).toUpperCase()
}

function readConnection(): SellerConnection | null {
  try {
    const value = window.sessionStorage.getItem(CONNECTION_KEY)
    return value ? (JSON.parse(value) as SellerConnection) : null
  } catch {
    return null
  }
}

function lastChangedAt(order: SellerOrder) {
  const last = order.statusHistory.at(-1)?.changedAt
  return last ? new Date(last) : new Date()
}

function elapsedMinutes(order: SellerOrder, now: Date) {
  return Math.max(
    0,
    Math.floor((now.getTime() - lastChangedAt(order).getTime()) / 60_000),
  )
}

function demoPaymentSummary(order: SellerOrder): SellerPaymentSummary {
  const refunded = ['CANCELED', 'REJECTED'].includes(order.status)
  return {
    orderPublicId: order.orderPublicId,
    paymentStatus: refunded ? 'CANCELED' : 'PAID',
    paymentMethod: 'CARD',
    approvedAmount: order.totalAmount,
    refundedAmount: refunded ? order.totalAmount : 0,
    refundableAmount: refunded ? 0 : order.totalAmount,
    refunds: refunded
      ? [
          {
            refundId: order.version,
            amount: order.totalAmount,
            reason:
              order.status === 'REJECTED'
                ? '판매자 주문 거절'
                : '고객 주문 취소',
            requesterType:
              order.status === 'REJECTED' ? 'SELLER' : 'GUEST',
            status: 'SUCCEEDED',
            requestedAt:
              order.statusHistory.at(-1)?.changedAt ?? new Date().toISOString(),
            completedAt:
              order.statusHistory.at(-1)?.changedAt ?? new Date().toISOString(),
            failureCode: null,
            failureMessage: null,
          },
        ]
      : [],
  }
}

function App() {
  const [activeView, setActiveView] = useState<SellerView>('orders')
  const [connection, setConnection] = useState<SellerConnection | null>(
    readConnection,
  )
  const [orders, setOrders] = useState<SellerOrder[]>(() =>
    readConnection() ? [] : freshDemoOrders(),
  )
  const [selectedId, setSelectedId] = useState<string | null>(
    () => freshDemoOrders()[0]?.orderPublicId ?? null,
  )
  const [filter, setFilter] = useState<OrderFilter>('ACTIVE')
  const [now, setNow] = useState(new Date())
  const [businessStatus, setBusinessStatus] =
    useState<BusinessStatus>('OPEN')
  const [connected, setConnected] = useState(false)
  const [loading, setLoading] = useState(Boolean(readConnection()))
  const [processing, setProcessing] = useState(false)
  const [paymentLoading, setPaymentLoading] = useState(false)
  const [paymentSummary, setPaymentSummary] =
    useState<SellerPaymentSummary | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [showConnection, setShowConnection] = useState(false)
  const [draftStoreId, setDraftStoreId] = useState(
    String(readConnection()?.storeId ?? 1),
  )
  const [draftToken, setDraftToken] = useState('')
  const seenEvents = useRef(new Set<string>())
  const isDemo = !connection

  const loadOrders = useCallback(async () => {
    if (!connection) return
    setLoading(true)
    try {
      const nextOrders = await getSellerOrders(connection)
      setOrders(nextOrders)
      setSelectedId((current) =>
        current && nextOrders.some((order) => order.orderPublicId === current)
          ? current
          : (nextOrders[0]?.orderPublicId ?? null),
      )
      setError(null)
    } catch (caught) {
      setError(
        caught instanceof Error
          ? caught.message
          : '주문 목록을 불러오지 못했습니다.',
      )
    } finally {
      setLoading(false)
    }
  }, [connection])

  useEffect(() => {
    const timer = window.setInterval(() => setNow(new Date()), 30_000)
    return () => window.clearInterval(timer)
  }, [])

  useEffect(() => {
    if (!connection) return
    const initialLoad = window.setTimeout(() => void loadOrders(), 0)
    const disconnect = connectSellerRealtime(
      connection,
      (event: OrderRealtimeEvent) => {
        if (seenEvents.current.has(event.eventId)) return
        seenEvents.current.add(event.eventId)
        void loadOrders()
      },
      () => {
        setConnected(true)
        void loadOrders()
      },
      () => setConnected(false),
    )
    return () => {
      window.clearTimeout(initialLoad)
      disconnect()
    }
  }, [connection, loadOrders])

  const visibleOrders = useMemo(() => {
    if (filter === 'ACTIVE') {
      return orders.filter((order) =>
        ['PLACED', 'ACCEPTED', 'PREPARING', 'READY'].includes(order.status),
      )
    }
    return orders.filter((order) => order.status === filter)
  }, [filter, orders])

  const selectedOrder =
    orders.find((order) => order.orderPublicId === selectedId) ?? null

  useEffect(() => {
    const timer = window.setTimeout(() => {
      if (!selectedOrder) {
        setPaymentSummary(null)
        setPaymentLoading(false)
        return
      }
      if (!connection) {
        setPaymentSummary((current) =>
          current?.orderPublicId === selectedOrder.orderPublicId
            ? current
            : demoPaymentSummary(selectedOrder),
        )
        setPaymentLoading(false)
        return
      }
      setPaymentLoading(true)
      void getSellerPaymentSummary(connection, selectedOrder.orderPublicId)
        .then((summary) => {
          setPaymentSummary(summary)
          setError(null)
        })
        .catch((caught: unknown) => {
          setPaymentSummary(null)
          setError(
            caught instanceof Error
              ? caught.message
              : '결제 정보를 불러오지 못했습니다.',
          )
        })
        .finally(() => setPaymentLoading(false))
    }, 0)
    return () => window.clearTimeout(timer)
  }, [connection, selectedOrder])

  const openOrders = orders.filter((order) =>
    ['PLACED', 'ACCEPTED', 'PREPARING', 'READY'].includes(order.status),
  )
  const newOrderCount = orders.filter(
    (order) => order.status === 'PLACED',
  ).length
  const readyCount = orders.filter((order) => order.status === 'READY').length
  const completedSales = orders
    .filter((order) => order.status === 'COMPLETED')
    .reduce((total, order) => total + order.totalAmount, 0)

  async function changeStatus(
    order: SellerOrder,
    action: TransitionAction,
  ) {
    setProcessing(true)
    try {
      let updated: SellerOrder
      if (isDemo) {
        const target = TARGET_STATUS[action]
        updated = {
          ...order,
          status: target,
          version: order.version + 1,
          statusHistory: [
            ...order.statusHistory,
            {
              previousStatus: order.status,
              currentStatus: target,
              actorType: 'SELLER',
              actorId: 1,
              reason: action === 'reject' ? '데모 주문 거절' : '데모 상태 변경',
              changedAt: new Date().toISOString(),
            },
          ],
        }
      } else {
        updated = await transitionSellerOrder(
          connection,
          order.orderPublicId,
          action,
        )
      }
      setOrders((current) =>
        current.map((item) =>
          item.orderPublicId === updated.orderPublicId ? updated : item,
        ),
      )
      if (isDemo && action === 'reject') {
        setPaymentSummary(demoPaymentSummary(updated))
      }
      setSelectedId(updated.orderPublicId)
      setError(null)
    } catch (caught) {
      setError(
        caught instanceof Error
          ? caught.message
          : '주문 상태를 변경하지 못했습니다.',
      )
    } finally {
      setProcessing(false)
    }
  }

  async function refundOrder(order: SellerOrder, reason: string) {
    if (!paymentSummary || paymentSummary.refundableAmount <= 0) return
    setProcessing(true)
    try {
      let updated: SellerPaymentSummary
      if (isDemo) {
        const completedAt = new Date().toISOString()
        updated = {
          ...paymentSummary,
          paymentStatus: 'REFUNDED',
          refundedAmount: paymentSummary.approvedAmount,
          refundableAmount: 0,
          refunds: [
            ...paymentSummary.refunds,
            {
              refundId: paymentSummary.refunds.length + 1,
              amount: paymentSummary.approvedAmount,
              reason,
              requesterType: 'SELLER',
              status: 'SUCCEEDED',
              requestedAt: completedAt,
              completedAt,
              failureCode: null,
              failureMessage: null,
            },
          ],
        }
      } else {
        updated = await refundSellerOrder(
          connection,
          order.orderPublicId,
          paymentSummary.refundableAmount,
          reason,
        )
      }
      setPaymentSummary(updated)
      setError(null)
    } catch (caught) {
      setError(
        caught instanceof Error
          ? caught.message
          : '환불을 처리하지 못했습니다.',
      )
    } finally {
      setProcessing(false)
    }
  }

  function connectLive() {
    const storeId = Number(draftStoreId)
    if (!Number.isInteger(storeId) || storeId <= 0 || !draftToken.trim()) {
      setError('스토어 ID와 판매자 Access Token을 확인해 주세요.')
      return
    }
    const nextConnection = {
      storeId,
      accessToken: draftToken.trim(),
    }
    window.sessionStorage.setItem(
      CONNECTION_KEY,
      JSON.stringify(nextConnection),
    )
    setConnection(nextConnection)
    setOrders([])
    setSelectedId(null)
    setShowConnection(false)
  }

  function useDemo() {
    window.sessionStorage.removeItem(CONNECTION_KEY)
    setConnection(null)
    const demo = freshDemoOrders()
    setOrders(demo)
    setSelectedId(demo[0]?.orderPublicId ?? null)
    setConnected(false)
    setError(null)
    setShowConnection(false)
  }

  return (
    <div className="seller-shell">
      <aside className="sidebar">
        <div className="brand">
          <span className="brand-mark">P</span>
          <div>
            <strong>POPQ</strong>
            <small>SELLER</small>
          </div>
        </div>
        <nav aria-label="판매자 메뉴">
          <button
            className={activeView === 'orders' ? 'active' : ''}
            onClick={() => setActiveView('orders')}
          >
            <span>⌁</span>
            주문 운영
            {newOrderCount > 0 && <b>{newOrderCount}</b>}
          </button>
          <button
            className={activeView === 'products' ? 'active' : ''}
            onClick={() => setActiveView('products')}
          >
            <span>□</span>
            상품 관리
          </button>
          <button
            className={activeView === 'qr' ? 'active' : ''}
            onClick={() => setActiveView('qr')}
          >
            <span>⌗</span>
            QR 관리
          </button>
          <button
            className={activeView === 'analytics' ? 'active' : ''}
            onClick={() => setActiveView('analytics')}
          >
            <span>↗</span>
            매출 분석
          </button>
          <button
            className={activeView === 'settings' ? 'active' : ''}
            onClick={() => setActiveView('settings')}
          >
            <span>⚙</span>
            스토어 설정
          </button>
          <button
            className={activeView === 'admin' ? 'active' : ''}
            onClick={() => setActiveView('admin')}
          >
            <span>◇</span>
            관리자
          </button>
        </nav>
        <div className="sidebar-bottom">
          <button className="profile-button" onClick={() => setShowConnection(true)}>
            <span>SL</span>
            <div>
              <strong>성수 라운지</strong>
              <small>{isDemo ? '데모 운영자' : `스토어 ${connection.storeId}`}</small>
            </div>
            <b>···</b>
          </button>
        </div>
      </aside>

      <div className="workspace">
        <header className="topbar">
          <div>
            <p className="eyebrow">{VIEW_COPY[activeView].eyebrow}</p>
            <h1>{VIEW_COPY[activeView].title}</h1>
          </div>
          <div className="topbar-actions">
            <span className={`live-state ${connected || isDemo ? 'on' : ''}`}>
              <i />
              {isDemo ? 'Demo live' : connected ? '실시간 연결' : '재연결 중'}
            </span>
            <button
              className={`store-toggle ${
                businessStatus === 'OPEN' ? 'open' : ''
              }`}
              onClick={() => setActiveView('settings')}
              aria-pressed={businessStatus === 'OPEN'}
            >
              <span />
              {businessStatus === 'OPEN'
                ? '영업 중'
                : businessStatus === 'PRE_OPEN'
                  ? '오픈 준비'
                  : '영업 종료'}
            </button>
            <button
              className="icon-button"
              aria-label="연결 설정"
              onClick={() => setShowConnection(true)}
            >
              ⚙
            </button>
          </div>
        </header>

        {error && (
          <div className="alert" role="alert">
            <span>{error}</span>
            <button onClick={() => setError(null)}>닫기</button>
          </div>
        )}

        {activeView === 'orders' && <main>
          <section className="pulse-strip" aria-label="오늘 운영 현황">
            <div className="pulse-intro">
              <span>{now.toLocaleDateString('ko-KR', { month: 'long', day: 'numeric' })}</span>
              <strong>
                {now.toLocaleTimeString('ko-KR', {
                  hour: '2-digit',
                  minute: '2-digit',
                })}
              </strong>
              <p>성수 라운지의 주문 흐름이 안정적입니다.</p>
            </div>
            <article>
              <span className="metric-icon coral">↘</span>
              <div>
                <small>진행 주문</small>
                <strong>{openOrders.length}</strong>
                <p>지금 처리할 주문</p>
              </div>
            </article>
            <article>
              <span className="metric-icon lime">!</span>
              <div>
                <small>신규 접수</small>
                <strong>{newOrderCount}</strong>
                <p>평균 대기 5분</p>
              </div>
            </article>
            <article>
              <span className="metric-icon violet">✓</span>
              <div>
                <small>전달 대기</small>
                <strong>{readyCount}</strong>
                <p>픽업 확인 필요</p>
              </div>
            </article>
            <article>
              <span className="metric-icon cream">₩</span>
              <div>
                <small>완료 매출</small>
                <strong>{money(completedSales)}</strong>
                <p>현재 세션 기준</p>
              </div>
            </article>
          </section>

          <section className="orders-section">
            <div className="section-head">
              <div>
                <p className="eyebrow">ORDER FLOW</p>
                <h2>주문 보드</h2>
              </div>
              <div className="filters" aria-label="주문 필터">
                {(
                  [
                    ['ACTIVE', '진행 중'],
                    ['PLACED', '신규'],
                    ['READY', '전달 대기'],
                    ['COMPLETED', '완료'],
                  ] as [OrderFilter, string][]
                ).map(([value, label]) => (
                  <button
                    key={value}
                    className={filter === value ? 'active' : ''}
                    onClick={() => setFilter(value)}
                  >
                    {label}
                  </button>
                ))}
              </div>
              <button
                className="refresh-button"
                onClick={() =>
                  isDemo ? setOrders(freshDemoOrders()) : void loadOrders()
                }
                disabled={loading}
              >
                {loading ? '불러오는 중…' : '↻ 새로고침'}
              </button>
            </div>

            {filter === 'ACTIVE' ? (
              <div className="order-board">
                {LANES.map((lane) => {
                  const laneOrders = visibleOrders.filter((order) =>
                    lane.statuses.includes(order.status),
                  )
                  return (
                    <section className={`lane lane-${lane.tone}`} key={lane.title}>
                      <header>
                        <div>
                          <span />
                          <strong>{lane.title}</strong>
                          <b>{laneOrders.length}</b>
                        </div>
                        <small>{lane.description}</small>
                      </header>
                      <div className="lane-list">
                        {laneOrders.map((order) => (
                          <OrderCard
                            key={order.orderPublicId}
                            order={order}
                            now={now}
                            selected={order.orderPublicId === selectedId}
                            onSelect={() => setSelectedId(order.orderPublicId)}
                          />
                        ))}
                        {laneOrders.length === 0 && (
                          <div className="lane-empty">
                            <span>✓</span>
                            <p>대기 중인 주문이 없습니다.</p>
                          </div>
                        )}
                      </div>
                    </section>
                  )
                })}
              </div>
            ) : (
              <div className="filtered-list">
                {visibleOrders.map((order) => (
                  <OrderCard
                    key={order.orderPublicId}
                    order={order}
                    now={now}
                    selected={order.orderPublicId === selectedId}
                    onSelect={() => setSelectedId(order.orderPublicId)}
                  />
                ))}
                {visibleOrders.length === 0 && (
                  <div className="list-empty">해당 상태의 주문이 없습니다.</div>
                )}
              </div>
            )}
          </section>
        </main>}
        {activeView === 'products' && (
          <ProductManagement connection={connection} onError={setError} />
        )}
        {activeView === 'qr' && (
          <QrManagement connection={connection} onError={setError} />
        )}
        {activeView === 'analytics' && (
          <SalesAnalytics connection={connection} onError={setError} />
        )}
        {activeView === 'settings' && (
          <StoreSettings
            connection={connection}
            onError={setError}
            onBusinessStatusChange={setBusinessStatus}
          />
        )}
        {activeView === 'admin' && (
          <AdminManagement connection={connection} onError={setError} />
        )}
      </div>

      <aside
        className={`detail-panel ${
          selectedOrder && activeView === 'orders' ? 'open' : ''
        }`}
      >
        {selectedOrder && activeView === 'orders' && (
          <OrderDetail
            key={selectedOrder.orderPublicId}
            order={selectedOrder}
            processing={processing}
            paymentLoading={paymentLoading}
            paymentSummary={paymentSummary}
            onClose={() => setSelectedId(null)}
            onAction={(action) => void changeStatus(selectedOrder, action)}
            onRefund={(reason) => void refundOrder(selectedOrder, reason)}
          />
        )}
      </aside>

      {showConnection && (
        <div className="modal-backdrop" role="presentation">
          <section
            className="connection-modal"
            role="dialog"
            aria-modal="true"
            aria-labelledby="connection-title"
          >
            <button
              className="modal-close"
              aria-label="닫기"
              onClick={() => setShowConnection(false)}
            >
              ×
            </button>
            <p className="eyebrow">CONNECTION</p>
            <h2 id="connection-title">백엔드 연결</h2>
            <p>
              발급받은 판매자 Access Token은 이 브라우저 탭이 열려 있는 동안만
              보관됩니다.
            </p>
            <label>
              스토어 ID
              <input
                inputMode="numeric"
                value={draftStoreId}
                onChange={(event) => setDraftStoreId(event.target.value)}
              />
            </label>
            <label>
              Access Token
              <textarea
                rows={4}
                placeholder="Bearer 접두사 없이 입력"
                value={draftToken}
                onChange={(event) => setDraftToken(event.target.value)}
              />
            </label>
            <button className="primary-action" onClick={connectLive}>
              실제 백엔드 연결
            </button>
            <button className="secondary-action" onClick={useDemo}>
              데모 데이터 사용
            </button>
          </section>
        </div>
      )}
    </div>
  )
}

function OrderCard({
  order,
  now,
  selected,
  onSelect,
}: {
  order: SellerOrder
  now: Date
  selected: boolean
  onSelect: () => void
}) {
  const itemCount = order.items.reduce(
    (total, item) => total + item.quantity,
    0,
  )
  return (
    <button
      className={`order-card ${selected ? 'selected' : ''}`}
      onClick={onSelect}
      aria-label={`주문 ${shortOrderId(order.orderPublicId)} 상세 보기`}
    >
      <div className="card-top">
        <div>
          <span className={`type-badge ${order.orderType.toLowerCase()}`}>
            {order.orderType === 'DINE_IN' ? '매장' : '포장'}
          </span>
          <strong>#{shortOrderId(order.orderPublicId)}</strong>
        </div>
        <time>{elapsedMinutes(order, now)}분 전</time>
      </div>
      <div className="card-items">
        {order.items.slice(0, 2).map((item) => (
          <p key={item.orderItemId}>
            <span>{item.productName}</span>
            <b>×{item.quantity}</b>
          </p>
        ))}
        {order.items.length > 2 && <small>외 {order.items.length - 2}개</small>}
      </div>
      <div className="card-bottom">
        <span>{itemCount}개 메뉴</span>
        <strong>{money(order.totalAmount)}</strong>
      </div>
    </button>
  )
}

function OrderDetail({
  order,
  processing,
  paymentLoading,
  paymentSummary,
  onClose,
  onAction,
  onRefund,
}: {
  order: SellerOrder
  processing: boolean
  paymentLoading: boolean
  paymentSummary: SellerPaymentSummary | null
  onClose: () => void
  onAction: (action: TransitionAction) => void
  onRefund: (reason: string) => void
}) {
  const [showRefundForm, setShowRefundForm] = useState(false)
  const [refundReason, setRefundReason] = useState('')
  const actions = ACTIONS[order.status]
  const canRefund =
    order.status === 'COMPLETED' &&
    paymentSummary?.paymentStatus === 'PAID' &&
    paymentSummary.refundableAmount > 0
  const paymentStatus =
    paymentSummary?.paymentStatus === 'REFUNDED'
      ? '환불 완료'
      : paymentSummary?.paymentStatus === 'CANCELED'
        ? '결제 취소'
        : paymentSummary?.paymentStatus === 'PAID'
          ? '결제 완료'
          : '확인 중'
  return (
    <>
      <header className="detail-head">
        <div>
          <p className="eyebrow">ORDER DETAIL</p>
          <h2>#{shortOrderId(order.orderPublicId)}</h2>
        </div>
        <button aria-label="상세 닫기" onClick={onClose}>
          ×
        </button>
      </header>
      <div className="detail-status">
        <span className={`status-dot status-${order.status.toLowerCase()}`} />
        <div>
          <small>현재 상태</small>
          <strong>{STATUS_COPY[order.status].label}</strong>
        </div>
        <b>v{order.version}</b>
      </div>
      <div className="detail-meta">
        <div>
          <small>주문 유형</small>
          <strong>
            {order.orderType === 'DINE_IN' ? '매장 이용' : '포장 주문'}
          </strong>
        </div>
        <div>
          <small>주문 시각</small>
          <strong>
            {lastChangedAt(order).toLocaleTimeString('ko-KR', {
              hour: '2-digit',
              minute: '2-digit',
            })}
          </strong>
        </div>
      </div>
      <section className="detail-items">
        <h3>주문 메뉴</h3>
        {order.items.map((item) => (
          <article key={item.orderItemId}>
            <span>{item.quantity}</span>
            <div>
              <strong>{item.productName}</strong>
              <p>
                {item.options.map((option) => option.optionName).join(' · ') ||
                  '기본 옵션'}
              </p>
            </div>
            <b>{money(item.itemTotalPrice)}</b>
          </article>
        ))}
      </section>
      <div className="detail-total">
        <span>결제 금액</span>
        <strong>{money(order.totalAmount)}</strong>
      </div>
      <section className="payment-refund">
        <header>
          <div>
            <small>PAYMENT</small>
            <h3>결제·환불</h3>
          </div>
          <span
            className={`payment-status ${
              paymentSummary?.paymentStatus.toLowerCase() ?? 'loading'
            }`}
          >
            {paymentLoading ? '불러오는 중' : paymentStatus}
          </span>
        </header>
        {paymentSummary && (
          <>
            <div className="payment-amounts">
              <p>
                <span>승인 금액</span>
                <strong>{money(paymentSummary.approvedAmount)}</strong>
              </p>
              <p>
                <span>환불 금액</span>
                <strong>{money(paymentSummary.refundedAmount)}</strong>
              </p>
            </div>
            {paymentSummary.refunds.length > 0 && (
              <div className="refund-history">
                {paymentSummary.refunds.map((refund) => (
                  <article key={refund.refundId}>
                    <div>
                      <strong>{refund.reason}</strong>
                      <small>
                        {refund.requesterType === 'SELLER'
                          ? '판매자 요청'
                          : '고객 요청'}
                      </small>
                    </div>
                    <p>
                      <b>{money(refund.amount)}</b>
                      <span>
                        {refund.status === 'SUCCEEDED'
                          ? '완료'
                          : refund.status === 'FAILED'
                            ? '실패'
                            : '처리 중'}
                      </span>
                    </p>
                  </article>
                ))}
              </div>
            )}
            {canRefund && !showRefundForm && (
              <button
                className="refund-open"
                onClick={() => setShowRefundForm(true)}
              >
                전액 환불
              </button>
            )}
            {canRefund && showRefundForm && (
              <div className="refund-form">
                <label>
                  환불 사유
                  <textarea
                    rows={3}
                    value={refundReason}
                    placeholder="고객에게 안내할 환불 사유"
                    onChange={(event) => setRefundReason(event.target.value)}
                  />
                </label>
                <p>
                  {money(paymentSummary.refundableAmount)} 전액이 환불되며
                  되돌릴 수 없습니다.
                </p>
                <div>
                  <button
                    className="secondary-action"
                    onClick={() => setShowRefundForm(false)}
                  >
                    취소
                  </button>
                  <button
                    className="refund-confirm"
                    disabled={processing || !refundReason.trim()}
                    onClick={() => onRefund(refundReason.trim())}
                  >
                    {processing ? '환불 처리 중…' : '전액 환불 확정'}
                  </button>
                </div>
              </div>
            )}
          </>
        )}
      </section>
      <section className="history">
        <h3>최근 처리</h3>
        {order.statusHistory.slice(-2).reverse().map((entry) => (
          <div key={`${entry.currentStatus}-${entry.changedAt}`}>
            <span />
            <p>
              <strong>{STATUS_COPY[entry.currentStatus].short}</strong>
              <small>{entry.reason ?? '상태가 변경되었습니다.'}</small>
            </p>
            <time>
              {new Date(entry.changedAt).toLocaleTimeString('ko-KR', {
                hour: '2-digit',
                minute: '2-digit',
              })}
            </time>
          </div>
        ))}
      </section>
      {actions ? (
        <div className="detail-actions">
          {actions.secondary && (
            <button
              className="reject-action"
              disabled={processing}
              onClick={() => onAction(actions.secondary!.action)}
            >
              {actions.secondary.label}
            </button>
          )}
          <button
            className="primary-action"
            disabled={processing}
            onClick={() => onAction(actions.primary.action)}
          >
            {processing ? '처리 중…' : actions.primary.label}
          </button>
        </div>
      ) : (
        <div className="terminal-note">
          이 주문의 처리가 종료되었습니다.
        </div>
      )}
    </>
  )
}

export default App

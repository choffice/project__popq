import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import './App.css'
import { freshDemoOrders } from './data/demo'
import {
  getSellerPaymentSummary,
  getSellerOrders,
  getSellerStores,
  getSellerUnreadConversationCount,
  refundSellerOrder,
  transitionSellerOrder,
} from './services/api'
import { connectSellerRealtime } from './services/realtime'
import { useThemePreference } from './theme'
import { ProductManagement } from './features/catalog/ProductManagement'
import { QrManagement } from './features/qr/QrManagement'
import { SalesAnalytics } from './features/analytics/SalesAnalytics'
import { StoreSettings } from './features/store/StoreSettings'
import { AdminManagement } from './features/admin/AdminManagement'
import { AdminContentManagement } from './features/admin/AdminContentManagement'
import { AdminSupportManagement } from './features/admin/AdminSupportManagement'
import { AnnouncementManagement } from './features/announcements/AnnouncementManagement'
import { SellerAuth } from './features/auth/SellerAuth'
import { MessageManagement } from './features/messages/MessageManagement'
import { ReviewManagement } from './features/reviews/ReviewManagement'
import type {
  BusinessStatus,
  OrderRealtimeEvent,
  OrderStatus,
  SellerConnection,
  SellerOrder,
  SellerPaymentSummary,
  StoreSummary,
} from './types'

type OrderFilter = 'ACTIVE' | OrderStatus
type SellerView =
  | 'orders'
  | 'products'
  | 'qr'
  | 'analytics'
  | 'announcements'
  | 'messages'
  | 'reviews'
  | 'settings'
  | 'admin-customers'
  | 'admin-sellers'
  | 'admin-stores'
  | 'admin-announcements'
  | 'admin-support'
  | 'admin-faqs'
type TransitionAction =
  | 'accept'
  | 'reject'
  | 'prepare'
  | 'ready'
  | 'complete'
type TransitionOptions = {
  reason?: string
  preparationMinutes?: number
  applyAsStoreDefault?: boolean
}

const CONNECTION_KEY = 'popq:seller:connection'
const DEMO_KEY = 'popq:seller:demo'

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
  announcements: { eyebrow: 'STORE ANNOUNCEMENTS', title: '공지사항' },
  messages: { eyebrow: 'CUSTOMER CONVERSATIONS', title: '고객 문의' },
  reviews: { eyebrow: 'CUSTOMER REVIEWS', title: '리뷰 관리' },
  settings: { eyebrow: 'STORE OPERATIONS', title: '스토어 설정' },
  'admin-customers': { eyebrow: 'MEMBER CONTROL', title: '구매자 회원 관리' },
  'admin-sellers': { eyebrow: 'SELLER CONTROL', title: '판매자 회원 · 인증' },
  'admin-stores': { eyebrow: 'STORE CONTROL', title: '스토어 관리' },
  'admin-announcements': { eyebrow: 'PLATFORM CONTENT', title: '플랫폼 공지' },
  'admin-support': { eyebrow: 'CUSTOMER SUPPORT', title: '문의 관리' },
  'admin-faqs': { eyebrow: 'PLATFORM CONTENT', title: 'FAQ 관리' },
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

function readDemoMode() {
  return window.sessionStorage.getItem(DEMO_KEY) === 'true'
}

function connectionScope(connection: SellerConnection | null) {
  if (!connection) return null
  return `${connection.user?.userId ?? 'anonymous'}:${connection.storeId ?? 'admin'}:${connection.accessToken}`
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
  const { theme, toggleTheme } = useThemePreference()
  const [activeView, setActiveView] = useState<SellerView>(() =>
    readConnection()?.user?.role === 'ADMIN' ? 'admin-customers' : 'orders',
  )
  const [connection, setConnection] = useState<SellerConnection | null>(
    readConnection,
  )
  const [authenticated, setAuthenticated] = useState(
    () => Boolean(readConnection()) || readDemoMode(),
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
  const [accountStores, setAccountStores] = useState<StoreSummary[]>([])
  const [accountStoresLoading, setAccountStoresLoading] = useState(false)
  const [accountStoresError, setAccountStoresError] = useState<string | null>(null)
  const [unreadMessageCount, setUnreadMessageCount] = useState(0)
  const seenEvents = useRef(new Set<string>())
  const accountRequestId = useRef(0)
  const activeConnectionScope = useRef(connectionScope(connection))
  const isDemo = authenticated && !connection
  const isAdmin = connection?.user?.role === 'ADMIN'
  const resolvedStoreRole =
    connection?.storeRole ??
    accountStores.find((store) => store.storeId === connection?.storeId)?.myRole
  const canManageStore =
    isDemo ||
    resolvedStoreRole === 'OWNER' ||
    resolvedStoreRole === 'MANAGER'
  const storeScopeKey = isDemo ? 'demo' : `store-${connection?.storeId ?? 'none'}`

  const loadOrders = useCallback(async () => {
    if (!connection || connection.user?.role === 'ADMIN') return
    const requestScope = connectionScope(connection)
    setLoading(true)
    try {
      const nextOrders = await getSellerOrders(connection)
      if (activeConnectionScope.current !== requestScope) return
      setOrders(nextOrders)
      setSelectedId((current) =>
        current && nextOrders.some((order) => order.orderPublicId === current)
          ? current
          : (nextOrders[0]?.orderPublicId ?? null),
      )
      setError(null)
    } catch (caught) {
      if (activeConnectionScope.current !== requestScope) return
      setError(
        caught instanceof Error
          ? caught.message
          : '주문 목록을 불러오지 못했습니다.',
      )
    } finally {
      if (activeConnectionScope.current === requestScope) {
        setLoading(false)
      }
    }
  }, [connection])

  useEffect(() => {
    const timer = window.setInterval(() => setNow(new Date()), 30_000)
    return () => window.clearInterval(timer)
  }, [])

  useEffect(() => {
    if (!connection || connection.user?.role === 'ADMIN') return
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

  useEffect(() => {
    if (!connection || isAdmin) {
      return
    }
    let active = true
    const refreshAccount = async () => {
      try {
        const [stores, unread] = await Promise.all([
          getSellerStores(connection),
          getSellerUnreadConversationCount(connection),
        ])
        if (!active) return
        setUnreadMessageCount(unread)
        setAccountStores(stores)
        const currentStore = stores.find(
          (store) => store.storeId === connection.storeId,
        )
        if (
          currentStore &&
          (connection.storeRole !== currentStore.myRole ||
            connection.storeName !== currentStore.name)
        ) {
          const next = {
            ...connection,
            storeName: currentStore.name,
            storeRole: currentStore.myRole,
          }
          window.sessionStorage.setItem(CONNECTION_KEY, JSON.stringify(next))
        }
      } catch {
        // Feature screens surface request failures when the user opens them.
      }
    }
    void refreshAccount()
    const timer = window.setInterval(() => {
      void getSellerUnreadConversationCount(connection)
        .then((count) => {
          if (active) setUnreadMessageCount(count)
        })
        .catch(() => undefined)
    }, 30_000)
    return () => {
      active = false
      window.clearInterval(timer)
    }
  }, [connection, isAdmin])

  function openAccount() {
    setShowConnection(true)
    if (!connection || isAdmin) return
    const requestId = accountRequestId.current + 1
    accountRequestId.current = requestId
    setAccountStoresLoading(true)
    setAccountStoresError(null)
    void getSellerStores(connection)
      .then((stores) => {
        if (accountRequestId.current === requestId) setAccountStores(stores)
      })
      .catch((caught: unknown) => {
        if (accountRequestId.current !== requestId) return
        setAccountStoresError(
          caught instanceof Error
            ? caught.message
            : '스토어 목록을 불러오지 못했습니다.',
        )
      })
      .finally(() => {
        if (accountRequestId.current === requestId) {
          setAccountStoresLoading(false)
        }
      })
  }

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
    let active = true
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
          if (!active) return
          setPaymentSummary(summary)
          setError(null)
        })
        .catch((caught: unknown) => {
          if (!active) return
          setPaymentSummary(null)
          setError(
            caught instanceof Error
              ? caught.message
              : '결제 정보를 불러오지 못했습니다.',
          )
        })
        .finally(() => {
          if (active) setPaymentLoading(false)
        })
    }, 0)
    return () => {
      active = false
      window.clearTimeout(timer)
    }
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
    options?: TransitionOptions,
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
          preparationMinutes:
            action === 'accept'
              ? (options?.preparationMinutes ?? 0)
              : order.preparationMinutes,
          estimatedReadyAt:
            action === 'accept'
              ? new Date(Date.now() + (options?.preparationMinutes ?? 0) * 60_000).toISOString()
              : order.estimatedReadyAt,
          statusHistory: [
            ...order.statusHistory,
            {
              previousStatus: order.status,
              currentStatus: target,
              actorType: 'SELLER',
              actorId: 1,
              reason: options?.reason ?? (action === 'reject' ? '데모 주문 거절' : '데모 상태 변경'),
              changedAt: new Date().toISOString(),
            },
          ],
        }
      } else {
        updated = await transitionSellerOrder(
          connection!,
          order.orderPublicId,
          action,
          options,
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

  async function refundOrder(
    order: SellerOrder,
    amount: number,
    reason: string,
  ) {
    if (
      !paymentSummary ||
      amount <= 0 ||
      amount > paymentSummary.refundableAmount
    ) return
    setProcessing(true)
    try {
      let updated: SellerPaymentSummary
      if (isDemo) {
        const completedAt = new Date().toISOString()
        updated = {
          ...paymentSummary,
          paymentStatus:
            amount === paymentSummary.refundableAmount
              ? 'REFUNDED'
              : 'PARTIALLY_REFUNDED',
          refundedAmount: paymentSummary.refundedAmount + amount,
          refundableAmount: paymentSummary.refundableAmount - amount,
          refunds: [
            ...paymentSummary.refunds,
            {
              refundId: paymentSummary.refunds.length + 1,
              amount,
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
          connection!,
          order.orderPublicId,
          amount,
          reason,
        )
      }
      setPaymentSummary(updated)
      setError(null)
    } catch (caught) {
      if (connection) {
        try {
          setPaymentSummary(
            await getSellerPaymentSummary(connection, order.orderPublicId),
          )
        } catch {
          // Preserve the original refund error if recovery refresh also fails.
        }
      }
      setError(
        caught instanceof Error
          ? caught.message
          : '환불을 처리하지 못했습니다.',
      )
    } finally {
      setProcessing(false)
    }
  }

  function authenticate(nextConnection: SellerConnection) {
    window.sessionStorage.setItem(
      CONNECTION_KEY,
      JSON.stringify(nextConnection),
    )
    window.sessionStorage.removeItem(DEMO_KEY)
    activeConnectionScope.current = connectionScope(nextConnection)
    setConnection(nextConnection)
    setAuthenticated(true)
    setActiveView(nextConnection.user?.role === 'ADMIN' ? 'admin-customers' : 'orders')
    setOrders([])
    setSelectedId(null)
    setConnected(false)
    setUnreadMessageCount(0)
    setError(null)
    setShowConnection(false)
  }

  function useDemo() {
    window.sessionStorage.removeItem(CONNECTION_KEY)
    window.sessionStorage.setItem(DEMO_KEY, 'true')
    activeConnectionScope.current = null
    setConnection(null)
    setAuthenticated(true)
    setActiveView('orders')
    const demo = freshDemoOrders()
    setOrders(demo)
    setSelectedId(demo[0]?.orderPublicId ?? null)
    setConnected(false)
    setUnreadMessageCount(0)
    setError(null)
    setShowConnection(false)
  }

  function signOut() {
    window.sessionStorage.removeItem(CONNECTION_KEY)
    window.sessionStorage.removeItem(DEMO_KEY)
    activeConnectionScope.current = null
    setConnection(null)
    setAuthenticated(false)
    setActiveView('orders')
    setOrders([])
    setSelectedId(null)
    setConnected(false)
    setUnreadMessageCount(0)
    setError(null)
    setShowConnection(false)
  }

  function switchStore(store: StoreSummary) {
    if (!connection || connection.storeId === store.storeId) return
    const nextConnection: SellerConnection = {
      ...connection,
      storeId: store.storeId,
      storeName: store.name,
      storeRole: store.myRole,
    }
    window.sessionStorage.setItem(
      CONNECTION_KEY,
      JSON.stringify(nextConnection),
    )
    activeConnectionScope.current = connectionScope(nextConnection)
    seenEvents.current.clear()
    setConnection(nextConnection)
    setOrders([])
    setSelectedId(null)
    setFilter('ACTIVE')
    setPaymentSummary(null)
    setPaymentLoading(false)
    setProcessing(false)
    setConnected(false)
    setUnreadMessageCount(0)
    setLoading(true)
    setBusinessStatus(store.businessStatus)
    setError(null)
    setShowConnection(false)
  }

  const updateCurrentStore = useCallback((store: StoreSummary) => {
    setConnection((current) => {
      if (!current || current.storeId !== store.storeId) return current
      if (
        current.storeName === store.name &&
        current.storeRole === store.myRole
      ) return current
      const next = {
        ...current,
        storeName: store.name,
        storeRole: store.myRole,
      }
      window.sessionStorage.setItem(CONNECTION_KEY, JSON.stringify(next))
      return next
    })
    setBusinessStatus(store.businessStatus)
  }, [])

  if (!authenticated) {
    return (
      <>
        <SellerAuth
          onAuthenticated={authenticate}
          onUseDemo={useDemo}
        />
        <button
          className="theme-toggle auth-theme-toggle"
          type="button"
          aria-label={theme === 'dark' ? '기본 모드로 전환' : '다크 모드로 전환'}
          aria-pressed={theme === 'dark'}
          onClick={toggleTheme}
        >
          <span aria-hidden="true">{theme === 'dark' ? '☀' : '☾'}</span>
        </button>
      </>
    )
  }

  return (
    <div className="seller-shell">
      <aside className="sidebar">
        <div className="brand">
          <span className="brand-mark">P</span>
          <div>
            <strong>POPQ</strong>
            <small>{isAdmin ? 'ADMIN' : 'SELLER'}</small>
          </div>
        </div>
        <nav aria-label={isAdmin ? '관리자 메뉴' : '판매자 메뉴'}>
          {isAdmin ? (
            <>
              <small className="sidebar-section-label">회원 관리</small>
              <button className={activeView === 'admin-customers' ? 'active' : ''} onClick={() => setActiveView('admin-customers')}><span>◎</span>구매자 회원</button>
              <button className={activeView === 'admin-sellers' ? 'active' : ''} onClick={() => setActiveView('admin-sellers')}><span>◇</span>판매자 · 인증</button>
              <button className={activeView === 'admin-stores' ? 'active' : ''} onClick={() => setActiveView('admin-stores')}><span>□</span>스토어 관리</button>
              <small className="sidebar-section-label">콘텐츠 · 지원</small>
              <button className={activeView === 'admin-announcements' ? 'active' : ''} onClick={() => setActiveView('admin-announcements')}><span>◉</span>플랫폼 공지</button>
              <button className={activeView === 'admin-support' ? 'active' : ''} onClick={() => setActiveView('admin-support')}><span>◌</span>문의 관리</button>
              <button className={activeView === 'admin-faqs' ? 'active' : ''} onClick={() => setActiveView('admin-faqs')}><span>?</span>FAQ 관리</button>
            </>
          ) : (
            <>
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
                className={activeView === 'announcements' ? 'active' : ''}
                onClick={() => setActiveView('announcements')}
              >
                <span>📢</span>
                공지사항
              </button>
              <button
                className={activeView === 'messages' ? 'active' : ''}
                onClick={() => setActiveView('messages')}
              >
                <span>💬</span>
                고객 문의
                {unreadMessageCount > 0 && <b>{unreadMessageCount}</b>}
              </button>
              <button
                className={activeView === 'reviews' ? 'active' : ''}
                onClick={() => setActiveView('reviews')}
              >
                <span>★</span>
                리뷰 관리
              </button>
              <button
                className={activeView === 'settings' ? 'active' : ''}
                onClick={() => setActiveView('settings')}
              >
                <span>⚙</span>
                스토어 설정
              </button>
            </>
          )}
        </nav>
        <div className="sidebar-bottom">
          <button className="profile-button" onClick={openAccount}>
            <span>{isAdmin ? 'AD' : 'SL'}</span>
            <div>
              <strong>{isDemo ? '데모 운영자' : connection?.user?.name ?? '판매자'}</strong>
              <small>
                {isDemo
                  ? '데모 스토어'
                  : isAdmin
                    ? '플랫폼 관리자'
                    : connection?.storeName ?? `스토어 ${connection?.storeId}`}
              </small>
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
            <button
              className="icon-button theme-toggle"
              type="button"
              aria-label={theme === 'dark' ? '기본 모드로 전환' : '다크 모드로 전환'}
              aria-pressed={theme === 'dark'}
              onClick={toggleTheme}
            >
              <span aria-hidden="true">{theme === 'dark' ? '☀' : '☾'}</span>
            </button>
            {!isAdmin && (
              <>
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
                    : '준비중'}
                </button>
              </>
            )}
            <button
              className="icon-button"
              aria-label="계정 설정"
              onClick={openAccount}
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
              <p>
                {isDemo
                  ? '데모 스토어'
                  : connection?.storeName ?? `스토어 ${connection?.storeId}`}
                의 주문 흐름이 안정적입니다.
              </p>
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
          <ProductManagement
            key={storeScopeKey}
            connection={connection}
            storeRole={resolvedStoreRole}
            onError={setError}
          />
        )}
        {activeView === 'qr' && (
          <QrManagement
            key={storeScopeKey}
            connection={connection}
            storeRole={resolvedStoreRole}
            onError={setError}
          />
        )}
        {activeView === 'analytics' && (
          <SalesAnalytics
            key={storeScopeKey}
            connection={connection}
            onError={setError}
          />
        )}
        {activeView === 'settings' && (
          <StoreSettings
            key={storeScopeKey}
            connection={connection}
            onError={setError}
            onBusinessStatusChange={setBusinessStatus}
            onStoreSelected={switchStore}
            onStoreUpdated={updateCurrentStore}
            onStoreDeleted={(remaining) => {
              if (remaining.length > 0) switchStore(remaining[0])
              else signOut()
            }}
          />
        )}
        {activeView === 'announcements' && (
          <AnnouncementManagement
            key={storeScopeKey}
            connection={connection}
            storeRole={resolvedStoreRole}
            onError={setError}
          />
        )}
        {activeView === 'messages' && (
          <MessageManagement
            key={storeScopeKey}
            connection={connection}
            onError={setError}
            onUnreadChange={setUnreadMessageCount}
          />
        )}
        {activeView === 'reviews' && (
          <ReviewManagement
            key={storeScopeKey}
            connection={connection}
            storeRole={resolvedStoreRole}
            onError={setError}
          />
        )}
        {isAdmin && activeView === 'admin-customers' && <AdminManagement connection={connection} section="customers" onError={setError} />}
        {isAdmin && activeView === 'admin-sellers' && <AdminManagement connection={connection} section="sellers" onError={setError} />}
        {isAdmin && activeView === 'admin-stores' && <AdminManagement connection={connection} section="stores" onError={setError} />}
        {isAdmin && activeView === 'admin-announcements' && <AdminContentManagement connection={connection} kind="announcements" onError={setError} />}
        {isAdmin && activeView === 'admin-support' && <AdminSupportManagement connection={connection} onError={setError} />}
        {isAdmin && activeView === 'admin-faqs' && <AdminContentManagement connection={connection} kind="faqs" onError={setError} />}
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
            onAction={(action, options) => void changeStatus(selectedOrder, action, options)}
            canRefund={canManageStore}
            onRefund={(amount, reason) =>
              void refundOrder(selectedOrder, amount, reason)
            }
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
            <p className="eyebrow">ACCOUNT</p>
            <h2 id="connection-title">{isAdmin ? '관리자 계정' : '판매자 계정'}</h2>
            <p>
              {isDemo
                ? '현재 데모 데이터로 판매자 웹을 체험하고 있습니다.'
                : isAdmin
                  ? `${connection?.user?.email ?? '관리자 계정'} · 플랫폼 관리자`
                  : `${connection?.user?.email ?? '판매자 계정'} · ${connection?.storeName ?? `스토어 ${connection?.storeId}`}`}
            </p>
            {!isDemo && !isAdmin && (
              <div className="account-store-switcher">
                <div className="account-store-heading">
                  <strong>운영 스토어</strong>
                  <small>전환하면 스토어별 운영 데이터가 새로 연결됩니다.</small>
                </div>
                {accountStoresLoading ? (
                  <p className="account-store-status">스토어를 불러오는 중…</p>
                ) : accountStoresError ? (
                  <p className="account-store-error" role="alert">
                    {accountStoresError}
                  </p>
                ) : (
                  <div className="account-store-list">
                    {accountStores.map((store) => {
                      const current = store.storeId === connection?.storeId
                      return (
                        <button
                          key={store.storeId}
                          type="button"
                          className={current ? 'current' : ''}
                          disabled={current}
                          aria-label={
                            current
                              ? `${store.name} 현재 스토어`
                              : `${store.name}로 전환`
                          }
                          onClick={() => switchStore(store)}
                        >
                          <span>{store.name.slice(0, 1)}</span>
                          <div>
                            <strong>{store.name}</strong>
                            <small>
                              {store.myRole} · {store.businessStatus}
                            </small>
                          </div>
                          <b>{current ? '현재' : '전환'}</b>
                        </button>
                      )
                    })}
                    {accountStores.length === 0 && (
                      <p className="account-store-status">
                        전환할 수 있는 스토어가 없습니다.
                      </p>
                    )}
                  </div>
                )}
              </div>
            )}
            <button className="primary-action" onClick={signOut}>
              {isDemo ? '로그인 화면으로 이동' : '로그아웃'}
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
  canRefund: canIssueRefund,
  onClose,
  onAction,
  onRefund,
}: {
  order: SellerOrder
  processing: boolean
  paymentLoading: boolean
  paymentSummary: SellerPaymentSummary | null
  canRefund: boolean
  onClose: () => void
  onAction: (action: TransitionAction, options?: TransitionOptions) => void
  onRefund: (amount: number, reason: string) => void
}) {
  const [showRefundForm, setShowRefundForm] = useState(false)
  const [refundReason, setRefundReason] = useState('')
  const [actionDialog, setActionDialog] = useState<'accept' | 'reject' | null>(null)
  const [preparationMinutes, setPreparationMinutes] = useState(10)
  const [applyAsStoreDefault, setApplyAsStoreDefault] = useState(false)
  const [rejectReason, setRejectReason] = useState('')
  const actions = ACTIONS[order.status]
  const canRefund =
    canIssueRefund &&
    order.status === 'COMPLETED' &&
    (paymentSummary?.paymentStatus === 'PAID' ||
      paymentSummary?.paymentStatus === 'PARTIALLY_REFUNDED') &&
    paymentSummary.refundableAmount > 0
  const paymentStatus =
    paymentSummary?.paymentStatus === 'REFUNDED'
      ? '환불 완료'
      : paymentSummary?.paymentStatus === 'PARTIALLY_REFUNDED'
        ? '부분 환불'
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
                    {refund.status === 'FAILED' && (
                      <div className="refund-failure-recovery">
                        <small>{refund.failureMessage ?? '환불 처리에 실패했습니다.'}</small>
                      </div>
                    )}
                  </article>
                ))}
              </div>
            )}
            {canRefund && !showRefundForm && (
              <button
                className="refund-open"
                onClick={() => {
                  setShowRefundForm(true)
                }}
              >
                전액 환불
              </button>
            )}
            {canRefund && showRefundForm && (
              <div className="refund-form">
                <strong>{money(paymentSummary.refundableAmount)} 전액 환불</strong>
                <label>
                  환불 사유
                  <textarea
                    rows={3}
                    value={refundReason}
                    placeholder="고객에게 안내할 환불 사유"
                    onChange={(event) => setRefundReason(event.target.value)}
                  />
                </label>
                <p>환불 가능한 금액 전액을 처리합니다. 승인 후에는 되돌릴 수 없습니다.</p>
                <div>
                  <button
                    className="secondary-action"
                    onClick={() => setShowRefundForm(false)}
                  >
                    취소
                  </button>
                  <button
                    className="refund-confirm"
                    disabled={
                      processing ||
                      !refundReason.trim()
                    }
                    onClick={() => onRefund(paymentSummary.refundableAmount, refundReason.trim())}
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
              onClick={() => {
                if (actions.secondary!.action === 'reject') setActionDialog('reject')
                else onAction(actions.secondary!.action)
              }}
            >
              {actions.secondary.label}
            </button>
          )}
          <button
            className="primary-action"
            disabled={processing}
            onClick={() => {
              if (actions.primary.action === 'accept') setActionDialog('accept')
              else onAction(actions.primary.action)
            }}
          >
            {processing ? '처리 중…' : actions.primary.label}
          </button>
        </div>
      ) : (
        <div className="terminal-note">
          이 주문의 처리가 종료되었습니다.
        </div>
      )}
      {actionDialog === 'accept' && (
        <div className="modal-backdrop" role="presentation">
          <section className="connection-modal" role="dialog" aria-modal="true" aria-labelledby="accept-order-title">
            <button className="modal-close" aria-label="닫기" onClick={() => setActionDialog(null)}>×</button>
            <p className="eyebrow">ACCEPT ORDER</p>
            <h2 id="accept-order-title">준비시간 선택</h2>
            <div className="status-options" role="radiogroup" aria-label="준비시간">
              {[0, 5, 10, 15, 20, 30, 40, 50].map((minutes) => (
                <button key={minutes} type="button" role="radio" aria-checked={preparationMinutes === minutes} className={preparationMinutes === minutes ? 'active' : ''} onClick={() => setPreparationMinutes(minutes)}>
                  {minutes === 0 ? '즉시' : `${minutes}분`}
                </button>
              ))}
            </div>
            <label className="required-check"><input type="checkbox" checked={applyAsStoreDefault} onChange={(event) => setApplyAsStoreDefault(event.target.checked)} />이 시간을 사업장 기본 준비시간으로 사용</label>
            <button className="primary-action" disabled={processing} onClick={() => { onAction('accept', { preparationMinutes, applyAsStoreDefault }); setActionDialog(null) }}>주문 접수</button>
          </section>
        </div>
      )}
      {actionDialog === 'reject' && (
        <div className="modal-backdrop" role="presentation">
          <section className="connection-modal" role="dialog" aria-modal="true" aria-labelledby="reject-order-title">
            <button className="modal-close" aria-label="닫기" onClick={() => setActionDialog(null)}>×</button>
            <p className="eyebrow">REJECT ORDER</p>
            <h2 id="reject-order-title">주문 거절 사유</h2>
            <label>고객 안내 사유<textarea maxLength={500} rows={4} value={rejectReason} onChange={(event) => setRejectReason(event.target.value)} placeholder="재료 소진, 운영 종료 등 사유를 입력해 주세요." /></label>
            <button className="danger-action" disabled={processing || !rejectReason.trim()} onClick={() => { onAction('reject', { reason: rejectReason.trim() }); setActionDialog(null) }}>주문 거절 확정</button>
          </section>
        </div>
      )}
    </>
  )
}

export default App

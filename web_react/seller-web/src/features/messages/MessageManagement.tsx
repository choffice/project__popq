import { useCallback, useEffect, useRef, useState } from 'react'
import {
  getSellerConversation,
  getSellerConversations,
  getSellerOrderMessages,
  getSellerUnreadConversationCount,
  sendSellerOrderMessage,
} from '../../services/api'
import {
  connectSellerChatRealtime,
  type SellerChatRealtimeSession,
} from '../../services/realtime'
import type {
  OrderChatEvent,
  OrderMessage,
  SellerConnection,
  SellerConversationDetail,
  SellerConversationSummary,
} from '../../types'

type Props = {
  connection: SellerConnection | null
  onError: (message: string | null) => void
  onUnreadChange: (count: number) => void
}

const demoConversation: SellerConversationSummary = {
  orderPublicId: 'DEMO-ORDER-1001',
  customerUserId: 101,
  customerName: '김고객',
  orderStatus: 'PREPARING',
  lastMessage: '포크 하나 더 부탁드려요.',
  lastMessageSenderType: 'CUSTOMER',
  lastMessageAt: new Date().toISOString(),
  unreadCount: 1,
}

const orderStatusLabel: Record<
  SellerConversationDetail['orderStatus'],
  string
> = {
  CREATED: '결제 대기',
  PLACED: '신규 주문',
  ACCEPTED: '접수 완료',
  PREPARING: '준비 중',
  READY: '픽업 대기',
  COMPLETED: '완료',
  CANCELED: '고객 취소',
  REJECTED: '주문 거절',
  EXPIRED: '시간 만료',
}

const orderTypeLabel: Record<SellerConversationDetail['orderType'], string> = {
  DINE_IN: '매장',
  TAKEOUT: '포장',
}

function displayOrderNumber(orderPublicId: string) {
  return orderPublicId.slice(-4).toUpperCase()
}

function mergeMessages(current: OrderMessage[], incoming: OrderMessage[]) {
  const byId = new Map(current.map((message) => [message.orderMessageId, message]))
  incoming.forEach((message) => byId.set(message.orderMessageId, message))
  return [...byId.values()].sort((a, b) => a.orderMessageId - b.orderMessageId)
}

export function MessageManagement({ connection, onError, onUnreadChange }: Props) {
  const isDemo = !connection
  const [conversations, setConversations] = useState<SellerConversationSummary[]>(isDemo ? [demoConversation] : [])
  const [selectedId, setSelectedId] = useState<string | null>(isDemo ? demoConversation.orderPublicId : null)
  const [detail, setDetail] = useState<SellerConversationDetail | null>(null)
  const [messages, setMessages] = useState<OrderMessage[]>([])
  const [hasMore, setHasMore] = useState(false)
  const [nextBeforeMessageId, setNextBeforeMessageId] = useState<number | null>(null)
  const [draft, setDraft] = useState('')
  const [loading, setLoading] = useState(!isDemo)
  const [sending, setSending] = useState(false)
  const [realtimeConnected, setRealtimeConnected] = useState(false)
  const realtimeRef = useRef<SellerChatRealtimeSession | null>(null)
  const selectedIdRef = useRef(selectedId)

  useEffect(() => { selectedIdRef.current = selectedId }, [selectedId])

  const refreshList = useCallback(async () => {
    if (!connection) {
      setConversations([demoConversation])
      onUnreadChange(demoConversation.unreadCount)
      return
    }
    const [list, unread] = await Promise.all([
      getSellerConversations(connection),
      getSellerUnreadConversationCount(connection),
    ])
    setConversations(list)
    onUnreadChange(unread)
    setSelectedId((current) =>
      current && list.some((item) => item.orderPublicId === current)
        ? current
        : (list[0]?.orderPublicId ?? null),
    )
  }, [connection, onUnreadChange])

  const handleRealtimeEvent = useCallback((event: OrderChatEvent) => {
    void refreshList().catch(() => undefined)
    if (event.orderPublicId !== selectedIdRef.current) return
    if (event.eventType === 'MESSAGE_CREATED' && event.message) {
      setMessages((current) => mergeMessages(current, [event.message!]))
      if (event.message.senderType === 'CUSTOMER') {
        window.setTimeout(() => realtimeRef.current?.markRead(event.orderPublicId, event.message!.orderMessageId), 50)
      }
    } else if (event.eventType === 'MESSAGE_READ') {
      const readIds = new Set(event.readMessageIds)
      setMessages((current) => current.map((message) => readIds.has(message.orderMessageId) ? { ...message, read: true, readAt: event.occurredAt } : message))
    }
  }, [refreshList])

  useEffect(() => {
    if (!connection) return
    const session = connectSellerChatRealtime(
      connection,
      handleRealtimeEvent,
      () => setRealtimeConnected(true),
      () => setRealtimeConnected(false),
    )
    realtimeRef.current = session
    return () => {
      session.disconnect()
      realtimeRef.current = null
    }
  }, [connection, handleRealtimeEvent])

  useEffect(() => {
    const timer = window.setTimeout(() => {
      setLoading(true)
      void refreshList()
        .then(() => onError(null))
        .catch((caught: unknown) => onError(caught instanceof Error ? caught.message : '대화 목록을 불러오지 못했습니다.'))
        .finally(() => setLoading(false))
    }, 0)
    return () => window.clearTimeout(timer)
  }, [onError, refreshList])

  useEffect(() => {
    let active = true
    const timer = window.setTimeout(() => {
      if (!selectedId) return
      if (!connection) {
        const now = new Date().toISOString()
        setDetail({ orderPublicId: selectedId, storeId: 1, storeName: '데모 스토어', customerUserId: 101, customerName: '김고객', orderType: 'TAKEOUT', orderStatus: 'PREPARING', totalAmount: 14500, orderedAt: now, orderItems: [{ orderItemId: 1, productName: '아메리카노', quantity: 2, itemTotalPrice: 9000 }], messages: [] })
        setMessages([{ orderMessageId: 1, senderUserId: 101, senderName: '김고객', senderType: 'CUSTOMER', clientMessageId: null, content: '포크 하나 더 부탁드려요.', read: false, readAt: null, createdAt: now }])
        setHasMore(false)
        return
      }
      void Promise.all([
        getSellerConversation(connection, selectedId),
        getSellerOrderMessages(connection, selectedId),
      ]).then(([metadata, page]) => {
        if (!active) return
        setDetail(metadata)
        setMessages(page.messages)
        setHasMore(page.hasMore)
        setNextBeforeMessageId(page.nextBeforeMessageId)
        const lastCustomer = [...page.messages].reverse().find((message) => message.senderType === 'CUSTOMER' && !message.read)
        if (lastCustomer) realtimeRef.current?.markRead(selectedId, lastCustomer.orderMessageId)
      }).catch((caught: unknown) => onError(caught instanceof Error ? caught.message : '주문 메시지를 불러오지 못했습니다.'))
    }, 0)
    return () => { active = false; window.clearTimeout(timer) }
  }, [connection, onError, selectedId])

  async function loadOlder() {
    if (!connection || !selectedId || !nextBeforeMessageId) return
    try {
      const page = await getSellerOrderMessages(connection, selectedId, nextBeforeMessageId)
      setMessages((current) => mergeMessages(page.messages, current))
      setHasMore(page.hasMore)
      setNextBeforeMessageId(page.nextBeforeMessageId)
    } catch (caught) {
      onError(caught instanceof Error ? caught.message : '이전 메시지를 불러오지 못했습니다.')
    }
  }

  async function sendMessage() {
    const content = draft.trim()
    if (!selectedId || !content) return
    setSending(true)
    try {
      const sent = connection
        ? await sendSellerOrderMessage(connection, selectedId, content, crypto.randomUUID())
        : { orderMessageId: Math.max(0, ...messages.map((message) => message.orderMessageId)) + 1, senderUserId: 1, senderName: '스토어', senderType: 'SELLER' as const, clientMessageId: crypto.randomUUID(), content, read: false, readAt: null, createdAt: new Date().toISOString() }
      setMessages((current) => mergeMessages(current, [sent]))
      setDraft('')
      void refreshList()
      onError(null)
    } catch (caught) {
      onError(caught instanceof Error ? caught.message : '메시지를 보내지 못했습니다.')
    } finally {
      setSending(false)
    }
  }

  return (
    <main className="management-page messages-page">
      <section className="management-hero compact-hero">
        <div>
          <p className="eyebrow">CUSTOMER CONVERSATIONS</p>
          <h2>고객 문의 · 주문 메시지</h2>
          <p>주문별 요청을 확인하고 실시간으로 답변합니다.</p>
        </div>
        <span className={`realtime-indicator ${realtimeConnected || isDemo ? 'connected' : ''}`}>
          <i aria-hidden="true" />
          {realtimeConnected || isDemo ? '실시간 연결' : '재연결 중'}
        </span>
      </section>
      <section className="message-workspace">
        <aside className="conversation-list">
          <header>
            <div>
              <h3>대화 목록</h3>
              <small>{conversations.length}개의 대화</small>
            </div>
            <button
              type="button"
              className="conversation-refresh"
              aria-label="대화 목록 새로고침"
              onClick={() => void refreshList()}
            >
              <span aria-hidden="true">↻</span>
            </button>
          </header>
          {loading && <p>불러오는 중…</p>}
          {conversations.map((item) => (
            <button
              type="button"
              key={item.orderPublicId}
              className={selectedId === item.orderPublicId ? 'active' : ''}
              aria-pressed={selectedId === item.orderPublicId}
              onClick={() => setSelectedId(item.orderPublicId)}
            >
              <span className="conversation-avatar">{item.customerName.slice(0, 1)}</span>
              <span className="conversation-copy">
                <strong>{item.customerName}</strong>
                <small>{item.lastMessage}</small>
                <time>{new Date(item.lastMessageAt).toLocaleString('ko-KR')}</time>
              </span>
              {item.unreadCount > 0 && <b className="unread-badge">{item.unreadCount}</b>}
            </button>
          ))}
          {!loading && conversations.length === 0 && <p className="management-empty">아직 대화가 없습니다.</p>}
        </aside>
        <article className="chat-panel">
          {!detail ? (
            <div className="management-empty">대화를 선택해 주세요.</div>
          ) : (
            <>
              <header>
                <div className="chat-customer-summary">
                  <span className="chat-customer-avatar">{detail.customerName.slice(0, 1)}</span>
                  <div>
                    <h3>{detail.customerName}</h3>
                    <p>
                      <span>{orderTypeLabel[detail.orderType]} 주문 #{displayOrderNumber(detail.orderPublicId)}</span>
                      <b>{orderStatusLabel[detail.orderStatus]}</b>
                    </p>
                  </div>
                </div>
                <div className="chat-order-total">
                  <small>주문 금액</small>
                  <strong>{detail.totalAmount.toLocaleString('ko-KR')}원</strong>
                </div>
              </header>
              <div className="order-message-summary" aria-label="주문 상품">
                <strong>주문 상품</strong>
                <div>
                  {detail.orderItems.map((item) => (
                    <span key={item.orderItemId}>{item.productName} × {item.quantity}</span>
                  ))}
                </div>
              </div>
              <div
                className="message-stream"
                role="log"
                aria-live="polite"
                aria-label={`${detail.customerName}님과의 대화`}
              >
                {hasMore && (
                  <button type="button" className="load-more" onClick={() => void loadOlder()}>
                    이전 메시지 불러오기
                  </button>
                )}
                {messages.map((message) => {
                  const senderClass = message.senderType.toLowerCase()
                  return (
                    <div key={message.orderMessageId} className={`message-row ${senderClass}`}>
                      {message.senderType === 'CUSTOMER' && (
                        <span className="message-avatar" aria-hidden="true">
                          {message.senderName.slice(0, 1)}
                        </span>
                      )}
                      <div className="message-content">
                        <strong className="message-sender">{message.senderName}</strong>
                        <div className="message-bubble">
                          <p>{message.content}</p>
                        </div>
                        <small className="message-time">
                          {new Date(message.createdAt).toLocaleTimeString('ko-KR', { hour: '2-digit', minute: '2-digit' })}
                          {message.senderType === 'SELLER' && ` · ${message.read ? '읽음' : '전송됨'}`}
                        </small>
                      </div>
                    </div>
                  )
                })}
              </div>
              <footer>
                <div className="message-composer">
                  <textarea
                    maxLength={2000}
                    aria-label="고객에게 보낼 메시지"
                    placeholder="고객에게 보낼 메시지를 입력하세요."
                    value={draft}
                    onChange={(event) => setDraft(event.target.value)}
                    onKeyDown={(event) => {
                      if (event.key === 'Enter' && !event.shiftKey) {
                        event.preventDefault()
                        void sendMessage()
                      }
                    }}
                  />
                  <small>{draft.length.toLocaleString('ko-KR')} / 2,000 · Enter 전송</small>
                </div>
                <button
                  type="button"
                  className="primary-action message-send"
                  disabled={sending || !draft.trim()}
                  onClick={() => void sendMessage()}
                >
                  <span aria-hidden="true">↑</span>
                  {sending ? '전송 중' : '전송'}
                </button>
              </footer>
            </>
          )}
        </article>
      </section>
    </main>
  )
}

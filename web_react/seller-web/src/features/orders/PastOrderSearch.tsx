import { useMemo, useState } from 'react'
import { getSellerOrders } from '../../services/api'
import type { SellerConnection, SellerOrder } from '../../types'

type PastOrderStatus = 'ALL' | 'COMPLETED' | 'CANCELED' | 'REJECTED' | 'EXPIRED'

const STATUS_OPTIONS: { value: PastOrderStatus; label: string }[] = [
  { value: 'ALL', label: '전체 종료 상태' },
  { value: 'COMPLETED', label: '완료' },
  { value: 'CANCELED', label: '고객 취소' },
  { value: 'REJECTED', label: '주문 거절' },
  { value: 'EXPIRED', label: '시간 만료' },
]

const STATUS_LABEL: Record<Exclude<PastOrderStatus, 'ALL'>, string> = {
  COMPLETED: '완료',
  CANCELED: '고객 취소',
  REJECTED: '주문 거절',
  EXPIRED: '시간 만료',
}

function localDate(date: Date) {
  const offset = date.getTimezoneOffset() * 60_000
  return new Date(date.getTime() - offset).toISOString().slice(0, 10)
}

function orderDate(order: SellerOrder) {
  const value = order.createdAt ?? order.statusHistory.at(-1)?.changedAt
  return value ? localDate(new Date(value)) : ''
}

function shortOrderId(orderPublicId: string) {
  return orderPublicId.slice(-4).toUpperCase()
}

function money(value: number) {
  return `${value.toLocaleString('ko-KR')}원`
}

function initialDate(demoOrders: SellerOrder[]) {
  const latestTerminal = demoOrders
    .filter((order) => ['COMPLETED', 'CANCELED', 'REJECTED', 'EXPIRED'].includes(order.status))
    .map(orderDate)
    .filter(Boolean)
    .sort()
    .at(-1)
  return latestTerminal ?? localDate(new Date())
}

export function PastOrderSearch({
  connection,
  demoOrders,
  selectedId,
  onSelect,
  onError,
}: {
  connection: SellerConnection | null
  demoOrders: SellerOrder[]
  selectedId: string | null
  onSelect: (order: SellerOrder) => void
  onError: (message: string | null) => void
}) {
  const [date, setDate] = useState(() => initialDate(demoOrders))
  const [status, setStatus] = useState<PastOrderStatus>('ALL')
  const [results, setResults] = useState<SellerOrder[]>([])
  const [searched, setSearched] = useState(false)
  const [loading, setLoading] = useState(false)

  const totalAmount = useMemo(
    () => results.reduce((sum, order) => sum + order.totalAmount, 0),
    [results],
  )

  async function search() {
    if (!date) return
    setLoading(true)
    try {
      const next = connection
        ? await getSellerOrders(connection, {
            date,
            status: status === 'ALL' ? undefined : status,
          })
        : demoOrders.filter(
            (order) =>
              orderDate(order) === date &&
              ['COMPLETED', 'CANCELED', 'REJECTED', 'EXPIRED'].includes(order.status) &&
              (status === 'ALL' || order.status === status),
          )
      setResults(next)
      setSearched(true)
      onError(null)
    } catch (caught) {
      setResults([])
      setSearched(true)
      onError(
        caught instanceof Error
          ? caught.message
          : '지난 주문을 불러오지 못했습니다.',
      )
    } finally {
      setLoading(false)
    }
  }

  return (
    <section className="past-order-search" aria-labelledby="past-order-title">
      <div className="past-order-intro">
        <div>
          <p className="eyebrow">ORDER ARCHIVE</p>
          <h2 id="past-order-title">지난 주문 조회</h2>
        </div>
        <p>영업일과 종료 상태를 선택해 완료·취소된 주문을 다시 확인하세요.</p>
      </div>

      <form
        className="past-order-form"
        onSubmit={(event) => {
          event.preventDefault()
          void search()
        }}
      >
        <label>
          <span>주문 날짜</span>
          <input
            type="date"
            value={date}
            max={localDate(new Date())}
            onChange={(event) => setDate(event.target.value)}
          />
        </label>
        <label>
          <span>주문 상태</span>
          <select
            value={status}
            onChange={(event) => setStatus(event.target.value as PastOrderStatus)}
          >
            {STATUS_OPTIONS.map((option) => (
              <option key={option.value} value={option.value}>
                {option.label}
              </option>
            ))}
          </select>
        </label>
        <button className="past-order-submit" type="submit" disabled={loading || !date}>
          {loading ? '조회 중…' : '주문 조회'}
        </button>
      </form>

      {searched && (
        <div className="past-order-results" aria-live="polite">
          <header>
            <div>
              <strong>{results.length}건</strong>
              <span>{date.replaceAll('-', '.')} 조회 결과</span>
            </div>
            {results.length > 0 && <b>주문 합계 {money(totalAmount)}</b>}
          </header>
          {results.length > 0 ? (
            <div className="past-order-list">
              {results.map((order) => {
                const firstItem = order.items[0]
                const itemCount = order.items.reduce((sum, item) => sum + item.quantity, 0)
                const timestamp = order.createdAt ?? order.statusHistory.at(-1)?.changedAt
                return (
                  <button
                    type="button"
                    key={order.orderPublicId}
                    className={order.orderPublicId === selectedId ? 'selected' : ''}
                    aria-label={`지난 주문 ${shortOrderId(order.orderPublicId)} 상세 보기`}
                    onClick={() => onSelect(order)}
                  >
                    <span className={`past-order-status status-${order.status.toLowerCase()}`}>
                      {STATUS_LABEL[order.status as Exclude<PastOrderStatus, 'ALL'>]}
                    </span>
                    <div className="past-order-number">
                      <strong>#{shortOrderId(order.orderPublicId)}</strong>
                      <time>
                        {timestamp
                          ? new Date(timestamp).toLocaleTimeString('ko-KR', {
                              hour: '2-digit',
                              minute: '2-digit',
                            })
                          : '시간 정보 없음'}
                      </time>
                    </div>
                    <div className="past-order-items">
                      <strong>{firstItem?.productName ?? '주문 상품'}</strong>
                      <span>
                        {itemCount}개 메뉴 · {order.orderType === 'DINE_IN' ? '매장' : '포장'}
                      </span>
                    </div>
                    <strong className="past-order-amount">{money(order.totalAmount)}</strong>
                    <span className="past-order-chevron" aria-hidden="true">›</span>
                  </button>
                )
              })}
            </div>
          ) : (
            <div className="past-order-empty">
              <span>⌕</span>
              <div>
                <strong>조건에 맞는 지난 주문이 없습니다.</strong>
                <p>다른 날짜나 상태를 선택해 다시 조회해 보세요.</p>
              </div>
            </div>
          )}
        </div>
      )}
    </section>
  )
}

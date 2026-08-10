import { useEffect, useMemo, useState } from 'react'
import { createDemoSalesSummary } from '../../data/demo'
import { getSalesSummary } from '../../services/api'
import type { SalesSummary, SellerConnection } from '../../types'

type Props = {
  connection: SellerConnection | null
  onError: (message: string | null) => void
}

type LedgerTab = 'orders' | 'refunds' | 'cancellations'

function money(value: number) {
  return `${value.toLocaleString('ko-KR')}원`
}

function localDate(date: Date) {
  const year = date.getFullYear()
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const day = String(date.getDate()).padStart(2, '0')
  return `${year}-${month}-${day}`
}

function rangeDates(days: number) {
  const to = new Date()
  const from = new Date(to)
  from.setDate(to.getDate() - days + 1)
  return { from: localDate(from), to: localDate(to) }
}

function dateTime(value: string | null) {
  if (!value) return '처리 시각 없음'
  return new Date(value).toLocaleString('ko-KR', {
    month: 'numeric',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  })
}

function orderNumber(orderPublicId: string) {
  return `#${orderPublicId.slice(-8).toUpperCase()}`
}

const REQUESTER_LABELS: Record<string, string> = {
  GUEST: '비회원 고객',
  CUSTOMER: '고객',
  SELLER: '판매자',
  ADMIN: '관리자',
  SYSTEM: '시스템',
  UNKNOWN: '처리자 미상',
}

export function SalesAnalytics({ connection, onError }: Props) {
  const isDemo = !connection
  const initialRange = rangeDates(7)
  const [range, setRange] = useState<7 | 30 | 'custom'>(7)
  const [from, setFrom] = useState(initialRange.from)
  const [to, setTo] = useState(initialRange.to)
  const [summary, setSummary] = useState<SalesSummary>(() =>
    createDemoSalesSummary(7),
  )
  const [loading, setLoading] = useState(!isDemo)
  const [ledgerTab, setLedgerTab] = useState<LedgerTab>('orders')

  // Keep the analytics page compatible with API instances that have not yet
  // deployed the optional ledger fields. Missing arrays must render as empty
  // states instead of crashing the whole seller application.
  const orderHistory = summary.orderHistory ?? []
  const refundHistory = summary.refundHistory ?? []
  const cancellationHistory = summary.cancellationHistory ?? []

  useEffect(() => {
    const timer = window.setTimeout(() => {
      const dayCount = Math.round(
        (new Date(to).getTime() - new Date(from).getTime()) / 86_400_000,
      ) + 1
      if (!from || !to || dayCount < 1 || dayCount > 31) {
        setLoading(false)
        onError('매출 조회 기간은 시작일 이후 최대 31일로 선택해 주세요.')
        return
      }
      if (!connection) {
        setSummary(createDemoSalesSummary(dayCount <= 7 ? 7 : 30))
        setLoading(false)
        return
      }
      setLoading(true)
      void getSalesSummary(connection, from, to)
        .then((data) => {
          setSummary(data)
          onError(null)
        })
        .catch((caught: unknown) =>
          onError(
            caught instanceof Error
              ? caught.message
              : '매출 요약을 불러오지 못했습니다.',
          ),
        )
        .finally(() => setLoading(false))
    }, 0)
    return () => window.clearTimeout(timer)
  }, [connection, from, onError, to])

  const maxSales = Math.max(1, ...summary.dailySales.map((day) => day.sales))
  const chartDays = useMemo(
    () => summary.dailySales.length > 14 ? summary.dailySales.slice(-14) : summary.dailySales,
    [summary.dailySales],
  )
  const dineInRatio =
    summary.netSales === 0
      ? 0
      : Math.round((summary.dineInSales / summary.netSales) * 100)

  function selectPreset(days: 7 | 30) {
    const dates = rangeDates(days)
    setRange(days)
    setFrom(dates.from)
    setTo(dates.to)
  }

  function exportCsv() {
    const rows = [
      ['날짜', '순매출', '완료 주문 수'],
      ...summary.dailySales.map((day) => [day.date, day.sales, day.orderCount]),
      [],
      ['지표', '값'],
      ['총 완료 매출', summary.grossSales],
      ['환불 금액', summary.refundedAmount],
      ['환불 건수', summary.refundCount],
      ['취소/거절 주문 수', summary.canceledOrderCount],
      ['취소/거절 금액', summary.canceledAmount],
      ['순매출', summary.netSales],
      [],
      ['완료 주문 내역'],
      ['완료 시각', '주문 번호', '상품', '주문 유형', '결제액', '환불액', '순매출'],
      ...orderHistory.map((order) => [
        order.completedAt,
        orderNumber(order.orderPublicId),
        order.itemSummary,
        order.orderType,
        order.approvedAmount,
        order.refundedAmount,
        order.netSales,
      ]),
      [],
      ['환불 내역'],
      ['환불 시각', '주문 번호', '사유', '처리자', '환불액'],
      ...refundHistory.map((refund) => [
        refund.completedAt,
        orderNumber(refund.orderPublicId),
        refund.reason,
        REQUESTER_LABELS[refund.requesterType] ?? refund.requesterType,
        refund.amount,
      ]),
      [],
      ['취소·거절 내역'],
      ['처리 시각', '주문 번호', '상태', '사유', '주문 금액'],
      ...cancellationHistory.map((cancellation) => [
        cancellation.canceledAt,
        orderNumber(cancellation.orderPublicId),
        cancellation.status,
        cancellation.reason,
        cancellation.amount,
      ]),
    ]
    const csv = rows.map((row) => row.map((value) => `"${String(value ?? '').replaceAll('"', '""')}"`).join(',')).join('\r\n')
    const url = URL.createObjectURL(new Blob([`\uFEFF${csv}`], { type: 'text/csv;charset=utf-8' }))
    const anchor = document.createElement('a')
    anchor.href = url
    anchor.download = `popq-sales-${summary.from}-${summary.to}.csv`
    anchor.click()
    URL.revokeObjectURL(url)
  }

  return (
    <main className="management-page analytics-page">
      <section className="management-hero analytics-hero">
        <div>
          <p className="eyebrow">SALES PULSE</p>
          <h2>매출 흐름</h2>
          <p>
            조회 기간에 완료된 주문의 결제 금액에서 성공한 환불 금액을 차감합니다.
          </p>
        </div>
        <div className="range-control" aria-label="매출 조회 기간">
          <button
            className={range === 7 ? 'active' : ''}
            onClick={() => selectPreset(7)}
          >
            최근 7일
          </button>
          <button
            className={range === 30 ? 'active' : ''}
            onClick={() => selectPreset(30)}
          >
            최근 30일
          </button>
          <label>시작일<input type="date" value={from} max={to} onChange={(event) => { setRange('custom'); setFrom(event.target.value) }} /></label>
          <label>종료일<input type="date" value={to} min={from} onChange={(event) => { setRange('custom'); setTo(event.target.value) }} /></label>
          <button className="csv-export" onClick={exportCsv}>CSV 내보내기</button>
        </div>
      </section>

      {loading ? (
        <div className="management-empty">매출을 계산하는 중입니다…</div>
      ) : (
        <>
          <section className="sales-metrics" aria-label="매출 핵심 지표">
            <article className="primary">
              <small>순매출</small>
              <strong>{money(summary.netSales)}</strong>
              <p>
                {summary.from} — {summary.to}
              </p>
            </article>
            <article>
              <span className="metric-symbol coral">#</span>
              <div>
                <small>완료 주문</small>
                <strong>{summary.completedOrderCount}건</strong>
              </div>
            </article>
            <article>
              <span className="metric-symbol coral">↩</span>
              <div><small>환불</small><strong>{money(summary.refundedAmount)}</strong><p>{summary.refundCount}건</p></div>
            </article>
            <article>
              <span className="metric-symbol violet">×</span>
              <div><small>취소·거절</small><strong>{summary.canceledOrderCount}건</strong><p>{money(summary.canceledAmount)}</p></div>
            </article>
            <article>
              <span className="metric-symbol violet">₩</span>
              <div>
                <small>평균 주문 금액</small>
                <strong>{money(summary.averageOrderAmount)}</strong>
              </div>
            </article>
            <article>
              <span className="metric-symbol lime">%</span>
              <div>
                <small>매장 이용 비중</small>
                <strong>{dineInRatio}%</strong>
              </div>
            </article>
          </section>

          <section className="analytics-grid">
            <article className="sales-chart-card">
              <header>
                <div>
                  <p className="eyebrow">DAILY SALES</p>
                  <h3>일별 순매출</h3>
                </div>
                <small>최근 {chartDays.length}일 표시</small>
              </header>
              <div className="bar-chart" aria-label="일별 매출 차트">
                {chartDays.map((day) => (
                  <div className="bar-column" key={day.date}>
                    <span className="bar-value">{money(day.sales)}</span>
                    <i
                      style={{
                        height: `${Math.max(4, (day.sales / maxSales) * 100)}%`,
                      }}
                    />
                    <small>
                      {new Date(`${day.date}T00:00:00`).toLocaleDateString(
                        'ko-KR',
                        { month: 'numeric', day: 'numeric' },
                      )}
                    </small>
                  </div>
                ))}
              </div>
            </article>

            <article className="channel-card">
              <header>
                <p className="eyebrow">ORDER TYPE</p>
                <h3>이용 유형</h3>
              </header>
              <div
                className="channel-donut"
                style={{
                  background: `conic-gradient(var(--violet) 0 ${dineInRatio}%, var(--coral) ${dineInRatio}% 100%)`,
                }}
              >
                <span>
                  <strong>{summary.completedOrderCount}</strong>
                  <small>orders</small>
                </span>
              </div>
              <div className="channel-legend">
                <div>
                  <span className="violet" />
                  <p>
                    <small>매장 이용</small>
                    <strong>{money(summary.dineInSales)}</strong>
                  </p>
                </div>
                <div>
                  <span className="coral" />
                  <p>
                    <small>포장 주문</small>
                    <strong>{money(summary.takeoutSales)}</strong>
                  </p>
                </div>
              </div>
            </article>

            <article className="top-products-card">
              <header>
                <div>
                  <p className="eyebrow">TOP PRODUCTS</p>
                  <h3>인기 상품</h3>
                </div>
                <small>완료 주문 기준</small>
              </header>
              <ol>
                {summary.topProducts.map((product, index) => (
                  <li key={product.productName}>
                    <b>{String(index + 1).padStart(2, '0')}</b>
                    <div>
                      <strong>{product.productName}</strong>
                      <small>{product.quantity}개 판매</small>
                    </div>
                    <span>{money(product.sales)}</span>
                  </li>
                ))}
                {summary.topProducts.length === 0 && (
                  <li className="no-sales">완료된 상품 판매가 없습니다.</li>
                )}
              </ol>
            </article>
          </section>

          <section className="sales-ledger-card" aria-label="매출 상세 내역">
            <header className="sales-ledger-header">
              <div>
                <p className="eyebrow">SALES LEDGER</p>
                <h3>매출 상세 내역</h3>
                <p>순매출을 구성하는 완료 주문과 환불, 별도의 취소·거절 기록을 확인하세요.</p>
              </div>
              <div className="sales-ledger-tabs" role="tablist" aria-label="매출 내역 유형">
                <button
                  role="tab"
                  aria-selected={ledgerTab === 'orders'}
                  className={ledgerTab === 'orders' ? 'active' : ''}
                  onClick={() => setLedgerTab('orders')}
                >
                  주문 내역 <b>{orderHistory.length}</b>
                </button>
                <button
                  role="tab"
                  aria-selected={ledgerTab === 'refunds'}
                  className={ledgerTab === 'refunds' ? 'active' : ''}
                  onClick={() => setLedgerTab('refunds')}
                >
                  환불 내역 <b>{refundHistory.length}</b>
                </button>
                <button
                  role="tab"
                  aria-selected={ledgerTab === 'cancellations'}
                  className={ledgerTab === 'cancellations' ? 'active' : ''}
                  onClick={() => setLedgerTab('cancellations')}
                >
                  취소·거절 <b>{cancellationHistory.length}</b>
                </button>
              </div>
            </header>

            {ledgerTab === 'orders' && (
              <div className="sales-ledger-list order-ledger" role="tabpanel">
                <div className="sales-ledger-columns" aria-hidden="true">
                  <span>주문</span><span>유형</span><span>결제액</span><span>환불</span><span>순매출</span>
                </div>
                {orderHistory.map((order) => (
                  <article className="sales-ledger-row" key={order.orderPublicId}>
                    <div className="ledger-order-main">
                      <strong>{orderNumber(order.orderPublicId)}</strong>
                      <span>{order.itemSummary} · 총 {order.itemCount}개</span>
                      <small>{dateTime(order.completedAt)} 완료</small>
                    </div>
                    <span className="ledger-pill">{order.orderType === 'DINE_IN' ? '매장' : '포장'}</span>
                    <span>{money(order.approvedAmount)}</span>
                    <span className={order.refundedAmount > 0 ? 'ledger-refund' : ''}>
                      {order.refundedAmount > 0 ? `-${money(order.refundedAmount)}` : '—'}
                    </span>
                    <strong className="ledger-net">{money(order.netSales)}</strong>
                  </article>
                ))}
                {orderHistory.length === 0 && (
                  <div className="sales-ledger-empty">선택한 기간에 완료된 주문이 없습니다.</div>
                )}
              </div>
            )}

            {ledgerTab === 'refunds' && (
              <div className="sales-ledger-list refund-ledger" role="tabpanel">
                <div className="sales-ledger-columns" aria-hidden="true">
                  <span>환불 정보</span><span>처리자</span><span>처리 시각</span><span>환불액</span>
                </div>
                {refundHistory.map((refund) => (
                  <article className="sales-ledger-row" key={refund.refundId}>
                    <div className="ledger-order-main">
                      <strong>{orderNumber(refund.orderPublicId)}</strong>
                      <span>{refund.reason}</span>
                    </div>
                    <span>{REQUESTER_LABELS[refund.requesterType] ?? refund.requesterType}</span>
                    <span>{dateTime(refund.completedAt)}</span>
                    <strong className="ledger-refund">-{money(refund.amount)}</strong>
                  </article>
                ))}
                {refundHistory.length === 0 && (
                  <div className="sales-ledger-empty">선택한 완료 주문에 적용된 환불이 없습니다.</div>
                )}
              </div>
            )}

            {ledgerTab === 'cancellations' && (
              <div className="sales-ledger-list cancellation-ledger" role="tabpanel">
                <div className="sales-ledger-columns" aria-hidden="true">
                  <span>주문</span><span>상태</span><span>처리 시각</span><span>주문 금액</span>
                </div>
                {cancellationHistory.map((cancellation) => (
                  <article className="sales-ledger-row" key={`${cancellation.orderPublicId}-${cancellation.canceledAt}`}>
                    <div className="ledger-order-main">
                      <strong>{orderNumber(cancellation.orderPublicId)}</strong>
                      <span>{cancellation.reason || '처리 사유 없음'}</span>
                    </div>
                    <span className="ledger-pill muted">
                      {cancellation.status === 'CANCELED' ? '고객 취소' : '주문 거절'}
                    </span>
                    <span>{dateTime(cancellation.canceledAt)}</span>
                    <strong>{money(cancellation.amount)}</strong>
                  </article>
                ))}
                {cancellationHistory.length === 0 && (
                  <div className="sales-ledger-empty">선택한 기간의 취소·거절 주문이 없습니다.</div>
                )}
              </div>
            )}
          </section>
        </>
      )}
      <p className="source-note">
        {isDemo
          ? '데모 매출은 화면 확인을 위한 예시 데이터입니다.'
          : 'Asia/Seoul 기준 최대 31일의 완료 주문을 서버에서 집계합니다.'}
      </p>
    </main>
  )
}

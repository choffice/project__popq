import { useEffect, useMemo, useState } from 'react'
import { createDemoSalesSummary } from '../../data/demo'
import { getSalesSummary } from '../../services/api'
import type { SalesSummary, SellerConnection } from '../../types'

type Props = {
  connection: SellerConnection | null
  onError: (message: string | null) => void
}

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

export function SalesAnalytics({ connection, onError }: Props) {
  const isDemo = !connection
  const [range, setRange] = useState<7 | 30>(7)
  const [summary, setSummary] = useState<SalesSummary>(() =>
    createDemoSalesSummary(7),
  )
  const [loading, setLoading] = useState(!isDemo)

  useEffect(() => {
    const timer = window.setTimeout(() => {
      if (!connection) {
        setSummary(createDemoSalesSummary(range))
        setLoading(false)
        return
      }
      const dates = rangeDates(range)
      setLoading(true)
      void getSalesSummary(connection, dates.from, dates.to)
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
  }, [connection, onError, range])

  const maxSales = Math.max(1, ...summary.dailySales.map((day) => day.sales))
  const chartDays = useMemo(
    () => (range === 30 ? summary.dailySales.slice(-14) : summary.dailySales),
    [range, summary.dailySales],
  )
  const dineInRatio =
    summary.netSales === 0
      ? 0
      : Math.round((summary.dineInSales / summary.netSales) * 100)

  return (
    <main className="management-page analytics-page">
      <section className="management-hero analytics-hero">
        <div>
          <p className="eyebrow">SALES PULSE</p>
          <h2>매출 흐름</h2>
          <p>
            결제 후 전달까지 완료된 주문만 순매출로 집계합니다.
          </p>
        </div>
        <div className="range-control" aria-label="매출 조회 기간">
          <button
            className={range === 7 ? 'active' : ''}
            onClick={() => setRange(7)}
          >
            최근 7일
          </button>
          <button
            className={range === 30 ? 'active' : ''}
            onClick={() => setRange(30)}
          >
            최근 30일
          </button>
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
                  <h3>일별 완료 매출</h3>
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

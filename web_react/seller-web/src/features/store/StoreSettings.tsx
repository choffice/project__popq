import { useEffect, useState } from 'react'
import {
  demoStore,
  freshDemoTables,
} from '../../data/demo'
import {
  changeStoreBusinessStatus,
  createStoreTable,
  getSellerStores,
  getStoreTables,
} from '../../services/api'
import type {
  BusinessStatus,
  SellerConnection,
  StoreSummary,
  StoreTable,
} from '../../types'

type Props = {
  connection: SellerConnection | null
  onError: (message: string | null) => void
  onBusinessStatusChange: (status: BusinessStatus) => void
}

const STATUS_LABEL: Record<BusinessStatus, string> = {
  PRE_OPEN: '오픈 준비',
  OPEN: '영업 중',
  CLOSED: '영업 종료',
}

export function StoreSettings({
  connection,
  onError,
  onBusinessStatusChange,
}: Props) {
  const isDemo = !connection
  const [store, setStore] = useState<StoreSummary>(() =>
    structuredClone(demoStore),
  )
  const [tables, setTables] = useState<StoreTable[]>(freshDemoTables)
  const [loading, setLoading] = useState(!isDemo)
  const [processing, setProcessing] = useState(false)
  const [showTableForm, setShowTableForm] = useState(false)
  const [tableCode, setTableCode] = useState('')
  const [tableName, setTableName] = useState('')

  useEffect(() => {
    const timer = window.setTimeout(() => {
      if (!connection) {
        const demo = structuredClone(demoStore)
        setStore(demo)
        setTables(freshDemoTables())
        setLoading(false)
        onBusinessStatusChange(demo.businessStatus)
        return
      }
      setLoading(true)
      void Promise.all([
        getSellerStores(connection),
        getStoreTables(connection),
      ])
        .then(([stores, storeTables]) => {
          const selected = stores.find(
            (item) => item.storeId === connection.storeId,
          )
          if (!selected) {
            throw new Error('선택한 스토어의 운영 권한을 찾을 수 없습니다.')
          }
          setStore(selected)
          setTables(storeTables)
          onBusinessStatusChange(selected.businessStatus)
          onError(null)
        })
        .catch((caught: unknown) =>
          onError(
            caught instanceof Error
              ? caught.message
              : '스토어 설정을 불러오지 못했습니다.',
          ),
        )
        .finally(() => setLoading(false))
    }, 0)
    return () => window.clearTimeout(timer)
  }, [connection, onBusinessStatusChange, onError])

  async function changeStatus(status: BusinessStatus) {
    setProcessing(true)
    try {
      const updated = isDemo
        ? { ...store, businessStatus: status }
        : await changeStoreBusinessStatus(connection, status)
      setStore(updated)
      onBusinessStatusChange(updated.businessStatus)
      onError(null)
    } catch (caught) {
      onError(
        caught instanceof Error
          ? caught.message
          : '영업 상태를 변경하지 못했습니다.',
      )
    } finally {
      setProcessing(false)
    }
  }

  async function addTable() {
    const code = tableCode.trim().toUpperCase()
    const name = tableName.trim()
    if (!/^[A-Z0-9_-]+$/.test(code) || !name) {
      onError('테이블 코드는 영문·숫자·밑줄·하이픈으로 입력해 주세요.')
      return
    }
    setProcessing(true)
    try {
      const created = isDemo
        ? {
            storeTableId: Math.max(0, ...tables.map((table) => table.storeTableId)) + 1,
            tableCode: code,
            name,
            status: 'ACTIVE' as const,
          }
        : await createStoreTable(connection, code, name)
      setTables((current) => [...current, created])
      setTableCode('')
      setTableName('')
      setShowTableForm(false)
      onError(null)
    } catch (caught) {
      onError(
        caught instanceof Error
          ? caught.message
          : '테이블을 추가하지 못했습니다.',
      )
    } finally {
      setProcessing(false)
    }
  }

  if (loading) {
    return (
      <main className="management-page">
        <div className="management-empty">스토어 설정을 불러오는 중입니다…</div>
      </main>
    )
  }

  return (
    <main className="management-page settings-page">
      <section className="management-hero settings-hero">
        <div>
          <p className="eyebrow">STORE OPERATIONS</p>
          <h2>{store.name}</h2>
          <p>{store.description ?? '스토어 소개가 아직 없습니다.'}</p>
        </div>
        <span className={`store-health status-${store.status.toLowerCase()}`}>
          {store.status === 'ACTIVE' ? '정상 운영' : store.status}
        </span>
      </section>

      <section className="settings-grid">
        <article className="business-status-card">
          <header>
            <div>
              <p className="eyebrow">BUSINESS STATUS</p>
              <h3>영업 상태</h3>
            </div>
            <span>{STATUS_LABEL[store.businessStatus]}</span>
          </header>
          <p>
            고객 QR 화면의 주문 가능 여부를 결정합니다. 실제 운영 상황과
            일치하도록 관리하세요.
          </p>
          <div className="status-options" role="radiogroup" aria-label="영업 상태">
            {(
              [
                ['PRE_OPEN', '오픈 준비', '주문 전 메뉴 미리보기'],
                ['OPEN', '영업 중', '고객 주문과 결제 허용'],
                ['CLOSED', '영업 종료', '신규 주문 차단'],
              ] as [BusinessStatus, string, string][]
            ).map(([value, label, description]) => (
              <button
                key={value}
                role="radio"
                aria-checked={store.businessStatus === value}
                className={store.businessStatus === value ? 'active' : ''}
                disabled={processing}
                onClick={() => void changeStatus(value)}
              >
                <span />
                <div>
                  <strong>{label}</strong>
                  <small>{description}</small>
                </div>
              </button>
            ))}
          </div>
        </article>

        <article className="store-info-card">
          <header>
            <p className="eyebrow">STORE PROFILE</p>
            <h3>운영 정보</h3>
          </header>
          <dl>
            <div>
              <dt>스토어 ID</dt>
              <dd>{store.storeId}</dd>
            </div>
            <div>
              <dt>운영 유형</dt>
              <dd>
                {store.storeType === 'LOCAL_STORE'
                  ? '상설 매장'
                  : '이벤트 커머스'}
              </dd>
            </div>
            <div>
              <dt>내 권한</dt>
              <dd>{store.myRole}</dd>
            </div>
            <div>
              <dt>스토어 상태</dt>
              <dd>{store.status}</dd>
            </div>
          </dl>
          <div className="security-note">
            <span>●</span>
            <p>
              <strong>서버 권한 검증 적용</strong>
              <small>모든 변경 요청은 StoreMember 권한으로 다시 확인합니다.</small>
            </p>
          </div>
        </article>

        <article className="tables-card">
          <header>
            <div>
              <p className="eyebrow">TABLES</p>
              <h3>테이블 관리</h3>
            </div>
            <button onClick={() => setShowTableForm(true)}>+ 테이블 추가</button>
          </header>
          <div className="table-list">
            {tables.map((table) => (
              <div key={table.storeTableId}>
                <span>{table.name.slice(0, 1)}</span>
                <p>
                  <strong>{table.name}</strong>
                  <small>{table.tableCode}</small>
                </p>
                <b className={table.status.toLowerCase()}>
                  {table.status === 'ACTIVE' ? '사용 중' : '중지'}
                </b>
              </div>
            ))}
          </div>
        </article>
      </section>

      {showTableForm && (
        <div className="modal-backdrop" role="presentation">
          <section
            className="connection-modal"
            role="dialog"
            aria-modal="true"
            aria-labelledby="table-title"
          >
            <button
              className="modal-close"
              aria-label="닫기"
              onClick={() => setShowTableForm(false)}
            >
              ×
            </button>
            <p className="eyebrow">NEW TABLE</p>
            <h2 id="table-title">테이블 추가</h2>
            <p>QR 발급에 사용할 고유 코드와 고객에게 보일 이름을 입력합니다.</p>
            <label>
              테이블 코드
              <input
                placeholder="예: WINDOW-08"
                value={tableCode}
                onChange={(event) => setTableCode(event.target.value)}
              />
            </label>
            <label>
              표시 이름
              <input
                placeholder="예: Window 08"
                value={tableName}
                onChange={(event) => setTableName(event.target.value)}
              />
            </label>
            <button
              className="primary-action"
              disabled={processing}
              onClick={() => void addTable()}
            >
              {processing ? '추가 중…' : '테이블 추가하기'}
            </button>
          </section>
        </div>
      )}
      <p className="source-note">
        {isDemo
          ? '데모 설정은 새로고침 시 초기화됩니다.'
          : '영업 상태와 테이블은 Spring Boot와 MySQL에 저장됩니다.'}
      </p>
    </main>
  )
}

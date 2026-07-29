import { useEffect, useMemo, useState } from 'react'
import QRCode from 'qrcode'
import {
  freshDemoQrCodes,
  freshDemoTables,
} from '../../data/demo'
import {
  changeQrStatus,
  getQrCodes,
  getStoreTables,
  issueQrCode,
} from '../../services/api'
import type {
  QrCodeSummary,
  QrIssued,
  SellerConnection,
  StoreTable,
} from '../../types'

type Props = {
  connection: SellerConnection | null
  onError: (message: string | null) => void
}

const STATUS_LABEL = {
  ACTIVE: '사용 중',
  INACTIVE: '일시 중지',
  REVOKED: '폐기됨',
  EXPIRED: '만료됨',
}

export function QrManagement({ connection, onError }: Props) {
  const isDemo = !connection
  const [qrCodes, setQrCodes] = useState<QrCodeSummary[]>(() =>
    freshDemoQrCodes(),
  )
  const [tables, setTables] = useState<StoreTable[]>(() => freshDemoTables())
  const [loading, setLoading] = useState(!isDemo)
  const [processingId, setProcessingId] = useState<number | null>(null)
  const [showIssue, setShowIssue] = useState(false)
  const [tableId, setTableId] = useState('7')
  const [expiresOn, setExpiresOn] = useState('')
  const [issued, setIssued] = useState<QrIssued | null>(null)
  const [qrImage, setQrImage] = useState('')

  useEffect(() => {
    const timer = window.setTimeout(() => {
      if (!connection) {
        setQrCodes(freshDemoQrCodes())
        setTables(freshDemoTables())
        setLoading(false)
        return
      }
      setLoading(true)
      void Promise.all([getQrCodes(connection), getStoreTables(connection)])
        .then(([codes, storeTables]) => {
          setQrCodes(codes)
          setTables(storeTables)
          setTableId(String(storeTables[0]?.storeTableId ?? ''))
          onError(null)
        })
        .catch((caught: unknown) =>
          onError(
            caught instanceof Error
              ? caught.message
              : 'QR 목록을 불러오지 못했습니다.',
          ),
        )
        .finally(() => setLoading(false))
    }, 0)
    return () => window.clearTimeout(timer)
  }, [connection, onError])

  useEffect(() => {
    if (!issued) return
    let active = true
    void QRCode.toDataURL(issued.publicUrl, {
      width: 280,
      margin: 2,
      color: { dark: '#171711', light: '#faf9f4' },
      errorCorrectionLevel: 'M',
    }).then((dataUrl) => {
      if (active) setQrImage(dataUrl)
    })
    return () => {
      active = false
    }
  }, [issued])

  const activeCount = qrCodes.filter((code) => code.status === 'ACTIVE').length
  const inactiveCount = qrCodes.filter(
    (code) => code.status === 'INACTIVE',
  ).length
  const availableTables = useMemo(
    () => tables.filter((table) => table.status === 'ACTIVE'),
    [tables],
  )

  async function issue() {
    const selectedTableId = Number(tableId)
    if (!Number.isInteger(selectedTableId)) {
      onError('QR을 연결할 테이블을 선택해 주세요.')
      return
    }
    const expiresAt = expiresOn
      ? new Date(`${expiresOn}T14:59:59Z`).toISOString()
      : null
    setProcessingId(-1)
    try {
      let result: QrIssued
      if (isDemo) {
        const nextId = Math.max(0, ...qrCodes.map((code) => code.qrCodeId)) + 1
        result = {
          qrCodeId: nextId,
          storeId: 1,
          storeTableId: selectedTableId,
          token: `demo-table-${selectedTableId}-${nextId}`,
          publicUrl: `http://127.0.0.1:5173/q/demo-table-${selectedTableId}-${nextId}`,
          status: 'ACTIVE',
          expiresAt,
        }
      } else {
        result = await issueQrCode(connection, selectedTableId, expiresAt)
      }
      const table = tables.find(
        (item) => item.storeTableId === selectedTableId,
      )
      setQrCodes((current) => [
        {
          qrCodeId: result.qrCodeId,
          storeTableId: result.storeTableId,
          tableName: table?.name ?? null,
          status: result.status,
          expiresAt: result.expiresAt,
          createdAt: new Date().toISOString(),
        },
        ...current,
      ])
      setQrImage('')
      setIssued(result)
      setShowIssue(false)
      onError(null)
    } catch (caught) {
      onError(
        caught instanceof Error ? caught.message : 'QR을 발급하지 못했습니다.',
      )
    } finally {
      setProcessingId(null)
    }
  }

  async function changeStatus(
    code: QrCodeSummary,
    action: 'activate' | 'deactivate' | 'revoke',
  ) {
    if (
      action === 'revoke' &&
      !window.confirm('이 QR을 폐기하면 다시 활성화할 수 없습니다. 계속할까요?')
    ) {
      return
    }
    setProcessingId(code.qrCodeId)
    try {
      let updated: QrCodeSummary
      if (isDemo) {
        updated = {
          ...code,
          status:
            action === 'activate'
              ? 'ACTIVE'
              : action === 'deactivate'
                ? 'INACTIVE'
                : 'REVOKED',
        }
      } else {
        updated = await changeQrStatus(
          connection,
          code.qrCodeId,
          action,
        )
      }
      setQrCodes((current) =>
        current.map((item) =>
          item.qrCodeId === updated.qrCodeId ? updated : item,
        ),
      )
      onError(null)
    } catch (caught) {
      onError(
        caught instanceof Error
          ? caught.message
          : 'QR 상태를 변경하지 못했습니다.',
      )
    } finally {
      setProcessingId(null)
    }
  }

  return (
    <main className="management-page">
      <section className="management-hero qr-hero">
        <div>
          <p className="eyebrow">TABLE ACCESS</p>
          <h2>QR 주문 입구</h2>
          <p>
            테이블별 주문 QR을 발급하고 노출 상태와 만료를 관리합니다.
          </p>
        </div>
        <div className="hero-stat-grid">
          <article>
            <small>전체 QR</small>
            <strong>{qrCodes.length}</strong>
          </article>
          <article>
            <small>사용 중</small>
            <strong>{activeCount}</strong>
          </article>
          <article>
            <small>일시 중지</small>
            <strong>{inactiveCount}</strong>
          </article>
        </div>
        <button className="hero-action" onClick={() => setShowIssue(true)}>
          + 새 QR 발급
        </button>
      </section>

      {loading ? (
        <div className="management-empty">QR 목록을 불러오는 중입니다…</div>
      ) : (
        <section className="qr-grid" aria-label="테이블 QR 목록">
          {qrCodes.map((code) => (
            <article className="qr-card" key={code.qrCodeId}>
              <div className="qr-visual" aria-hidden="true">
                <span />
                <span />
                <span />
                <i />
              </div>
              <div className="qr-card-copy">
                <div>
                  <span className={`qr-status status-${code.status.toLowerCase()}`}>
                    {STATUS_LABEL[code.status]}
                  </span>
                  <small>QR #{code.qrCodeId}</small>
                </div>
                <h3>{code.tableName ?? '공용 픽업'}</h3>
                <p>
                  {code.expiresAt
                    ? `${new Date(code.expiresAt).toLocaleDateString('ko-KR')}까지`
                    : '만료 없음'}
                </p>
              </div>
              <div className="qr-actions">
                {code.status === 'ACTIVE' && (
                  <button
                    disabled={processingId === code.qrCodeId}
                    onClick={() => void changeStatus(code, 'deactivate')}
                  >
                    일시 중지
                  </button>
                )}
                {code.status === 'INACTIVE' && (
                  <button
                    disabled={processingId === code.qrCodeId}
                    onClick={() => void changeStatus(code, 'activate')}
                  >
                    다시 사용
                  </button>
                )}
                {!['REVOKED', 'EXPIRED'].includes(code.status) && (
                  <button
                    className="danger-text"
                    disabled={processingId === code.qrCodeId}
                    onClick={() => void changeStatus(code, 'revoke')}
                  >
                    폐기
                  </button>
                )}
              </div>
            </article>
          ))}
        </section>
      )}

      {showIssue && (
        <div className="modal-backdrop" role="presentation">
          <section
            className="connection-modal"
            role="dialog"
            aria-modal="true"
            aria-labelledby="issue-title"
          >
            <button
              className="modal-close"
              aria-label="닫기"
              onClick={() => setShowIssue(false)}
            >
              ×
            </button>
            <p className="eyebrow">ISSUE QR</p>
            <h2 id="issue-title">새 QR 발급</h2>
            <p>테이블과 선택 만료일을 지정해 새 주문 입구를 만듭니다.</p>
            <label>
              연결 테이블
              <select
                value={tableId}
                onChange={(event) => setTableId(event.target.value)}
              >
                {availableTables.map((table) => (
                  <option key={table.storeTableId} value={table.storeTableId}>
                    {table.name} · {table.tableCode}
                  </option>
                ))}
              </select>
            </label>
            <label>
              만료일
              <input
                type="date"
                value={expiresOn}
                onChange={(event) => setExpiresOn(event.target.value)}
              />
              <small>비워두면 만료 없이 발급합니다.</small>
            </label>
            <button
              className="primary-action"
              disabled={processingId === -1 || availableTables.length === 0}
              onClick={() => void issue()}
            >
              {processingId === -1 ? '발급 중…' : 'QR 발급하기'}
            </button>
          </section>
        </div>
      )}

      {issued && (
        <div className="modal-backdrop" role="presentation">
          <section
            className="issued-modal"
            role="dialog"
            aria-modal="true"
            aria-labelledby="issued-title"
          >
            <button
              className="modal-close"
              aria-label="닫기"
              onClick={() => setIssued(null)}
            >
              ×
            </button>
            <p className="eyebrow">READY TO SCAN</p>
            <h2 id="issued-title">QR 발급 완료</h2>
            <p>보안을 위해 원본 토큰과 URL은 발급 직후 한 번만 제공합니다.</p>
            {qrImage && (
              <img
                className="issued-qr"
                src={qrImage}
                alt="발급된 주문 QR 코드"
              />
            )}
            <code>{issued.publicUrl}</code>
            <div className="issued-actions">
              <button
                className="secondary-action"
                onClick={() => void navigator.clipboard.writeText(issued.publicUrl)}
              >
                URL 복사
              </button>
              <a
                className="primary-action"
                href={qrImage}
                download={`popq-qr-${issued.qrCodeId}.png`}
              >
                QR 이미지 저장
              </a>
            </div>
          </section>
        </div>
      )}
    </main>
  )
}

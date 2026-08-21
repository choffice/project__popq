import { useEffect, useMemo, useState } from 'react'
import QRCode from 'qrcode'
import {
  freshDemoQrCodes,
  freshDemoTables,
} from '../../data/demo'
import {
  archiveQrCode,
  changeQrStatus,
  createStoreTable,
  getQrCodeDetail,
  getQrCodes,
  getStoreTables,
  issueQrCode,
  reissueQrCode,
  restoreQrCode,
} from '../../services/api'
import type {
  QrCodeDetail,
  QrCodeSummary,
  QrIssued,
  SellerConnection,
  StoreRole,
  StoreTable,
} from '../../types'

type Props = {
  connection: SellerConnection | null
  storeRole?: StoreRole
  onError: (message: string | null) => void
}

type QrArtifact = Pick<
  QrCodeDetail,
  | 'qrCodeId'
  | 'storeTableId'
  | 'tableName'
  | 'status'
  | 'expiresAt'
  | 'publicUrl'
>

type ArtifactMode = 'issued' | 'stored' | 'reissued'
type ListMode = 'current' | 'archived'
type QrConfirmation = { kind: 'reissue' | 'archive' | 'revoke'; code: QrCodeSummary } | null

const STATUS_LABEL = {
  ACTIVE: '사용 중',
  INACTIVE: '일시 중지',
  REVOKED: '폐기됨',
  EXPIRED: '만료됨',
}

function isFutureExpiration(expiresAt: string) {
  return new Date(expiresAt).getTime() > Date.now()
}

export function QrManagement({ connection, storeRole, onError }: Props) {
  const isDemo = !connection
  const canManage = isDemo || storeRole === 'OWNER' || storeRole === 'MANAGER'
  const [qrCodes, setQrCodes] = useState<QrCodeSummary[]>(() =>
    freshDemoQrCodes(),
  )
  const [tables, setTables] = useState<StoreTable[]>(() => freshDemoTables())
  const [loading, setLoading] = useState(!isDemo)
  const [processingId, setProcessingId] = useState<number | null>(null)
  const [showIssue, setShowIssue] = useState(false)
  const [tableId, setTableId] = useState('7')
  const [showTableForm, setShowTableForm] = useState(false)
  const [tableCode, setTableCode] = useState('')
  const [tableName, setTableName] = useState('')
  const [creatingTable, setCreatingTable] = useState(false)
  const [createdTableName, setCreatedTableName] = useState('')
  const [expiresOn, setExpiresOn] = useState('')
  const [artifact, setArtifact] = useState<QrArtifact | null>(null)
  const [artifactMode, setArtifactMode] = useState<ArtifactMode>('stored')
  const [qrImage, setQrImage] = useState('')
  const [listMode, setListMode] = useState<ListMode>('current')
  const [confirmation, setConfirmation] = useState<QrConfirmation>(null)

  useEffect(() => {
    const timer = window.setTimeout(() => {
      if (!connection) {
        setQrCodes(freshDemoQrCodes())
        setTables(freshDemoTables())
        setLoading(false)
        return
      }
      setLoading(true)
      void Promise.all([getQrCodes(connection, true), getStoreTables(connection)])
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
    if (!artifact) return
    let active = true
    void QRCode.toDataURL(artifact.publicUrl, {
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
  }, [artifact])

  const currentCodes = qrCodes.filter((code) => !code.archived)
  const archivedCodes = qrCodes.filter((code) => code.archived)
  const visibleCodes = listMode === 'current' ? currentCodes : archivedCodes
  const activeCount = currentCodes.filter((code) => code.status === 'ACTIVE').length
  const inactiveCount = currentCodes.filter(
    (code) => code.status === 'INACTIVE',
  ).length
  const availableTables = useMemo(
    () => tables.filter((table) => table.status === 'ACTIVE'),
    [tables],
  )

  function closeIssue() {
    setShowIssue(false)
    setShowTableForm(false)
    setTableCode('')
    setTableName('')
    setCreatedTableName('')
  }

  async function addTableAndContinue() {
    const code = tableCode.trim().toUpperCase()
    const name = tableName.trim()
    if (!/^[A-Z0-9_-]+$/.test(code)) {
      onError('테이블 코드는 영문·숫자·밑줄·하이픈으로 입력해 주세요.')
      return
    }
    if (!name) {
      onError('테이블 표시 이름을 입력해 주세요.')
      return
    }

    setCreatingTable(true)
    try {
      const created = isDemo
        ? {
            storeTableId:
              Math.max(0, ...tables.map((table) => table.storeTableId)) + 1,
            tableCode: code,
            name,
            status: 'ACTIVE' as const,
          }
        : await createStoreTable(connection, code, name)
      setTables((current) => [...current, created])
      setTableId(String(created.storeTableId))
      setCreatedTableName(created.name)
      setTableCode('')
      setTableName('')
      setShowTableForm(false)
      onError(null)
    } catch (caught) {
      onError(
        caught instanceof Error ? caught.message : '테이블을 추가하지 못했습니다.',
      )
    } finally {
      setCreatingTable(false)
    }
  }

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
          recoverable: true,
          archived: false,
        },
        ...current,
      ])
      setQrImage('')
      setArtifact({
        qrCodeId: result.qrCodeId,
        storeTableId: result.storeTableId,
        tableName: table?.name ?? null,
        status: result.status,
        expiresAt: result.expiresAt,
        publicUrl: result.publicUrl,
      })
      setArtifactMode('issued')
      closeIssue()
      onError(null)
    } catch (caught) {
      onError(
        caught instanceof Error ? caught.message : 'QR을 발급하지 못했습니다.',
      )
    } finally {
      setProcessingId(null)
    }
  }

  async function openArtifact(code: QrCodeSummary) {
    setProcessingId(code.qrCodeId)
    try {
      let detail: QrCodeDetail
      if (isDemo) {
        detail = {
          ...code,
          storeId: 1,
          publicUrl: `http://127.0.0.1:5173/q/demo-qr-${code.qrCodeId}`,
        }
      } else {
        detail = await getQrCodeDetail(connection, code.qrCodeId)
      }
      setQrImage('')
      setArtifact(detail)
      setArtifactMode('stored')
      onError(null)
    } catch (caught) {
      onError(
        caught instanceof Error
          ? caught.message
          : 'QR을 불러오지 못했습니다.',
      )
    } finally {
      setProcessingId(null)
    }
  }

  async function reissue(code: QrCodeSummary) {
    const expiration =
      code.expiresAt && isFutureExpiration(code.expiresAt)
        ? code.expiresAt
        : null
    setProcessingId(code.qrCodeId)
    try {
      let result: QrIssued
      if (isDemo) {
        const nextId = Math.max(0, ...qrCodes.map((item) => item.qrCodeId)) + 1
        result = {
          qrCodeId: nextId,
          storeId: 1,
          storeTableId: code.storeTableId,
          token: `demo-reissued-${nextId}`,
          publicUrl: `http://127.0.0.1:5173/q/demo-reissued-${nextId}`,
          status: 'ACTIVE',
          expiresAt: expiration,
        }
      } else {
        result = await reissueQrCode(
          connection,
          code.qrCodeId,
          expiration,
        )
      }
      setQrCodes((current) => [
        {
          qrCodeId: result.qrCodeId,
          storeTableId: result.storeTableId,
          tableName: code.tableName,
          status: result.status,
          expiresAt: result.expiresAt,
          createdAt: new Date().toISOString(),
          recoverable: true,
          archived: false,
        },
        ...current.map((item) =>
          item.qrCodeId === code.qrCodeId
            ? { ...item, status: 'REVOKED' as const }
            : item,
        ),
      ])
      setQrImage('')
      setArtifact({
        qrCodeId: result.qrCodeId,
        storeTableId: result.storeTableId,
        tableName: code.tableName,
        status: result.status,
        expiresAt: result.expiresAt,
        publicUrl: result.publicUrl,
      })
      setArtifactMode('reissued')
      onError(null)
    } catch (caught) {
      onError(
        caught instanceof Error ? caught.message : 'QR을 재발급하지 못했습니다.',
      )
    } finally {
      setProcessingId(null)
    }
  }

  async function downloadSvg() {
    if (!artifact) return
    try {
      const svg = await QRCode.toString(artifact.publicUrl, {
        type: 'svg',
        width: 1024,
        margin: 2,
        color: { dark: '#171711', light: '#ffffff' },
        errorCorrectionLevel: 'M',
      })
      const objectUrl = URL.createObjectURL(
        new Blob([svg], { type: 'image/svg+xml;charset=utf-8' }),
      )
      const anchor = document.createElement('a')
      anchor.href = objectUrl
      anchor.download = `popq-qr-${artifact.qrCodeId}.svg`
      anchor.click()
      window.setTimeout(() => URL.revokeObjectURL(objectUrl), 1000)
    } catch (caught) {
      onError(
        caught instanceof Error ? caught.message : 'SVG를 만들지 못했습니다.',
      )
    }
  }

  function printArtifact() {
    if (!artifact || !qrImage) return
    const popup = window.open('', '_blank', 'width=680,height=800')
    if (!popup) {
      onError('인쇄 창을 열 수 없습니다. 팝업 허용 여부를 확인해 주세요.')
      return
    }
    popup.document.title = `POPQ QR #${artifact.qrCodeId}`
    const style = popup.document.createElement('style')
    style.textContent = `
      body { margin: 0; padding: 48px; font-family: sans-serif; text-align: center; color: #171711; }
      h1 { margin: 0 0 8px; font-size: 28px; }
      p { margin: 0 0 28px; color: #69665e; }
      img { width: 420px; max-width: 100%; }
      small { display: block; margin-top: 22px; color: #8c887f; word-break: break-all; }
    `
    const title = popup.document.createElement('h1')
    title.textContent = artifact.tableName ?? `QR #${artifact.qrCodeId}`
    const description = popup.document.createElement('p')
    description.textContent = 'POPQ 테이블 주문 QR'
    const image = popup.document.createElement('img')
    image.alt = 'POPQ 주문 QR 코드'
    const url = popup.document.createElement('small')
    url.textContent = artifact.publicUrl
    image.addEventListener('load', () => {
      popup.focus()
      popup.print()
    })
    image.src = qrImage
    popup.document.head.append(style)
    popup.document.body.append(title, description, image, url)
  }

  async function archiveCode(code: QrCodeSummary) {
    setProcessingId(code.qrCodeId)
    try {
      const updated = isDemo
        ? { ...code, archived: true }
        : await archiveQrCode(connection, code.qrCodeId)
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
          : '폐기된 QR을 목록에서 제거하지 못했습니다.',
      )
    } finally {
      setProcessingId(null)
    }
  }

  async function restoreCode(code: QrCodeSummary) {
    setProcessingId(code.qrCodeId)
    try {
      const updated = isDemo
        ? { ...code, archived: false }
        : await restoreQrCode(connection, code.qrCodeId)
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
          : '폐기된 QR을 목록으로 복원하지 못했습니다.',
      )
    } finally {
      setProcessingId(null)
    }
  }

  async function changeStatus(
    code: QrCodeSummary,
    action: 'activate' | 'deactivate' | 'revoke',
  ) {
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
            <strong>{currentCodes.length}</strong>
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
        {canManage && <button className="hero-action" onClick={() => setShowIssue(true)}>
          + 새 QR 발급
        </button>}
      </section>

      {!canManage && <p className="permission-notice">STAFF 권한은 QR을 조회할 수 있지만 발급·상태 변경·재발급은 할 수 없습니다.</p>}

      <nav className="qr-list-tabs" aria-label="QR 목록 구분">
        <button
          className={listMode === 'current' ? 'active' : ''}
          aria-pressed={listMode === 'current'}
          onClick={() => setListMode('current')}
        >
          현재 QR <span>{currentCodes.length}</span>
        </button>
        <button
          className={listMode === 'archived' ? 'active' : ''}
          aria-pressed={listMode === 'archived'}
          onClick={() => setListMode('archived')}
        >
          폐기함 <span>{archivedCodes.length}</span>
        </button>
      </nav>

      {loading ? (
        <div className="management-empty">QR 목록을 불러오는 중입니다…</div>
      ) : visibleCodes.length === 0 ? (
        <div className="management-empty">
          {listMode === 'current'
            ? '현재 관리 중인 QR이 없습니다.'
            : '폐기함이 비어 있습니다.'}
        </div>
      ) : (
        <section
          className="qr-grid"
          aria-label={listMode === 'current' ? '테이블 QR 목록' : '폐기 QR 목록'}
        >
          {visibleCodes.map((code) => (
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
                {code.archived ? (
                  <>
                    {code.recoverable && (
                      <button
                        className="vault-action"
                        disabled={processingId === code.qrCodeId}
                        onClick={() => void openArtifact(code)}
                      >
                        QR 보기
                      </button>
                    )}
                    {canManage && <button
                      disabled={processingId === code.qrCodeId}
                      onClick={() => void restoreCode(code)}
                    >
                      목록으로 복원
                    </button>}
                  </>
                ) : (
                  <>
                    {code.recoverable ? (
                      <button
                        className="vault-action"
                        disabled={processingId === code.qrCodeId}
                        onClick={() => void openArtifact(code)}
                      >
                        QR 보기
                      </button>
                    ) : canManage ? (
                      <button
                        className="vault-action needs-reissue"
                        disabled={processingId === code.qrCodeId}
                        onClick={() => setConfirmation({ kind: 'reissue', code })}
                      >
                        재발급 필요
                      </button>
                    ) : null}
                    {canManage && code.status === 'ACTIVE' && (
                      <button
                        disabled={processingId === code.qrCodeId}
                        onClick={() => void changeStatus(code, 'deactivate')}
                      >
                        일시 중지
                      </button>
                    )}
                    {canManage && code.status === 'INACTIVE' && (
                      <button
                        disabled={processingId === code.qrCodeId}
                        onClick={() => void changeStatus(code, 'activate')}
                      >
                        다시 사용
                      </button>
                    )}
                    {canManage && code.status === 'REVOKED' && (
                      <button
                        className="archive-action"
                        disabled={processingId === code.qrCodeId}
                        onClick={() => setConfirmation({ kind: 'archive', code })}
                      >
                        목록에서 제거
                      </button>
                    )}
                    {canManage && !['REVOKED', 'EXPIRED'].includes(code.status) && (
                      <button
                        className="danger-text"
                        disabled={processingId === code.qrCodeId}
                        onClick={() => setConfirmation({ kind: 'revoke', code })}
                      >
                        폐기
                      </button>
                    )}
                  </>
                )}
              </div>
            </article>
          ))}
        </section>
      )}


      {confirmation && (
        <div className="modal-backdrop" role="presentation">
          <section className="connection-modal" role="dialog" aria-modal="true" aria-labelledby="qr-confirm-title">
            <button className="modal-close" aria-label="닫기" onClick={() => setConfirmation(null)}>×</button>
            <p className="eyebrow">QR ACTION</p>
            <h2 id="qr-confirm-title">
              {confirmation.kind === 'reissue' ? 'QR 재발급' : confirmation.kind === 'archive' ? 'QR 목록에서 제거' : 'QR 폐기'}
            </h2>
            <p>
              {confirmation.kind === 'reissue'
                ? '기존 QR은 즉시 폐기되고 새 QR로 교체됩니다. 계속할까요?'
                : confirmation.kind === 'archive'
                  ? '폐기된 QR을 현재 목록에서 제거하고 폐기함으로 이동할까요?'
                  : '이 QR을 폐기하면 다시 활성화할 수 없습니다. 계속할까요?'}
            </p>
            <button className="secondary-action" disabled={processingId != null} onClick={() => setConfirmation(null)}>취소</button>
            <button className="reject-action" style={{ width: '100%', marginTop: 8 }} disabled={processingId != null} onClick={() => { const target = confirmation; setConfirmation(null); if (target.kind === 'reissue') void reissue(target.code); else if (target.kind === 'archive') void archiveCode(target.code); else void changeStatus(target.code, 'revoke') }}>
              {confirmation.kind === 'reissue' ? '재발급하기' : confirmation.kind === 'archive' ? '목록에서 제거' : '폐기하기'}
            </button>
          </section>
        </div>
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
              onClick={closeIssue}
            >
              ×
            </button>
            <p className="eyebrow">ISSUE QR</p>
            <h2 id="issue-title">새 QR 발급</h2>
            <p>테이블과 선택 만료일을 지정해 새 주문 입구를 만듭니다.</p>
            {availableTables.length === 0 ? (
              <div className="qr-table-empty">
                <div>
                  <strong>먼저 테이블을 추가해 주세요</strong>
                  <p>테이블을 추가하면 이 화면에서 바로 QR 발급을 이어갈 수 있습니다.</p>
                </div>
                {showTableForm ? (
                  <div className="qr-table-form">
                    <label>
                      테이블 코드
                      <input
                        placeholder="TABLE-01"
                        value={tableCode}
                        onChange={(event) => setTableCode(event.target.value)}
                        autoFocus
                      />
                    </label>
                    <label>
                      표시 이름
                      <input
                        placeholder="테이블 1"
                        value={tableName}
                        onChange={(event) => setTableName(event.target.value)}
                      />
                    </label>
                    <button
                      className="primary-action"
                      disabled={creatingTable}
                      onClick={() => void addTableAndContinue()}
                    >
                      {creatingTable ? '추가 중…' : '추가하고 QR 발급 계속하기'}
                    </button>
                  </div>
                ) : (
                  <button
                    className="primary-action"
                    onClick={() => setShowTableForm(true)}
                  >
                    + 테이블 추가
                  </button>
                )}
              </div>
            ) : (
              <>
                {createdTableName && (
                  <p className="qr-table-created">
                    {createdTableName} 테이블이 추가되어 연결 테이블로 선택되었습니다.
                  </p>
                )}
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
                  disabled={processingId === -1}
                  onClick={() => void issue()}
                >
                  {processingId === -1 ? '발급 중…' : 'QR 발급하기'}
                </button>
              </>
            )}
          </section>
        </div>
      )}

      {artifact && (
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
              onClick={() => setArtifact(null)}
            >
              ×
            </button>
            <p className="eyebrow">READY TO SCAN</p>
            <h2 id="issued-title">
              {artifactMode === 'issued'
                ? 'QR 발급 완료'
                : artifactMode === 'reissued'
                  ? 'QR 재발급 완료'
                  : 'QR 보관함'}
            </h2>
            <p>
              {artifact.tableName ?? '공용 픽업'} · QR #{artifact.qrCodeId}
              <span className={`qr-status status-${artifact.status.toLowerCase()}`}>
                {STATUS_LABEL[artifact.status]}
              </span>
            </p>
            {qrImage && (
              <img
                className="issued-qr"
                src={qrImage}
                alt="발급된 주문 QR 코드"
              />
            )}
            <code>{artifact.publicUrl}</code>
            <div className="issued-actions">
              <button
                className="secondary-action"
                onClick={() => void navigator.clipboard.writeText(artifact.publicUrl)}
              >
                URL 복사
              </button>
              <a
                className="primary-action"
                href={qrImage}
                download={`popq-qr-${artifact.qrCodeId}.png`}
              >
                QR 이미지 저장
              </a>
              <button
                className="secondary-action"
                onClick={() => void downloadSvg()}
              >
                SVG 저장
              </button>
              <button className="secondary-action" onClick={printArtifact}>
                인쇄
              </button>
              <a
                className="secondary-action"
                href={artifact.publicUrl}
                target="_blank"
                rel="noreferrer"
              >
                QR 테스트
              </a>
            </div>
          </section>
        </div>
      )}
    </main>
  )
}

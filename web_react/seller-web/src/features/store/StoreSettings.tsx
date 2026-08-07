import { useEffect, useMemo, useState } from 'react'
import { demoStore, freshDemoTables } from '../../data/demo'
import {
  changeStoreBusinessStatus,
  createSellerStore,
  createStoreTable,
  deleteSellerStore,
  getSellerStoreDetail,
  getSellerStores,
  getStoreTables,
  updateSellerStore,
} from '../../services/api'
import type {
  BusinessStatus,
  SellerConnection,
  StoreClosedDay,
  StoreDetail,
  StoreSavePayload,
  StoreSummary,
  StoreTable,
  StoreType,
} from '../../types'

type Props = {
  connection: SellerConnection | null
  onError: (message: string | null) => void
  onBusinessStatusChange: (status: BusinessStatus) => void
  onStoreSelected?: (store: StoreSummary) => void
  onStoreUpdated?: (store: StoreSummary) => void
  onStoreDeleted?: (remainingStores: StoreSummary[]) => void
}

type EditorState = {
  storeType: StoreType
  name: string
  description: string
  address: string
  detailAddress: string
  representativeCategory: string
  imageUrl: string
  phone: string
  latitude: string
  longitude: string
  openTime: string
  closeTime: string
  closedDays: StoreClosedDay[]
  takeoutAvailable: boolean
  dineInAvailable: boolean
  orderAcceptingEnabled: boolean
  tags: string
}

const CLOSED_DAYS: { value: StoreClosedDay; label: string }[] = [
  { value: 'MONDAY', label: '월' },
  { value: 'TUESDAY', label: '화' },
  { value: 'WEDNESDAY', label: '수' },
  { value: 'THURSDAY', label: '목' },
  { value: 'FRIDAY', label: '금' },
  { value: 'SATURDAY', label: '토' },
  { value: 'SUNDAY', label: '일' },
]

const STATUS_LABEL: Record<BusinessStatus, string> = {
  PRE_OPEN: '오픈 준비',
  OPEN: '영업 중',
  CLOSED: '영업 종료',
}

function blankEditor(): EditorState {
  return {
    storeType: 'LOCAL_STORE',
    name: '',
    description: '',
    address: '',
    detailAddress: '',
    representativeCategory: '',
    imageUrl: '',
    phone: '',
    latitude: '',
    longitude: '',
    openTime: '09:00',
    closeTime: '21:00',
    closedDays: [],
    takeoutAvailable: true,
    dineInAvailable: true,
    orderAcceptingEnabled: true,
    tags: '',
  }
}

function editorFromStore(store: StoreDetail): EditorState {
  return {
    storeType: store.storeType,
    name: store.name,
    description: store.description ?? '',
    address: store.address ?? '',
    detailAddress: store.detailAddress ?? '',
    representativeCategory: store.representativeCategory ?? '',
    imageUrl: store.imageUrl ?? '',
    phone: store.phone ?? '',
    latitude: store.latitude?.toString() ?? '',
    longitude: store.longitude?.toString() ?? '',
    openTime: store.openTime?.slice(0, 5) ?? '',
    closeTime: store.closeTime?.slice(0, 5) ?? '',
    closedDays: store.closedDays,
    takeoutAvailable: store.takeoutAvailable,
    dineInAvailable: store.dineInAvailable,
    orderAcceptingEnabled: store.orderAcceptingEnabled,
    tags: store.tags.join(', '),
  }
}

function optional(value: string) {
  const trimmed = value.trim()
  return trimmed || null
}

function payloadFromEditor(editor: EditorState): StoreSavePayload {
  return {
    storeType: editor.storeType,
    name: editor.name.trim(),
    description: optional(editor.description),
    address: optional(editor.address),
    detailAddress: optional(editor.detailAddress),
    representativeCategory: optional(editor.representativeCategory),
    imageUrl: optional(editor.imageUrl),
    phone: optional(editor.phone),
    latitude: editor.latitude ? Number(editor.latitude) : null,
    longitude: editor.longitude ? Number(editor.longitude) : null,
    openTime: optional(editor.openTime),
    closeTime: optional(editor.closeTime),
    closedDays: editor.closedDays,
    takeoutAvailable: editor.takeoutAvailable,
    dineInAvailable: editor.dineInAvailable,
    orderAcceptingEnabled: editor.orderAcceptingEnabled,
    tags: editor.tags
      .split(',')
      .map((tag) => tag.trim())
      .filter(Boolean)
      .slice(0, 10),
  }
}

function demoDetail(): StoreDetail {
  return { ...structuredClone(demoStore), tags: ['카페', '성수'] }
}

export function StoreSettings({
  connection,
  onError,
  onBusinessStatusChange,
  onStoreSelected,
  onStoreUpdated,
  onStoreDeleted,
}: Props) {
  const isDemo = !connection
  const [store, setStore] = useState<StoreDetail>(demoDetail)
  const [tables, setTables] = useState<StoreTable[]>(freshDemoTables)
  const [loading, setLoading] = useState(!isDemo)
  const [processing, setProcessing] = useState(false)
  const [editorMode, setEditorMode] = useState<'edit' | 'create' | null>(null)
  const [editor, setEditor] = useState<EditorState>(blankEditor)
  const [showTableForm, setShowTableForm] = useState(false)
  const [tableCode, setTableCode] = useState('')
  const [tableName, setTableName] = useState('')

  const canManage = store.myRole === 'OWNER' || store.myRole === 'MANAGER'
  const canDelete = store.myRole === 'OWNER'
  const orderMethods = useMemo(
    () => [
      store.dineInAvailable && '매장 식사',
      store.takeoutAvailable && '포장',
    ].filter(Boolean).join(' · ') || '주문 방식 미설정',
    [store.dineInAvailable, store.takeoutAvailable],
  )

  useEffect(() => {
    let active = true
    const load = async () => {
      if (!connection) {
        const demo = demoDetail()
        setStore(demo)
        setTables(freshDemoTables())
        setLoading(false)
        onBusinessStatusChange(demo.businessStatus)
        return
      }
      setLoading(true)
      try {
        const [detail, storeTables] = await Promise.all([
          getSellerStoreDetail(connection),
          getStoreTables(connection),
        ])
        if (!active) return
        setStore(detail)
        setTables(storeTables)
        onBusinessStatusChange(detail.businessStatus)
        onStoreUpdated?.(detail)
        onError(null)
      } catch (caught) {
        if (active) onError(caught instanceof Error ? caught.message : '스토어 설정을 불러오지 못했습니다.')
      } finally {
        if (active) setLoading(false)
      }
    }
    void load()
    return () => { active = false }
  }, [connection, onBusinessStatusChange, onError, onStoreUpdated])

  async function changeStatus(status: BusinessStatus) {
    if (!canManage) return
    setProcessing(true)
    try {
      const updated = isDemo
        ? { ...store, businessStatus: status }
        : await changeStoreBusinessStatus(connection, status)
      setStore((current) => ({ ...current, ...updated }))
      onBusinessStatusChange(updated.businessStatus)
      onStoreUpdated?.(updated)
      onError(null)
    } catch (caught) {
      onError(caught instanceof Error ? caught.message : '영업 상태를 변경하지 못했습니다.')
    } finally {
      setProcessing(false)
    }
  }

  function openEditor(mode: 'edit' | 'create') {
    setEditor(mode === 'edit' ? editorFromStore(store) : blankEditor())
    setEditorMode(mode)
  }

  async function saveStore() {
    const payload = payloadFromEditor(editor)
    if (!payload.name) {
      onError('스토어 이름을 입력해 주세요.')
      return
    }
    setProcessing(true)
    try {
      if (editorMode === 'create') {
        if (isDemo) throw new Error('체험 모드에서는 스토어를 생성할 수 없습니다.')
        const created = await createSellerStore(connection, payload)
        setEditorMode(null)
        onStoreSelected?.(created)
      } else {
        const updated = isDemo
          ? { ...store, ...payload }
          : await updateSellerStore(connection, payload)
        setStore(updated)
        setEditorMode(null)
        onStoreUpdated?.(updated)
        onError(null)
      }
    } catch (caught) {
      onError(caught instanceof Error ? caught.message : '스토어를 저장하지 못했습니다.')
    } finally {
      setProcessing(false)
    }
  }

  async function removeStore() {
    if (!connection || !canDelete) return
    if (!window.confirm(`'${store.name}' 스토어를 삭제할까요? 이 작업은 되돌릴 수 없습니다.`)) return
    setProcessing(true)
    try {
      await deleteSellerStore(connection)
      const remaining = await getSellerStores(connection)
      onStoreDeleted?.(remaining)
      onError(null)
    } catch (caught) {
      onError(caught instanceof Error ? caught.message : '스토어를 삭제하지 못했습니다.')
    } finally {
      setProcessing(false)
    }
  }

  async function addTable() {
    const code = tableCode.trim().toUpperCase()
    const name = tableName.trim()
    if (!canManage || !/^[A-Z0-9_-]+$/.test(code) || !name) {
      onError('테이블 코드는 영문·숫자·밑줄·하이픈으로 입력해 주세요.')
      return
    }
    setProcessing(true)
    try {
      const created = isDemo
        ? { storeTableId: Math.max(0, ...tables.map((table) => table.storeTableId)) + 1, tableCode: code, name, status: 'ACTIVE' as const }
        : await createStoreTable(connection, code, name)
      setTables((current) => [...current, created])
      setTableCode('')
      setTableName('')
      setShowTableForm(false)
      onError(null)
    } catch (caught) {
      onError(caught instanceof Error ? caught.message : '테이블을 추가하지 못했습니다.')
    } finally {
      setProcessing(false)
    }
  }

  if (loading) return <main className="management-page"><div className="management-empty">스토어 설정을 불러오는 중입니다.</div></main>

  return (
    <main className="management-page settings-page">
      <section className="management-hero settings-hero">
        <div>
          <p className="eyebrow">STORE OPERATIONS</p>
          <h2>{store.name}</h2>
          <p>{store.description ?? '스토어 소개가 아직 없습니다.'}</p>
        </div>
        <div className="store-profile-actions">
          <span className={`store-health status-${store.status.toLowerCase()}`}>{store.status === 'ACTIVE' ? '정상 운영' : store.status}</span>
          <button className="secondary-action" onClick={() => openEditor('create')}>+ 새 스토어</button>
          {canManage && <button className="secondary-action" onClick={() => openEditor('edit')}>상세 편집</button>}
          {canDelete && <button className="danger-action" disabled={processing} onClick={() => void removeStore()}>스토어 삭제</button>}
        </div>
      </section>

      {store.myRole === 'STAFF' && <p className="permission-notice">STAFF 권한은 스토어 정보를 조회할 수 있지만 설정을 변경할 수 없습니다.</p>}

      <section className="settings-grid">
        <article className="business-status-card">
          <header><div><p className="eyebrow">BUSINESS STATUS</p><h3>영업 상태</h3></div><span>{STATUS_LABEL[store.businessStatus]}</span></header>
          <p>고객 주문 가능 여부에 맞춰 현재 영업 상태를 관리합니다.</p>
          <div className="status-options" role="radiogroup" aria-label="영업 상태">
            {(['PRE_OPEN', 'OPEN', 'CLOSED'] as BusinessStatus[]).map((value) => (
              <button key={value} role="radio" aria-checked={store.businessStatus === value} className={store.businessStatus === value ? 'active' : ''} disabled={processing || !canManage} onClick={() => void changeStatus(value)}>
                <span /><div><strong>{STATUS_LABEL[value]}</strong><small>{value === 'OPEN' ? '고객 주문 허용' : '신규 주문 제한'}</small></div>
              </button>
            ))}
          </div>
        </article>

        <article className="store-info-card">
          <header><p className="eyebrow">STORE PROFILE</p><h3>운영 정보</h3></header>
          <dl>
            <div><dt>권한</dt><dd>{store.myRole}</dd></div>
            <div><dt>주소</dt><dd>{[store.address, store.detailAddress].filter(Boolean).join(' ') || '-'}</dd></div>
            <div><dt>연락처</dt><dd>{store.phone || '-'}</dd></div>
            <div><dt>영업시간</dt><dd>{store.openTime && store.closeTime ? `${store.openTime.slice(0, 5)}–${store.closeTime.slice(0, 5)}` : '-'}</dd></div>
            <div><dt>휴무일</dt><dd>{store.closedDays.map((day) => CLOSED_DAYS.find((item) => item.value === day)?.label).join(', ') || '없음'}</dd></div>
            <div><dt>주문 방식</dt><dd>{orderMethods}</dd></div>
            <div><dt>태그</dt><dd>{store.tags.join(', ') || '-'}</dd></div>
          </dl>
        </article>

        <article className="tables-card">
          <header><div><p className="eyebrow">TABLES</p><h3>테이블 관리</h3></div>{canManage && <button onClick={() => setShowTableForm(true)}>+ 테이블 추가</button>}</header>
          <div className="table-list">{tables.map((table) => <div key={table.storeTableId}><span>{table.name.slice(0, 1)}</span><p><strong>{table.name}</strong><small>{table.tableCode}</small></p><b className={table.status.toLowerCase()}>{table.status === 'ACTIVE' ? '사용 중' : '중지'}</b></div>)}</div>
        </article>
      </section>

      {editorMode && (
        <div className="modal-backdrop" role="presentation"><section className="connection-modal store-editor-modal" role="dialog" aria-modal="true" aria-labelledby="store-editor-title">
          <button className="modal-close" aria-label="닫기" onClick={() => setEditorMode(null)}>×</button>
          <p className="eyebrow">{editorMode === 'create' ? 'NEW STORE' : 'STORE PROFILE'}</p>
          <h2 id="store-editor-title">{editorMode === 'create' ? '스토어 생성' : '스토어 상세 편집'}</h2>
          <div className="store-editor-grid">
            <label>유형<select value={editor.storeType} onChange={(event) => setEditor({ ...editor, storeType: event.target.value as StoreType })}><option value="LOCAL_STORE">상설 매장</option><option value="EVENT_COMMERCE">이벤트 커머스</option></select></label>
            <label>이름<input maxLength={150} value={editor.name} onChange={(event) => setEditor({ ...editor, name: event.target.value })} /></label>
            <label className="wide">소개<textarea maxLength={1000} value={editor.description} onChange={(event) => setEditor({ ...editor, description: event.target.value })} /></label>
            <label>주소<input value={editor.address} onChange={(event) => setEditor({ ...editor, address: event.target.value })} /></label>
            <label>상세 주소<input value={editor.detailAddress} onChange={(event) => setEditor({ ...editor, detailAddress: event.target.value })} /></label>
            <label>대표 카테고리<input value={editor.representativeCategory} onChange={(event) => setEditor({ ...editor, representativeCategory: event.target.value })} /></label>
            <label>연락처<input value={editor.phone} onChange={(event) => setEditor({ ...editor, phone: event.target.value })} /></label>
            <label>오픈 시간<input type="time" value={editor.openTime} onChange={(event) => setEditor({ ...editor, openTime: event.target.value })} /></label>
            <label>마감 시간<input type="time" value={editor.closeTime} onChange={(event) => setEditor({ ...editor, closeTime: event.target.value })} /></label>
            <label>위도<input type="number" step="any" value={editor.latitude} onChange={(event) => setEditor({ ...editor, latitude: event.target.value })} /></label>
            <label>경도<input type="number" step="any" value={editor.longitude} onChange={(event) => setEditor({ ...editor, longitude: event.target.value })} /></label>
            <label className="wide">이미지 URL<input value={editor.imageUrl} onChange={(event) => setEditor({ ...editor, imageUrl: event.target.value })} /></label>
            <label className="wide">태그 (쉼표로 구분)<input value={editor.tags} onChange={(event) => setEditor({ ...editor, tags: event.target.value })} /></label>
          </div>
          <fieldset className="choice-fieldset"><legend>정기 휴무일</legend>{CLOSED_DAYS.map((day) => <label key={day.value}><input type="checkbox" checked={editor.closedDays.includes(day.value)} onChange={() => setEditor({ ...editor, closedDays: editor.closedDays.includes(day.value) ? editor.closedDays.filter((value) => value !== day.value) : [...editor.closedDays, day.value] })} />{day.label}</label>)}</fieldset>
          <fieldset className="choice-fieldset"><legend>주문 설정</legend><label><input type="checkbox" checked={editor.dineInAvailable} onChange={(event) => setEditor({ ...editor, dineInAvailable: event.target.checked })} />매장 식사</label><label><input type="checkbox" checked={editor.takeoutAvailable} onChange={(event) => setEditor({ ...editor, takeoutAvailable: event.target.checked })} />포장</label><label><input type="checkbox" checked={editor.orderAcceptingEnabled} onChange={(event) => setEditor({ ...editor, orderAcceptingEnabled: event.target.checked })} />주문 접수</label></fieldset>
          <button className="primary-action" disabled={processing} onClick={() => void saveStore()}>{processing ? '저장 중…' : '저장'}</button>
        </section></div>
      )}

      {showTableForm && <div className="modal-backdrop" role="presentation"><section className="connection-modal" role="dialog" aria-modal="true" aria-labelledby="table-title"><button className="modal-close" aria-label="닫기" onClick={() => setShowTableForm(false)}>×</button><p className="eyebrow">NEW TABLE</p><h2 id="table-title">테이블 추가</h2><label>테이블 코드<input placeholder="WINDOW-08" value={tableCode} onChange={(event) => setTableCode(event.target.value)} /></label><label>표시 이름<input placeholder="Window 08" value={tableName} onChange={(event) => setTableName(event.target.value)} /></label><button className="primary-action" disabled={processing} onClick={() => void addTable()}>{processing ? '추가 중…' : '테이블 추가하기'}</button></section></div>}
    </main>
  )
}

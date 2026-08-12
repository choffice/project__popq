import { useCallback, useEffect, useState } from 'react'
import {
  changeSellerAnnouncementStatus,
  createSellerAnnouncement,
  getSellerAnnouncements,
  updateSellerAnnouncement,
} from '../../services/api'
import type {
  Announcement,
  AnnouncementStatus,
  SellerConnection,
  StoreRole,
} from '../../types'

type Props = {
  connection: SellerConnection | null
  storeRole?: StoreRole
  onError: (message: string | null) => void
}

const STATUS_LABEL: Record<AnnouncementStatus, string> = {
  DRAFT: '초안',
  PUBLISHED: '게시 중',
  HIDDEN: '숨김',
}

const demoAnnouncements: Announcement[] = [
  {
    announcementId: 1,
    storeId: 1,
    title: '주말 영업시간 안내',
    content: '이번 주말은 오전 10시부터 오후 8시까지 운영합니다.',
    status: 'PUBLISHED',
    publishedAt: new Date().toISOString(),
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  },
]

export function AnnouncementManagement({ connection, storeRole, onError }: Props) {
  const isDemo = !connection
  const canManage = isDemo || storeRole === 'OWNER' || storeRole === 'MANAGER'
  const [items, setItems] = useState<Announcement[]>(demoAnnouncements)
  const [loading, setLoading] = useState(!isDemo)
  const [processing, setProcessing] = useState(false)
  const [editing, setEditing] = useState<Announcement | null | 'new'>(null)
  const [title, setTitle] = useState('')
  const [content, setContent] = useState('')
  const [notifyInterestedCustomers, setNotifyInterestedCustomers] = useState(false)

  const load = useCallback(async () => {
    if (!connection) {
      setItems(structuredClone(demoAnnouncements))
      setLoading(false)
      return
    }
    setLoading(true)
    try {
      setItems(await getSellerAnnouncements(connection))
      onError(null)
    } catch (caught) {
      onError(caught instanceof Error ? caught.message : '공지사항을 불러오지 못했습니다.')
    } finally {
      setLoading(false)
    }
  }, [connection, onError])

  useEffect(() => {
    const timer = window.setTimeout(() => { void load() }, 0)
    return () => window.clearTimeout(timer)
  }, [load])

  function openEditor(item?: Announcement) {
    setEditing(item ?? 'new')
    setTitle(item?.title ?? '')
    setContent(item?.content ?? '')
    setNotifyInterestedCustomers(false)
  }

  async function save() {
    if (!canManage || !title.trim() || !content.trim()) {
      onError('제목과 내용을 모두 입력해 주세요.')
      return
    }
    setProcessing(true)
    try {
      if (isDemo) {
        const now = new Date().toISOString()
        const saved: Announcement = typeof editing === 'object' && editing
          ? { ...editing, title: title.trim(), content: content.trim(), status: notifyInterestedCustomers ? 'PUBLISHED' : editing.status, publishedAt: notifyInterestedCustomers ? now : editing.publishedAt, updatedAt: now }
          : { announcementId: Date.now(), storeId: 1, title: title.trim(), content: content.trim(), status: notifyInterestedCustomers ? 'PUBLISHED' : 'DRAFT', publishedAt: notifyInterestedCustomers ? now : null, createdAt: now, updatedAt: now }
        setItems((current) => typeof editing === 'object' && editing ? current.map((item) => item.announcementId === saved.announcementId ? saved : item) : [saved, ...current])
      } else if (typeof editing === 'object' && editing) {
        const saved = await updateSellerAnnouncement(connection, editing.announcementId, title.trim(), content.trim(), notifyInterestedCustomers)
        setItems((current) => current.map((item) => item.announcementId === saved.announcementId ? saved : item))
      } else {
        const saved = await createSellerAnnouncement(connection, title.trim(), content.trim(), notifyInterestedCustomers)
        setItems((current) => [saved, ...current])
      }
      setEditing(null)
      onError(null)
    } catch (caught) {
      onError(caught instanceof Error ? caught.message : '공지사항을 저장하지 못했습니다.')
    } finally {
      setProcessing(false)
    }
  }

  async function changeStatus(item: Announcement, status: AnnouncementStatus) {
    if (!canManage) return
    setProcessing(true)
    try {
      const updated = isDemo
        ? { ...item, status, publishedAt: status === 'PUBLISHED' ? new Date().toISOString() : item.publishedAt }
        : await changeSellerAnnouncementStatus(connection, item.announcementId, status)
      setItems((current) => current.map((candidate) => candidate.announcementId === updated.announcementId ? updated : candidate))
      onError(null)
    } catch (caught) {
      onError(caught instanceof Error ? caught.message : '공지 상태를 변경하지 못했습니다.')
    } finally {
      setProcessing(false)
    }
  }

  return (
    <main className="management-page">
      <section className="management-hero compact-hero">
        <div><p className="eyebrow">STORE ANNOUNCEMENTS</p><h2>공지사항</h2><p>초안을 준비하고 고객에게 게시하거나 잠시 숨길 수 있습니다.</p></div>
        {canManage && <button className="primary-action" onClick={() => openEditor()}>+ 새 공지</button>}
      </section>
      {!canManage && <p className="permission-notice">STAFF 권한은 공지를 조회할 수 있지만 작성하거나 상태를 변경할 수 없습니다.</p>}
      {loading ? <div className="management-empty">공지사항을 불러오는 중입니다.</div> : (
        <section className="announcement-list">
          {items.length === 0 && <div className="management-empty">등록된 공지사항이 없습니다.</div>}
          {items.map((item) => <article key={item.announcementId} className="announcement-card">
            <header><div><span className={`announcement-status status-${item.status.toLowerCase()}`}>{STATUS_LABEL[item.status]}</span><h3>{item.title}</h3></div><time>{new Date(item.updatedAt).toLocaleString('ko-KR')}</time></header>
            <p>{item.content}</p>
            {canManage && <footer><button className="secondary-action" onClick={() => openEditor(item)}>수정</button>{item.status !== 'PUBLISHED' && <button disabled={processing} onClick={() => void changeStatus(item, 'PUBLISHED')}>게시</button>}{item.status === 'PUBLISHED' && <button disabled={processing} onClick={() => void changeStatus(item, 'HIDDEN')}>숨김</button>}{item.status === 'HIDDEN' && <button disabled={processing} onClick={() => void changeStatus(item, 'DRAFT')}>초안으로</button>}</footer>}
          </article>)}
        </section>
      )}
      {editing && <div className="modal-backdrop" role="presentation"><section className="connection-modal announcement-editor" role="dialog" aria-modal="true"><button className="modal-close" aria-label="닫기" onClick={() => setEditing(null)}>×</button><p className="eyebrow">ANNOUNCEMENT DRAFT</p><h2>{editing === 'new' ? '공지 작성' : '공지 수정'}</h2><label>제목<input maxLength={200} value={title} onChange={(event) => setTitle(event.target.value)} /></label><label>내용<textarea maxLength={2000} rows={8} value={content} onChange={(event) => setContent(event.target.value)} /></label><label className="required-check"><input type="checkbox" checked={notifyInterestedCustomers} onChange={(event) => setNotifyInterestedCustomers(event.target.checked)} />찜한 고객에게 알림 보내기</label><small>선택하면 저장과 동시에 공지를 게시하고 관심 고객에게 알립니다.</small><button className="primary-action" disabled={processing} onClick={() => void save()}>{processing ? '저장 중…' : notifyInterestedCustomers ? '게시하고 알림 보내기' : '초안 저장'}</button></section></div>}
    </main>
  )
}

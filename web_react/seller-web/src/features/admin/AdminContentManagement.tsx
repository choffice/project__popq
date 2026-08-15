import { useCallback, useEffect, useState } from 'react'
import {
  getAdminFaqs,
  getAdminPlatformAnnouncements,
  saveAdminFaq,
  saveAdminPlatformAnnouncement,
  updateAdminFaqStatus,
  updateAdminPlatformAnnouncementStatus,
} from '../../services/api'
import type {
  AppAudience,
  ContentStatus,
  Faq,
  PageResponse,
  PlatformAnnouncement,
  SellerConnection,
} from '../../types'

type Props = {
  connection: SellerConnection | null
  kind: 'announcements' | 'faqs'
  onError: (message: string | null) => void
}

const audienceLabel: Record<AppAudience, string> = {
  ALL: '전체 앱', CUSTOMER_APP: '구매자 앱', SELLER_APP: '판매자 앱',
}
const statusLabel: Record<ContentStatus, string> = {
  DRAFT: '초안', PUBLISHED: '게시', HIDDEN: '숨김',
}

const emptyPage = <T,>(): PageResponse<T> => ({
  content: [], page: 0, size: 20, totalElements: 0, totalPages: 0, first: true, last: true,
})

function toDateTimeLocalValue(value: string | null) {
  if (!value) return ''
  const instant = new Date(value)
  if (Number.isNaN(instant.getTime())) return ''
  const local = new Date(instant.getTime() - instant.getTimezoneOffset() * 60_000)
  return local.toISOString().slice(0, 16)
}

function toIsoInstant(value: string) {
  if (!value) return null
  const instant = new Date(value)
  return Number.isNaN(instant.getTime()) ? undefined : instant.toISOString()
}

export function AdminContentManagement({ connection, kind, onError }: Props) {
  const [announcements, setAnnouncements] = useState<PageResponse<PlatformAnnouncement>>(emptyPage)
  const [faqs, setFaqs] = useState<PageResponse<Faq>>(emptyPage)
  const [page, setPage] = useState(0)
  const [query, setQuery] = useState('')
  const [debouncedQuery, setDebouncedQuery] = useState('')
  const [audience, setAudience] = useState<AppAudience | ''>('')
  const [status, setStatus] = useState<ContentStatus | ''>('')
  const [loading, setLoading] = useState(true)
  const [refreshVersion, setRefreshVersion] = useState(0)
  const [editingAnnouncement, setEditingAnnouncement] = useState<PlatformAnnouncement | 'new' | null>(null)
  const [editingFaq, setEditingFaq] = useState<Faq | 'new' | null>(null)
  const [formAudience, setFormAudience] = useState<AppAudience>('ALL')
  const [title, setTitle] = useState('')
  const [content, setContent] = useState('')
  const [publishStartAt, setPublishStartAt] = useState('')
  const [publishEndAt, setPublishEndAt] = useState('')
  const [category, setCategory] = useState('기타')
  const [question, setQuestion] = useState('')
  const [answer, setAnswer] = useState('')
  const [displayOrder, setDisplayOrder] = useState(0)
  const [saving, setSaving] = useState(false)
  const [saveError, setSaveError] = useState<string | null>(null)
  const [feedback, setFeedback] = useState<string | null>(null)

  useEffect(() => {
    const timer = window.setTimeout(() => setDebouncedQuery(query.trim()), 300)
    return () => window.clearTimeout(timer)
  }, [query])

  useEffect(() => {
    const timer = window.setTimeout(() => {
      setPage(0); setQuery(''); setDebouncedQuery(''); setAudience(''); setStatus('')
    }, 0)
    return () => window.clearTimeout(timer)
  }, [kind])

  const load = useCallback(async () => {
    setLoading(true)
    try {
      if (!connection) {
        setAnnouncements(emptyPage())
        setFaqs(emptyPage())
        return
      }
      if (kind === 'announcements') {
        setAnnouncements(await getAdminPlatformAnnouncements(connection, { page, size: 20, query: debouncedQuery, audience: audience || undefined, status: status || undefined }))
      } else {
        setFaqs(await getAdminFaqs(connection, { page, size: 20, query: debouncedQuery, audience: audience || undefined, status: status || undefined }))
      }
      onError(null)
    } catch (caught) {
      onError(caught instanceof Error ? caught.message : '콘텐츠를 불러오지 못했습니다.')
    } finally { setLoading(false) }
  }, [audience, connection, debouncedQuery, kind, onError, page, status])

  useEffect(() => {
    const timer = window.setTimeout(() => { void load() }, 0)
    return () => window.clearTimeout(timer)
  }, [load, refreshVersion])

  function openAnnouncement(item?: PlatformAnnouncement) {
    setSaveError(null)
    setFeedback(null)
    setEditingAnnouncement(item ?? 'new')
    setFormAudience(item?.audience ?? 'ALL')
    setTitle(item?.title ?? '')
    setContent(item?.content ?? '')
    setPublishStartAt(toDateTimeLocalValue(item?.publishStartAt ?? null))
    setPublishEndAt(toDateTimeLocalValue(item?.publishEndAt ?? null))
  }

  function openFaq(item?: Faq) {
    setEditingFaq(item ?? 'new')
    setFormAudience(item?.audience ?? 'ALL')
    setCategory(item?.category ?? '기타')
    setQuestion(item?.question ?? '')
    setAnswer(item?.answer ?? '')
    setDisplayOrder(item?.displayOrder ?? 0)
  }

  async function saveAnnouncement() {
    setSaveError(null)
    if (!connection) {
      setSaveError('관리자 연결을 확인해 주세요.')
      return
    }
    if (!title.trim() || !content.trim()) {
      setSaveError('제목과 내용을 모두 입력해 주세요.')
      return
    }
    const startAt = toIsoInstant(publishStartAt)
    const endAt = toIsoInstant(publishEndAt)
    if (startAt === undefined || endAt === undefined) {
      setSaveError('게시 시작과 종료 시각을 다시 확인해 주세요.')
      return
    }
    if (startAt && endAt && new Date(endAt) <= new Date(startAt)) {
      setSaveError('게시 종료 시각은 시작 시각보다 뒤여야 합니다.')
      return
    }
    setSaving(true)
    try {
      const isNew = editingAnnouncement === 'new'
      await saveAdminPlatformAnnouncement(connection, {
        platformAnnouncementId: typeof editingAnnouncement === 'object' && editingAnnouncement ? editingAnnouncement.platformAnnouncementId : undefined,
        audience: formAudience,
        title: title.trim(),
        content: content.trim(),
        publishStartAt: startAt,
        publishEndAt: endAt,
      })
      setEditingAnnouncement(null)
      setFeedback(isNew ? '공지가 초안으로 저장되었습니다. 목록에서 게시할 수 있습니다.' : '공지 수정이 저장되었습니다.')
      setPage(0)
      setQuery('')
      setDebouncedQuery('')
      setAudience('')
      setStatus('')
      setRefreshVersion((value) => value + 1)
      onError(null)
    } catch (caught) {
      const message = caught instanceof Error ? caught.message : '플랫폼 공지를 저장하지 못했습니다.'
      setSaveError(message)
      onError(message)
    } finally { setSaving(false) }
  }

  async function saveFaq() {
    if (!connection || !category.trim() || !question.trim() || !answer.trim()) return
    setSaving(true)
    try {
      await saveAdminFaq(connection, {
        faqId: typeof editingFaq === 'object' && editingFaq ? editingFaq.faqId : undefined,
        audience: formAudience,
        category: category.trim(),
        question: question.trim(),
        answer: answer.trim(),
        displayOrder,
      })
      setEditingFaq(null)
      setRefreshVersion((value) => value + 1)
    } catch (caught) {
      onError(caught instanceof Error ? caught.message : 'FAQ를 저장하지 못했습니다.')
    } finally { setSaving(false) }
  }

  async function changeAnnouncementStatus(item: PlatformAnnouncement, next: ContentStatus) {
    if (!connection) return
    try { await updateAdminPlatformAnnouncementStatus(connection, item.platformAnnouncementId, next); await load() }
    catch (caught) { onError(caught instanceof Error ? caught.message : '공지 상태를 변경하지 못했습니다.') }
  }

  async function changeFaqStatus(item: Faq, next: ContentStatus) {
    if (!connection) return
    try { await updateAdminFaqStatus(connection, item.faqId, next); await load() }
    catch (caught) { onError(caught instanceof Error ? caught.message : 'FAQ 상태를 변경하지 못했습니다.') }
  }

  const currentPage = kind === 'announcements' ? announcements : faqs

  return (
    <main className="management-page admin-content-page">
      <section className="management-hero compact-hero">
        <div><p className="eyebrow">PLATFORM CONTENT</p><h2>{kind === 'announcements' ? '플랫폼 공지' : 'FAQ 관리'}</h2><p>{kind === 'announcements' ? '구매자 앱과 판매자 앱에 노출할 공지와 게시 기간을 관리합니다.' : '앱별 자주 묻는 질문, 노출 순서와 게시 상태를 관리합니다.'}</p></div>
        <button className="primary-action" disabled={!connection} onClick={() => kind === 'announcements' ? openAnnouncement() : openFaq()}>+ 새 {kind === 'announcements' ? '공지' : 'FAQ'}</button>
      </section>
      <section className="admin-toolbar">
        <label className="search-field"><span>⌕</span><input aria-label="콘텐츠 검색" placeholder="제목 또는 내용 검색" value={query} onChange={(event) => { setQuery(event.target.value); setPage(0) }} /></label>
        <div className="admin-filter-group">
          <select aria-label="대상 앱 필터" value={audience} onChange={(event) => { setAudience(event.target.value as AppAudience | ''); setPage(0) }}><option value="">대상 전체</option><option value="ALL">전체 앱</option><option value="CUSTOMER_APP">구매자 앱</option><option value="SELLER_APP">판매자 앱</option></select>
          <select aria-label="게시 상태 필터" value={status} onChange={(event) => { setStatus(event.target.value as ContentStatus | ''); setPage(0) }}><option value="">상태 전체</option><option value="DRAFT">초안</option><option value="PUBLISHED">게시</option><option value="HIDDEN">숨김</option></select>
        </div>
      </section>
      {feedback && <p className="content-feedback" role="status">{feedback}</p>}
      {loading ? <div className="management-empty">콘텐츠를 불러오는 중입니다.</div> : (
        <section className="admin-content-list">
          {kind === 'announcements' && announcements.content.map((item) => <article className="admin-content-card" key={item.platformAnnouncementId}><header><div><span className={`admin-status ${item.status.toLowerCase()}`}>{statusLabel[item.status]}</span><span className="content-audience">{audienceLabel[item.audience]}</span><h3>{item.title}</h3></div><time>{new Date(item.updatedAt).toLocaleString('ko-KR')}</time></header><p>{item.content}</p><small>{item.publishStartAt ? new Date(item.publishStartAt).toLocaleString('ko-KR') : '즉시'} ~ {item.publishEndAt ? new Date(item.publishEndAt).toLocaleString('ko-KR') : '종료 없음'}</small><footer><button onClick={() => openAnnouncement(item)}>수정</button>{item.status !== 'PUBLISHED' ? <button onClick={() => void changeAnnouncementStatus(item, 'PUBLISHED')}>게시</button> : <button onClick={() => void changeAnnouncementStatus(item, 'HIDDEN')}>숨김</button>}</footer></article>)}
          {kind === 'faqs' && faqs.content.map((item) => <article className="admin-content-card" key={item.faqId}><header><div><span className={`admin-status ${item.status.toLowerCase()}`}>{statusLabel[item.status]}</span><span className="content-audience">{audienceLabel[item.audience]} · {item.category} · 순서 {item.displayOrder}</span><h3>{item.question}</h3></div><time>{new Date(item.updatedAt).toLocaleString('ko-KR')}</time></header><p>{item.answer}</p><footer><button onClick={() => openFaq(item)}>수정</button>{item.status !== 'PUBLISHED' ? <button onClick={() => void changeFaqStatus(item, 'PUBLISHED')}>게시</button> : <button onClick={() => void changeFaqStatus(item, 'HIDDEN')}>숨김</button>}</footer></article>)}
          {currentPage.totalElements === 0 && <div className="management-empty">등록된 콘텐츠가 없습니다.</div>}
        </section>
      )}
      <footer className="admin-pagination"><button disabled={currentPage.first || loading} onClick={() => setPage((value) => Math.max(0, value - 1))}>이전</button><span>{currentPage.totalPages === 0 ? 0 : currentPage.page + 1} / {currentPage.totalPages} · 총 {currentPage.totalElements.toLocaleString('ko-KR')}건</span><button disabled={currentPage.last || loading} onClick={() => setPage((value) => value + 1)}>다음</button></footer>

      {editingAnnouncement && <div className="modal-backdrop" role="presentation"><section className="connection-modal admin-content-editor" role="dialog" aria-modal="true" aria-describedby={saveError ? 'announcement-save-error' : undefined}><button className="modal-close" aria-label="닫기" onClick={() => setEditingAnnouncement(null)}>×</button><p className="eyebrow">PLATFORM ANNOUNCEMENT</p><h2>{editingAnnouncement === 'new' ? '플랫폼 공지 작성' : '플랫폼 공지 수정'}</h2><label>대상 앱<select value={formAudience} onChange={(event) => setFormAudience(event.target.value as AppAudience)}><option value="ALL">전체 앱</option><option value="CUSTOMER_APP">구매자 앱</option><option value="SELLER_APP">판매자 앱</option></select></label><label>제목<input maxLength={200} value={title} onChange={(event) => setTitle(event.target.value)} /></label><label>내용<textarea rows={8} maxLength={4000} value={content} onChange={(event) => setContent(event.target.value)} /></label><div className="content-period"><label>게시 시작<input type="datetime-local" value={publishStartAt} onChange={(event) => setPublishStartAt(event.target.value)} /></label><label>게시 종료<input type="datetime-local" value={publishEndAt} onChange={(event) => setPublishEndAt(event.target.value)} /></label></div>{saveError && <p className="form-error" id="announcement-save-error" role="alert">{saveError}</p>}<button type="button" className="primary-action" disabled={saving || !title.trim() || !content.trim()} onClick={() => void saveAnnouncement()}>{saving ? '저장 중…' : '저장'}</button></section></div>}
      {editingFaq && <div className="modal-backdrop" role="presentation"><section className="connection-modal admin-content-editor" role="dialog" aria-modal="true"><button className="modal-close" aria-label="닫기" onClick={() => setEditingFaq(null)}>×</button><p className="eyebrow">FREQUENTLY ASKED QUESTIONS</p><h2>{editingFaq === 'new' ? 'FAQ 작성' : 'FAQ 수정'}</h2><label>대상 앱<select value={formAudience} onChange={(event) => setFormAudience(event.target.value as AppAudience)}><option value="ALL">전체 앱</option><option value="CUSTOMER_APP">구매자 앱</option><option value="SELLER_APP">판매자 앱</option></select></label><label>카테고리<input maxLength={50} value={category} onChange={(event) => setCategory(event.target.value)} /></label><label>질문<input maxLength={300} value={question} onChange={(event) => setQuestion(event.target.value)} /></label><label>답변<textarea rows={8} maxLength={4000} value={answer} onChange={(event) => setAnswer(event.target.value)} /></label><label>노출 순서<input type="number" min={0} value={displayOrder} onChange={(event) => setDisplayOrder(Number(event.target.value))} /></label><button className="primary-action" disabled={saving || !question.trim() || !answer.trim()} onClick={() => void saveFaq()}>{saving ? '저장 중…' : '저장'}</button></section></div>}
    </main>
  )
}

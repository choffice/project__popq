import { useCallback, useEffect, useMemo, useState } from 'react'
import {
  createSellerReviewReplyTemplate,
  deleteSellerReviewReply,
  deleteSellerReviewReplyTemplate,
  getSellerReviewReplyTemplates,
  getSellerReviews,
  replySellerReview,
  updateSellerReviewReplyTemplate,
} from '../../services/api'
import type {
  SellerConnection,
  SellerReview,
  SellerReviewReplyTemplate,
  StoreRole,
} from '../../types'

type ReviewConfirmation =
  | { kind: 'reply'; review: SellerReview }
  | { kind: 'template'; templateId: number }
  | null

type Props = {
  connection: SellerConnection | null
  storeRole?: StoreRole
  onError: (message: string | null) => void
}

const demoReviews: SellerReview[] = [
  {
    reviewId: 1,
    orderPublicId: 'DEMO-ORDER-1001',
    storeId: 1,
    storeName: 'POPQ Demo',
    storeCategory: '카페',
    authorName: '김고객',
    rating: 5,
    content: '준비가 빠르고 메뉴가 맛있었어요.',
    status: 'ACTIVE',
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    sellerReply: null,
    sellerRepliedAt: null,
    sellerRepliedByUserId: null,
  },
]

export function ReviewManagement({ connection, storeRole, onError }: Props) {
  const isDemo = !connection
  const canReply = isDemo || storeRole === 'OWNER' || storeRole === 'MANAGER'
  const [reviews, setReviews] = useState<SellerReview[]>(isDemo ? demoReviews : [])
  const [templates, setTemplates] = useState<SellerReviewReplyTemplate[]>([])
  const [rating, setRating] = useState<number | null>(null)
  const [unanswered, setUnanswered] = useState(false)
  const [loading, setLoading] = useState(!isDemo)
  const [processing, setProcessing] = useState(false)
  const [editingReview, setEditingReview] = useState<SellerReview | null>(null)
  const [reply, setReply] = useState('')
  const [showTemplates, setShowTemplates] = useState(false)
  const [templateContent, setTemplateContent] = useState('')
  const [editingTemplateId, setEditingTemplateId] = useState<number | null>(null)
  const [confirmation, setConfirmation] = useState<ReviewConfirmation>(null)

  const load = useCallback(async () => {
    if (!connection) {
      setReviews(demoReviews)
      setTemplates([])
      setLoading(false)
      return
    }
    setLoading(true)
    try {
      const [nextReviews, nextTemplates] = await Promise.all([
        getSellerReviews(connection, { rating: rating ?? undefined, unanswered }),
        getSellerReviewReplyTemplates(connection),
      ])
      setReviews(nextReviews)
      setTemplates(nextTemplates)
      onError(null)
    } catch (caught) {
      onError(caught instanceof Error ? caught.message : '리뷰를 불러오지 못했습니다.')
    } finally {
      setLoading(false)
    }
  }, [connection, onError, rating, unanswered])

  useEffect(() => {
    const timer = window.setTimeout(() => void load(), 0)
    return () => window.clearTimeout(timer)
  }, [load])

  const unansweredCount = useMemo(
    () => reviews.filter((review) => !review.sellerReply).length,
    [reviews],
  )

  function openReply(review: SellerReview) {
    setEditingReview(review)
    setReply(review.sellerReply ?? '')
  }

  async function saveReply() {
    if (!editingReview || !reply.trim() || !canReply) return
    setProcessing(true)
    try {
      const saved = isDemo
        ? { ...editingReview, sellerReply: reply.trim(), sellerRepliedAt: new Date().toISOString() }
        : await replySellerReview(connection, editingReview.reviewId, reply.trim())
      setReviews((current) => current.map((item) => item.reviewId === saved.reviewId ? saved : item))
      setEditingReview(null)
      onError(null)
    } catch (caught) {
      onError(caught instanceof Error ? caught.message : '리뷰 답글을 저장하지 못했습니다.')
    } finally {
      setProcessing(false)
    }
  }

  async function removeReply(review: SellerReview) {
    if (!canReply) return
    setProcessing(true)
    try {
      const saved = isDemo
        ? { ...review, sellerReply: null, sellerRepliedAt: null }
        : await deleteSellerReviewReply(connection, review.reviewId)
      setReviews((current) => current.map((item) => item.reviewId === saved.reviewId ? saved : item))
      onError(null)
    } catch (caught) {
      onError(caught instanceof Error ? caught.message : '리뷰 답글을 삭제하지 못했습니다.')
    } finally {
      setProcessing(false)
    }
  }

  async function saveTemplate() {
    const content = templateContent.trim()
    if (!connection || !content || !canReply) return
    setProcessing(true)
    try {
      const saved = editingTemplateId == null
        ? await createSellerReviewReplyTemplate(connection, content)
        : await updateSellerReviewReplyTemplate(connection, editingTemplateId, content)
      setTemplates((current) => editingTemplateId == null
        ? [...current, saved]
        : current.map((item) => item.templateId === saved.templateId ? saved : item))
      setTemplateContent('')
      setEditingTemplateId(null)
      onError(null)
    } catch (caught) {
      onError(caught instanceof Error ? caught.message : '답글 템플릿을 저장하지 못했습니다.')
    } finally {
      setProcessing(false)
    }
  }

  async function removeTemplate(templateId: number) {
    if (!connection) return
    setProcessing(true)
    try {
      await deleteSellerReviewReplyTemplate(connection, templateId)
      setTemplates((current) => current.filter((item) => item.templateId !== templateId))
      onError(null)
    } catch (caught) {
      onError(caught instanceof Error ? caught.message : '답글 템플릿을 삭제하지 못했습니다.')
    } finally {
      setProcessing(false)
    }
  }

  return (
    <main className="management-page review-page">
      <section className="management-hero compact-hero">
        <div><p className="eyebrow">CUSTOMER REVIEWS</p><h2>리뷰 관리</h2><p>평점과 미답변 리뷰를 확인하고 답글 템플릿으로 응답합니다.</p></div>
        {canReply && <button className="secondary-action" onClick={() => setShowTemplates(true)}>답글 템플릿</button>}
      </section>
      {!canReply && <p className="permission-notice">STAFF 권한은 리뷰를 조회할 수 있지만 답글을 작성하거나 삭제할 수 없습니다.</p>}
      <section className="review-toolbar">
        <div className="filters" aria-label="리뷰 평점 필터">
          <button className={rating == null ? 'active' : ''} onClick={() => setRating(null)}>전체</button>
          {[5, 4, 3, 2, 1].map((value) => <button key={value} className={rating === value ? 'active' : ''} onClick={() => setRating(value)}>{value}점</button>)}
        </div>
        <label className="required-check"><input type="checkbox" checked={unanswered} onChange={(event) => setUnanswered(event.target.checked)} />미답변만 {unansweredCount > 0 ? `(${unansweredCount})` : ''}</label>
      </section>
      {loading ? <div className="management-empty">리뷰를 불러오는 중입니다.</div> : <section className="review-list">
        {reviews.map((review) => <article key={review.reviewId} className="review-card">
          <header><div><strong>{'★'.repeat(review.rating)}{'☆'.repeat(5 - review.rating)}</strong><span>{review.authorName}</span></div><time>{new Date(review.createdAt).toLocaleDateString('ko-KR')}</time></header>
          <p>{review.content?.trim() || '작성된 리뷰 내용이 없습니다.'}</p>
          <small>주문 #{review.orderPublicId.slice(-8)}</small>
          {review.sellerReply ? <div className="seller-review-reply"><strong>판매자 답글</strong><p>{review.sellerReply}</p>{canReply && <div><button className="secondary-action" onClick={() => openReply(review)}>수정</button><button className="danger-action" disabled={processing} onClick={() => setConfirmation({ kind: 'reply', review })}>삭제</button></div>}</div> : canReply && <button className="primary-action" onClick={() => openReply(review)}>답글 작성</button>}
        </article>)}
        {reviews.length === 0 && <div className="management-empty">조건에 맞는 리뷰가 없습니다.</div>}
      </section>}
      {editingReview && <div className="modal-backdrop" role="presentation"><section className="connection-modal review-reply-modal" role="dialog" aria-modal="true" aria-labelledby="review-reply-title"><button className="modal-close" aria-label="닫기" onClick={() => setEditingReview(null)}>×</button><p className="eyebrow">REVIEW REPLY</p><h2 id="review-reply-title">{editingReview.sellerReply ? '답글 수정' : '답글 작성'}</h2>{templates.length > 0 && <label>템플릿<select value="" onChange={(event) => { const template = templates.find((item) => item.templateId === Number(event.target.value)); if (template) setReply(template.content) }}><option value="">템플릿 선택</option>{templates.map((template) => <option key={template.templateId} value={template.templateId}>{template.content}</option>)}</select></label>}<label>답글<textarea maxLength={1000} rows={6} value={reply} onChange={(event) => setReply(event.target.value)} /></label><button className="primary-action" disabled={processing || !reply.trim()} onClick={() => void saveReply()}>{processing ? '저장 중…' : '답글 저장'}</button></section></div>}
      {showTemplates && <div className="modal-backdrop" role="presentation"><section className="connection-modal review-reply-modal" role="dialog" aria-modal="true" aria-labelledby="review-template-title"><button className="modal-close" aria-label="닫기" onClick={() => setShowTemplates(false)}>×</button><p className="eyebrow">REPLY TEMPLATES</p><h2 id="review-template-title">답글 템플릿</h2><div className="reply-template-list">{templates.map((template) => <article key={template.templateId}><p>{template.content}</p><div><button className="secondary-action" onClick={() => { setEditingTemplateId(template.templateId); setTemplateContent(template.content) }}>수정</button><button className="danger-action" onClick={() => setConfirmation({ kind: 'template', templateId: template.templateId })}>삭제</button></div></article>)}</div>{isDemo ? <p>체험 모드에서는 템플릿을 저장할 수 없습니다.</p> : <><label>템플릿 내용<textarea maxLength={1000} rows={4} value={templateContent} onChange={(event) => setTemplateContent(event.target.value)} /></label><button className="primary-action" disabled={processing || !templateContent.trim()} onClick={() => void saveTemplate()}>{editingTemplateId == null ? '템플릿 추가' : '템플릿 수정'}</button></>}</section></div>}

      {confirmation && <div className="modal-backdrop" role="presentation"><section className="connection-modal" role="dialog" aria-modal="true" aria-labelledby="review-confirm-title"><button className="modal-close" aria-label="닫기" onClick={() => setConfirmation(null)}>×</button><p className="eyebrow">CONFIRM ACTION</p><h2 id="review-confirm-title">삭제 확인</h2><p>{confirmation.kind === 'reply' ? '등록한 리뷰 답글을 삭제할까요?' : '이 답글 템플릿을 삭제할까요?'}</p><button className="secondary-action" disabled={processing} onClick={() => setConfirmation(null)}>취소</button><button className="reject-action" style={{ width: '100%', marginTop: 8 }} disabled={processing} onClick={() => { const target = confirmation; setConfirmation(null); if (target.kind === 'reply') void removeReply(target.review); else void removeTemplate(target.templateId) }}>삭제하기</button></section></div>}
    </main>
  )
}

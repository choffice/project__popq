import { useCallback, useEffect, useMemo, useState } from 'react'
import {
  getAdminOverview,
  getAdminSellersPage,
  getAdminStoresPage,
  getAdminUsersPage,
  updateAdminSellerVerification,
  updateAdminStoreStatus,
  updateAdminUserStatus,
} from '../../services/api'
import type {
  AdminOverview,
  AdminSeller,
  AdminStore,
  AdminUser,
  PageResponse,
  SellerConnection,
  UserStatus,
} from '../../types'

type AdminReasonAction =
  | { kind: 'user'; user: AdminUser; status: UserStatus; message: string; confirmLabel: string }
  | { kind: 'seller-verification'; seller: AdminSeller; status: AdminSeller['verificationStatus']; message: string; confirmLabel: string }
  | { kind: 'seller-user'; seller: AdminSeller; status: UserStatus; message: string; confirmLabel: string }
  | { kind: 'store'; store: AdminStore; status: AdminStore['status']; message: string; confirmLabel: string }

export type AdminManagementSection = 'customers' | 'sellers' | 'stores'

type Props = {
  connection: SellerConnection | null
  section?: AdminManagementSection
  onError: (message: string | null) => void
}

const demoUsers: AdminUser[] = [
  { userId: 1, email: 'admin@popq.test', name: 'POPQ 운영자', role: 'ADMIN', roles: ['ADMIN'], status: 'ACTIVE', createdAt: '2026-07-01T09:00:00Z' },
  { userId: 12, email: 'seller@seongsu.test', name: '성수 라운지', role: 'SELLER', roles: ['SELLER'], status: 'ACTIVE', createdAt: '2026-07-12T03:30:00Z' },
  { userId: 28, email: 'guest@example.com', name: '김고객', role: 'CUSTOMER', roles: ['CUSTOMER'], status: 'SUSPENDED', createdAt: '2026-07-25T08:20:00Z' },
]

const demoSellers: AdminSeller[] = [
  { sellerProfileId: 3, userId: 12, email: 'seller@seongsu.test', name: '성수 라운지', businessName: 'POPQ 성수 라운지', businessRegistrationNumber: '123-45-67890', verificationStatus: 'VERIFIED', userStatus: 'ACTIVE', createdAt: '2026-07-12T03:30:00Z' },
  { sellerProfileId: 8, userId: 31, email: 'new-seller@popq.test', name: '신규 판매자', businessName: '여름 마켓', businessRegistrationNumber: '987-65-43210', verificationStatus: 'PENDING', userStatus: 'ACTIVE', createdAt: '2026-07-28T01:10:00Z' },
]

const demoStores: AdminStore[] = [
  { storeId: 1, storeType: 'LOCAL_STORE', name: 'POPQ 성수 라운지', status: 'ACTIVE', businessStatus: 'OPEN', createdAt: '2026-07-12T03:40:00Z' },
  { storeId: 5, storeType: 'EVENT_COMMERCE', name: '서울 여름 마켓', status: 'SUSPENDED', businessStatus: 'PRE_OPEN', createdAt: '2026-07-20T06:00:00Z' },
]

const userStatusLabel: Record<UserStatus, string> = {
  ACTIVE: '활성',
  SUSPENDED: '이용정지',
  WITHDRAWAL_PENDING: '탈퇴 대기',
  WITHDRAWN: '탈퇴',
}

const emptyPage = <T,>(): PageResponse<T> => ({
  content: [], page: 0, size: 20, totalElements: 0, totalPages: 0, first: true, last: true,
})

function summarize(): AdminOverview {
  return {
    totalUsers: demoUsers.length,
    activeUsers: demoUsers.filter((item) => item.status === 'ACTIVE').length,
    sellerProfiles: demoSellers.length,
    pendingSellers: demoSellers.filter((item) => item.verificationStatus === 'PENDING').length,
    totalStores: demoStores.length,
    activeStores: demoStores.filter((item) => item.status === 'ACTIVE').length,
    suspendedStores: demoStores.filter((item) => item.status === 'SUSPENDED').length,
  }
}

function demoPage<T>(items: T[], page: number): PageResponse<T> {
  const size = 20
  return {
    content: items.slice(page * size, page * size + size),
    page,
    size,
    totalElements: items.length,
    totalPages: Math.ceil(items.length / size),
    first: page === 0,
    last: (page + 1) * size >= items.length,
  }
}

export function AdminManagement({ connection, section = 'customers', onError }: Props) {
  const [overview, setOverview] = useState<AdminOverview>(summarize)
  const [users, setUsers] = useState<PageResponse<AdminUser>>(emptyPage)
  const [sellers, setSellers] = useState<PageResponse<AdminSeller>>(emptyPage)
  const [stores, setStores] = useState<PageResponse<AdminStore>>(emptyPage)
  const [query, setQuery] = useState('')
  const [debouncedQuery, setDebouncedQuery] = useState('')
  const [userStatus, setUserStatus] = useState<UserStatus | ''>('')
  const [verificationStatus, setVerificationStatus] = useState<AdminSeller['verificationStatus'] | ''>('')
  const [storeStatus, setStoreStatus] = useState<AdminStore['status'] | ''>('')
  const [page, setPage] = useState(0)
  const [loading, setLoading] = useState(true)
  const [updating, setUpdating] = useState<string | null>(null)
  const [reasonAction, setReasonAction] = useState<AdminReasonAction | null>(null)
  const [reason, setReason] = useState('')

  useEffect(() => {
    const timer = window.setTimeout(() => setDebouncedQuery(query.trim()), 300)
    return () => window.clearTimeout(timer)
  }, [query])

  useEffect(() => {
    const timer = window.setTimeout(() => {
      setPage(0)
      setQuery('')
      setDebouncedQuery('')
      setUserStatus('')
      setVerificationStatus('')
      setStoreStatus('')
    }, 0)
    return () => window.clearTimeout(timer)
  }, [section])

  const load = useCallback(async () => {
    setLoading(true)
    try {
      if (!connection) {
        setOverview(summarize())
        const search = debouncedQuery.toLocaleLowerCase('ko-KR')
        if (section === 'customers') {
          const filtered = demoUsers.filter((item) =>
            item.roles.includes('CUSTOMER') &&
            (!userStatus || item.status === userStatus) &&
            `${item.name} ${item.email ?? ''}`.toLocaleLowerCase('ko-KR').includes(search),
          )
          setUsers(demoPage(filtered, page))
        } else if (section === 'sellers') {
          const filtered = demoSellers.filter((item) =>
            (!verificationStatus || item.verificationStatus === verificationStatus) &&
            (!userStatus || item.userStatus === userStatus) &&
            `${item.name} ${item.email ?? ''} ${item.businessName ?? ''}`.toLocaleLowerCase('ko-KR').includes(search),
          )
          setSellers(demoPage(filtered, page))
        } else {
          const filtered = demoStores.filter((item) =>
            (!storeStatus || item.status === storeStatus) &&
            item.name.toLocaleLowerCase('ko-KR').includes(search),
          )
          setStores(demoPage(filtered, page))
        }
        onError(null)
        return
      }

      const overviewPromise = getAdminOverview(connection)
      if (section === 'customers') {
        const [nextOverview, result] = await Promise.all([
          overviewPromise,
          getAdminUsersPage(connection, { page, size: 20, query: debouncedQuery, role: 'CUSTOMER', status: userStatus || undefined }),
        ])
        setOverview(nextOverview)
        setUsers(result)
      } else if (section === 'sellers') {
        const [nextOverview, result] = await Promise.all([
          overviewPromise,
          getAdminSellersPage(connection, { page, size: 20, query: debouncedQuery, verificationStatus: verificationStatus || undefined, userStatus: userStatus || undefined }),
        ])
        setOverview(nextOverview)
        setSellers(result)
      } else {
        const [nextOverview, result] = await Promise.all([
          overviewPromise,
          getAdminStoresPage(connection, { page, size: 20, query: debouncedQuery, status: storeStatus || undefined }),
        ])
        setOverview(nextOverview)
        setStores(result)
      }
      onError(null)
    } catch (caught) {
      onError(caught instanceof Error ? caught.message : '관리자 데이터를 불러오지 못했습니다.')
    } finally {
      setLoading(false)
    }
  }, [connection, debouncedQuery, onError, page, section, storeStatus, userStatus, verificationStatus])

  useEffect(() => {
    const timer = window.setTimeout(() => { void load() }, 0)
    return () => window.clearTimeout(timer)
  }, [load])

  const currentPage = section === 'customers' ? users : section === 'sellers' ? sellers : stores
  const title = section === 'customers' ? '구매자 회원 관리' : section === 'sellers' ? '판매자 회원 · 인증' : '스토어 관리'
  const description = section === 'customers'
    ? '구매자 계정의 활성·이용정지·탈퇴 상태를 조회하고 관리합니다.'
    : section === 'sellers'
      ? '판매자 계정과 사업자 인증 상태를 함께 점검합니다.'
      : '플랫폼에 등록된 스토어의 운영 상태를 관리합니다.'

  function openReasonDialog(action: AdminReasonAction) {
    setReason('')
    setReasonAction(action)
  }

  function toggleUser(user: AdminUser) {
    const status: UserStatus = user.status === 'ACTIVE' ? 'SUSPENDED' : 'ACTIVE'
    openReasonDialog({
      kind: 'user',
      user,
      status,
      message: `${user.name} 계정을 ${userStatusLabel[status]} 상태로 변경하는 사유를 입력해 주세요.`,
      confirmLabel: status === 'SUSPENDED' ? '이용 정지' : '활성화',
    })
  }

  function verifySeller(seller: AdminSeller, status: AdminSeller['verificationStatus']) {
    openReasonDialog({
      kind: 'seller-verification',
      seller,
      status,
      message: `${seller.name} 판매자를 ${status === 'VERIFIED' ? '승인' : '반려'}하는 사유를 입력해 주세요.`,
      confirmLabel: status === 'VERIFIED' ? '승인' : '반려',
    })
  }

  function toggleSellerUser(seller: AdminSeller) {
    if (!['ACTIVE', 'SUSPENDED'].includes(seller.userStatus)) return
    const status: UserStatus = seller.userStatus === 'ACTIVE' ? 'SUSPENDED' : 'ACTIVE'
    openReasonDialog({
      kind: 'seller-user',
      seller,
      status,
      message: `${seller.name} 판매자 계정을 ${userStatusLabel[status]} 상태로 변경하는 사유를 입력해 주세요.`,
      confirmLabel: status === 'SUSPENDED' ? '계정 정지' : '계정 활성화',
    })
  }

  function toggleStore(store: AdminStore) {
    const status: AdminStore['status'] = store.status === 'ACTIVE' ? 'SUSPENDED' : 'ACTIVE'
    openReasonDialog({
      kind: 'store',
      store,
      status,
      message: `${store.name} 스토어를 ${status === 'ACTIVE' ? '활성' : '운영정지'} 상태로 변경하는 사유를 입력해 주세요.`,
      confirmLabel: status === 'ACTIVE' ? '재활성화' : '운영 정지',
    })
  }

  async function submitReasonAction() {
    const action = reasonAction
    const trimmedReason = reason.trim()
    if (!action || !trimmedReason) return

    setReasonAction(null)

    if (action.kind === 'user') {
      setUpdating(`user-${action.user.userId}`)
      try {
        if (connection) await updateAdminUserStatus(connection, action.user.userId, action.status, trimmedReason)
        else action.user.status = action.status
        await load()
      } catch (caught) {
        onError(caught instanceof Error ? caught.message : '사용자 상태를 변경하지 못했습니다.')
      } finally { setUpdating(null) }
      return
    }

    if (action.kind === 'seller-verification') {
      setUpdating(`seller-${action.seller.sellerProfileId}`)
      try {
        if (connection) await updateAdminSellerVerification(connection, action.seller.sellerProfileId, action.status, trimmedReason)
        else action.seller.verificationStatus = action.status
        await load()
      } catch (caught) {
        onError(caught instanceof Error ? caught.message : '판매자 인증 상태를 변경하지 못했습니다.')
      } finally { setUpdating(null) }
      return
    }

    if (action.kind === 'seller-user') {
      setUpdating(`seller-user-${action.seller.userId}`)
      try {
        if (connection) await updateAdminUserStatus(connection, action.seller.userId, action.status, trimmedReason)
        else action.seller.userStatus = action.status
        await load()
      } catch (caught) {
        onError(caught instanceof Error ? caught.message : '판매자 계정 상태를 변경하지 못했습니다.')
      } finally { setUpdating(null) }
      return
    }

    setUpdating(`store-${action.store.storeId}`)
    try {
      if (connection) await updateAdminStoreStatus(connection, action.store.storeId, action.status, trimmedReason)
      else action.store.status = action.status
      await load()
    } catch (caught) {
      onError(caught instanceof Error ? caught.message : '스토어 상태를 변경하지 못했습니다.')
    } finally { setUpdating(null) }
  }

  const metrics = useMemo(() => [
    ['전체 사용자', overview.totalUsers, `활성 ${overview.activeUsers}`],
    ['판매자 인증 대기', overview.pendingSellers, `전체 ${overview.sellerProfiles}`],
    ['운영 스토어', overview.activeStores, `정지 ${overview.suspendedStores}`],
  ], [overview])

  return (
    <main className="management-page admin-page">
      <section className="management-hero admin-hero">
        <div><p className="eyebrow">PLATFORM CONTROL</p><h2>{title}</h2><p>{description}</p></div>
        <div className="admin-metrics">
          {metrics.map(([label, value, sub]) => <article key={String(label)}><small>{label}</small><strong>{value}</strong><span>{sub}</span></article>)}
        </div>
      </section>

      <section className="admin-toolbar">
        <label className="search-field"><span>⌕</span><input aria-label="관리자 목록 검색" placeholder="이름, 이메일 또는 사업자 정보 검색" value={query} onChange={(event) => { setQuery(event.target.value); setPage(0) }} /></label>
        <div className="admin-filter-group">
          {(section === 'customers' || section === 'sellers') && (
            <select aria-label="회원 상태 필터" value={userStatus} onChange={(event) => { setUserStatus(event.target.value as UserStatus | ''); setPage(0) }}>
              <option value="">상태 전체</option><option value="ACTIVE">활성</option><option value="SUSPENDED">이용정지</option><option value="WITHDRAWAL_PENDING">탈퇴 대기</option><option value="WITHDRAWN">탈퇴</option>
            </select>
          )}
          {section === 'sellers' && (
            <select aria-label="판매자 인증 필터" value={verificationStatus} onChange={(event) => { setVerificationStatus(event.target.value as AdminSeller['verificationStatus'] | ''); setPage(0) }}>
              <option value="">인증 전체</option><option value="PENDING">대기</option><option value="VERIFIED">인증</option><option value="REJECTED">반려</option>
            </select>
          )}
          {section === 'stores' && (
            <select aria-label="스토어 상태 필터" value={storeStatus} onChange={(event) => { setStoreStatus(event.target.value as AdminStore['status'] | ''); setPage(0) }}>
              <option value="">상태 전체</option><option value="ACTIVE">활성</option><option value="SUSPENDED">운영정지</option><option value="CLOSED">폐점</option>
            </select>
          )}
        </div>
      </section>

      {loading ? <div className="management-empty">관리자 데이터를 불러오는 중입니다.</div> : (
        <section className="admin-table" aria-label="관리자 운영 목록">
          {section === 'customers' && <><header className="admin-user-row"><span>구매자</span><span>가입일</span><span>상태</span><span>관리</span></header>{users.content.map((user) => <article className="admin-user-row" key={user.userId}><div><strong>{user.name}</strong><small>{user.email ?? '이메일 없음'}</small></div><span>{new Date(user.createdAt).toLocaleDateString('ko-KR')}</span><b className={`admin-status ${user.status.toLowerCase()}`}>{userStatusLabel[user.status]}</b><button disabled={updating === `user-${user.userId}` || !['ACTIVE', 'SUSPENDED'].includes(user.status)} onClick={() => void toggleUser(user)}>{user.status === 'ACTIVE' ? '이용 정지' : user.status === 'SUSPENDED' ? '활성화' : '조회 전용'}</button></article>)}</>}
          {section === 'sellers' && <><header className="admin-seller-row"><span>판매자</span><span>사업자 정보</span><span>인증</span><span>관리</span></header>{sellers.content.map((seller) => <article className="admin-seller-row" key={seller.sellerProfileId}><div><strong>{seller.name}</strong><small>{seller.email ?? '이메일 없음'} · {userStatusLabel[seller.userStatus]}</small></div><div><strong>{seller.businessName ?? '미입력'}</strong><small>{seller.businessRegistrationNumber ?? '등록번호 미입력'}</small></div><b className={`admin-status ${seller.verificationStatus.toLowerCase()}`}>{seller.verificationStatus === 'VERIFIED' ? '인증' : seller.verificationStatus === 'REJECTED' ? '반려' : '대기'}</b><div className="admin-row-actions"><button disabled={updating === `seller-${seller.sellerProfileId}`} onClick={() => void verifySeller(seller, 'VERIFIED')}>승인</button><button className="danger" disabled={updating === `seller-${seller.sellerProfileId}`} onClick={() => void verifySeller(seller, 'REJECTED')}>반려</button><button disabled={updating === `seller-user-${seller.userId}` || !['ACTIVE', 'SUSPENDED'].includes(seller.userStatus)} onClick={() => void toggleSellerUser(seller)}>{seller.userStatus === 'ACTIVE' ? '계정 정지' : seller.userStatus === 'SUSPENDED' ? '계정 활성화' : '조회 전용'}</button></div></article>)}</>}
          {section === 'stores' && <><header className="admin-store-row"><span>스토어</span><span>유형</span><span>영업</span><span>상태</span><span>관리</span></header>{stores.content.map((store) => <article className="admin-store-row" key={store.storeId}><div><strong>{store.name}</strong><small>ID {store.storeId}</small></div><span>{store.storeType === 'LOCAL_STORE' ? '일반 매장' : '행사'}</span><span>{store.businessStatus === 'OPEN' ? '영업 중' : '준비중'}</span><b className={`admin-status ${store.status.toLowerCase()}`}>{store.status === 'ACTIVE' ? '활성' : store.status === 'SUSPENDED' ? '운영정지' : '폐점'}</b><button disabled={updating === `store-${store.storeId}` || store.status === 'CLOSED'} onClick={() => void toggleStore(store)}>{store.status === 'ACTIVE' ? '운영 정지' : store.status === 'SUSPENDED' ? '재활성화' : '조회 전용'}</button></article>)}</>}
          {currentPage.totalElements === 0 && <div className="management-empty">조건에 맞는 항목이 없습니다.</div>}
        </section>
      )}

      <footer className="admin-pagination" aria-label="목록 페이지">
        <button disabled={currentPage.first || loading} onClick={() => setPage((value) => Math.max(0, value - 1))}>이전</button>
        <span>{currentPage.totalPages === 0 ? 0 : currentPage.page + 1} / {currentPage.totalPages} · 총 {currentPage.totalElements.toLocaleString('ko-KR')}건</span>
        <button disabled={currentPage.last || loading} onClick={() => setPage((value) => value + 1)}>다음</button>
      </footer>
      <p className="source-note">탈퇴 대기와 탈퇴 상태는 개인정보 정리 절차 보호를 위해 조회만 가능합니다.</p>

      {reasonAction && (
        <div className="modal-backdrop" role="presentation">
          <section className="connection-modal" role="dialog" aria-modal="true" aria-labelledby="admin-reason-title">
            <button className="modal-close" aria-label="닫기" onClick={() => setReasonAction(null)}>×</button>
            <p className="eyebrow">ADMIN ACTION</p>
            <h2 id="admin-reason-title">변경 사유 입력</h2>
            <p>{reasonAction.message}</p>
            <label>
              변경 사유
              <textarea rows={4} maxLength={500} autoFocus value={reason} onChange={(event) => setReason(event.target.value)} placeholder="사유를 입력해 주세요." />
            </label>
            <button className="secondary-action" onClick={() => setReasonAction(null)}>취소</button>
            <button className={reasonAction.confirmLabel.includes('정지') || reasonAction.confirmLabel === '반려' ? 'reject-action' : 'primary-action'} style={{ width: '100%', marginTop: 8 }} disabled={!reason.trim()} onClick={() => void submitReasonAction()}>{reasonAction.confirmLabel}</button>
          </section>
        </div>
      )}
    </main>
  )
}

import { useEffect, useMemo, useState } from 'react'
import {
  getAdminOverview,
  getAdminSellers,
  getAdminStores,
  getAdminUsers,
  updateAdminSellerVerification,
  updateAdminStoreStatus,
  updateAdminUserStatus,
} from '../../services/api'
import type {
  AdminOverview,
  AdminSeller,
  AdminStore,
  AdminUser,
  SellerConnection,
} from '../../types'

type Props = {
  connection: SellerConnection | null
  onError: (message: string | null) => void
}

type AdminTab = 'users' | 'sellers' | 'stores'

const demoUsers: AdminUser[] = [
  {
    userId: 1,
    email: 'admin@popq.test',
    name: 'POPQ 운영자',
    role: 'ADMIN',
    status: 'ACTIVE',
    createdAt: '2026-07-01T09:00:00Z',
  },
  {
    userId: 12,
    email: 'seller@seongsu.test',
    name: '성수 라운지',
    role: 'SELLER',
    status: 'ACTIVE',
    createdAt: '2026-07-12T03:30:00Z',
  },
  {
    userId: 28,
    email: 'guest@example.com',
    name: '김고객',
    role: 'CUSTOMER',
    status: 'SUSPENDED',
    createdAt: '2026-07-25T08:20:00Z',
  },
]

const demoSellers: AdminSeller[] = [
  {
    sellerProfileId: 3,
    userId: 12,
    email: 'seller@seongsu.test',
    name: '성수 라운지',
    businessName: 'POPQ 성수 라운지',
    businessRegistrationNumber: '123-45-67890',
    verificationStatus: 'VERIFIED',
    userStatus: 'ACTIVE',
    createdAt: '2026-07-12T03:30:00Z',
  },
  {
    sellerProfileId: 8,
    userId: 31,
    email: 'new-seller@popq.test',
    name: '신규 판매자',
    businessName: '여름 마켓',
    businessRegistrationNumber: '987-65-43210',
    verificationStatus: 'PENDING',
    userStatus: 'ACTIVE',
    createdAt: '2026-07-28T01:10:00Z',
  },
]

const demoStores: AdminStore[] = [
  {
    storeId: 1,
    storeType: 'LOCAL_STORE',
    name: 'POPQ 성수 라운지',
    status: 'ACTIVE',
    businessStatus: 'OPEN',
    createdAt: '2026-07-12T03:40:00Z',
  },
  {
    storeId: 5,
    storeType: 'EVENT_COMMERCE',
    name: '서울 여름 마켓',
    status: 'SUSPENDED',
    businessStatus: 'CLOSED',
    createdAt: '2026-07-20T06:00:00Z',
  },
]

function summarize(
  users: AdminUser[],
  sellers: AdminSeller[],
  stores: AdminStore[],
): AdminOverview {
  return {
    totalUsers: users.length,
    activeUsers: users.filter((user) => user.status === 'ACTIVE').length,
    sellerProfiles: sellers.length,
    pendingSellers: sellers.filter(
      (seller) => seller.verificationStatus === 'PENDING',
    ).length,
    totalStores: stores.length,
    activeStores: stores.filter((store) => store.status === 'ACTIVE').length,
    suspendedStores: stores.filter((store) => store.status === 'SUSPENDED')
      .length,
  }
}

function freshDemoData() {
  return {
    users: structuredClone(demoUsers),
    sellers: structuredClone(demoSellers),
    stores: structuredClone(demoStores),
  }
}

const roleLabel = {
  CUSTOMER: '고객',
  SELLER: '판매자',
  ADMIN: '관리자',
}

export function AdminManagement({ connection, onError }: Props) {
  const isDemo = !connection
  const initial = freshDemoData()
  const [overview, setOverview] = useState<AdminOverview>(() =>
    summarize(initial.users, initial.sellers, initial.stores),
  )
  const [users, setUsers] = useState<AdminUser[]>(() =>
    isDemo ? freshDemoData().users : [],
  )
  const [sellers, setSellers] = useState<AdminSeller[]>(() =>
    isDemo ? freshDemoData().sellers : [],
  )
  const [stores, setStores] = useState<AdminStore[]>(() =>
    isDemo ? freshDemoData().stores : [],
  )
  const [tab, setTab] = useState<AdminTab>('users')
  const [query, setQuery] = useState('')
  const [loading, setLoading] = useState(!isDemo)
  const [updating, setUpdating] = useState<string | null>(null)

  useEffect(() => {
    const timer = window.setTimeout(() => {
      if (!connection) {
        const demo = freshDemoData()
        setUsers(demo.users)
        setSellers(demo.sellers)
        setStores(demo.stores)
        setOverview(summarize(demo.users, demo.sellers, demo.stores))
        setLoading(false)
        return
      }
      setLoading(true)
      void Promise.all([
        getAdminOverview(connection),
        getAdminUsers(connection),
        getAdminSellers(connection),
        getAdminStores(connection),
      ])
        .then(([nextOverview, nextUsers, nextSellers, nextStores]) => {
          setOverview(nextOverview)
          setUsers(nextUsers)
          setSellers(nextSellers)
          setStores(nextStores)
          onError(null)
        })
        .catch((caught: unknown) =>
          onError(
            caught instanceof Error
              ? caught.message
              : '관리자 데이터를 불러오지 못했습니다.',
          ),
        )
        .finally(() => setLoading(false))
    }, 0)
    return () => window.clearTimeout(timer)
  }, [connection, onError])

  const normalizedQuery = query.trim().toLocaleLowerCase('ko-KR')
  const visibleUsers = useMemo(
    () =>
      users.filter((user) =>
        `${user.name} ${user.email} ${user.role}`
          .toLocaleLowerCase('ko-KR')
          .includes(normalizedQuery),
      ),
    [normalizedQuery, users],
  )
  const visibleSellers = useMemo(
    () =>
      sellers.filter((seller) =>
        `${seller.name} ${seller.email} ${seller.businessName ?? ''}`
          .toLocaleLowerCase('ko-KR')
          .includes(normalizedQuery),
      ),
    [normalizedQuery, sellers],
  )
  const visibleStores = useMemo(
    () =>
      stores.filter((store) =>
        store.name.toLocaleLowerCase('ko-KR').includes(normalizedQuery),
      ),
    [normalizedQuery, stores],
  )

  function updateOverview(
    nextUsers: AdminUser[],
    nextSellers: AdminSeller[],
    nextStores: AdminStore[],
  ) {
    setOverview(summarize(nextUsers, nextSellers, nextStores))
  }

  async function toggleUser(user: AdminUser) {
    const status: AdminUser['status'] =
      user.status === 'ACTIVE' ? 'SUSPENDED' : 'ACTIVE'
    setUpdating(`user-${user.userId}`)
    try {
      const updated = isDemo
        ? { ...user, status }
        : await updateAdminUserStatus(connection, user.userId, status)
      const next = users.map((item) =>
        item.userId === updated.userId ? updated : item,
      )
      setUsers(next)
      updateOverview(next, sellers, stores)
      onError(null)
    } catch (caught) {
      onError(
        caught instanceof Error
          ? caught.message
          : '사용자 상태를 변경하지 못했습니다.',
      )
    } finally {
      setUpdating(null)
    }
  }

  async function verifySeller(
    seller: AdminSeller,
    verificationStatus: AdminSeller['verificationStatus'],
  ) {
    setUpdating(`seller-${seller.sellerProfileId}`)
    try {
      const updated = isDemo
        ? { ...seller, verificationStatus }
        : await updateAdminSellerVerification(
            connection,
            seller.sellerProfileId,
            verificationStatus,
          )
      const next = sellers.map((item) =>
        item.sellerProfileId === updated.sellerProfileId ? updated : item,
      )
      setSellers(next)
      updateOverview(users, next, stores)
      onError(null)
    } catch (caught) {
      onError(
        caught instanceof Error
          ? caught.message
          : '판매자 인증 상태를 변경하지 못했습니다.',
      )
    } finally {
      setUpdating(null)
    }
  }

  async function toggleStore(store: AdminStore) {
    const status: AdminStore['status'] =
      store.status === 'ACTIVE' ? 'SUSPENDED' : 'ACTIVE'
    setUpdating(`store-${store.storeId}`)
    try {
      const updated = isDemo
        ? { ...store, status }
        : await updateAdminStoreStatus(connection, store.storeId, status)
      const next = stores.map((item) =>
        item.storeId === updated.storeId ? updated : item,
      )
      setStores(next)
      updateOverview(users, sellers, next)
      onError(null)
    } catch (caught) {
      onError(
        caught instanceof Error
          ? caught.message
          : '스토어 상태를 변경하지 못했습니다.',
      )
    } finally {
      setUpdating(null)
    }
  }

  return (
    <main className="management-page admin-page">
      <section className="management-hero admin-hero">
        <div>
          <p className="eyebrow">PLATFORM CONTROL</p>
          <h2>플랫폼 운영 현황</h2>
          <p>
            사용자, 판매자 인증, 스토어 운영 상태를 관리자 권한으로 점검합니다.
          </p>
        </div>
        <div className="admin-metrics">
          <article>
            <small>전체 사용자</small>
            <strong>{overview.totalUsers}</strong>
            <span>활성 {overview.activeUsers}</span>
          </article>
          <article>
            <small>판매자 인증 대기</small>
            <strong>{overview.pendingSellers}</strong>
            <span>전체 {overview.sellerProfiles}</span>
          </article>
          <article>
            <small>운영 스토어</small>
            <strong>{overview.activeStores}</strong>
            <span>정지 {overview.suspendedStores}</span>
          </article>
        </div>
      </section>

      <section className="admin-toolbar">
        <div className="admin-tabs" role="tablist" aria-label="관리자 데이터">
          <button
            role="tab"
            aria-selected={tab === 'users'}
            className={tab === 'users' ? 'active' : ''}
            onClick={() => setTab('users')}
          >
            사용자
          </button>
          <button
            role="tab"
            aria-selected={tab === 'sellers'}
            className={tab === 'sellers' ? 'active' : ''}
            onClick={() => setTab('sellers')}
          >
            판매자 인증
          </button>
          <button
            role="tab"
            aria-selected={tab === 'stores'}
            className={tab === 'stores' ? 'active' : ''}
            onClick={() => setTab('stores')}
          >
            스토어
          </button>
        </div>
        <label className="search-field">
          <span>⌕</span>
          <input
            aria-label="관리자 목록 검색"
            placeholder="이름 또는 이메일 검색"
            value={query}
            onChange={(event) => setQuery(event.target.value)}
          />
        </label>
      </section>

      {loading ? (
        <div className="management-empty">관리자 데이터를 불러오는 중입니다.</div>
      ) : (
        <section className="admin-table" aria-label="관리자 운영 목록">
          {tab === 'users' && (
            <>
              <header className="admin-user-row">
                <span>사용자</span>
                <span>역할</span>
                <span>상태</span>
                <span>관리</span>
              </header>
              {visibleUsers.map((user) => (
                <article className="admin-user-row" key={user.userId}>
                  <div>
                    <strong>{user.name}</strong>
                    <small>{user.email}</small>
                  </div>
                  <span>{roleLabel[user.role]}</span>
                  <b className={`admin-status ${user.status.toLowerCase()}`}>
                    {user.status === 'ACTIVE'
                      ? '활성'
                      : user.status === 'SUSPENDED'
                        ? '정지'
                        : '탈퇴'}
                  </b>
                  <button
                    disabled={
                      updating === `user-${user.userId}` ||
                      user.role === 'ADMIN' ||
                      user.status === 'WITHDRAWN'
                    }
                    onClick={() => void toggleUser(user)}
                  >
                    {user.status === 'ACTIVE' ? '이용 정지' : '활성화'}
                  </button>
                </article>
              ))}
            </>
          )}

          {tab === 'sellers' && (
            <>
              <header className="admin-seller-row">
                <span>판매자</span>
                <span>사업자 정보</span>
                <span>인증</span>
                <span>관리</span>
              </header>
              {visibleSellers.map((seller) => (
                <article
                  className="admin-seller-row"
                  key={seller.sellerProfileId}
                >
                  <div>
                    <strong>{seller.name}</strong>
                    <small>{seller.email}</small>
                  </div>
                  <div>
                    <strong>{seller.businessName ?? '미입력'}</strong>
                    <small>
                      {seller.businessRegistrationNumber ?? '등록번호 미입력'}
                    </small>
                  </div>
                  <b
                    className={`admin-status ${seller.verificationStatus.toLowerCase()}`}
                  >
                    {seller.verificationStatus === 'VERIFIED'
                      ? '인증'
                      : seller.verificationStatus === 'REJECTED'
                        ? '반려'
                        : '대기'}
                  </b>
                  <div className="admin-row-actions">
                    <button
                      disabled={
                        updating === `seller-${seller.sellerProfileId}`
                      }
                      onClick={() => void verifySeller(seller, 'VERIFIED')}
                    >
                      승인
                    </button>
                    <button
                      className="danger"
                      disabled={
                        updating === `seller-${seller.sellerProfileId}`
                      }
                      onClick={() => void verifySeller(seller, 'REJECTED')}
                    >
                      반려
                    </button>
                  </div>
                </article>
              ))}
            </>
          )}

          {tab === 'stores' && (
            <>
              <header className="admin-store-row">
                <span>스토어</span>
                <span>유형</span>
                <span>영업</span>
                <span>상태</span>
                <span>관리</span>
              </header>
              {visibleStores.map((store) => (
                <article className="admin-store-row" key={store.storeId}>
                  <div>
                    <strong>{store.name}</strong>
                    <small>ID {store.storeId}</small>
                  </div>
                  <span>
                    {store.storeType === 'LOCAL_STORE' ? '일반 매장' : '행사'}
                  </span>
                  <span>
                    {store.businessStatus === 'OPEN'
                      ? '영업 중'
                      : store.businessStatus === 'PRE_OPEN'
                        ? '오픈 준비'
                        : '영업 종료'}
                  </span>
                  <b className={`admin-status ${store.status.toLowerCase()}`}>
                    {store.status === 'ACTIVE'
                      ? '활성'
                      : store.status === 'SUSPENDED'
                        ? '정지'
                        : '폐점'}
                  </b>
                  <button
                    disabled={
                      updating === `store-${store.storeId}` ||
                      store.status === 'CLOSED'
                    }
                    onClick={() => void toggleStore(store)}
                  >
                    {store.status === 'ACTIVE' ? '운영 정지' : '재활성화'}
                  </button>
                </article>
              ))}
            </>
          )}
        </section>
      )}

      <p className="source-note">
        {isDemo
          ? '데모 관리자 데이터는 새로고침 시 초기화됩니다.'
          : 'ADMIN 역할 토큰만 조회와 상태 변경을 실행할 수 있습니다.'}
      </p>
    </main>
  )
}

import { useState, type FormEvent } from 'react'
import { getSellerStores, loginAccount, signUpSeller } from '../../services/api'
import type {
  SellerAuthResult,
  SellerConnection,
  StoreSummary,
} from '../../types'

type AuthMode = 'seller-login' | 'admin-login' | 'signup'

type SellerAuthProps = {
  onAuthenticated: (connection: SellerConnection) => void
  onUseDemo: () => void
}

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
const PASSWORD_PATTERN = /^(?=.*[A-Za-z])(?=.*\d).+$/
const PHONE_PATTERN = /^01[0-9]-?\d{3,4}-?\d{4}$/

export function SellerAuth({ onAuthenticated, onUseDemo }: SellerAuthProps) {
  const [mode, setMode] = useState<AuthMode>('seller-login')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [passwordConfirm, setPasswordConfirm] = useState('')
  const [name, setName] = useState('')
  const [phone, setPhone] = useState('')
  const [agreed, setAgreed] = useState(false)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [notice, setNotice] = useState<string | null>(null)
  const [pendingAuth, setPendingAuth] = useState<SellerAuthResult | null>(null)
  const [stores, setStores] = useState<StoreSummary[]>([])

  function switchMode(nextMode: AuthMode) {
    setMode(nextMode)
    setError(null)
    setNotice(null)
    setPassword('')
    setPasswordConfirm('')
  }

  function completeAuthentication(auth: SellerAuthResult, store: StoreSummary) {
    onAuthenticated({
      storeId: store.storeId,
      accessToken: auth.accessToken,
      storeName: store.name,
      user: auth.user,
    })
  }

  async function handleLogin(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setError(null)
    setNotice(null)

    if (!EMAIL_PATTERN.test(email.trim())) {
      setError('올바른 이메일 주소를 입력해 주세요.')
      return
    }
    if (!password) {
      setError('비밀번호를 입력해 주세요.')
      return
    }

    setBusy(true)
    try {
      const expectedRole = mode === 'admin-login' ? 'ADMIN' : 'SELLER'
      const auth = await loginAccount(email.trim(), password, expectedRole)
      if (auth.user.role !== expectedRole) {
        throw new Error(
          expectedRole === 'ADMIN'
            ? '관리자 권한이 있는 계정만 관리자 화면에 로그인할 수 있습니다.'
            : '판매자 권한이 있는 계정으로 로그인해 주세요.',
        )
      }

      if (expectedRole === 'ADMIN') {
        onAuthenticated({
          storeId: null,
          accessToken: auth.accessToken,
          user: auth.user,
        })
        return
      }

      const connection = { storeId: 0, accessToken: auth.accessToken }
      const ownedStores = await getSellerStores(connection)
      if (ownedStores.length === 0) {
        throw new Error(
          '운영할 수 있는 스토어가 없습니다. 판매자 앱에서 스토어를 먼저 등록해 주세요.',
        )
      }
      if (ownedStores.length === 1) {
        completeAuthentication(auth, ownedStores[0])
        return
      }

      setPendingAuth(auth)
      setStores(ownedStores)
    } catch (caught) {
      setError(
        caught instanceof Error
          ? caught.message
          : '로그인에 실패했습니다. 다시 시도해 주세요.',
      )
    } finally {
      setBusy(false)
    }
  }

  async function handleSignup(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setError(null)
    setNotice(null)

    const normalizedEmail = email.trim()
    const normalizedName = name.trim()
    const normalizedPhone = phone.trim()
    if (!EMAIL_PATTERN.test(normalizedEmail)) {
      setError('올바른 이메일 주소를 입력해 주세요.')
      return
    }
    if (normalizedName.length < 2 || normalizedName.length > 100) {
      setError('이름은 2자 이상 100자 이하로 입력해 주세요.')
      return
    }
    if (!PHONE_PATTERN.test(normalizedPhone)) {
      setError('올바른 휴대전화 번호를 입력해 주세요.')
      return
    }
    if (
      password.length < 8 ||
      password.length > 64 ||
      !PASSWORD_PATTERN.test(password)
    ) {
      setError('비밀번호는 영문과 숫자를 포함해 8자 이상 입력해 주세요.')
      return
    }
    if (password !== passwordConfirm) {
      setError('비밀번호가 일치하지 않습니다.')
      return
    }
    if (!agreed) {
      setError('개인정보 수집 및 이용에 동의해 주세요.')
      return
    }

    setBusy(true)
    try {
      await signUpSeller({
        email: normalizedEmail,
        password,
        name: normalizedName,
        phone: normalizedPhone,
      })
      setMode('seller-login')
      setPassword('')
      setPasswordConfirm('')
      setNotice('회원가입이 완료되었습니다. 로그인해 주세요.')
    } catch (caught) {
      setError(
        caught instanceof Error
          ? caught.message
          : '회원가입에 실패했습니다. 다시 시도해 주세요.',
      )
    } finally {
      setBusy(false)
    }
  }

  if (pendingAuth) {
    return (
      <main className="auth-page">
        <section className="auth-card store-choice-card">
          <AuthBrand />
          <p className="eyebrow">SELECT STORE</p>
          <h1>운영할 스토어를 선택하세요</h1>
          <p className="auth-description">
            판매자 앱과 동일한 계정에 연결된 스토어입니다.
          </p>
          <div className="auth-store-list">
            {stores.map((store) => (
              <button
                key={store.storeId}
                type="button"
                onClick={() => completeAuthentication(pendingAuth, store)}
              >
                <span>{store.name.slice(0, 1)}</span>
                <div>
                  <strong>{store.name}</strong>
                  <small>
                    {store.myRole} · {store.businessStatus}
                  </small>
                </div>
                <b>선택</b>
              </button>
            ))}
          </div>
          <button
            type="button"
            className="auth-text-button"
            onClick={() => {
              setPendingAuth(null)
              setStores([])
            }}
          >
            다른 계정으로 로그인
          </button>
        </section>
      </main>
    )
  }

  return (
    <main className="auth-page">
      <section className="auth-showcase" aria-label="POPQ 판매자 웹 소개">
        <AuthBrand />
        <div>
          <p className="eyebrow">SELL SMARTER, MOVE FASTER</p>
          <h1>오늘의 매장 운영을<br />한눈에 관리하세요.</h1>
          <p>
            주문 접수부터 상품, QR, 매출까지 판매자 앱과 같은 계정으로
            어디서든 이어서 관리할 수 있습니다.
          </p>
        </div>
        <ul>
          <li><strong>LIVE</strong><span>실시간 주문 현황</span></li>
          <li><strong>ONE</strong><span>앱·웹 통합 계정</span></li>
          <li><strong>SAFE</strong><span>탭 단위 보안 세션</span></li>
        </ul>
      </section>

      <section className="auth-card">
        <div className="auth-mobile-brand"><AuthBrand /></div>
        <p className="eyebrow">
          {mode === 'admin-login' ? 'ADMIN ACCOUNT' : 'SELLER ACCOUNT'}
        </p>
        <h2>
          {mode === 'seller-login'
            ? '판매자 로그인'
            : mode === 'admin-login'
              ? '관리자 로그인'
              : '판매자 회원가입'}
        </h2>
        <p className="auth-description">
          {mode === 'seller-login'
            ? '판매자 앱에서 사용하던 계정으로 로그인할 수 있습니다.'
            : mode === 'admin-login'
              ? '플랫폼 관리자 권한이 있는 계정만 접근할 수 있습니다.'
              : '가입한 계정은 판매자 앱과 웹에서 함께 사용할 수 있습니다.'}
        </p>

        <div className="auth-tabs" role="tablist" aria-label="인증 방식">
          <button
            type="button"
            role="tab"
            aria-selected={mode === 'seller-login'}
            className={mode === 'seller-login' ? 'active' : ''}
            onClick={() => switchMode('seller-login')}
          >
            판매자
          </button>
          <button
            type="button"
            role="tab"
            aria-selected={mode === 'admin-login'}
            className={mode === 'admin-login' ? 'active' : ''}
            onClick={() => switchMode('admin-login')}
          >
            관리자
          </button>
          <button
            type="button"
            role="tab"
            aria-selected={mode === 'signup'}
            className={mode === 'signup' ? 'active' : ''}
            onClick={() => switchMode('signup')}
          >
            회원가입
          </button>
        </div>

        <form
          className="auth-form"
          onSubmit={mode === 'signup' ? handleSignup : handleLogin}
          noValidate
        >
          <label>
            이메일
            <input
              type="email"
              autoComplete="email"
              placeholder={
                mode === 'admin-login' ? 'admin@popq.kr' : 'seller@popq.kr'
              }
              value={email}
              onChange={(event) => setEmail(event.target.value)}
              disabled={busy}
            />
          </label>
          {mode === 'signup' && (
            <>
              <label>
                이름 (대표자명)
                <input
                  type="text"
                  autoComplete="name"
                  maxLength={100}
                  value={name}
                  onChange={(event) => setName(event.target.value)}
                  disabled={busy}
                />
              </label>
              <label>
                휴대전화 번호
                <input
                  type="tel"
                  autoComplete="tel"
                  placeholder="010-1234-5678"
                  value={phone}
                  onChange={(event) => setPhone(event.target.value)}
                  disabled={busy}
                />
              </label>
            </>
          )}
          <label>
            비밀번호
            <input
              type="password"
              autoComplete={mode === 'signup' ? 'new-password' : 'current-password'}
              placeholder={mode === 'signup' ? '영문·숫자 포함 8자 이상' : undefined}
              value={password}
              onChange={(event) => setPassword(event.target.value)}
              disabled={busy}
            />
          </label>
          {mode === 'signup' && (
            <>
              <label>
                비밀번호 확인
                <input
                  type="password"
                  autoComplete="new-password"
                  value={passwordConfirm}
                  onChange={(event) => setPasswordConfirm(event.target.value)}
                  disabled={busy}
                />
              </label>
              <label className="auth-agreement">
                <input
                  type="checkbox"
                  checked={agreed}
                  onChange={(event) => setAgreed(event.target.checked)}
                  disabled={busy}
                />
                <span>개인정보 수집 및 이용에 동의합니다.</span>
              </label>
            </>
          )}

          {notice && <p className="auth-notice" role="status">{notice}</p>}
          {error && <p className="auth-error" role="alert">{error}</p>}

          <button className="auth-submit" type="submit" disabled={busy}>
            {busy
              ? mode === 'signup' ? '가입 처리 중…' : '로그인 중…'
              : mode === 'signup' ? '회원가입' : '로그인'}
          </button>
        </form>

        {mode !== 'admin-login' && (
          <div className="auth-demo">
            <span>백엔드 없이 화면을 둘러보고 싶다면</span>
            <button type="button" onClick={onUseDemo}>데모로 체험하기</button>
          </div>
        )}
      </section>
    </main>
  )
}

function AuthBrand() {
  return (
    <div className="auth-brand">
      <span>P</span>
      <div><strong>POPQ</strong><small>SELLER</small></div>
    </div>
  )
}

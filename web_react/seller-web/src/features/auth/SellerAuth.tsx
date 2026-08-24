import { useEffect, useRef, useState, type FormEvent } from "react";
import {
  createSellerStore,
  getInactiveSellerStores,
  getSellerStores,
  loginAccount,
  loginSellerSocial,
  loginSellerWithKakaoCode,
  loginSellerWithNaverCode,
  reopenSellerStore,
  signUpSeller,
} from "../../services/api";
import type {
  SellerAuthResult,
  SellerConnection,
  StoreSavePayload,
  StoreSummary,
  StoreType,
} from "../../types";
import { renderGoogleSellerButton } from "./googleSellerAuth";
import { startKakaoSellerLogin } from "./kakaoSellerAuth";
import {
  consumeNaverSellerState,
  startNaverSellerLogin,
} from "./naverSellerAuth";

type AuthMode = "seller-login" | "admin-login" | "signup";

type SellerAuthProps = {
  onAuthenticated: (connection: SellerConnection) => void;
  onUseDemo: () => void;
};

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const PASSWORD_PATTERN = /^(?=.*[A-Za-z])(?=.*\d).+$/;
const PHONE_PATTERN = /^01[0-9]-?\d{3,4}-?\d{4}$/;
const NICKNAME_PATTERN =
  /^[A-Za-z0-9 \u3040-\u30FF\u3400-\u4DBF\u4E00-\u9FFF\uAC00-\uD7A3\u3131-\u318E]+$/u;
const STORE_PHONE_PATTERN = /^[0-9+\-()\s]+$/;
const STORE_CATEGORIES = [
  "카페",
  "디저트",
  "베이커리",
  "한식",
  "중식",
  "일식",
  "양식",
  "분식",
  "치킨",
  "피자",
  "패스트푸드",
  "주점",
  "푸드트럭",
  "팝업·행사",
  "플리마켓·행사",
  "기타",
];

type FirstStoreDraft = {
  storeType: StoreType;
  name: string;
  representativeCategory: string;
  address: string;
  detailAddress: string;
  phone: string;
  dineInAvailable: boolean;
  takeoutAvailable: boolean;
};

const EMPTY_FIRST_STORE: FirstStoreDraft = {
  storeType: "LOCAL_STORE",
  name: "",
  representativeCategory: "",
  address: "",
  detailAddress: "",
  phone: "",
  dineInAvailable: true,
  takeoutAvailable: true,
};

export function SellerAuth({ onAuthenticated, onUseDemo }: SellerAuthProps) {
  const [mode, setMode] = useState<AuthMode>("seller-login");
  const googleButtonRef = useRef<HTMLDivElement>(null);
  const kakaoCodeHandledRef = useRef(false);
  const naverCodeHandledRef = useRef(false);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [passwordConfirm, setPasswordConfirm] = useState("");
  const [name, setName] = useState("");
  const [phone, setPhone] = useState("");
  const [agreed, setAgreed] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [pendingAuth, setPendingAuth] = useState<SellerAuthResult | null>(null);
  const [stores, setStores] = useState<StoreSummary[]>([]);
  const [needsFirstStore, setNeedsFirstStore] = useState(false);
  const [needsStoreRecovery, setNeedsStoreRecovery] = useState(false);
  const [firstStore, setFirstStore] =
    useState<FirstStoreDraft>(EMPTY_FIRST_STORE);

  function switchMode(nextMode: AuthMode) {
    setMode(nextMode);
    setError(null);
    setNotice(null);
    setPassword("");
    setPasswordConfirm("");
  }

  function completeAuthentication(auth: SellerAuthResult, store: StoreSummary) {
    onAuthenticated({
      storeId: store.storeId,
      accessToken: auth.accessToken,
      storeName: store.name,
      storeRole: store.myRole,
      user: auth.user,
    });
  }
  async function completeSellerAuthentication(auth: SellerAuthResult) {
    if (auth.user.role !== "SELLER") {
      throw new Error("판매자 권한이 있는 계정으로 로그인해 주세요.");
    }

    const connection = {
      storeId: 0,
      accessToken: auth.accessToken,
    };

    const ownedStores = await getSellerStores(connection);

    if (ownedStores.length === 0) {
      const inactiveStores = await getInactiveSellerStores(connection);

      setPendingAuth(auth);
      setStores(inactiveStores);

      const hasSuspendedStore = inactiveStores.some(
        (store) => store.status === "SUSPENDED",
      );

      setNeedsStoreRecovery(hasSuspendedStore);
      setNeedsFirstStore(!hasSuspendedStore);
      return;
    }

    if (ownedStores.length === 1) {
      completeAuthentication(auth, ownedStores[0]);
      return;
    }

    setPendingAuth(auth);
    setStores(ownedStores);
    setNeedsFirstStore(false);
    setNeedsStoreRecovery(false);
  }

  async function handleGoogleIdToken(idToken: string) {
    setError(null);
    setNotice(null);
    setBusy(true);

    try {
      const auth = await loginSellerSocial("GOOGLE", idToken);

      await completeSellerAuthentication(auth);
    } catch (caught) {
      setError(
        caught instanceof Error
          ? caught.message
          : "Google 로그인에 실패했습니다.",
      );
    } finally {
      setBusy(false);
    }
  }

  async function handleKakaoLogin() {
    setError(null);
    setNotice(null);
    setBusy(true);

    try {
      await startKakaoSellerLogin();
    } catch (caught) {
      setError(
        caught instanceof Error
          ? caught.message
          : "카카오 로그인을 시작하지 못했습니다.",
      );
      setBusy(false);
    }
  }

  function handleNaverLogin() {
    setError(null);
    setNotice(null);
    setBusy(true);

    try {
      startNaverSellerLogin();
    } catch (caught) {
      setError(
        caught instanceof Error
          ? caught.message
          : "네이버 로그인을 시작하지 못했습니다.",
      );
      setBusy(false);
    }
  }

  useEffect(() => {
    if (mode !== "seller-login" || !googleButtonRef.current) {
      return;
    }

    let active = true;

    void renderGoogleSellerButton(googleButtonRef.current, (idToken) => {
      if (!active) {
        return;
      }

      void handleGoogleIdToken(idToken);
    }).catch((caught) => {
      if (!active) {
        return;
      }

      setError(
        caught instanceof Error
          ? caught.message
          : "Google 로그인 버튼을 준비하지 못했습니다.",
      );
    });

    return () => {
      active = false;
    };

    // 판매자 탭에 진입할 때 Google 버튼을 다시 렌더링합니다.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [mode]);

  useEffect(() => {
    function handlePageShow() {
      setBusy(false);
    }

    window.addEventListener("pageshow", handlePageShow);
    return () => window.removeEventListener("pageshow", handlePageShow);
  }, []);

  useEffect(() => {
    const redirectUri = import.meta.env.VITE_KAKAO_REDIRECT_URI?.trim();
    if (!redirectUri || kakaoCodeHandledRef.current) {
      return;
    }

    const callbackUrl = new URL(redirectUri, window.location.origin);
    if (window.location.pathname !== callbackUrl.pathname) {
      return;
    }

    const authorizationCode = new URLSearchParams(window.location.search).get(
      "code",
    );
    if (!authorizationCode) {
      setError("카카오 인증코드를 받지 못했습니다.");
      return;
    }

    kakaoCodeHandledRef.current = true;
    setBusy(true);
    setError(null);
    window.history.replaceState({}, document.title, "/");

    void loginSellerWithKakaoCode(authorizationCode)
      .then((auth) => completeSellerAuthentication(auth))
      .catch((caught) => {
        setError(
          caught instanceof Error
            ? caught.message
            : "카카오 로그인에 실패했습니다.",
        );
      })
      .finally(() => setBusy(false));

    // 카카오 콜백 인증코드는 최초 마운트에서 한 번만 처리합니다.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    const redirectUri = import.meta.env.VITE_NAVER_REDIRECT_URI?.trim();
    if (!redirectUri || naverCodeHandledRef.current) {
      return;
    }

    const callbackUrl = new URL(redirectUri, window.location.origin);
    if (window.location.pathname !== callbackUrl.pathname) {
      return;
    }

    const params = new URLSearchParams(window.location.search);
    const authorizationCode = params.get("code");
    const receivedState = params.get("state");
    const oauthError = params.get("error_description") ?? params.get("error");

    naverCodeHandledRef.current = true;
    window.history.replaceState({}, document.title, "/");

    if (oauthError) {
      setError(`네이버 로그인이 취소되었거나 실패했습니다: ${oauthError}`);
      return;
    }

    if (!authorizationCode || !receivedState) {
      setError("네이버 인증코드 또는 state를 받지 못했습니다.");
      return;
    }

    if (!consumeNaverSellerState(receivedState)) {
      setError("네이버 로그인 요청을 확인할 수 없습니다. 다시 시도해 주세요.");
      return;
    }

    setBusy(true);
    setError(null);

    void loginSellerWithNaverCode(authorizationCode, receivedState)
      .then((auth) => completeSellerAuthentication(auth))
      .catch((caught) => {
        setError(
          caught instanceof Error
            ? caught.message
            : "네이버 로그인에 실패했습니다.",
        );
      })
      .finally(() => setBusy(false));

    // 네이버 콜백 인증코드는 최초 마운트에서 한 번만 처리합니다.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  async function handleLogin(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError(null);
    setNotice(null);

    if (!EMAIL_PATTERN.test(email.trim())) {
      setError("올바른 이메일 주소를 입력해 주세요.");
      return;
    }
    if (!password) {
      setError("비밀번호를 입력해 주세요.");
      return;
    }

    setBusy(true);
    try {
      const expectedRole = mode === "admin-login" ? "ADMIN" : "SELLER";
      const auth = await loginAccount(email.trim(), password, expectedRole);
      if (auth.user.role !== expectedRole) {
        throw new Error(
          expectedRole === "ADMIN"
            ? "관리자 권한이 있는 계정만 관리자 화면에 로그인할 수 있습니다."
            : "판매자 권한이 있는 계정으로 로그인해 주세요.",
        );
      }

      if (expectedRole === "ADMIN") {
        onAuthenticated({
          storeId: null,
          accessToken: auth.accessToken,
          user: auth.user,
        });
        return;
      }

      await completeSellerAuthentication(auth);
    } catch (caught) {
      setError(
        caught instanceof Error
          ? caught.message
          : "로그인에 실패했습니다. 다시 시도해 주세요.",
      );
    } finally {
      setBusy(false);
    }
  }

  async function reopenStoreFromAuth(store: StoreSummary) {
    if (!pendingAuth || store.status !== "SUSPENDED") return;
    setBusy(true);
    setError(null);
    try {
      const reopened = await reopenSellerStore(
        {
          storeId: store.storeId,
          accessToken: pendingAuth.accessToken,
          user: pendingAuth.user,
        },
        store.storeId,
      );
      completeAuthentication(pendingAuth, reopened);
    } catch (caught) {
      setError(
        caught instanceof Error
          ? caught.message
          : "사업장을 재개하지 못했습니다.",
      );
    } finally {
      setBusy(false);
    }
  }

  async function createFirstStore(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!pendingAuth) return;
    const draft = {
      ...firstStore,
      name: firstStore.name.trim(),
      representativeCategory: firstStore.representativeCategory.trim(),
      address: firstStore.address.trim(),
      detailAddress: firstStore.detailAddress.trim(),
      phone: firstStore.phone.trim(),
    };
    if (
      !draft.name ||
      !draft.representativeCategory ||
      !draft.address ||
      !draft.detailAddress ||
      !draft.phone
    ) {
      setError(
        "사업장명, 대표 카테고리, 주소, 상세 주소와 연락처를 모두 입력해 주세요.",
      );
      return;
    }
    if (!STORE_PHONE_PATTERN.test(draft.phone)) {
      setError("연락처 형식을 확인해 주세요.");
      return;
    }
    if (!draft.dineInAvailable && !draft.takeoutAvailable) {
      setError("포장 또는 매장 식사 중 하나는 가능해야 합니다.");
      return;
    }
    const payload: StoreSavePayload = {
      storeType: draft.storeType,
      name: draft.name,
      description: null,
      address: draft.address,
      detailAddress: draft.detailAddress,
      representativeCategory: draft.representativeCategory,
      imageUrl: null,
      phone: draft.phone,
      latitude: null,
      longitude: null,
      openTime: "09:00",
      closeTime: "21:00",
      operationStartDate: null,
      operationEndDate: null,
      closedDays: [],
      takeoutAvailable: draft.takeoutAvailable,
      dineInAvailable: draft.dineInAvailable,
      orderAcceptingEnabled: true,
      tags: [],
    };
    setBusy(true);
    setError(null);
    try {
      const created = await createSellerStore(
        {
          storeId: 0,
          accessToken: pendingAuth.accessToken,
          user: pendingAuth.user,
        },
        payload,
      );
      completeAuthentication(pendingAuth, created);
    } catch (caught) {
      setError(
        caught instanceof Error
          ? caught.message
          : "첫 사업장을 등록하지 못했습니다.",
      );
    } finally {
      setBusy(false);
    }
  }

  async function handleSignup(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError(null);
    setNotice(null);

    const normalizedEmail = email.trim();
    const normalizedName = name.trim();
    const normalizedPhone = phone.trim();
    if (!EMAIL_PATTERN.test(normalizedEmail)) {
      setError("올바른 이메일 주소를 입력해 주세요.");
      return;
    }
    if (
      normalizedName.length === 0 ||
      Array.from(normalizedName).length > 7 ||
      !NICKNAME_PATTERN.test(normalizedName)
    ) {
      setError("닉네임은 허용된 문자로 7자 이하로 입력해 주세요.");
      return;
    }
    if (!PHONE_PATTERN.test(normalizedPhone)) {
      setError("올바른 휴대전화 번호를 입력해 주세요.");
      return;
    }
    if (
      password.length < 8 ||
      password.length > 64 ||
      !PASSWORD_PATTERN.test(password)
    ) {
      setError("비밀번호는 영문과 숫자를 포함해 8자 이상 입력해 주세요.");
      return;
    }
    if (password !== passwordConfirm) {
      setError("비밀번호가 일치하지 않습니다.");
      return;
    }
    if (!agreed) {
      setError("개인정보 수집 및 이용에 동의해 주세요.");
      return;
    }

    setBusy(true);
    try {
      await signUpSeller({
        email: normalizedEmail,
        password,
        name: normalizedName,
        phone: normalizedPhone,
      });
      setMode("seller-login");
      setPassword("");
      setPasswordConfirm("");
      setNotice("회원가입이 완료되었습니다. 로그인해 주세요.");
    } catch (caught) {
      setError(
        caught instanceof Error
          ? caught.message
          : "회원가입에 실패했습니다. 다시 시도해 주세요.",
      );
    } finally {
      setBusy(false);
    }
  }

  if (pendingAuth) {
    if (needsFirstStore) {
      return (
        <main className="auth-page">
          <section className="auth-card store-choice-card">
            <AuthBrand />
            <p className="eyebrow">FIRST STORE</p>
            <h1>첫 사업장을 등록하세요</h1>
            <p className="auth-description">
              판매자 App과 동일한 필수 항목으로 첫 운영 공간을 만듭니다.
            </p>
            <form className="auth-form" onSubmit={createFirstStore}>
              <label>
                사업장 유형
                <select
                  value={firstStore.storeType}
                  onChange={(event) =>
                    setFirstStore({
                      ...firstStore,
                      storeType: event.target.value as StoreType,
                    })
                  }
                >
                  <option value="LOCAL_STORE">상설 매장</option>
                  <option value="EVENT_COMMERCE">이벤트 커머스</option>
                </select>
              </label>
              <label>
                사업장명 *
                <input
                  maxLength={150}
                  value={firstStore.name}
                  onChange={(event) =>
                    setFirstStore({ ...firstStore, name: event.target.value })
                  }
                />
              </label>
              <label>
                대표 카테고리 *
                <select
                  value={firstStore.representativeCategory}
                  onChange={(event) =>
                    setFirstStore({
                      ...firstStore,
                      representativeCategory: event.target.value,
                    })
                  }
                >
                  <option value="">선택</option>
                  {STORE_CATEGORIES.map((category) => (
                    <option key={category} value={category}>
                      {category}
                    </option>
                  ))}
                </select>
              </label>
              <label>
                주소 *
                <input
                  maxLength={255}
                  value={firstStore.address}
                  onChange={(event) =>
                    setFirstStore({
                      ...firstStore,
                      address: event.target.value,
                    })
                  }
                />
              </label>
              <label>
                상세 주소 *
                <input
                  maxLength={255}
                  value={firstStore.detailAddress}
                  onChange={(event) =>
                    setFirstStore({
                      ...firstStore,
                      detailAddress: event.target.value,
                    })
                  }
                />
              </label>
              <label>
                연락처 *
                <input
                  maxLength={30}
                  value={firstStore.phone}
                  onChange={(event) =>
                    setFirstStore({ ...firstStore, phone: event.target.value })
                  }
                />
              </label>
              <fieldset className="choice-fieldset">
                <legend>주문 방식 *</legend>
                <label>
                  <input
                    type="checkbox"
                    checked={firstStore.dineInAvailable}
                    onChange={(event) =>
                      setFirstStore({
                        ...firstStore,
                        dineInAvailable: event.target.checked,
                      })
                    }
                  />
                  매장 식사
                </label>
                <label>
                  <input
                    type="checkbox"
                    checked={firstStore.takeoutAvailable}
                    onChange={(event) =>
                      setFirstStore({
                        ...firstStore,
                        takeoutAvailable: event.target.checked,
                      })
                    }
                  />
                  포장
                </label>
              </fieldset>
              {error && (
                <p className="auth-error" role="alert">
                  {error}
                </p>
              )}
              <button className="auth-submit" type="submit" disabled={busy}>
                {busy ? "등록 중…" : "사업장 등록하고 시작하기"}
              </button>
            </form>
            <button
              type="button"
              className="auth-text-button"
              onClick={() => {
                setPendingAuth(null);
                setNeedsFirstStore(false);
                setFirstStore(EMPTY_FIRST_STORE);
                setError(null);
              }}
            >
              다른 계정으로 로그인
            </button>
          </section>
        </main>
      );
    }
    if (needsStoreRecovery) {
      return (
        <main className="auth-page">
          <section className="auth-card store-choice-card">
            <AuthBrand />
            <p className="eyebrow">INACTIVE STORES</p>
            <h1>휴업 사업장을 재개하세요</h1>
            <p className="auth-description">
              App과 동일하게 휴업 사업장은 기존 데이터와 함께 다시 운영할 수
              있습니다.
            </p>
            <div className="auth-store-list">
              {stores.map((store) => (
                <article key={store.storeId} className="announcement-card">
                  <div>
                    <strong>{store.name}</strong>
                    <small>
                      {store.status === "SUSPENDED" ? "휴업" : "폐업"}
                    </small>
                  </div>
                  {store.status === "SUSPENDED" && (
                    <button
                      type="button"
                      disabled={busy}
                      onClick={() => void reopenStoreFromAuth(store)}
                    >
                      재개
                    </button>
                  )}
                </article>
              ))}
            </div>
            {error && (
              <p className="auth-error" role="alert">
                {error}
              </p>
            )}
            <button
              type="button"
              className="auth-text-button"
              onClick={() => {
                setNeedsStoreRecovery(false);
                setNeedsFirstStore(true);
                setError(null);
              }}
            >
              새 사업장 등록
            </button>
            <button
              type="button"
              className="auth-text-button"
              onClick={() => {
                setPendingAuth(null);
                setStores([]);
                setNeedsStoreRecovery(false);
                setError(null);
              }}
            >
              다른 계정으로 로그인
            </button>
          </section>
        </main>
      );
    }
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
              setPendingAuth(null);
              setStores([]);
              setNeedsFirstStore(false);
              setNeedsStoreRecovery(false);
            }}
          >
            다른 계정으로 로그인
          </button>
        </section>
      </main>
    );
  }

  return (
    <main className="auth-page">
      <section className="auth-showcase" aria-label="POPQ 판매자 웹 소개">
        <AuthBrand />
        <div>
          <p className="eyebrow">SELL SMARTER, MOVE FASTER</p>
          <h1>
            오늘의 매장 운영을
            <br />
            한눈에 관리하세요.
          </h1>
          <p>
            주문 접수부터 상품, QR, 매출까지 판매자 앱과 같은 계정으로 어디서든
            이어서 관리할 수 있습니다.
          </p>
        </div>
        <ul>
          <li>
            <strong>LIVE</strong>
            <span>실시간 주문 현황</span>
          </li>
          <li>
            <strong>ONE</strong>
            <span>앱·웹 통합 계정</span>
          </li>
          <li>
            <strong>SAFE</strong>
            <span>탭 단위 보안 세션</span>
          </li>
        </ul>
      </section>

      <section className="auth-card">
        <div className="auth-mobile-brand">
          <AuthBrand />
        </div>
        <p className="eyebrow">
          {mode === "admin-login" ? "ADMIN ACCOUNT" : "SELLER ACCOUNT"}
        </p>
        <h2>
          {mode === "seller-login"
            ? "판매자 로그인"
            : mode === "admin-login"
              ? "관리자 로그인"
              : "판매자 회원가입"}
        </h2>
        <p className="auth-description">
          {mode === "seller-login"
            ? "판매자 앱에서 사용하던 계정으로 로그인할 수 있습니다."
            : mode === "admin-login"
              ? "플랫폼 관리자 권한이 있는 계정만 접근할 수 있습니다."
              : "가입한 계정은 판매자 앱과 웹에서 함께 사용할 수 있습니다."}
        </p>

        <div className="auth-tabs" role="tablist" aria-label="인증 방식">
          <button
            type="button"
            role="tab"
            aria-selected={mode === "seller-login"}
            className={mode === "seller-login" ? "active" : ""}
            onClick={() => switchMode("seller-login")}
          >
            판매자
          </button>
          <button
            type="button"
            role="tab"
            aria-selected={mode === "admin-login"}
            className={mode === "admin-login" ? "active" : ""}
            onClick={() => switchMode("admin-login")}
          >
            관리자
          </button>
          <button
            type="button"
            role="tab"
            aria-selected={mode === "signup"}
            className={mode === "signup" ? "active" : ""}
            onClick={() => switchMode("signup")}
          >
            회원가입
          </button>
        </div>

        <form
          className="auth-form"
          onSubmit={mode === "signup" ? handleSignup : handleLogin}
          noValidate
        >
          <label>
            이메일
            <input
              type="email"
              autoComplete="email"
              placeholder={
                mode === "admin-login" ? "admin@popq.kr" : "seller@popq.kr"
              }
              value={email}
              onChange={(event) => setEmail(event.target.value)}
              disabled={busy}
            />
          </label>
          {mode === "signup" && (
            <>
              <label>
                닉네임
                <input
                  type="text"
                  autoComplete="name"
                  maxLength={7}
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
              autoComplete={
                mode === "signup" ? "new-password" : "current-password"
              }
              placeholder={
                mode === "signup" ? "영문·숫자 포함 8자 이상" : undefined
              }
              value={password}
              onChange={(event) => setPassword(event.target.value)}
              disabled={busy}
            />
          </label>
          {mode === "signup" && (
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

          {notice && (
            <p className="auth-notice" role="status">
              {notice}
            </p>
          )}
          {error && (
            <p className="auth-error" role="alert">
              {error}
            </p>
          )}

          <button className="auth-submit" type="submit" disabled={busy}>
            {busy
              ? mode === "signup"
                ? "가입 처리 중…"
                : "로그인 중…"
              : mode === "signup"
                ? "회원가입"
                : "로그인"}
          </button>
        </form>

        {mode === "seller-login" && (
          <section
            className="seller-social-login"
            aria-label="판매자 소셜 로그인"
          >
            <div className="seller-social-divider">
              <span>또는 소셜 계정으로 로그인</span>
            </div>

            <div className="seller-social-buttons">
              <div
                ref={googleButtonRef}
                className={`seller-social-button seller-google-button-host${
                  busy ? " is-disabled" : ""
                }`}
                aria-label="Google로 판매자 로그인"
                aria-busy={busy}
              >
                <img src="/images/social/google_g.png" alt="" />
              </div>

              <button
                type="button"
                className="seller-social-button"
                aria-label="카카오로 판매자 로그인"
                onClick={() => void handleKakaoLogin()}
                disabled={busy}
              >
                <img src="/images/social/kakao_k.png" alt="" />
              </button>

              <button
                type="button"
                className="seller-social-button"
                aria-label="네이버로 판매자 로그인"
                onClick={handleNaverLogin}
                disabled={busy}
              >
                <img src="/images/social/naver_n.png" alt="" />
              </button>
            </div>
          </section>
        )}

        {mode !== "admin-login" && (
          <div className="auth-demo">
            <span>백엔드 없이 화면을 둘러보고 싶다면</span>
            <button type="button" onClick={onUseDemo}>
              데모로 체험하기
            </button>
          </div>
        )}
      </section>
    </main>
  );
}

function AuthBrand() {
  return (
    <div className="auth-brand">
      <span>P</span>
      <div>
        <strong>POPQ</strong>
        <small>SELLER</small>
      </div>
    </div>
  );
}

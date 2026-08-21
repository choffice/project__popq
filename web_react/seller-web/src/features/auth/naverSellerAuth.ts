const NAVER_AUTHORIZE_URL = "https://nid.naver.com/oauth2.0/authorize";
const NAVER_STATE_STORAGE_KEY = "popq.naver.seller.state";

function createState() {
  const bytes = new Uint8Array(32);
  window.crypto.getRandomValues(bytes);
  return Array.from(bytes, (value) => value.toString(16).padStart(2, "0")).join(
    "",
  );
}

export function startNaverSellerLogin() {
  const clientId = import.meta.env.VITE_NAVER_CLIENT_ID?.trim();
  const redirectUri = import.meta.env.VITE_NAVER_REDIRECT_URI?.trim();

  if (!clientId || !redirectUri) {
    throw new Error("네이버 로그인 환경변수가 설정되지 않았습니다.");
  }

  const state = createState();
  window.sessionStorage.setItem(NAVER_STATE_STORAGE_KEY, state);

  const authorizeUrl = new URL(NAVER_AUTHORIZE_URL);
  authorizeUrl.searchParams.set("response_type", "code");
  authorizeUrl.searchParams.set("client_id", clientId);
  authorizeUrl.searchParams.set("redirect_uri", redirectUri);
  authorizeUrl.searchParams.set("state", state);

  window.location.assign(authorizeUrl.toString());
}

export function consumeNaverSellerState(receivedState: string) {
  const expectedState = window.sessionStorage.getItem(
    NAVER_STATE_STORAGE_KEY,
  );
  window.sessionStorage.removeItem(NAVER_STATE_STORAGE_KEY);

  return Boolean(expectedState) && expectedState === receivedState;
}

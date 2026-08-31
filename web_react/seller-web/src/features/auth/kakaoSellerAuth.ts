const KAKAO_SDK_URL = "https://t1.kakaocdn.net/kakao_js_sdk/2.7.4/kakao.min.js";

type KakaoSdk = {
  init: (javascriptKey: string) => void;
  isInitialized: () => boolean;
  Auth: {
    authorize: (options: { redirectUri: string }) => void;
  };
};

declare global {
  interface Window {
    Kakao?: KakaoSdk;
  }
}

let kakaoSdkPromise: Promise<KakaoSdk> | null = null;

function loadKakaoSdk() {
  if (window.Kakao) {
    return Promise.resolve(window.Kakao);
  }

  if (kakaoSdkPromise) {
    return kakaoSdkPromise;
  }

  kakaoSdkPromise = new Promise<KakaoSdk>((resolve, reject) => {
    const script = document.createElement("script");
    script.src = KAKAO_SDK_URL;
    script.async = true;
    script.onload = () => {
      if (window.Kakao) {
        resolve(window.Kakao);
        return;
      }
      reject(new Error("카카오 로그인 SDK를 불러오지 못했습니다."));
    };
    script.onerror = () =>
      reject(new Error("카카오 로그인 SDK를 불러오지 못했습니다."));
    document.head.appendChild(script);
  });

  return kakaoSdkPromise;
}

export async function startKakaoSellerLogin() {
  const javascriptKey = import.meta.env.VITE_KAKAO_JAVASCRIPT_KEY?.trim();
  const redirectUri = import.meta.env.VITE_KAKAO_REDIRECT_URI?.trim();

  if (!javascriptKey || !redirectUri) {
    throw new Error("카카오 로그인 환경변수가 설정되지 않았습니다.");
  }

  const kakao = await loadKakaoSdk();
  if (!kakao.isInitialized()) {
    kakao.init(javascriptKey);
  }
  kakao.Auth.authorize({ redirectUri });
}

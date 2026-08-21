type GoogleCredentialResponse = {
  credential: string;
  select_by?: string;
};

type GoogleButtonConfiguration = {
  type: "icon";
  shape: "circle";
  theme: "outline";
  size: "large";
};

type GoogleIdentityApi = {
  accounts: {
    id: {
      initialize(config: {
        client_id: string;
        callback(response: GoogleCredentialResponse): void;
        auto_select?: boolean;
        cancel_on_tap_outside?: boolean;
      }): void;

      renderButton(
        parent: HTMLElement,
        options: GoogleButtonConfiguration,
      ): void;

      disableAutoSelect(): void;
    };
  };
};

declare global {
  interface Window {
    google?: GoogleIdentityApi;
  }
}
const GOOGLE_SCRIPT_ID = "google-identity-services";
const GOOGLE_SCRIPT_URL = "https://accounts.google.com/gsi/client";

let googleScriptPromise: Promise<void> | null = null;

let googleInitialized = false;

let googleIdTokenHandler: ((idToken: string) => void) | null = null;

function loadGoogleIdentityScript(): Promise<void> {
  if (window.google?.accounts.id) {
    return Promise.resolve();
  }

  if (googleScriptPromise) {
    return googleScriptPromise;
  }

  googleScriptPromise = new Promise<void>((resolve, reject) => {
    const existingScript = document.getElementById(
      GOOGLE_SCRIPT_ID,
    ) as HTMLScriptElement | null;

    if (existingScript) {
      existingScript.addEventListener("load", () => resolve(), { once: true });

      existingScript.addEventListener(
        "error",
        () => reject(new Error("Google 로그인 SDK를 불러오지 못했습니다.")),
        { once: true },
      );

      return;
    }

    const script = document.createElement("script");

    script.id = GOOGLE_SCRIPT_ID;
    script.src = GOOGLE_SCRIPT_URL;
    script.async = true;
    script.defer = true;

    script.addEventListener("load", () => resolve(), { once: true });

    script.addEventListener(
      "error",
      () => reject(new Error("Google 로그인 SDK를 불러오지 못했습니다.")),
      { once: true },
    );

    document.head.appendChild(script);
  });

  return googleScriptPromise;
}
export async function renderGoogleSellerButton(
  container: HTMLElement,
  onIdToken: (idToken: string) => void,
): Promise<void> {
  const clientId = import.meta.env.VITE_GOOGLE_CLIENT_ID;

  if (!clientId) {
    throw new Error("Google Client ID가 설정되지 않았습니다.");
  }

  await loadGoogleIdentityScript();

  const googleIdentity = window.google?.accounts.id;

  if (!googleIdentity) {
    throw new Error("Google 로그인 SDK를 초기화하지 못했습니다.");
  }

  googleIdTokenHandler = onIdToken;

  if (!googleInitialized) {
    googleIdentity.initialize({
      client_id: clientId,
      auto_select: false,
      cancel_on_tap_outside: true,
      callback(response) {
        if (!response.credential) {
          return;
        }

        googleIdTokenHandler?.(response.credential);
      },
    });

    googleInitialized = true;
  }

  container.replaceChildren();

  googleIdentity.renderButton(container, {
    type: "icon",
    shape: "circle",
    theme: "outline",
    size: "large",
  });
}

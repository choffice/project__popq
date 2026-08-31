import { act, cleanup, render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

const { renderGoogleSellerButtonMock } = vi.hoisted(() => ({
  renderGoogleSellerButtonMock: vi.fn().mockResolvedValue(undefined),
}));

vi.mock("./googleSellerAuth", () => ({
  renderGoogleSellerButton: renderGoogleSellerButtonMock,
}));

import { SellerAuth } from "./SellerAuth";
describe("판매자 웹 인증", () => {
  afterEach(() => {
    cleanup();
    vi.clearAllMocks();
    vi.restoreAllMocks();
    vi.unstubAllEnvs();
    window.sessionStorage.clear();
    window.history.replaceState({}, "", "/");
  });

  it("판매자 앱과 같은 회원가입 계약을 사용한다", async () => {
    const user = userEvent.setup();
    const fetchMock = vi.spyOn(window, "fetch").mockResolvedValue(
      new Response(
        JSON.stringify({
          success: true,
          data: {
            accessToken: "signup-token",
            tokenType: "Bearer",
            expiresIn: 3600,
            user: {
              userId: 8,
              email: "new-seller@popq.test",
              name: "신규 판매자",
              role: "SELLER",
              status: "ACTIVE",
            },
          },
        }),
        { status: 201, headers: { "Content-Type": "application/json" } },
      ),
    );

    render(<SellerAuth onAuthenticated={vi.fn()} onUseDemo={vi.fn()} />);
    await user.click(screen.getByRole("tab", { name: "회원가입" }));
    await user.type(screen.getByLabelText("이메일"), "new-seller@popq.test");
    await user.type(screen.getByLabelText("닉네임"), "신규 판매자");
    await user.type(screen.getByLabelText("휴대전화 번호"), "010-1234-5678");
    await user.type(screen.getByLabelText("비밀번호"), "password1");
    await user.type(screen.getByLabelText("비밀번호 확인"), "password1");
    await user.click(
      screen.getByRole("checkbox", {
        name: "개인정보 수집 및 이용에 동의합니다.",
      }),
    );
    await user.click(screen.getByRole("button", { name: "회원가입" }));

    expect(fetchMock).toHaveBeenCalledWith(
      "/api/v1/auth/signup",
      expect.objectContaining({
        method: "POST",
        body: JSON.stringify({
          email: "new-seller@popq.test",
          password: "password1",
          name: "신규 판매자",
          phone: "010-1234-5678",
          role: "SELLER",
        }),
      }),
    );
    expect(
      await screen.findByText("회원가입이 완료되었습니다. 로그인해 주세요."),
    ).toBeVisible();
  });

  it("로그인 후 계정 소유 매장을 자동 선택한다", async () => {
    const user = userEvent.setup();
    const onAuthenticated = vi.fn();
    const fetchMock = vi
      .spyOn(window, "fetch")
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            success: true,
            data: {
              accessToken: "seller-token",
              tokenType: "Bearer",
              expiresIn: 3600,
              user: {
                userId: 1,
                email: "seller@popq.test",
                name: "POPQ 판매자",
                role: "SELLER",
                status: "ACTIVE",
              },
            },
          }),
          { status: 200, headers: { "Content-Type": "application/json" } },
        ),
      )
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            success: true,
            data: [
              {
                storeId: 7,
                storeType: "LOCAL_STORE",
                name: "성수 라운지",
                description: null,
                status: "ACTIVE",
                businessStatus: "OPEN",
                myRole: "OWNER",
              },
            ],
          }),
          { status: 200, headers: { "Content-Type": "application/json" } },
        ),
      );

    render(
      <SellerAuth onAuthenticated={onAuthenticated} onUseDemo={vi.fn()} />,
    );
    await user.type(screen.getByLabelText("이메일"), "seller@popq.test");
    await user.type(screen.getByLabelText("비밀번호"), "password1");
    await user.click(screen.getByRole("button", { name: "로그인" }));

    expect(fetchMock).toHaveBeenNthCalledWith(
      1,
      "/api/v1/auth/login",
      expect.objectContaining({
        method: "POST",
        body: JSON.stringify({
          email: "seller@popq.test",
          password: "password1",
          role: "SELLER",
        }),
      }),
    );
    expect(fetchMock).toHaveBeenNthCalledWith(
      2,
      "/api/v1/seller/stores",
      expect.objectContaining({
        headers: expect.objectContaining({
          Authorization: "Bearer seller-token",
        }),
      }),
    );
    expect(onAuthenticated).toHaveBeenCalledWith(
      expect.objectContaining({
        storeId: 7,
        accessToken: "seller-token",
        storeName: "성수 라운지",
      }),
    );
  });

  it("활성·휴업 사업장이 없으면 Web에서 첫 사업장을 등록한다", async () => {
    const user = userEvent.setup();
    const onAuthenticated = vi.fn();
    const authData = {
      accessToken: "first-store-token",
      tokenType: "Bearer",
      expiresIn: 3600,
      user: {
        userId: 10,
        email: "first@popq.test",
        name: "첫 판매자",
        role: "SELLER",
        status: "ACTIVE",
      },
    };
    const createdStore = {
      storeId: 21,
      storeType: "LOCAL_STORE",
      name: "첫 카페",
      status: "ACTIVE",
      businessStatus: "PRE_OPEN",
      myRole: "OWNER",
    };
    const fetchMock = vi
      .spyOn(window, "fetch")
      .mockResolvedValueOnce(
        new Response(JSON.stringify({ success: true, data: authData }), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        }),
      )
      .mockResolvedValueOnce(
        new Response(JSON.stringify({ success: true, data: [] }), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        }),
      )
      .mockResolvedValueOnce(
        new Response(JSON.stringify({ success: true, data: [] }), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        }),
      )
      .mockResolvedValueOnce(
        new Response(JSON.stringify({ success: true, data: createdStore }), {
          status: 201,
          headers: { "Content-Type": "application/json" },
        }),
      );

    render(
      <SellerAuth onAuthenticated={onAuthenticated} onUseDemo={vi.fn()} />,
    );
    await user.type(screen.getByLabelText("이메일"), "first@popq.test");
    await user.type(screen.getByLabelText("비밀번호"), "password1");
    await user.click(screen.getByRole("button", { name: "로그인" }));

    expect(
      await screen.findByRole("heading", { name: "첫 사업장을 등록하세요" }),
    ).toBeVisible();
    await user.type(screen.getByLabelText(/사업장명/), "첫 카페");
    await user.selectOptions(screen.getByLabelText(/대표 카테고리/), "카페");
    await user.type(screen.getByLabelText(/^주소/), "서울시 성동구 성수동");
    await user.type(screen.getByLabelText(/상세 주소/), "1층");
    await user.type(screen.getByLabelText(/연락처/), "02-1234-5678");
    await user.click(
      screen.getByRole("button", { name: "사업장 등록하고 시작하기" }),
    );

    expect(fetchMock).toHaveBeenNthCalledWith(
      4,
      "/api/v1/seller/stores",
      expect.objectContaining({
        method: "POST",
        body: expect.stringContaining('"representativeCategory":"카페"'),
      }),
    );
    expect(onAuthenticated).toHaveBeenCalledWith(
      expect.objectContaining({ storeId: 21, storeName: "첫 카페" }),
    );
  });

  it("시연용 aaaa / 1 로그인은 실제 개발용 판매자 토큰과 매장을 사용한다", async () => {
    const user = userEvent.setup();
    const onAuthenticated = vi.fn();
    const fetchMock = vi
      .spyOn(window, "fetch")
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            success: true,
            data: {
              accessToken: "presentation-token",
              refreshToken: "presentation-refresh-token",
              tokenType: "Bearer",
              expiresIn: 3600,
              user: {
                userId: 1,
                email: "seller@popq.local",
                name: "POPQ 테스트 판매자",
                role: "SELLER",
                status: "ACTIVE",
              },
            },
          }),
          { status: 201, headers: { "Content-Type": "application/json" } },
        ),
      )
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            success: true,
            data: [
              {
                storeId: 1,
                storeType: "LOCAL_STORE",
                name: "POPQ 테스트 카페",
                description: null,
                status: "ACTIVE",
                businessStatus: "OPEN",
                myRole: "OWNER",
              },
            ],
          }),
          { status: 200, headers: { "Content-Type": "application/json" } },
        ),
      );

    render(
      <SellerAuth onAuthenticated={onAuthenticated} onUseDemo={vi.fn()} />,
    );
    await user.type(screen.getByLabelText("이메일"), "aaaa");
    await user.type(screen.getByLabelText("비밀번호"), "1");
    await user.click(screen.getByRole("button", { name: "로그인" }));

    expect(fetchMock).toHaveBeenNthCalledWith(
      1,
      "/api/v1/dev/auth/login",
      expect.objectContaining({
        method: "POST",
        body: JSON.stringify({
          email: "seller@popq.local",
          name: "POPQ 테스트 판매자",
          role: "SELLER",
        }),
      }),
    );
    expect(fetchMock).toHaveBeenNthCalledWith(
      2,
      "/api/v1/seller/stores",
      expect.objectContaining({
        headers: expect.objectContaining({
          Authorization: "Bearer presentation-token",
        }),
      }),
    );
    expect(onAuthenticated).toHaveBeenCalledWith(
      expect.objectContaining({
        storeId: 1,
        accessToken: "presentation-token",
        storeName: "POPQ 테스트 카페",
      }),
    );
  });

  it("Google ID Token으로 판매자 로그인한다", async () => {
    const onAuthenticated = vi.fn();

    const fetchMock = vi
      .spyOn(window, "fetch")
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            success: true,
            data: {
              accessToken: "google-seller-token",
              tokenType: "Bearer",
              expiresIn: 3600,
              user: {
                userId: 12,
                email: "google-seller@popq.test",
                name: "Google 판매자",
                role: "SELLER",
                status: "ACTIVE",
              },
            },
          }),
          {
            status: 200,
            headers: {
              "Content-Type": "application/json",
            },
          },
        ),
      )
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            success: true,
            data: [
              {
                storeId: 31,
                storeType: "LOCAL_STORE",
                name: "Google 매장",
                description: null,
                status: "ACTIVE",
                businessStatus: "OPEN",
                myRole: "OWNER",
              },
            ],
          }),
          {
            status: 200,
            headers: {
              "Content-Type": "application/json",
            },
          },
        ),
      );

    render(
      <SellerAuth onAuthenticated={onAuthenticated} onUseDemo={vi.fn()} />,
    );

    await waitFor(() => {
      expect(renderGoogleSellerButtonMock).toHaveBeenCalled();
    });

    const onIdToken = renderGoogleSellerButtonMock.mock.calls[0][1];

    await act(async () => {
      onIdToken("google-id-token");
    });

    expect(fetchMock).toHaveBeenNthCalledWith(
      1,
      "/api/v1/auth/social/login",
      expect.objectContaining({
        method: "POST",
        body: JSON.stringify({
          provider: "GOOGLE",
          providerToken: "google-id-token",
          role: "SELLER",
        }),
      }),
    );

    expect(fetchMock).toHaveBeenNthCalledWith(
      2,
      "/api/v1/seller/stores",
      expect.objectContaining({
        headers: expect.objectContaining({
          Authorization: "Bearer google-seller-token",
        }),
      }),
    );

    expect(onAuthenticated).toHaveBeenCalledWith(
      expect.objectContaining({
        storeId: 31,
        accessToken: "google-seller-token",
        storeName: "Google 매장",
      }),
    );
  });

  it("관리자 탭에서는 소셜 로그인을 표시하지 않는다", async () => {
    const user = userEvent.setup();

    render(<SellerAuth onAuthenticated={vi.fn()} onUseDemo={vi.fn()} />);

    expect(
      screen.getByRole("region", {
        name: "판매자 소셜 로그인",
      }),
    ).toBeVisible();

    await user.click(
      screen.getByRole("tab", {
        name: "관리자",
      }),
    );

    expect(
      screen.queryByRole("region", {
        name: "판매자 소셜 로그인",
      }),
    ).not.toBeInTheDocument();
  });

  it("외부 소셜 로그인에서 뒤로가면 소셜 버튼을 다시 활성화한다", async () => {
    const user = userEvent.setup();

    render(<SellerAuth onAuthenticated={vi.fn()} onUseDemo={vi.fn()} />);

    const kakaoButton = screen.getByRole("button", {
      name: "카카오로 판매자 로그인",
    });
    const naverButton = screen.getByRole("button", {
      name: "네이버로 판매자 로그인",
    });

    await user.click(kakaoButton);

    expect(kakaoButton).toBeDisabled();
    expect(naverButton).toBeDisabled();

    act(() => {
      window.dispatchEvent(new PageTransitionEvent("pageshow", {
        persisted: true,
      }));
    });

    expect(kakaoButton).toBeEnabled();
    expect(naverButton).toBeEnabled();
  });

  it("카카오 콜백 인증코드로 판매자 로그인을 완료한다", async () => {
    vi.stubEnv(
      "VITE_KAKAO_REDIRECT_URI",
      "http://localhost:5174/auth/kakao/callback",
    );
    window.history.replaceState(
      {},
      "",
      "/auth/kakao/callback?code=kakao-authorization-code",
    );

    const onAuthenticated = vi.fn();
    const fetchMock = vi
      .spyOn(window, "fetch")
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            success: true,
            data: {
              accessToken: "kakao-seller-token",
              tokenType: "Bearer",
              expiresIn: 3600,
              user: {
                userId: 41,
                email: "kakao-seller@popq.test",
                name: "카카오 판매자",
                role: "SELLER",
                status: "ACTIVE",
              },
            },
          }),
          { status: 200, headers: { "Content-Type": "application/json" } },
        ),
      )
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            success: true,
            data: [
              {
                storeId: 42,
                storeType: "LOCAL_STORE",
                name: "카카오 매장",
                description: null,
                status: "ACTIVE",
                businessStatus: "OPEN",
                myRole: "OWNER",
              },
            ],
          }),
          { status: 200, headers: { "Content-Type": "application/json" } },
        ),
      );

    render(
      <SellerAuth onAuthenticated={onAuthenticated} onUseDemo={vi.fn()} />,
    );

    await waitFor(() => {
      expect(onAuthenticated).toHaveBeenCalledWith(
        expect.objectContaining({
          storeId: 42,
          accessToken: "kakao-seller-token",
          storeName: "카카오 매장",
        }),
      );
    });

    expect(fetchMock).toHaveBeenNthCalledWith(
      1,
      "/api/v1/auth/social/kakao/code",
      expect.objectContaining({
        method: "POST",
        body: JSON.stringify({ code: "kakao-authorization-code" }),
      }),
    );
    expect(fetchMock).toHaveBeenNthCalledWith(
      2,
      "/api/v1/seller/stores",
      expect.objectContaining({
        headers: expect.objectContaining({
          Authorization: "Bearer kakao-seller-token",
        }),
      }),
    );
    expect(window.location.pathname).toBe("/");
    expect(window.location.search).toBe("");
  });

  it("일치하는 네이버 state로 판매자 로그인을 완료한다", async () => {
    vi.stubEnv(
      "VITE_NAVER_REDIRECT_URI",
      "http://localhost:5174/auth/naver/callback",
    );
    window.sessionStorage.setItem(
      "popq.naver.seller.state",
      "expected-naver-state",
    );
    window.history.replaceState(
      {},
      "",
      "/auth/naver/callback?code=naver-code&state=expected-naver-state",
    );

    const onAuthenticated = vi.fn();
    const fetchMock = vi
      .spyOn(window, "fetch")
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            success: true,
            data: {
              accessToken: "naver-seller-token",
              tokenType: "Bearer",
              expiresIn: 3600,
              user: {
                userId: 51,
                email: "naver-seller@popq.test",
                name: "네이버 판매자",
                role: "SELLER",
                status: "ACTIVE",
              },
            },
          }),
          { status: 200, headers: { "Content-Type": "application/json" } },
        ),
      )
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            success: true,
            data: [
              {
                storeId: 52,
                storeType: "LOCAL_STORE",
                name: "네이버 매장",
                description: null,
                status: "ACTIVE",
                businessStatus: "OPEN",
                myRole: "OWNER",
              },
            ],
          }),
          { status: 200, headers: { "Content-Type": "application/json" } },
        ),
      );

    render(
      <SellerAuth onAuthenticated={onAuthenticated} onUseDemo={vi.fn()} />,
    );

    await waitFor(() => {
      expect(onAuthenticated).toHaveBeenCalledWith(
        expect.objectContaining({
          storeId: 52,
          accessToken: "naver-seller-token",
          storeName: "네이버 매장",
        }),
      );
    });

    expect(fetchMock).toHaveBeenNthCalledWith(
      1,
      "/api/v1/auth/social/naver/code",
      expect.objectContaining({
        method: "POST",
        body: JSON.stringify({
          code: "naver-code",
          state: "expected-naver-state",
        }),
      }),
    );
    expect(window.sessionStorage.getItem("popq.naver.seller.state")).toBeNull();
    expect(window.location.pathname).toBe("/");
    expect(window.location.search).toBe("");
  });

  it("일치하지 않는 네이버 state는 백엔드 호출 없이 차단한다", async () => {
    vi.stubEnv(
      "VITE_NAVER_REDIRECT_URI",
      "http://localhost:5174/auth/naver/callback",
    );
    window.sessionStorage.setItem(
      "popq.naver.seller.state",
      "expected-naver-state",
    );
    window.history.replaceState(
      {},
      "",
      "/auth/naver/callback?code=naver-code&state=changed-state",
    );
    const fetchMock = vi.spyOn(window, "fetch");

    render(<SellerAuth onAuthenticated={vi.fn()} onUseDemo={vi.fn()} />);

    expect(await screen.findByRole("alert")).toHaveTextContent(
      "네이버 로그인 요청을 확인할 수 없습니다. 다시 시도해 주세요.",
    );
    expect(fetchMock).not.toHaveBeenCalled();
    expect(window.sessionStorage.getItem("popq.naver.seller.state")).toBeNull();
  });

  it("Google 소셜 로그인 실패 메시지를 표시한다", async () => {
    const fetchMock = vi.spyOn(window, "fetch").mockResolvedValueOnce(
      new Response(
        JSON.stringify({
          success: false,
          data: null,
          error: {
            code: "INVALID_SOCIAL_TOKEN",
            message: "유효하지 않은 소셜 로그인 정보입니다.",
          },
        }),
        {
          status: 401,
          headers: {
            "Content-Type": "application/json",
          },
        },
      ),
    );

    render(<SellerAuth onAuthenticated={vi.fn()} onUseDemo={vi.fn()} />);

    await waitFor(() => {
      expect(renderGoogleSellerButtonMock).toHaveBeenCalled();
    });

    const onIdToken = renderGoogleSellerButtonMock.mock.calls[0][1];

    await act(async () => {
      onIdToken("invalid-google-token");
    });

    expect(fetchMock).toHaveBeenCalledWith(
      "/api/v1/auth/social/login",
      expect.objectContaining({
        body: JSON.stringify({
          provider: "GOOGLE",
          providerToken: "invalid-google-token",
          role: "SELLER",
        }),
      }),
    );

    expect(await screen.findByRole("alert")).toHaveTextContent(
      "유효하지 않은 소셜 로그인 정보입니다.",
    );
  });

  it("Google SDK를 불러오지 못하면 오류를 표시한다", async () => {
    renderGoogleSellerButtonMock.mockRejectedValueOnce(
      new Error("Google 로그인 SDK를 불러오지 못했습니다."),
    );

    render(<SellerAuth onAuthenticated={vi.fn()} onUseDemo={vi.fn()} />);

    expect(await screen.findByRole("alert")).toHaveTextContent(
      "Google 로그인 SDK를 불러오지 못했습니다.",
    );
  });

  it("관리자 로그인은 스토어 선택 없이 관리자 세션을 만든다", async () => {
    const user = userEvent.setup();
    const onAuthenticated = vi.fn();
    const fetchMock = vi.spyOn(window, "fetch").mockResolvedValue(
      new Response(
        JSON.stringify({
          success: true,
          data: {
            accessToken: "admin-token",
            tokenType: "Bearer",
            expiresIn: 3600,
            user: {
              userId: 99,
              email: "admin@popq.test",
              name: "POPQ 관리자",
              role: "ADMIN",
              status: "ACTIVE",
            },
          },
        }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      ),
    );

    render(
      <SellerAuth onAuthenticated={onAuthenticated} onUseDemo={vi.fn()} />,
    );
    await user.click(screen.getByRole("tab", { name: "관리자" }));
    await user.type(screen.getByLabelText("이메일"), "admin@popq.test");
    await user.type(screen.getByLabelText("비밀번호"), "password1");
    await user.click(screen.getByRole("button", { name: "로그인" }));

    expect(fetchMock).toHaveBeenCalledTimes(1);
    expect(fetchMock).toHaveBeenCalledWith(
      "/api/v1/auth/login",
      expect.objectContaining({
        method: "POST",
        body: JSON.stringify({
          email: "admin@popq.test",
          password: "password1",
          role: "ADMIN",
        }),
      }),
    );
    expect(onAuthenticated).toHaveBeenCalledWith({
      storeId: null,
      accessToken: "admin-token",
      user: expect.objectContaining({ role: "ADMIN" }),
    });
  });
});

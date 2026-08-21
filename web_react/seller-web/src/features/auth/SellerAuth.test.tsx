import { cleanup, render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";
import { SellerAuth } from "./SellerAuth";

describe("판매자 웹 인증", () => {
  afterEach(() => {
    cleanup();
    vi.restoreAllMocks();
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

import {
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
} from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { AdminContentManagement } from "./AdminContentManagement";

const apiMocks = vi.hoisted(() => ({
  getAdminFaqs: vi.fn(),
  getAdminPlatformAnnouncements: vi.fn(),
  saveAdminFaq: vi.fn(),
  saveAdminPlatformAnnouncement: vi.fn(),
  updateAdminFaqStatus: vi.fn(),
  updateAdminPlatformAnnouncementStatus: vi.fn(),
}));

vi.mock("../../services/api", () => apiMocks);

const connection = { storeId: null, accessToken: "admin-token" };
const emptyPage = {
  content: [],
  page: 0,
  size: 20,
  totalElements: 0,
  totalPages: 0,
  first: true,
  last: true,
};

describe("관리자 플랫폼 공지 작성", () => {
  afterEach(cleanup);

  beforeEach(() => {
    vi.clearAllMocks();
    apiMocks.getAdminPlatformAnnouncements.mockResolvedValue(emptyPage);
    apiMocks.getAdminFaqs.mockResolvedValue(emptyPage);
    apiMocks.saveAdminPlatformAnnouncement.mockResolvedValue({
      platformAnnouncementId: 31,
    });
  });

  it("입력한 공지를 API로 저장하고 성공 상태를 안내한다", async () => {
    const user = userEvent.setup();
    render(
      <AdminContentManagement
        connection={connection}
        kind="announcements"
        onError={vi.fn()}
      />,
    );

    await screen.findByText("등록된 콘텐츠가 없습니다.");
    await user.click(screen.getByRole("button", { name: "+ 새 공지" }));
    fireEvent.change(screen.getByLabelText("제목"), {
      target: { value: "서비스 점검 안내" },
    });
    fireEvent.change(screen.getByLabelText("내용"), {
      target: { value: "새벽 시간에 점검합니다." },
    });
    fireEvent.change(screen.getByLabelText("게시 시작"), {
      target: { value: "2026-08-13T09:00" },
    });
    fireEvent.change(screen.getByLabelText("게시 종료"), {
      target: { value: "2026-08-13T10:00" },
    });
    await user.click(screen.getByRole("button", { name: "저장" }));

    await waitFor(() =>
      expect(apiMocks.saveAdminPlatformAnnouncement).toHaveBeenCalledTimes(1),
    );
    expect(apiMocks.saveAdminPlatformAnnouncement).toHaveBeenCalledWith(
      connection,
      expect.objectContaining({
        audience: "ALL",
        title: "서비스 점검 안내",
        content: "새벽 시간에 점검합니다.",
        publishStartAt: new Date("2026-08-13T09:00").toISOString(),
        publishEndAt: new Date("2026-08-13T10:00").toISOString(),
      }),
    );
    expect(await screen.findByRole("status")).toHaveTextContent(
      "공지가 초안으로 저장되었습니다.",
    );
  });

  it("종료 시각이 시작 시각보다 빠르면 모달 안에서 오류를 보여준다", async () => {
    const user = userEvent.setup();
    render(
      <AdminContentManagement
        connection={connection}
        kind="announcements"
        onError={vi.fn()}
      />,
    );

    await screen.findByText("등록된 콘텐츠가 없습니다.");
    await user.click(screen.getByRole("button", { name: "+ 새 공지" }));
    fireEvent.change(screen.getByLabelText("제목"), {
      target: { value: "기간 오류 확인" },
    });
    fireEvent.change(screen.getByLabelText("내용"), {
      target: { value: "기간을 확인합니다." },
    });
    fireEvent.change(screen.getByLabelText("게시 시작"), {
      target: { value: "2026-08-13T10:00" },
    });
    fireEvent.change(screen.getByLabelText("게시 종료"), {
      target: { value: "2026-08-13T09:00" },
    });
    await user.click(screen.getByRole("button", { name: "저장" }));

    expect(await screen.findByRole("alert")).toHaveTextContent(
      "게시 종료 시각은 시작 시각보다 뒤여야 합니다.",
    );
    expect(apiMocks.saveAdminPlatformAnnouncement).not.toHaveBeenCalled();
  });

  it("입력한 FAQ를 대상 앱과 노출 순서와 함께 저장한다", async () => {
    const user = userEvent.setup();

    apiMocks.saveAdminFaq.mockResolvedValue({
      faqId: 41,
    });

    render(
      <AdminContentManagement
        connection={connection}
        kind="faqs"
        onError={vi.fn()}
      />,
    );

    await screen.findByText("등록된 콘텐츠가 없습니다.");

    await user.click(
      screen.getByRole("button", {
        name: "+ 새 FAQ",
      }),
    );

    await user.selectOptions(screen.getByLabelText("대상 앱"), "CUSTOMER_APP");

    fireEvent.change(screen.getByLabelText("카테고리"), {
      target: {
        value: "주문",
      },
    });

    fireEvent.change(screen.getByLabelText("질문"), {
      target: {
        value: "주문은 어떻게 취소하나요?",
      },
    });

    fireEvent.change(screen.getByLabelText("답변"), {
      target: {
        value: "주문 상세 화면에서 취소할 수 있습니다.",
      },
    });

    fireEvent.change(screen.getByLabelText("노출 순서"), {
      target: {
        value: "3",
      },
    });

    await user.click(
      screen.getByRole("button", {
        name: "저장",
      }),
    );

    await waitFor(() => {
      expect(apiMocks.saveAdminFaq).toHaveBeenCalledTimes(1);
    });

    expect(apiMocks.saveAdminFaq).toHaveBeenCalledWith(connection, {
      faqId: undefined,
      audience: "CUSTOMER_APP",
      category: "주문",
      question: "주문은 어떻게 취소하나요?",
      answer: "주문 상세 화면에서 취소할 수 있습니다.",
      displayOrder: 3,
    });
  });

  it("초안 상태의 FAQ를 게시한다", async () => {
    const user = userEvent.setup();

    const faqPage = {
      content: [
        {
          faqId: 52,
          audience: "SELLER_APP",
          category: "매장",
          question: "매장 정보는 어디에서 수정하나요?",
          answer: "매장 관리 화면에서 수정할 수 있습니다.",
          displayOrder: 1,
          status: "DRAFT",
          authorName: "관리자",
          createdAt: "2026-08-18T00:00:00Z",
          updatedAt: "2026-08-18T00:00:00Z",
        },
      ],
      page: 0,
      size: 20,
      totalElements: 1,
      totalPages: 1,
      first: true,
      last: true,
    };

    apiMocks.getAdminFaqs.mockResolvedValue(faqPage);
    apiMocks.updateAdminFaqStatus.mockResolvedValue({
      ...faqPage.content[0],
      status: "PUBLISHED",
    });

    render(
      <AdminContentManagement
        connection={connection}
        kind="faqs"
        onError={vi.fn()}
      />,
    );

    await screen.findByText("매장 정보는 어디에서 수정하나요?");

    await user.click(
      screen.getByRole("button", {
        name: "게시",
      }),
    );

    await waitFor(() => {
      expect(apiMocks.updateAdminFaqStatus).toHaveBeenCalledWith(
        connection,
        52,
        "PUBLISHED",
      );
    });
  });
});

import { useCallback, useEffect, useState } from "react";
import {
  getAdminSupportTicket,
  getAdminSupportTickets,
  replyAdminSupportTicket,
  updateAdminSupportTicketStatus,
} from "../../services/api";
import type {
  PageResponse,
  SellerConnection,
  SupportCategory,
  SupportRequesterType,
  SupportTicketDetail,
  SupportTicketStatus,
  SupportTicketSummary,
} from "../../types";

import { connectAdminSupportRealtime } from "../../services/realtime";

type Props = {
  connection: SellerConnection | null;
  onError: (message: string | null) => void;
};

const statusLabel: Record<SupportTicketStatus, string> = {
  RECEIVED: "접수",
  WAITING_ADMIN: "답변 대기",
  WAITING_REQUESTER: "사용자 응답 대기",
  CLOSED: "종료",
};
const categoryLabel: Record<SupportCategory, string> = {
  ACCOUNT: "계정",
  STORE_VISIBILITY: "스토어 노출",
  ORDER_PAYMENT: "주문·결제",
  OTHER: "기타",
};

const emptyPage = (): PageResponse<SupportTicketSummary> => ({
  content: [],
  page: 0,
  size: 20,
  totalElements: 0,
  totalPages: 0,
  first: true,
  last: true,
});

export function AdminSupportManagement({ connection, onError }: Props) {
  const [tickets, setTickets] =
    useState<PageResponse<SupportTicketSummary>>(emptyPage);
  const [detail, setDetail] = useState<SupportTicketDetail | null>(null);
  const [page, setPage] = useState(0);
  const [query, setQuery] = useState("");
  const [debouncedQuery, setDebouncedQuery] = useState("");
  const [requesterType, setRequesterType] = useState<SupportRequesterType | "">(
    "",
  );
  const [category, setCategory] = useState<SupportCategory | "">("");
  const [status, setStatus] = useState<SupportTicketStatus | "">("");
  const [draft, setDraft] = useState("");
  const [loading, setLoading] = useState(true);
  const [sending, setSending] = useState(false);

  useEffect(() => {
    const timer = window.setTimeout(() => setDebouncedQuery(query.trim()), 300);
    return () => window.clearTimeout(timer);
  }, [query]);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      if (!connection) {
        setTickets(emptyPage());
        return;
      }
      const result = await getAdminSupportTickets(connection, {
        page,
        size: 20,
        query: debouncedQuery,
        requesterType: requesterType || undefined,
        category: category || undefined,
        status: status || undefined,
      });
      setTickets(result);
      if (
        detail &&
        !result.content.some(
          (item) => item.supportTicketId === detail.ticket.supportTicketId,
        )
      )
        setDetail(null);
      onError(null);
    } catch (caught) {
      onError(
        caught instanceof Error
          ? caught.message
          : "문의 목록을 불러오지 못했습니다.",
      );
    } finally {
      setLoading(false);
    }
  }, [
    category,
    connection,
    debouncedQuery,
    detail,
    onError,
    page,
    requesterType,
    status,
  ]);

  useEffect(() => {
    const timer = window.setTimeout(() => {
      void load();
    }, 0);
    return () => window.clearTimeout(timer);
  }, [load]);

  useEffect(() => {
    if (!connection) return;

    return connectAdminSupportRealtime(connection, (event) => {
      void load();

      if (detail?.ticket.supportTicketId !== event.ticketId) {
        return;
      }

      void getAdminSupportTicket(connection, event.ticketId)
        .then((result) => {
          setDetail(result);
          onError(null);
        })
        .catch((caught: unknown) => {
          onError(
            caught instanceof Error
              ? caught.message
              : "문의 상세를 새로 불러오지 못했습니다.",
          );
        });
    });
  }, [connection, detail?.ticket.supportTicketId, load, onError]);

  async function openTicket(ticketId: number) {
    if (!connection) return;
    try {
      setDetail(await getAdminSupportTicket(connection, ticketId));
      onError(null);
    } catch (caught) {
      onError(
        caught instanceof Error
          ? caught.message
          : "문의 상세를 불러오지 못했습니다.",
      );
    }
  }

  async function reply() {
    if (!connection || !detail || !draft.trim()) return;
    setSending(true);
    try {
      setDetail(
        await replyAdminSupportTicket(
          connection,
          detail.ticket.supportTicketId,
          draft.trim(),
        ),
      );
      setDraft("");
      await load();
    } catch (caught) {
      onError(
        caught instanceof Error ? caught.message : "답변을 보내지 못했습니다.",
      );
    } finally {
      setSending(false);
    }
  }

  async function changeStatus(next: SupportTicketStatus) {
    if (!connection || !detail) return;
    try {
      setDetail(
        await updateAdminSupportTicketStatus(
          connection,
          detail.ticket.supportTicketId,
          next,
        ),
      );
      await load();
    } catch (caught) {
      onError(
        caught instanceof Error
          ? caught.message
          : "문의 상태를 변경하지 못했습니다.",
      );
    }
  }

  return (
    <main className="management-page admin-support-page">
      <section className="management-hero compact-hero">
        <div>
          <p className="eyebrow">CUSTOMER SUPPORT</p>
          <h2>문의 관리</h2>
          <p>구매자와 판매자의 앱 문의를 한 곳에서 확인하고 답변합니다.</p>
        </div>
      </section>
      <section className="admin-toolbar">
        <label className="search-field">
          <span>⌕</span>
          <input
            aria-label="문의 검색"
            placeholder="제목, 이름 또는 이메일 검색"
            value={query}
            onChange={(event) => {
              setQuery(event.target.value);
              setPage(0);
            }}
          />
        </label>
        <div className="admin-filter-group">
          <select
            aria-label="요청자 유형 필터"
            value={requesterType}
            onChange={(event) => {
              setRequesterType(event.target.value as SupportRequesterType | "");
              setPage(0);
            }}
          >
            <option value="">요청자 전체</option>
            <option value="CUSTOMER">구매자</option>
            <option value="SELLER">판매자</option>
          </select>
          <select
            aria-label="문의 카테고리 필터"
            value={category}
            onChange={(event) => {
              setCategory(event.target.value as SupportCategory | "");
              setPage(0);
            }}
          >
            <option value="">카테고리 전체</option>
            {Object.entries(categoryLabel).map(([value, label]) => (
              <option key={value} value={value}>
                {label}
              </option>
            ))}
          </select>
          <select
            aria-label="문의 상태 필터"
            value={status}
            onChange={(event) => {
              setStatus(event.target.value as SupportTicketStatus | "");
              setPage(0);
            }}
          >
            <option value="">상태 전체</option>
            {Object.entries(statusLabel).map(([value, label]) => (
              <option key={value} value={value}>
                {label}
              </option>
            ))}
          </select>
        </div>
      </section>
      <section className="support-workspace">
        <aside className="support-ticket-list">
          {loading ? (
            <p>불러오는 중…</p>
          ) : (
            tickets.content.map((ticket) => (
              <button
                key={ticket.supportTicketId}
                className={
                  detail?.ticket.supportTicketId === ticket.supportTicketId
                    ? "active"
                    : ""
                }
                onClick={() => void openTicket(ticket.supportTicketId)}
              >
                <span>
                  <b>
                    {ticket.requesterType === "CUSTOMER" ? "구매자" : "판매자"}
                  </b>
                  <small>{categoryLabel[ticket.category]}</small>
                </span>
                <strong>{ticket.subject}</strong>
                <small>
                  {ticket.requesterName} ·{" "}
                  {new Date(ticket.lastMessageAt).toLocaleString("ko-KR")}
                </small>
                <i className={`admin-status ${ticket.status.toLowerCase()}`}>
                  {statusLabel[ticket.status]}
                </i>
              </button>
            ))
          )}
          {!loading && tickets.totalElements === 0 && (
            <div className="management-empty">접수된 문의가 없습니다.</div>
          )}
        </aside>
        <article className="support-detail">
          {!detail ? (
            <div className="management-empty">문의를 선택해 주세요.</div>
          ) : (
            <>
              <header>
                <div>
                  <span>
                    {detail.ticket.requesterType === "CUSTOMER"
                      ? "구매자"
                      : "판매자"}{" "}
                    · {categoryLabel[detail.ticket.category]}
                  </span>
                  <h3>{detail.ticket.subject}</h3>
                  <small>
                    {detail.ticket.requesterName} ·{" "}
                    {detail.ticket.requesterEmail ?? "이메일 없음"}
                  </small>
                </div>
                <select
                  aria-label="문의 상태 변경"
                  value={detail.ticket.status}
                  onChange={(event) =>
                    void changeStatus(event.target.value as SupportTicketStatus)
                  }
                >
                  {Object.entries(statusLabel).map(([value, label]) => (
                    <option key={value} value={value}>
                      {label}
                    </option>
                  ))}
                </select>
              </header>
              <div className="support-message-stream">
                {detail.messages.map((message) => (
                  <div
                    key={message.supportMessageId}
                    className={`support-message ${message.senderType.toLowerCase()}`}
                  >
                    <strong>{message.senderName}</strong>
                    <p>{message.content}</p>
                    <small>
                      {new Date(message.createdAt).toLocaleString("ko-KR")}
                    </small>
                  </div>
                ))}
              </div>
              <footer>
                <textarea
                  aria-label="문의 답변"
                  rows={4}
                  maxLength={4000}
                  disabled={detail.ticket.status === "CLOSED"}
                  placeholder={
                    detail.ticket.status === "CLOSED"
                      ? "종료된 문의입니다."
                      : "답변을 입력하세요."
                  }
                  value={draft}
                  onChange={(event) => setDraft(event.target.value)}
                />
                <button
                  className="primary-action"
                  disabled={
                    sending ||
                    !draft.trim() ||
                    detail.ticket.status === "CLOSED"
                  }
                  onClick={() => void reply()}
                >
                  {sending ? "전송 중…" : "답변 전송"}
                </button>
              </footer>
            </>
          )}
        </article>
      </section>
      <footer className="admin-pagination">
        <button
          disabled={tickets.first || loading}
          onClick={() => setPage((value) => Math.max(0, value - 1))}
        >
          이전
        </button>
        <span>
          {tickets.totalPages === 0 ? 0 : tickets.page + 1} /{" "}
          {tickets.totalPages} · 총{" "}
          {tickets.totalElements.toLocaleString("ko-KR")}건
        </span>
        <button
          disabled={tickets.last || loading}
          onClick={() => setPage((value) => value + 1)}
        >
          다음
        </button>
      </footer>
    </main>
  );
}

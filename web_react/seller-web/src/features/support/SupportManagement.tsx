import { useCallback, useEffect, useState } from "react";
import {
  changeAdminSupportInquiryStatus,
  getAdminSupportInquiries,
  getAdminSupportInquiry,
  sendAdminSupportAnswer,
} from "../../services/api";
import type {
  SellerConnection,
  SupportInquiryDetail,
  SupportInquiryStatus,
  SupportInquirySummary,
} from "../../types";

type Props = {
  connection: SellerConnection | null;
  onError: (message: string | null) => void;
  onUnreadChange: (count: number) => void;
};

const statusLabels: Record<SupportInquiryStatus, string> = {
  RECEIVED: "접수",
  IN_PROGRESS: "처리 중",
  ANSWERED: "답변 완료",
  CLOSED: "종료",
};

const categoryLabels: Record<string, string> = {
  ACCOUNT: "계정",
  ORDER: "주문",
  PAYMENT: "결제·환불",
  COUPON: "쿠폰",
  APP: "앱 이용",
  OTHER: "기타",
};

const statusOptions: Array<{
  value: SupportInquiryStatus | "";
  label: string;
}> = [
  { value: "", label: "전체" },
  { value: "RECEIVED", label: "접수" },
  { value: "IN_PROGRESS", label: "처리 중" },
  { value: "ANSWERED", label: "답변 완료" },
  { value: "CLOSED", label: "종료" },
];

export function SupportManagement({
  connection,
  onError,
  onUnreadChange,
}: Props) {
  const [statusFilter, setStatusFilter] = useState<SupportInquiryStatus | "">(
    "",
  );

  const [inquiries, setInquiries] = useState<SupportInquirySummary[]>([]);

  const [selectedId, setSelectedId] = useState<number | null>(null);

  const [detail, setDetail] = useState<SupportInquiryDetail | null>(null);

  const [answer, setAnswer] = useState("");
  const [loading, setLoading] = useState(true);
  const [detailLoading, setDetailLoading] = useState(false);
  const [sending, setSending] = useState(false);
  const [changingStatus, setChangingStatus] = useState(false);

  const refreshList = useCallback(async () => {
    if (!connection) {
      setInquiries([]);
      setSelectedId(null);
      onUnreadChange(0);
      return;
    }

    const list = await getAdminSupportInquiries(
      connection,
      statusFilter || undefined,
    );

    setInquiries(list);

    const unreadCount = list.reduce(
      (sum, inquiry) => sum + inquiry.unreadMessageCount,
      0,
    );

    onUnreadChange(unreadCount);

    setSelectedId((current) => {
      if (
        current !== null &&
        list.some((item) => item.supportInquiryId === current)
      ) {
        return current;
      }

      return list[0]?.supportInquiryId ?? null;
    });
  }, [connection, onUnreadChange, statusFilter]);

  useEffect(() => {
    let active = true;

    setLoading(true);

    void refreshList()
      .then(() => {
        if (active) {
          onError(null);
        }
      })
      .catch((caught: unknown) => {
        if (!active) {
          return;
        }

        onError(
          caught instanceof Error
            ? caught.message
            : "문의 목록을 불러오지 못했습니다.",
        );
      })
      .finally(() => {
        if (active) {
          setLoading(false);
        }
      });

    return () => {
      active = false;
    };
  }, [onError, refreshList]);

  useEffect(() => {
    let active = true;

    if (!connection || selectedId === null) {
      setDetail(null);
      return;
    }

    setDetailLoading(true);

    void getAdminSupportInquiry(connection, selectedId)
      .then((result) => {
        if (!active) {
          return;
        }

        setDetail(result);
        onError(null);

        void refreshList().catch(() => undefined);
      })
      .catch((caught: unknown) => {
        if (!active) {
          return;
        }

        onError(
          caught instanceof Error
            ? caught.message
            : "문의 내용을 불러오지 못했습니다.",
        );
      })
      .finally(() => {
        if (active) {
          setDetailLoading(false);
        }
      });

    return () => {
      active = false;
    };
  }, [connection, onError, refreshList, selectedId]);

  async function handleSendAnswer() {
    if (!connection || selectedId === null || !answer.trim() || sending) {
      return;
    }

    setSending(true);

    try {
      const updated = await sendAdminSupportAnswer(
        connection,
        selectedId,
        answer,
      );

      setDetail(updated);
      setAnswer("");
      await refreshList();
      onError(null);
    } catch (caught) {
      onError(
        caught instanceof Error
          ? caught.message
          : "답변을 등록하지 못했습니다.",
      );
    } finally {
      setSending(false);
    }
  }

  async function handleStatusChange(status: SupportInquiryStatus) {
    if (!connection || selectedId === null || changingStatus) {
      return;
    }

    setChangingStatus(true);

    try {
      await changeAdminSupportInquiryStatus(connection, selectedId, status);

      const updated = await getAdminSupportInquiry(connection, selectedId);

      setDetail(updated);
      await refreshList();
      onError(null);
    } catch (caught) {
      onError(
        caught instanceof Error
          ? caught.message
          : "문의 상태를 변경하지 못했습니다.",
      );
    } finally {
      setChangingStatus(false);
    }
  }

  return (
    <main className="management-page support-page">
      <section className="management-hero compact-hero">
        <div>
          <p className="eyebrow">CUSTOMER SUPPORT</p>
          <h2>고객센터 문의</h2>
          <p>고객이 앱에서 등록한 문의를 확인하고 답변합니다.</p>
        </div>
      </section>

      <section className="support-workspace">
        <aside className="support-inquiry-list">
          <header className="support-list-header">
            <div>
              <h3>문의 목록</h3>
              <small>{inquiries.length}건</small>
            </div>

            <select
              value={statusFilter}
              onChange={(event) => {
                setStatusFilter(
                  event.target.value as SupportInquiryStatus | "",
                );
              }}
              aria-label="문의 상태 필터"
            >
              {statusOptions.map((option) => (
                <option key={option.value || "ALL"} value={option.value}>
                  {option.label}
                </option>
              ))}
            </select>
          </header>

          {loading ? (
            <p className="support-empty">문의 목록을 불러오는 중입니다.</p>
          ) : inquiries.length === 0 ? (
            <p className="support-empty">해당하는 문의가 없습니다.</p>
          ) : (
            <div className="support-list-items">
              {inquiries.map((inquiry) => (
                <button
                  key={inquiry.supportInquiryId}
                  type="button"
                  className={
                    selectedId === inquiry.supportInquiryId
                      ? "support-list-item active"
                      : "support-list-item"
                  }
                  onClick={() => {
                    setSelectedId(inquiry.supportInquiryId);
                  }}
                >
                  <span className="support-list-top">
                    <strong>{inquiry.customerName}</strong>
                    <span
                      className={`support-status ${inquiry.status.toLowerCase()}`}
                    >
                      {statusLabels[inquiry.status]}
                    </span>
                  </span>

                  <span className="support-category">
                    {categoryLabels[inquiry.category] ?? inquiry.category}
                  </span>

                  <span className="support-title">{inquiry.title}</span>

                  <span className="support-list-bottom">
                    <small>{formatDate(inquiry.createdAt)}</small>

                    {inquiry.unreadMessageCount > 0 && (
                      <em>새 메시지 {inquiry.unreadMessageCount}</em>
                    )}
                  </span>
                </button>
              ))}
            </div>
          )}
        </aside>

        <section className="support-detail-panel">
          {detailLoading ? (
            <p className="support-empty">문의 내용을 불러오는 중입니다.</p>
          ) : !detail ? (
            <p className="support-empty">확인할 문의를 선택해 주세요.</p>
          ) : (
            <>
              <header className="support-detail-header">
                <div>
                  <p>{categoryLabels[detail.inquiry.category]}</p>
                  <h3>{detail.inquiry.title}</h3>
                  <span>
                    {detail.inquiry.customerName}
                    {" · "}
                    {detail.inquiry.customerEmail}
                  </span>
                </div>

                <select
                  value={detail.inquiry.status}
                  disabled={changingStatus}
                  onChange={(event) => {
                    void handleStatusChange(
                      event.target.value as SupportInquiryStatus,
                    );
                  }}
                  aria-label="문의 처리 상태"
                >
                  {statusOptions
                    .filter(
                      (
                        option,
                      ): option is {
                        value: SupportInquiryStatus;
                        label: string;
                      } => option.value !== "",
                    )
                    .map((option) => (
                      <option key={option.value} value={option.value}>
                        {option.label}
                      </option>
                    ))}
                </select>
              </header>

              <div className="support-messages">
                {detail.messages.map((message) => (
                  <article
                    key={message.supportInquiryMessageId}
                    className={
                      message.senderType === "ADMIN"
                        ? "support-message admin"
                        : "support-message customer"
                    }
                  >
                    <strong>
                      {message.senderType === "ADMIN"
                        ? "POPQ 관리자"
                        : message.senderName}
                    </strong>
                    <p>{message.content}</p>
                    <time>{formatDateTime(message.createdAt)}</time>
                  </article>
                ))}
              </div>

              {detail.inquiry.status === "CLOSED" ? (
                <p className="support-closed">종료된 문의입니다.</p>
              ) : (
                <footer className="support-answer">
                  <textarea
                    value={answer}
                    maxLength={3000}
                    placeholder="고객에게 전달할 답변을 입력하세요."
                    onChange={(event) => {
                      setAnswer(event.target.value);
                    }}
                  />

                  <div>
                    <span>{answer.length}/3000</span>
                    <button
                      type="button"
                      disabled={sending || !answer.trim()}
                      onClick={() => {
                        void handleSendAnswer();
                      }}
                    >
                      {sending ? "등록 중..." : "답변 등록"}
                    </button>
                  </div>
                </footer>
              )}
            </>
          )}
        </section>
      </section>
    </main>
  );
}

function formatDate(value: string) {
  return new Intl.DateTimeFormat("ko-KR", {
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date(value));
}

function formatDateTime(value: string) {
  return new Intl.DateTimeFormat("ko-KR", {
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
  }).format(new Date(value));
}

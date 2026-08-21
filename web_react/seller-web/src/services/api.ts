import type {
  AdminOverview,
  AdminSeller,
  AdminStore,
  AdminUser,
  Announcement,
  AnnouncementStatus,
  ApiEnvelope,
  AppAudience,
  BusinessStatus,
  ContentStatus,
  Faq,
  OrderMessage,
  OrderMessagePage,
  OrderStatus,
  PageResponse,
  PlatformAnnouncement,
  ProductDetail,
  ProductOptionGroupInput,
  QrCodeDetail,
  QrCodeSummary,
  QrIssued,
  SalesSummary,
  SellerAuthResult,
  SellerCategory,
  SellerConnection,
  SellerConversationDetail,
  SellerConversationSummary,
  SellerOrder,
  SellerPaymentSummary,
  SellerProduct,
  SellerReview,
  SellerReviewReplyTemplate,
  StoreDetail,
  StoreSavePayload,
  StoreSummary,
  StoreTable,
  StoreOptionTemplate,
  StoreOptionTemplateUsage,
  SupportCategory,
  SupportInquiryDetail,
  SupportInquiryStatus,
  SupportInquirySummary,
  SupportRequesterType,
  SupportTicketDetail,
  SupportTicketStatus,
  SupportTicketSummary,
  UserStatus,
} from "../types";

type TransitionAction = "accept" | "reject" | "prepare" | "ready" | "complete";

async function publicRequest<T>(path: string, init: RequestInit): Promise<T> {
  const response = await fetch(path, {
    ...init,
    headers: {
      "Content-Type": "application/json",
      ...init.headers,
    },
  });
  const envelope = (await response.json()) as ApiEnvelope<T>;
  if (!response.ok || !envelope.success) {
    throw new Error(envelope.error?.message ?? "요청을 처리하지 못했습니다.");
  }
  return envelope.data;
}

export function loginAccount(
  email: string,
  password: string,
  role: "SELLER" | "ADMIN",
) {
  return publicRequest<SellerAuthResult>("/api/v1/auth/login", {
    method: "POST",
    body: JSON.stringify({ email, password, role }),
  });
}

export function loginPresentationSeller() {
  return publicRequest<SellerAuthResult>("/api/v1/dev/auth/login", {
    method: "POST",
    body: JSON.stringify({
      email: "seller@popq.local",
      name: "POPQ 테스트 판매자",
      role: "SELLER",
    }),
  });
}

export function signUpSeller(payload: {
  email: string;
  password: string;
  name: string;
  phone: string;
}) {
  return publicRequest<SellerAuthResult>("/api/v1/auth/signup", {
    method: "POST",
    body: JSON.stringify({ ...payload, role: "SELLER" }),
  });
}

async function request<T>(
  path: string,
  connection: SellerConnection,
  init?: RequestInit,
): Promise<T> {
  const response = await fetch(path, {
    ...init,
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${connection.accessToken}`,
      ...init?.headers,
    },
  });
  const envelope = (await response.json()) as ApiEnvelope<T>;
  if (!response.ok || !envelope.success) {
    throw new Error(envelope.error?.message ?? "요청을 처리하지 못했습니다.");
  }
  return envelope.data;
}

function orderPath(connection: SellerConnection) {
  return `/api/v1/seller/stores/${connection.storeId}/orders`;
}

function adminPath(path: string) {
  return `/api/v1/admin${path}`;
}

export function getAdminOverview(connection: SellerConnection) {
  return request<AdminOverview>(adminPath("/overview"), connection);
}

export function getAdminUsers(connection: SellerConnection) {
  return getAdminUsersPage(connection, {}).then((page) => page.content);
}

export function getAdminSellers(connection: SellerConnection) {
  return getAdminSellersPage(connection, {}).then((page) => page.content);
}

export function getAdminStores(connection: SellerConnection) {
  return getAdminStoresPage(connection, {}).then((page) => page.content);
}

function withQuery(
  path: string,
  values: Record<string, string | number | undefined>,
) {
  const params = new URLSearchParams();
  Object.entries(values).forEach(([key, value]) => {
    if (value !== undefined && value !== "") params.set(key, String(value));
  });
  const query = params.toString();
  return query ? `${path}?${query}` : path;
}

function normalizePage<T>(value: PageResponse<T> | T[]): PageResponse<T> {
  if (!Array.isArray(value)) return value;
  return {
    content: value,
    page: 0,
    size: value.length || 20,
    totalElements: value.length,
    totalPages: value.length > 0 ? 1 : 0,
    first: true,
    last: true,
  };
}

export function getAdminUsersPage(
  connection: SellerConnection,
  filters: {
    page?: number;
    size?: number;
    query?: string;
    role?: AdminUser["role"];
    status?: UserStatus;
  },
) {
  return request<PageResponse<AdminUser> | AdminUser[]>(
    withQuery(adminPath("/users"), filters),
    connection,
  ).then(normalizePage);
}

export function getAdminSellersPage(
  connection: SellerConnection,
  filters: {
    page?: number;
    size?: number;
    query?: string;
    verificationStatus?: AdminSeller["verificationStatus"];
    userStatus?: UserStatus;
  },
) {
  return request<PageResponse<AdminSeller> | AdminSeller[]>(
    withQuery(adminPath("/sellers"), filters),
    connection,
  ).then(normalizePage);
}

export function getAdminStoresPage(
  connection: SellerConnection,
  filters: {
    page?: number;
    size?: number;
    query?: string;
    status?: AdminStore["status"];
  },
) {
  return request<PageResponse<AdminStore> | AdminStore[]>(
    withQuery(adminPath("/stores"), filters),
    connection,
  ).then(normalizePage);
}

export function updateAdminUserStatus(
  connection: SellerConnection,
  userId: number,
  status: AdminUser["status"],
  reason?: string,
) {
  return request<AdminUser>(adminPath(`/users/${userId}/status`), connection, {
    method: "PATCH",
    body: JSON.stringify({ status, reason }),
  });
}

export function updateAdminSellerVerification(
  connection: SellerConnection,
  sellerProfileId: number,
  verificationStatus: AdminSeller["verificationStatus"],
  reason?: string,
) {
  return request<AdminSeller>(
    adminPath(`/sellers/${sellerProfileId}/verification`),
    connection,
    {
      method: "PATCH",
      body: JSON.stringify({ verificationStatus, reason }),
    },
  );
}

export function updateAdminStoreStatus(
  connection: SellerConnection,
  storeId: number,
  status: AdminStore["status"],
  reason?: string,
) {
  return request<AdminStore>(
    adminPath(`/stores/${storeId}/status`),
    connection,
    {
      method: "PATCH",
      body: JSON.stringify({ status, reason }),
    },
  );
}

export function getAdminPlatformAnnouncements(
  connection: SellerConnection,
  filters: {
    page?: number;
    size?: number;
    query?: string;
    audience?: AppAudience;
    status?: ContentStatus;
  },
) {
  return request<PageResponse<PlatformAnnouncement>>(
    withQuery(adminPath("/content/announcements"), filters),
    connection,
  );
}

export function saveAdminPlatformAnnouncement(
  connection: SellerConnection,
  payload: {
    platformAnnouncementId?: number;
    audience: AppAudience;
    title: string;
    content: string;
    publishStartAt: string | null;
    publishEndAt: string | null;
  },
) {
  const path = payload.platformAnnouncementId
    ? adminPath(`/content/announcements/${payload.platformAnnouncementId}`)
    : adminPath("/content/announcements");
  return request<PlatformAnnouncement>(path, connection, {
    method: payload.platformAnnouncementId ? "PUT" : "POST",
    body: JSON.stringify(payload),
  });
}

export function updateAdminPlatformAnnouncementStatus(
  connection: SellerConnection,
  id: number,
  status: ContentStatus,
) {
  return request<PlatformAnnouncement>(
    adminPath(`/content/announcements/${id}/status`),
    connection,
    { method: "PATCH", body: JSON.stringify({ status }) },
  );
}

export function getAdminFaqs(
  connection: SellerConnection,
  filters: {
    page?: number;
    size?: number;
    query?: string;
    audience?: AppAudience;
    status?: ContentStatus;
    category?: string;
  },
) {
  return request<PageResponse<Faq>>(
    withQuery(adminPath("/content/faqs"), filters),
    connection,
  );
}

export function saveAdminFaq(
  connection: SellerConnection,
  payload: {
    faqId?: number;
    audience: AppAudience;
    category: string;
    question: string;
    answer: string;
    displayOrder: number;
  },
) {
  const path = payload.faqId
    ? adminPath(`/content/faqs/${payload.faqId}`)
    : adminPath("/content/faqs");
  return request<Faq>(path, connection, {
    method: payload.faqId ? "PUT" : "POST",
    body: JSON.stringify(payload),
  });
}

export function updateAdminFaqStatus(
  connection: SellerConnection,
  id: number,
  status: ContentStatus,
) {
  return request<Faq>(adminPath(`/content/faqs/${id}/status`), connection, {
    method: "PATCH",
    body: JSON.stringify({ status }),
  });
}

export function getAdminSupportTickets(
  connection: SellerConnection,
  filters: {
    page?: number;
    size?: number;
    query?: string;
    requesterType?: SupportRequesterType;
    category?: SupportCategory;
    status?: SupportTicketStatus;
  },
) {
  return request<PageResponse<SupportTicketSummary>>(
    withQuery(adminPath("/support/tickets"), filters),
    connection,
  );
}

export function getAdminSupportTicket(
  connection: SellerConnection,
  ticketId: number,
) {
  return request<SupportTicketDetail>(
    adminPath(`/support/tickets/${ticketId}`),
    connection,
  );
}

export function replyAdminSupportTicket(
  connection: SellerConnection,
  ticketId: number,
  content: string,
) {
  return request<SupportTicketDetail>(
    adminPath(`/support/tickets/${ticketId}/messages`),
    connection,
    { method: "POST", body: JSON.stringify({ content }) },
  );
}

export function updateAdminSupportTicketStatus(
  connection: SellerConnection,
  ticketId: number,
  status: SupportTicketStatus,
) {
  return request<SupportTicketDetail>(
    adminPath(`/support/tickets/${ticketId}/status`),
    connection,
    { method: "PATCH", body: JSON.stringify({ status }) },
  );
}

export function getAdminSupportInquiries(
  connection: SellerConnection,
  status?: SupportInquiryStatus,
) {
  const ticketStatus: SupportTicketStatus | undefined =
    status === "IN_PROGRESS"
      ? "WAITING_ADMIN"
      : status === "ANSWERED"
        ? "WAITING_REQUESTER"
        : status;

  return getAdminSupportTickets(connection, {
    page: 0,
    size: 100,
    requesterType: "CUSTOMER",
    status: ticketStatus,
  }).then((page) =>
    page.content.map((ticket): SupportInquirySummary => {
      const inquiryStatus: SupportInquiryStatus =
        ticket.status === "WAITING_ADMIN"
          ? "IN_PROGRESS"
          : ticket.status === "WAITING_REQUESTER"
            ? "ANSWERED"
            : ticket.status;

      const category = ticket.category;

      return {
        supportInquiryId: ticket.supportTicketId,
        customerUserId: ticket.requesterUserId,
        customerName: ticket.requesterName,
        customerEmail: ticket.requesterEmail ?? "",
        category,
        title: ticket.subject,
        status: inquiryStatus,
        unreadMessageCount: 0,
        answeredAt: null,
        closedAt: null,
        createdAt: ticket.createdAt,
        updatedAt: ticket.lastMessageAt,
      };
    }),
  );
}

export function getAdminSupportInquiry(
  connection: SellerConnection,
  supportInquiryId: number,
) {
  return getAdminSupportTicket(connection, supportInquiryId).then(
    (detail): SupportInquiryDetail => {
      const ticket = detail.ticket;

      const status: SupportInquiryStatus =
        ticket.status === "WAITING_ADMIN"
          ? "IN_PROGRESS"
          : ticket.status === "WAITING_REQUESTER"
            ? "ANSWERED"
            : ticket.status;

      const category = ticket.category;

      return {
        inquiry: {
          supportInquiryId: ticket.supportTicketId,
          customerUserId: ticket.requesterUserId,
          customerName: ticket.requesterName,
          customerEmail: ticket.requesterEmail ?? "",
          category,
          title: ticket.subject,
          status,
          unreadMessageCount: 0,
          answeredAt: null,
          closedAt: null,
          createdAt: ticket.createdAt,
          updatedAt: ticket.lastMessageAt,
        },
        messages: detail.messages.map((message) => ({
          supportInquiryMessageId: message.supportMessageId,
          senderUserId: message.senderUserId,
          senderName: message.senderName,
          senderType: message.senderType === "ADMIN" ? "ADMIN" : "CUSTOMER",
          content: message.content,
          read: true,
          readAt: null,
          createdAt: message.createdAt,
        })),
      };
    },
  );
}

export function sendAdminSupportAnswer(
  connection: SellerConnection,
  supportInquiryId: number,
  content: string,
) {
  return replyAdminSupportTicket(
    connection,
    supportInquiryId,
    content.trim(),
  ).then(() => getAdminSupportInquiry(connection, supportInquiryId));
}

export function changeAdminSupportInquiryStatus(
  connection: SellerConnection,
  supportInquiryId: number,
  status: SupportInquiryStatus,
) {
  const ticketStatus: SupportTicketStatus =
    status === "IN_PROGRESS"
      ? "WAITING_ADMIN"
      : status === "ANSWERED"
        ? "WAITING_REQUESTER"
        : status;

  return updateAdminSupportTicketStatus(
    connection,
    supportInquiryId,
    ticketStatus,
  )
    .then(() => getAdminSupportInquiry(connection, supportInquiryId))
    .then((detail) => detail.inquiry);
}

export function getSellerOrders(
  connection: SellerConnection,
  filter?:
    | OrderStatus
    | {
        status?: OrderStatus;
        statuses?: OrderStatus[];
        date?: string;
      },
) {
  const params = new URLSearchParams();
  if (typeof filter === "string") {
    params.set("status", filter);
  } else if (filter) {
    if (filter.status) params.set("status", filter.status);
    if (filter.statuses?.length) {
      params.set("statuses", filter.statuses.join(","));
    }
    if (filter.date) params.set("date", filter.date);
  }
  const query = params.size ? `?${params.toString()}` : "";
  return request<SellerOrder[]>(`${orderPath(connection)}${query}`, connection);
}

export function transitionSellerOrder(
  connection: SellerConnection,
  orderPublicId: string,
  action: TransitionAction,
  options?: {
    reason?: string;
    preparationMinutes?: number;
    applyAsStoreDefault?: boolean;
  },
) {
  const body =
    action === "accept"
      ? {
          preparationMinutes: options?.preparationMinutes ?? 0,
          applyAsStoreDefault: options?.applyAsStoreDefault ?? false,
          reason: options?.reason,
        }
      : { reason: options?.reason };
  return request<SellerOrder>(
    `${orderPath(connection)}/${orderPublicId}/${action}`,
    connection,
    {
      method: "POST",
      body: JSON.stringify(body),
    },
  );
}

export function getSellerPaymentSummary(
  connection: SellerConnection,
  orderPublicId: string,
) {
  return request<SellerPaymentSummary>(
    `${orderPath(connection)}/${orderPublicId}/payment`,
    connection,
  );
}

export function refundSellerOrder(
  connection: SellerConnection,
  orderPublicId: string,
  amount: number,
  reason: string,
) {
  return request<SellerPaymentSummary>(
    `${orderPath(connection)}/${orderPublicId}/refunds`,
    connection,
    {
      method: "POST",
      body: JSON.stringify({ amount, reason }),
    },
  );
}

export function syncSellerOrder(
  connection: SellerConnection,
  orderPublicId: string,
  knownVersion: number,
) {
  return request<{
    refreshRequired: boolean;
    serverVersion: number;
    order: SellerOrder | null;
  }>(
    `${orderPath(connection)}/${orderPublicId}/sync?knownVersion=${knownVersion}`,
    connection,
  );
}

function storePath(connection: SellerConnection) {
  return `/api/v1/seller/stores/${connection.storeId}`;
}

export function getSellerProducts(connection: SellerConnection) {
  return request<SellerProduct[]>(
    `${storePath(connection)}/products`,
    connection,
  );
}

export function getSellerCategories(connection: SellerConnection) {
  return request<SellerCategory[]>(
    `${storePath(connection)}/categories`,
    connection,
  );
}

export function createSellerCategory(
  connection: SellerConnection,
  name: string,
  displayOrder: number,
) {
  return request<SellerCategory>(
    `${storePath(connection)}/categories`,
    connection,
    {
      method: "POST",
      body: JSON.stringify({ name, displayOrder }),
    },
  );
}

export function createSellerProduct(
  connection: SellerConnection,
  payload: {
    categoryId: number;
    name: string;
    description: string | null;
    imageUrl: string | null;
    basePrice: number;
  },
) {
  return request<ProductDetail>(
    `${storePath(connection)}/products`,
    connection,
    {
      method: "POST",
      body: JSON.stringify(payload),
    },
  );
}

export function updateSellerProduct(
  connection: SellerConnection,
  productId: number,
  payload: {
    categoryId: number;
    name: string;
    description: string | null;
    imageUrl: string | null;
    basePrice: number;
  },
) {
  return request<ProductDetail>(
    `${storePath(connection)}/products/${productId}`,
    connection,
    {
      method: "PATCH",
      body: JSON.stringify(payload),
    },
  );
}

export function deleteSellerProduct(
  connection: SellerConnection,
  productId: number,
) {
  return request<boolean>(
    `${storePath(connection)}/products/${productId}`,
    connection,
    { method: "DELETE" },
  );
}

export async function uploadSellerProductImage(
  connection: SellerConnection,
  file: File,
) {
  const formData = new FormData();
  formData.append("file", file);

  const response = await fetch("/api/v1/seller/store-images", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${connection.accessToken}`,
    },
    body: formData,
  });
  const envelope = (await response.json()) as ApiEnvelope<{ imageUrl: string }>;
  if (!response.ok || !envelope.success) {
    throw new Error(
      envelope.error?.message ?? "이미지를 업로드하지 못했습니다.",
    );
  }
  return envelope.data.imageUrl;
}

export function getSellerProductDetail(
  connection: SellerConnection,
  productId: number,
) {
  return request<ProductDetail>(
    `${storePath(connection)}/products/${productId}`,
    connection,
  );
}

export function replaceProductOptions(
  connection: SellerConnection,
  productId: number,
  groups: ProductOptionGroupInput[],
) {
  return request<ProductDetail>(
    `${storePath(connection)}/products/${productId}/options`,
    connection,
    {
      method: "PUT",
      body: JSON.stringify({ groups }),
    },
  );
}

export function getStoreOptionTemplates(connection: SellerConnection) {
  return request<StoreOptionTemplate[]>(
    `${storePath(connection)}/option-group-templates`,
    connection,
  );
}

export function updateSellerCategory(
  connection: SellerConnection,
  categoryId: number,
  name: string,
  displayOrder: number,
) {
  return request<SellerCategory>(
    `${storePath(connection)}/categories/${categoryId}`,
    connection,
    {
      method: "PATCH",
      body: JSON.stringify({ name, displayOrder }),
    },
  );
}

export function deleteSellerCategory(
  connection: SellerConnection,
  categoryId: number,
) {
  return request<boolean>(
    `${storePath(connection)}/categories/${categoryId}`,
    connection,
    { method: "DELETE" },
  );
}

export function createStoreOptionTemplate(
  connection: SellerConnection,
  group: ProductOptionGroupInput,
) {
  return request<StoreOptionTemplate>(
    `${storePath(connection)}/option-group-templates`,
    connection,
    {
      method: "POST",
      body: JSON.stringify({
        name: group.name,
        minSelect: group.minSelect,
        maxSelect: group.maxSelect,
        required: group.required,
        options: group.options,
      }),
    },
  );
}

export function getStoreOptionTemplateUsage(
  connection: SellerConnection,
  templateId: number,
) {
  return request<StoreOptionTemplateUsage>(
    `${storePath(connection)}/option-group-templates/${templateId}/products`,
    connection,
  );
}

export function applyStoreOptionTemplateToAll(
  connection: SellerConnection,
  templateId: number,
  sourceProductId: number,
  sourceOptionGroupId: number,
  group: ProductOptionGroupInput,
) {
  return request<StoreOptionTemplate>(
    `${storePath(connection)}/option-group-templates/${templateId}/apply`,
    connection,
    {
      method: "POST",
      body: JSON.stringify({
        sourceProductId,
        sourceOptionGroupId,
        name: group.name,
        minSelect: group.minSelect,
        maxSelect: group.maxSelect,
        required: group.required,
        options: group.options,
      }),
    },
  );
}

export function deleteStoreOptionTemplate(
  connection: SellerConnection,
  templateId: number,
) {
  return request<boolean>(
    `${storePath(connection)}/option-group-templates/${templateId}`,
    connection,
    { method: "DELETE" },
  );
}

export function updateProductAvailability(
  connection: SellerConnection,
  product: SellerProduct,
  changes: Partial<
    Pick<
      SellerProduct,
      | "soldOut"
      | "salesStartAt"
      | "salesEndAt"
      | "qrWebEnabled"
      | "customerAppEnabled"
    >
  >,
) {
  return request<ProductDetail>(
    `${storePath(connection)}/products/${product.productId}/availability`,
    connection,
    {
      method: "PATCH",
      body: JSON.stringify({
        soldOut: changes.soldOut ?? product.soldOut,
        salesStartAt: changes.salesStartAt ?? product.salesStartAt,
        salesEndAt: changes.salesEndAt ?? product.salesEndAt,
        qrWebEnabled: changes.qrWebEnabled ?? product.qrWebEnabled,
        customerAppEnabled:
          changes.customerAppEnabled ?? product.customerAppEnabled,
      }),
    },
  );
}

export function getStoreTables(connection: SellerConnection) {
  return request<StoreTable[]>(`${storePath(connection)}/tables`, connection);
}

export function getQrCodes(
  connection: SellerConnection,
  includeArchived = false,
) {
  const query = includeArchived ? "?includeArchived=true" : "";
  return request<QrCodeSummary[]>(
    `${storePath(connection)}/qr-codes${query}`,
    connection,
  );
}

export function getQrCodeDetail(
  connection: SellerConnection,
  qrCodeId: number,
) {
  return request<QrCodeDetail>(
    `${storePath(connection)}/qr-codes/${qrCodeId}`,
    connection,
  );
}

export function issueQrCode(
  connection: SellerConnection,
  storeTableId: number | null,
  expiresAt: string | null,
) {
  return request<QrIssued>(`${storePath(connection)}/qr-codes`, connection, {
    method: "POST",
    body: JSON.stringify({ storeTableId, expiresAt }),
  });
}

export function changeQrStatus(
  connection: SellerConnection,
  qrCodeId: number,
  action: "activate" | "deactivate" | "revoke",
) {
  return request<QrCodeSummary>(
    `${storePath(connection)}/qr-codes/${qrCodeId}/${action}`,
    connection,
    { method: "POST" },
  );
}

export function reissueQrCode(
  connection: SellerConnection,
  qrCodeId: number,
  expiresAt: string | null,
) {
  return request<QrIssued>(
    `${storePath(connection)}/qr-codes/${qrCodeId}/reissue`,
    connection,
    {
      method: "POST",
      body: JSON.stringify({ expiresAt }),
    },
  );
}

export function archiveQrCode(connection: SellerConnection, qrCodeId: number) {
  return request<QrCodeSummary>(
    `${storePath(connection)}/qr-codes/${qrCodeId}/archive`,
    connection,
    { method: "POST" },
  );
}

export function restoreQrCode(connection: SellerConnection, qrCodeId: number) {
  return request<QrCodeSummary>(
    `${storePath(connection)}/qr-codes/${qrCodeId}/restore`,
    connection,
    { method: "POST" },
  );
}

export function getSalesSummary(
  connection: SellerConnection,
  from: string,
  to: string,
) {
  const query = new URLSearchParams({ from, to });
  return request<SalesSummary>(
    `${storePath(connection)}/analytics/sales?${query.toString()}`,
    connection,
  );
}

export function getSellerStores(connection: SellerConnection) {
  return request<StoreSummary[]>("/api/v1/seller/stores", connection);
}

export function getInactiveSellerStores(connection: SellerConnection) {
  return request<StoreSummary[]>("/api/v1/seller/stores/inactive", connection);
}

export function getSellerStoreDetail(connection: SellerConnection) {
  return request<StoreDetail>(storePath(connection), connection);
}

export function createSellerStore(
  connection: SellerConnection,
  payload: StoreSavePayload,
) {
  return request<StoreSummary>("/api/v1/seller/stores", connection, {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export function updateSellerStore(
  connection: SellerConnection,
  payload: StoreSavePayload,
) {
  return request<StoreDetail>(storePath(connection), connection, {
    method: "PATCH",
    body: JSON.stringify(payload),
  });
}

export function deleteSellerStore(connection: SellerConnection) {
  return request<boolean>(storePath(connection), connection, {
    method: "DELETE",
  });
}

export function suspendSellerStore(connection: SellerConnection) {
  return request<StoreSummary>(`${storePath(connection)}/suspend`, connection, {
    method: "POST",
  });
}

export function reopenSellerStore(
  connection: SellerConnection,
  storeId: number,
) {
  return request<StoreSummary>(
    `/api/v1/seller/stores/${storeId}/reopen`,
    connection,
    { method: "POST" },
  );
}

export function changeStoreBusinessStatus(
  connection: SellerConnection,
  businessStatus: BusinessStatus,
) {
  return request<StoreSummary>(
    `${storePath(connection)}/business-status`,
    connection,
    {
      method: "PATCH",
      body: JSON.stringify({ businessStatus }),
    },
  );
}

export function createStoreTable(
  connection: SellerConnection,
  tableCode: string,
  name: string,
) {
  return request<StoreTable>(`${storePath(connection)}/tables`, connection, {
    method: "POST",
    body: JSON.stringify({ tableCode, name }),
  });
}

export function getSellerAnnouncements(connection: SellerConnection) {
  return request<Announcement[]>(
    `${storePath(connection)}/announcements`,
    connection,
  );
}

export function createSellerAnnouncement(
  connection: SellerConnection,
  title: string,
  content: string,
  notifyInterestedCustomers: boolean,
) {
  return request<Announcement>(
    `${storePath(connection)}/announcements`,
    connection,
    {
      method: "POST",
      body: JSON.stringify({ title, content, notifyInterestedCustomers }),
    },
  );
}

export function updateSellerAnnouncement(
  connection: SellerConnection,
  announcementId: number,
  title: string,
  content: string,
  notifyInterestedCustomers: boolean,
) {
  return request<Announcement>(
    `${storePath(connection)}/announcements/${announcementId}`,
    connection,
    {
      method: "PATCH",
      body: JSON.stringify({ title, content, notifyInterestedCustomers }),
    },
  );
}

export function changeSellerAnnouncementStatus(
  connection: SellerConnection,
  announcementId: number,
  status: AnnouncementStatus,
) {
  return request<Announcement>(
    `${storePath(connection)}/announcements/${announcementId}/status`,
    connection,
    {
      method: "PATCH",
      body: JSON.stringify({ status }),
    },
  );
}

export function getSellerConversations(connection: SellerConnection) {
  return request<SellerConversationSummary[]>(
    `${storePath(connection)}/conversations`,
    connection,
  );
}

export function getSellerUnreadConversationCount(connection: SellerConnection) {
  return request<number>(
    `${storePath(connection)}/conversations/unread-count`,
    connection,
  );
}

export function getSellerConversation(
  connection: SellerConnection,
  orderPublicId: string,
) {
  return request<SellerConversationDetail>(
    `${storePath(connection)}/orders/${orderPublicId}/messages`,
    connection,
  );
}

export function getSellerOrderMessages(
  connection: SellerConnection,
  orderPublicId: string,
  beforeMessageId?: number,
  size = 30,
) {
  const query = new URLSearchParams({ size: String(size) });
  if (beforeMessageId) query.set("beforeMessageId", String(beforeMessageId));
  return request<OrderMessagePage>(
    `${storePath(connection)}/orders/${orderPublicId}/messages/page?${query.toString()}`,
    connection,
  );
}

export function sendSellerOrderMessage(
  connection: SellerConnection,
  orderPublicId: string,
  content: string,
  clientMessageId: string,
) {
  return request<OrderMessage>(
    `${storePath(connection)}/orders/${orderPublicId}/messages`,
    connection,
    {
      method: "POST",
      body: JSON.stringify({ content, clientMessageId }),
    },
  );
}

export function getSellerReviews(
  connection: SellerConnection,
  filters?: { rating?: number; unanswered?: boolean },
) {
  const query = new URLSearchParams();
  if (filters?.rating) query.set("rating", String(filters.rating));
  if (filters?.unanswered) query.set("unanswered", "true");
  const suffix = query.size > 0 ? `?${query.toString()}` : "";
  return request<SellerReview[]>(
    `${storePath(connection)}/reviews${suffix}`,
    connection,
  );
}

export function replySellerReview(
  connection: SellerConnection,
  reviewId: number,
  reply: string,
) {
  return request<SellerReview>(
    `${storePath(connection)}/reviews/${reviewId}/reply`,
    connection,
    { method: "PUT", body: JSON.stringify({ reply }) },
  );
}

export function deleteSellerReviewReply(
  connection: SellerConnection,
  reviewId: number,
) {
  return request<SellerReview>(
    `${storePath(connection)}/reviews/${reviewId}/reply`,
    connection,
    { method: "DELETE" },
  );
}

export function getSellerReviewReplyTemplates(connection: SellerConnection) {
  return request<SellerReviewReplyTemplate[]>(
    `${storePath(connection)}/reviews/reply-templates`,
    connection,
  );
}

export function createSellerReviewReplyTemplate(
  connection: SellerConnection,
  content: string,
) {
  return request<SellerReviewReplyTemplate>(
    `${storePath(connection)}/reviews/reply-templates`,
    connection,
    { method: "POST", body: JSON.stringify({ content }) },
  );
}

export function updateSellerReviewReplyTemplate(
  connection: SellerConnection,
  templateId: number,
  content: string,
) {
  return request<SellerReviewReplyTemplate>(
    `${storePath(connection)}/reviews/reply-templates/${templateId}`,
    connection,
    { method: "PATCH", body: JSON.stringify({ content }) },
  );
}

export function deleteSellerReviewReplyTemplate(
  connection: SellerConnection,
  templateId: number,
) {
  return request<null>(
    `${storePath(connection)}/reviews/reply-templates/${templateId}`,
    connection,
    { method: "DELETE" },
  );
}

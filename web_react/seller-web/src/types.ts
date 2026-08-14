export type OrderStatus =
  | "CREATED"
  | "PLACED"
  | "ACCEPTED"
  | "PREPARING"
  | "READY"
  | "COMPLETED"
  | "CANCELED"
  | "REJECTED"
  | "EXPIRED";

export type OrderType = "DINE_IN" | "TAKEOUT";

export type OrderItemOption = {
  productOptionId: number;
  optionGroupName: string;
  optionName: string;
  optionPrice: number;
};

export type OrderItem = {
  orderItemId: number;
  productId: number;
  productName: string;
  productImageUrl: string | null;
  unitPrice: number;
  quantity: number;
  itemTotalPrice: number;
  options: OrderItemOption[];
};

export type OrderStatusHistory = {
  previousStatus: OrderStatus | null;
  currentStatus: OrderStatus;
  actorType: string;
  actorId: number | null;
  reason: string | null;
  changedAt: string;
};

export type SellerOrder = {
  orderPublicId: string;
  storeId: number;
  storeName: string;
  orderType: OrderType;
  status: OrderStatus;
  subtotalAmount: number;
  discountAmount: number;
  taxAmount: number;
  serviceFeeAmount: number;
  totalAmount: number;
  expiresAt: string;
  createdAt?: string;
  acceptedAt?: string | null;
  preparationMinutes?: number | null;
  estimatedReadyAt?: string | null;
  version: number;
  items: OrderItem[];
  statusHistory: OrderStatusHistory[];
};

export type PaymentStatus =
  | "READY"
  | "IN_PROGRESS"
  | "PAID"
  | "FAILED"
  | "CANCELED"
  | "PARTIALLY_REFUNDED"
  | "REFUNDED";

export type RefundStatus = "REQUESTED" | "PROCESSING" | "SUCCEEDED" | "FAILED";

export type SellerPaymentSummary = {
  orderPublicId: string;
  paymentStatus: PaymentStatus;
  paymentMethod: string;
  approvedAmount: number;
  refundedAmount: number;
  refundableAmount: number;
  refunds: {
    refundId: number;
    amount: number;
    reason: string;
    requesterType: "GUEST" | "SELLER" | "ADMIN";
    status: RefundStatus;
    requestedAt: string;
    completedAt: string | null;
    failureCode: string | null;
    failureMessage: string | null;
  }[];
};

export type OrderRealtimeEvent = {
  eventId: string;
  eventType: string;
  orderPublicId: string;
  storeId: number;
  previousStatus: OrderStatus;
  currentStatus: OrderStatus;
  occurredAt: string;
  version: number;
};

export type ApiEnvelope<T> = {
  success: boolean;
  data: T;
  error?: {
    code: string;
    message: string;
  };
};

export type SellerAuthUser = {
  userId: number;
  email: string;
  name: string;
  role: "CUSTOMER" | "SELLER" | "ADMIN";
  status: "ACTIVE" | "SUSPENDED" | "WITHDRAWN";
};

export type SellerAuthResult = {
  accessToken: string;
  tokenType: string;
  expiresIn: number;
  user: SellerAuthUser;
};

export type SellerConnection = {
  storeId: number | null;
  accessToken: string;
  storeName?: string;
  storeRole?: StoreRole;
  user?: SellerAuthUser;
};

export type SellerProduct = {
  productId: number;
  categoryId: number;
  categoryName: string;
  name: string;
  description: string | null;
  imageUrl: string | null;
  basePrice: number;
  status: "ACTIVE" | "INACTIVE";
  soldOut: boolean;
  availableForQr: boolean;
  salesStartAt: string | null;
  salesEndAt: string | null;
  qrWebEnabled: boolean;
  customerAppEnabled: boolean;
};

export type SellerCategory = {
  categoryId: number;
  name: string;
  displayOrder: number;
  status: "ACTIVE" | "INACTIVE";
};

export type ProductOption = {
  optionId: number;
  name: string;
  additionalPrice: number;
  displayOrder: number;
};

export type ProductOptionGroup = {
  optionGroupId: number;
  name: string;
  minSelect: number;
  maxSelect: number;
  required: boolean;
  displayOrder: number;
  options: ProductOption[];
};

export type ProductOptionGroupInput = {
  name: string;
  minSelect: number;
  maxSelect: number;
  required: boolean;
  displayOrder: number;
  options: {
    name: string;
    additionalPrice: number;
    displayOrder: number;
  }[];
};

export type ProductDetail = {
  product: SellerProduct;
  availability: {
    soldOut: boolean;
    salesStartAt: string | null;
    salesEndAt: string | null;
    qrWebEnabled: boolean;
    customerAppEnabled: boolean;
  };
  optionGroups: ProductOptionGroup[];
};

export type StoreTable = {
  storeTableId: number;
  tableCode: string;
  name: string;
  status: "ACTIVE" | "INACTIVE";
};

export type QrCodeStatus = "ACTIVE" | "INACTIVE" | "REVOKED" | "EXPIRED";

export type QrCodeSummary = {
  qrCodeId: number;
  storeTableId: number | null;
  tableName: string | null;
  status: QrCodeStatus;
  expiresAt: string | null;
  createdAt: string;
  recoverable: boolean;
  archived: boolean;
};

export type QrIssued = {
  qrCodeId: number;
  storeId: number;
  storeTableId: number | null;
  token: string;
  publicUrl: string;
  status: QrCodeStatus;
  expiresAt: string | null;
};

export type QrCodeDetail = {
  qrCodeId: number;
  storeId: number;
  storeTableId: number | null;
  tableName: string | null;
  status: QrCodeStatus;
  expiresAt: string | null;
  createdAt: string;
  publicUrl: string;
};

export type SalesSummary = {
  from: string;
  to: string;
  grossSales: number;
  netSales: number;
  refundedAmount: number;
  refundCount: number;
  canceledOrderCount: number;
  canceledAmount: number;
  completedOrderCount: number;
  averageOrderAmount: number;
  dineInSales: number;
  takeoutSales: number;
  dailySales: {
    date: string;
    sales: number;
    orderCount: number;
  }[];
  topProducts: {
    productName: string;
    quantity: number;
    sales: number;
  }[];
  orderHistory: {
    orderPublicId: string;
    orderType: OrderType;
    approvedAmount: number;
    refundedAmount: number;
    netSales: number;
    completedAt: string;
    itemCount: number;
    itemSummary: string;
  }[];
  refundHistory: {
    refundId: number;
    orderPublicId: string;
    amount: number;
    reason: string;
    requesterType:
      | "GUEST"
      | "CUSTOMER"
      | "SELLER"
      | "ADMIN"
      | "SYSTEM"
      | "UNKNOWN";
    completedAt: string | null;
  }[];
  cancellationHistory: {
    orderPublicId: string;
    status: "CANCELED" | "REJECTED";
    amount: number;
    reason: string | null;
    canceledAt: string;
  }[];
};

export type BusinessStatus = "PRE_OPEN" | "OPEN" | "CLOSED";

export type StoreRole = "OWNER" | "MANAGER" | "STAFF";
export type StoreType = "LOCAL_STORE" | "EVENT_COMMERCE";
export type StoreStatus = "ACTIVE" | "SUSPENDED" | "CLOSED";
export type StoreClosedDay =
  | "MONDAY"
  | "TUESDAY"
  | "WEDNESDAY"
  | "THURSDAY"
  | "FRIDAY"
  | "SATURDAY"
  | "SUNDAY";

export type StoreSummary = {
  storeId: number;
  storeType: StoreType;
  name: string;
  description: string | null;
  address: string | null;
  detailAddress: string | null;
  representativeCategory: string | null;
  imageUrl: string | null;
  phone: string | null;
  latitude: number | null;
  longitude: number | null;
  openTime: string | null;
  closeTime: string | null;
  operationStartDate?: string | null;
  operationEndDate?: string | null;
  closedDays: StoreClosedDay[];
  takeoutAvailable: boolean;
  dineInAvailable: boolean;
  orderAcceptingEnabled: boolean;
  defaultPreparationMinutes?: number | null;
  status: StoreStatus;
  businessStatus: BusinessStatus;
  myRole: StoreRole;
};

export type StoreDetail = StoreSummary & {
  tags: string[];
};

export type StoreSavePayload = {
  storeType: StoreType;
  name: string;
  description: string | null;
  address: string | null;
  detailAddress: string | null;
  representativeCategory: string | null;
  imageUrl: string | null;
  phone: string | null;
  latitude: number | null;
  longitude: number | null;
  openTime: string | null;
  closeTime: string | null;
  operationStartDate: string | null;
  operationEndDate: string | null;
  closedDays: StoreClosedDay[];
  takeoutAvailable: boolean;
  dineInAvailable: boolean;
  orderAcceptingEnabled: boolean;
  tags: string[];
};

export type AnnouncementStatus = "DRAFT" | "PUBLISHED" | "HIDDEN";

export type Announcement = {
  announcementId: number;
  storeId: number;
  title: string;
  content: string;
  status: AnnouncementStatus;
  publishedAt: string | null;
  createdAt: string;
  updatedAt: string;
};

export type SellerReview = {
  reviewId: number;
  orderPublicId: string;
  storeId: number;
  storeName: string;
  storeCategory: string | null;
  authorName: string;
  rating: number;
  content: string | null;
  status: string;
  createdAt: string;
  updatedAt: string;
  sellerReply: string | null;
  sellerRepliedAt: string | null;
  sellerRepliedByUserId: number | null;
};

export type SellerReviewReplyTemplate = {
  templateId: number;
  content: string;
};

export type MessageSenderType = "CUSTOMER" | "SELLER";

export type OrderMessage = {
  orderMessageId: number;
  senderUserId: number;
  senderName: string;
  senderType: MessageSenderType;
  clientMessageId: string | null;
  content: string;
  read: boolean;
  readAt: string | null;
  createdAt: string;
};

export type SellerConversationSummary = {
  orderPublicId: string;
  customerUserId: number | null;
  customerName: string;
  orderStatus: OrderStatus;
  lastMessage: string;
  lastMessageSenderType: MessageSenderType;
  lastMessageAt: string;
  unreadCount: number;
};

export type SellerConversationDetail = {
  orderPublicId: string;
  storeId: number;
  storeName: string;
  customerUserId: number | null;
  customerName: string;
  orderType: OrderType;
  orderStatus: OrderStatus;
  totalAmount: number;
  orderedAt: string;
  orderItems: {
    orderItemId: number;
    productName: string;
    quantity: number;
    itemTotalPrice: number;
  }[];
  messages: OrderMessage[];
};

export type OrderMessagePage = {
  messages: OrderMessage[];
  hasMore: boolean;
  nextBeforeMessageId: number | null;
};

export type OrderChatEvent = {
  eventId: string;
  eventType: "MESSAGE_CREATED" | "MESSAGE_READ";
  orderPublicId: string;
  storeId: number;
  customerUserId: number | null;
  message: OrderMessage | null;
  readMessageIds: number[];
  readerType: MessageSenderType | null;
  occurredAt: string;
};

export type AdminOverview = {
  totalUsers: number;
  activeUsers: number;
  sellerProfiles: number;
  pendingSellers: number;
  totalStores: number;
  activeStores: number;
  suspendedStores: number;
};

export type PageResponse<T> = {
  content: T[];
  page: number;
  size: number;
  totalElements: number;
  totalPages: number;
  first: boolean;
  last: boolean;
};

export type UserStatus =
  | "ACTIVE"
  | "SUSPENDED"
  | "WITHDRAWAL_PENDING"
  | "WITHDRAWN";

export type AdminUser = {
  userId: number;
  email: string;
  name: string;
  role: "CUSTOMER" | "SELLER" | "ADMIN";
  roles: ("CUSTOMER" | "SELLER" | "ADMIN")[];
  status: UserStatus;
  createdAt: string;
};

export type AdminSeller = {
  sellerProfileId: number;
  userId: number;
  email: string;
  name: string;
  businessName: string | null;
  businessRegistrationNumber: string | null;
  verificationStatus: "PENDING" | "VERIFIED" | "REJECTED";
  userStatus: UserStatus;
  createdAt: string;
};

export type AdminStore = {
  storeId: number;
  storeType: "LOCAL_STORE" | "EVENT_COMMERCE";
  name: string;
  status: "ACTIVE" | "SUSPENDED" | "CLOSED";
  businessStatus: BusinessStatus;
  createdAt: string;
};

export type AppAudience = "ALL" | "CUSTOMER_APP" | "SELLER_APP";
export type ContentStatus = "DRAFT" | "PUBLISHED" | "HIDDEN";

export type PlatformAnnouncement = {
  platformAnnouncementId: number;
  audience: AppAudience;
  title: string;
  content: string;
  status: ContentStatus;
  publishStartAt: string | null;
  publishEndAt: string | null;
  authorName: string;
  createdAt: string;
  updatedAt: string;
};

export type Faq = {
  faqId: number;
  audience: AppAudience;
  category: string;
  question: string;
  answer: string;
  displayOrder: number;
  status: ContentStatus;
  authorName: string;
  createdAt: string;
  updatedAt: string;
};

export type SupportRequesterType = "CUSTOMER" | "SELLER";
export type SupportCategory =
  | "ACCOUNT"
  | "STORE_VISIBILITY"
  | "ORDER_PAYMENT"
  | "OTHER";
export type SupportTicketStatus =
  | "RECEIVED"
  | "WAITING_ADMIN"
  | "WAITING_REQUESTER"
  | "CLOSED";

export type SupportTicketRealtimeEventType =
  | "TICKET_CREATED"
  | "MESSAGE_ADDED"
  | "STATUS_CHANGED";

export type SupportTicketRealtimeEvent = {
  eventId: string;
  eventType: SupportTicketRealtimeEventType;
  ticketId: number;
  requesterUserId: number;
  requesterType: SupportRequesterType;
  senderType: "REQUESTER" | "ADMIN";
  status: SupportTicketStatus;
  occurredAt: string;
};

export type SupportTicketSummary = {
  supportTicketId: number;
  requesterUserId: number;
  requesterName: string;
  requesterEmail: string | null;
  requesterType: SupportRequesterType;
  category: SupportCategory;
  subject: string;
  status: SupportTicketStatus;
  lastMessageAt: string;
  createdAt: string;
};

export type SupportMessage = {
  supportMessageId: number;
  senderUserId: number;
  senderName: string;
  senderType: "REQUESTER" | "ADMIN";
  content: string;
  createdAt: string;
};

export type SupportTicketDetail = {
  ticket: SupportTicketSummary;
  messages: SupportMessage[];
};

export type SupportInquiryCategory =
  | 'ACCOUNT'
  | 'ORDER'
  | 'PAYMENT'
  | 'COUPON'
  | 'APP'
  | 'OTHER'

export type SupportInquiryStatus =
  | 'RECEIVED'
  | 'IN_PROGRESS'
  | 'ANSWERED'
  | 'CLOSED'

export type SupportInquirySummary = {
  supportInquiryId: number
  customerUserId: number
  customerName: string
  customerEmail: string
  category: SupportInquiryCategory
  title: string
  status: SupportInquiryStatus
  unreadMessageCount: number
  answeredAt: string | null
  closedAt: string | null
  createdAt: string
  updatedAt: string
}

export type SupportInquiryMessage = {
  supportInquiryMessageId: number
  senderUserId: number
  senderName: string
  senderType: 'CUSTOMER' | 'ADMIN'
  content: string
  read: boolean
  readAt: string | null
  createdAt: string
}

export type SupportInquiryDetail = {
  inquiry: SupportInquirySummary
  messages: SupportInquiryMessage[]
}

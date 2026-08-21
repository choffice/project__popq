import { useEffect, useMemo, useState } from "react";
import { demoStore, freshDemoTables } from "../../data/demo";
import {
  changeStoreBusinessStatus,
  createSellerStore,
  createStoreTable,
  deleteSellerStore,
  getInactiveSellerStores,
  getSellerStoreDetail,
  getSellerStores,
  getStoreTables,
  reopenSellerStore,
  suspendSellerStore,
  updateSellerStore,
} from "../../services/api";
import type {
  BusinessStatus,
  SellerConnection,
  StoreDetail,
  StoreSchedule,
  StoreSavePayload,
  StoreSummary,
  StoreTable,
  StoreType,
} from "../../types";
import {
  BusinessScheduleEditor,
  createDefaultSchedule,
  legacyFieldsFromSchedule,
  scheduleForApi,
  scheduleFromStore,
  scheduleSummary,
  scheduleValidationMessage,
} from "./BusinessScheduleEditor";

type StoreConfirmAction = "suspend" | "delete" | null;

type Props = {
  connection: SellerConnection | null;
  onError: (message: string | null) => void;
  onBusinessStatusChange: (status: BusinessStatus) => void;
  onStoreSelected?: (store: StoreSummary) => void;
  onStoreUpdated?: (store: StoreSummary) => void;
  onStoreDeleted?: (remainingStores: StoreSummary[]) => void;
};

type EditorState = {
  storeType: StoreType;
  name: string;
  description: string;
  address: string;
  detailAddress: string;
  representativeCategory: string;
  imageUrl: string;
  phone: string;
  latitude: string;
  longitude: string;
  operationStartDate: string;
  operationEndDate: string;
  schedule: StoreSchedule;
  takeoutAvailable: boolean;
  dineInAvailable: boolean;
  orderAcceptingEnabled: boolean;
  tags: string;
};

const STORE_CATEGORIES = [
  "카페",
  "디저트",
  "베이커리",
  "한식",
  "중식",
  "일식",
  "양식",
  "분식",
  "치킨",
  "피자",
  "패스트푸드",
  "주점",
  "푸드트럭",
  "팝업·행사",
  "플리마켓·행사",
  "기타",
];

const PHONE_PATTERN = /^[0-9+\-()\s]+$/;

const STATUS_LABEL: Record<BusinessStatus, string> = {
  PRE_OPEN: "준비중",
  OPEN: "영업 중",
  CLOSED: "운영 종료",
};

function blankEditor(): EditorState {
  return {
    storeType: "LOCAL_STORE",
    name: "",
    description: "",
    address: "",
    detailAddress: "",
    representativeCategory: "",
    imageUrl: "",
    phone: "",
    latitude: "",
    longitude: "",
    operationStartDate: "",
    operationEndDate: "",
    schedule: createDefaultSchedule(),
    takeoutAvailable: true,
    dineInAvailable: true,
    orderAcceptingEnabled: true,
    tags: "",
  };
}

function editorFromStore(store: StoreDetail): EditorState {
  return {
    storeType: store.storeType,
    name: store.name,
    description: store.description ?? "",
    address: store.address ?? "",
    detailAddress: store.detailAddress ?? "",
    representativeCategory: store.representativeCategory ?? "",
    imageUrl: store.imageUrl ?? "",
    phone: store.phone ?? "",
    latitude: store.latitude?.toString() ?? "",
    longitude: store.longitude?.toString() ?? "",
    operationStartDate: store.operationStartDate ?? "",
    operationEndDate: store.operationEndDate ?? "",
    schedule: scheduleFromStore(store),
    takeoutAvailable: store.takeoutAvailable,
    dineInAvailable: store.dineInAvailable,
    orderAcceptingEnabled: store.orderAcceptingEnabled,
    tags: store.tags.join(", "),
  };
}

function optional(value: string) {
  const trimmed = value.trim();
  return trimmed || null;
}

function payloadFromEditor(editor: EditorState): StoreSavePayload {
  const legacySchedule = legacyFieldsFromSchedule(editor.schedule);
  return {
    storeType: editor.storeType,
    name: editor.name.trim(),
    description: optional(editor.description),
    address: optional(editor.address),
    detailAddress: optional(editor.detailAddress),
    representativeCategory: optional(editor.representativeCategory),
    imageUrl: optional(editor.imageUrl),
    phone: optional(editor.phone),
    latitude: editor.latitude ? Number(editor.latitude) : null,
    longitude: editor.longitude ? Number(editor.longitude) : null,
    openTime: legacySchedule.openTime,
    closeTime: legacySchedule.closeTime,
    operationStartDate: optional(editor.operationStartDate),
    operationEndDate: optional(editor.operationEndDate),
    closedDays: legacySchedule.closedDays,
    takeoutAvailable: editor.takeoutAvailable,
    dineInAvailable: editor.dineInAvailable,
    orderAcceptingEnabled: editor.orderAcceptingEnabled,
    tags: editor.tags
      .split(",")
      .map((tag) => tag.trim())
      .filter(Boolean)
      .slice(0, 10),
    schedule: scheduleForApi(editor.schedule),
  };
}

function demoDetail(): StoreDetail {
  return { ...structuredClone(demoStore), tags: ["카페", "성수"] };
}

export function StoreSettings({
  connection,
  onError,
  onBusinessStatusChange,
  onStoreSelected,
  onStoreUpdated,
  onStoreDeleted,
}: Props) {
  const isDemo = !connection;
  const [store, setStore] = useState<StoreDetail>(demoDetail);
  const [tables, setTables] = useState<StoreTable[]>(freshDemoTables);
  const [loading, setLoading] = useState(!isDemo);
  const [processing, setProcessing] = useState(false);
  const [editorMode, setEditorMode] = useState<"edit" | "create" | null>(null);
  const [editor, setEditor] = useState<EditorState>(blankEditor);
  const [showTableForm, setShowTableForm] = useState(false);
  const [showInactiveStores, setShowInactiveStores] = useState(false);
  const [confirmAction, setConfirmAction] = useState<StoreConfirmAction>(null);
  const [inactiveStores, setInactiveStores] = useState<StoreSummary[]>([]);
  const [inactiveLoading, setInactiveLoading] = useState(false);
  const [tableCode, setTableCode] = useState("");
  const [tableName, setTableName] = useState("");

  const isActiveStore = store.status === "ACTIVE";
  const canManage =
    isActiveStore && (store.myRole === "OWNER" || store.myRole === "MANAGER");
  const canDelete = isActiveStore && store.myRole === "OWNER";
  const orderMethods = useMemo(
    () =>
      [store.dineInAvailable && "매장 식사", store.takeoutAvailable && "포장"]
        .filter(Boolean)
        .join(" · ") || "주문 방식 미설정",
    [store.dineInAvailable, store.takeoutAvailable],
  );
  const storeSchedule = useMemo(() => scheduleFromStore(store), [store]);
  const scheduleLines = useMemo(
    () => scheduleSummary(storeSchedule),
    [storeSchedule],
  );

  useEffect(() => {
    let active = true;
    const load = async () => {
      if (!connection) {
        const demo = demoDetail();
        setStore(demo);
        setTables(freshDemoTables());
        setLoading(false);
        onBusinessStatusChange(demo.businessStatus);
        return;
      }
      setLoading(true);
      try {
        const [detail, storeTables] = await Promise.all([
          getSellerStoreDetail(connection),
          getStoreTables(connection),
        ]);
        if (!active) return;
        setStore(detail);
        setTables(storeTables);
        onBusinessStatusChange(detail.businessStatus);
        onStoreUpdated?.(detail);
        onError(null);
      } catch (caught) {
        if (active)
          onError(
            caught instanceof Error
              ? caught.message
              : "스토어 설정을 불러오지 못했습니다.",
          );
      } finally {
        if (active) setLoading(false);
      }
    };
    void load();
    return () => {
      active = false;
    };
  }, [connection, onBusinessStatusChange, onError, onStoreUpdated]);

  async function changeStatus(status: BusinessStatus) {
    if (!canManage) return;
    setProcessing(true);
    try {
      const updated = isDemo
        ? { ...store, businessStatus: status }
        : await changeStoreBusinessStatus(connection, status);
      setStore((current) => ({ ...current, ...updated }));
      onBusinessStatusChange(updated.businessStatus);
      onStoreUpdated?.(updated);
      onError(null);
    } catch (caught) {
      onError(
        caught instanceof Error
          ? caught.message
          : "영업 상태를 변경하지 못했습니다.",
      );
    } finally {
      setProcessing(false);
    }
  }

  function openEditor(mode: "edit" | "create") {
    setEditor(mode === "edit" ? editorFromStore(store) : blankEditor());
    setEditorMode(mode);
  }

  async function saveStore() {
    const payload = payloadFromEditor(editor);
    if (
      !payload.name ||
      !payload.representativeCategory ||
      !payload.address ||
      !payload.detailAddress ||
      !payload.phone
    ) {
      onError(
        "사업장명, 대표 카테고리, 주소, 상세 주소와 연락처를 모두 입력해 주세요.",
      );
      return;
    }
    const scheduleError = scheduleValidationMessage(editor.schedule);
    if (scheduleError) {
      onError(scheduleError);
      return;
    }
    if (!PHONE_PATTERN.test(payload.phone)) {
      onError("연락처 형식을 확인해 주세요.");
      return;
    }
    if (!payload.takeoutAvailable && !payload.dineInAvailable) {
      onError("포장 또는 매장 식사 중 하나는 가능해야 합니다.");
      return;
    }
    if (
      payload.operationStartDate &&
      payload.operationEndDate &&
      payload.operationEndDate < payload.operationStartDate
    ) {
      onError("운영 종료일은 시작일보다 빠를 수 없습니다.");
      return;
    }
    setProcessing(true);
    try {
      if (editorMode === "create") {
        if (isDemo)
          throw new Error("체험 모드에서는 스토어를 생성할 수 없습니다.");
        const created = await createSellerStore(connection, payload);
        setEditorMode(null);
        onStoreSelected?.(created);
      } else {
        const updated = isDemo
          ? { ...store, ...payload, schedule: editor.schedule }
          : await updateSellerStore(connection, payload);
        setStore(updated);
        setEditorMode(null);
        onStoreUpdated?.(updated);
        onError(null);
      }
    } catch (caught) {
      onError(
        caught instanceof Error
          ? caught.message
          : "스토어를 저장하지 못했습니다.",
      );
    } finally {
      setProcessing(false);
    }
  }

  async function removeStore() {
    if (!connection || !canDelete) return;
    setProcessing(true);
    try {
      await deleteSellerStore(connection);
      const remaining = await getSellerStores(connection);
      if (remaining.length > 0) {
        onStoreDeleted?.(remaining);
      } else {
        const closed = {
          ...store,
          status: "CLOSED" as const,
          businessStatus: "PRE_OPEN" as const,
          orderAcceptingEnabled: false,
        };
        setStore(closed);
        setInactiveStores([closed]);
        setShowInactiveStores(true);
        onBusinessStatusChange("PRE_OPEN");
      }
      onError(null);
    } catch (caught) {
      onError(
        caught instanceof Error
          ? caught.message
          : "사업장을 폐업하지 못했습니다.",
      );
    } finally {
      setProcessing(false);
    }
  }

  async function suspendStore() {
    if (!connection || !canDelete) return;
    setProcessing(true);
    try {
      const suspended = await suspendSellerStore(connection);
      const remaining = await getSellerStores(connection);
      if (remaining.length > 0) {
        onStoreDeleted?.(remaining);
      } else {
        setStore((current) => ({ ...current, ...suspended }));
        setInactiveStores([suspended]);
        setShowInactiveStores(true);
        onBusinessStatusChange(suspended.businessStatus);
      }
      onError(null);
    } catch (caught) {
      onError(
        caught instanceof Error
          ? caught.message
          : "사업장을 휴업하지 못했습니다.",
      );
    } finally {
      setProcessing(false);
    }
  }

  async function openInactiveStores() {
    if (!connection) return;
    setShowInactiveStores(true);
    setInactiveLoading(true);
    try {
      setInactiveStores(await getInactiveSellerStores(connection));
      onError(null);
    } catch (caught) {
      onError(
        caught instanceof Error
          ? caught.message
          : "휴업·폐업 사업장을 불러오지 못했습니다.",
      );
    } finally {
      setInactiveLoading(false);
    }
  }

  async function reopenStore(target: StoreSummary) {
    if (!connection || target.status !== "SUSPENDED") return;
    setProcessing(true);
    try {
      const reopened = await reopenSellerStore(connection, target.storeId);
      setInactiveStores((current) =>
        current.filter((item) => item.storeId !== target.storeId),
      );
      setShowInactiveStores(false);
      onStoreSelected?.(reopened);
      onError(null);
    } catch (caught) {
      onError(
        caught instanceof Error
          ? caught.message
          : "사업장을 재개하지 못했습니다.",
      );
    } finally {
      setProcessing(false);
    }
  }

  async function addTable() {
    const code = tableCode.trim().toUpperCase();
    const name = tableName.trim();
    if (!canManage || !/^[A-Z0-9_-]+$/.test(code) || !name) {
      onError("테이블 코드는 영문·숫자·밑줄·하이픈으로 입력해 주세요.");
      return;
    }
    setProcessing(true);
    try {
      const created = isDemo
        ? {
            storeTableId:
              Math.max(0, ...tables.map((table) => table.storeTableId)) + 1,
            tableCode: code,
            name,
            status: "ACTIVE" as const,
          }
        : await createStoreTable(connection, code, name);
      setTables((current) => [...current, created]);
      setTableCode("");
      setTableName("");
      setShowTableForm(false);
      onError(null);
    } catch (caught) {
      onError(
        caught instanceof Error
          ? caught.message
          : "테이블을 추가하지 못했습니다.",
      );
    } finally {
      setProcessing(false);
    }
  }

  if (loading)
    return (
      <main className="management-page">
        <div className="management-empty">스토어 설정을 불러오는 중입니다.</div>
      </main>
    );

  return (
    <main className="management-page settings-page">
      <section className="management-hero settings-hero">
        <div>
          <p className="eyebrow">STORE OPERATIONS</p>
          <h2>{store.name}</h2>
          <p>{store.description ?? "스토어 소개가 아직 없습니다."}</p>
        </div>
        <div className="store-profile-actions">
          <span className={`store-health status-${store.status.toLowerCase()}`}>
            {store.status === "ACTIVE" ? "정상 운영" : store.status}
          </span>
          <button
            className="secondary-action"
            onClick={() => openEditor("create")}
          >
            + 새 스토어
          </button>
          {!isDemo && (
            <button
              className="secondary-action"
              onClick={() => void openInactiveStores()}
            >
              휴업·폐업 사업장
            </button>
          )}
          {canManage && (
            <button
              className="secondary-action"
              onClick={() => openEditor("edit")}
            >
              상세 편집
            </button>
          )}
          {canDelete && (
            <button
              className="secondary-action"
              disabled={processing}
              onClick={() => setConfirmAction("suspend")}
            >
              사업장 휴업
            </button>
          )}
          {canDelete && (
            <button
              className="danger-action"
              disabled={processing}
              onClick={() => setConfirmAction("delete")}
            >
              사업장 폐업
            </button>
          )}
        </div>
      </section>

      {store.myRole === "STAFF" && (
        <p className="permission-notice">
          STAFF 권한은 스토어 정보를 조회할 수 있지만 설정을 변경할 수 없습니다.
        </p>
      )}

      <section className="settings-grid">
        <article className="business-status-card">
          <header>
            <div>
              <p className="eyebrow">BUSINESS STATUS</p>
              <h3>영업 상태</h3>
            </div>
            <span>{STATUS_LABEL[store.businessStatus]}</span>
          </header>
          <p>고객 주문 가능 여부에 맞춰 현재 영업 상태를 관리합니다.</p>
          <div
            className="status-options"
            role="radiogroup"
            aria-label="영업 상태"
          >
            {(["PRE_OPEN", "OPEN"] as BusinessStatus[]).map((value) => (
              <button
                key={value}
                role="radio"
                aria-checked={store.businessStatus === value}
                className={store.businessStatus === value ? "active" : ""}
                disabled={processing || !canManage}
                onClick={() => void changeStatus(value)}
              >
                <span />
                <div>
                  <strong>{STATUS_LABEL[value]}</strong>
                  <small>
                    {value === "OPEN" ? "고객 주문 허용" : "신규 주문 제한"}
                  </small>
                </div>
              </button>
            ))}
          </div>
        </article>

        <article className="store-info-card">
          <header>
            <p className="eyebrow">STORE PROFILE</p>
            <h3>운영 정보</h3>
          </header>
          <dl>
            <div>
              <dt>권한</dt>
              <dd>{store.myRole}</dd>
            </div>
            <div>
              <dt>주소</dt>
              <dd>
                {[store.address, store.detailAddress]
                  .filter(Boolean)
                  .join(" ") || "-"}
              </dd>
            </div>
            <div>
              <dt>연락처</dt>
              <dd>{store.phone || "-"}</dd>
            </div>
            <div>
              <dt>운영 기간</dt>
              <dd>
                {store.operationStartDate || store.operationEndDate
                  ? `${store.operationStartDate ?? "시작일 미정"} ~ ${store.operationEndDate ?? "종료일 미정"}`
                  : "상시 운영"}
              </dd>
            </div>
            <div>
              <dt>주문 방식</dt>
              <dd>{orderMethods}</dd>
            </div>
            <div>
              <dt>태그</dt>
              <dd>{store.tags.join(", ") || "-"}</dd>
            </div>
          </dl>
        </article>

        <article className="schedule-overview-card">
          <header>
            <div>
              <p className="eyebrow">BUSINESS SCHEDULE</p>
              <h3>영업 일정</h3>
            </div>
            {canManage && (
              <button onClick={() => openEditor("edit")}>일정 편집</button>
            )}
          </header>
          <p className="schedule-overview-description">
            요일별 영업시간과 정기·임시휴무를 고객 안내 일정으로 관리합니다.
          </p>
          <div className="schedule-summary-list">
            {scheduleLines.map((line, index) => (
              <span key={`${line}-${index}`}>{line}</span>
            ))}
          </div>
        </article>

        <article className="tables-card">
          <header>
            <div>
              <p className="eyebrow">TABLES</p>
              <h3>테이블 관리</h3>
            </div>
            {canManage && (
              <button onClick={() => setShowTableForm(true)}>
                + 테이블 추가
              </button>
            )}
          </header>
          <div className="table-list">
            {tables.map((table) => (
              <div key={table.storeTableId}>
                <span>{table.name.slice(0, 1)}</span>
                <p>
                  <strong>{table.name}</strong>
                  <small>{table.tableCode}</small>
                </p>
                <b className={table.status.toLowerCase()}>
                  {table.status === "ACTIVE" ? "사용 중" : "중지"}
                </b>
              </div>
            ))}
          </div>
        </article>
      </section>

      {editorMode && (
        <div className="modal-backdrop" role="presentation">
          <section
            className="connection-modal store-editor-modal"
            role="dialog"
            aria-modal="true"
            aria-labelledby="store-editor-title"
          >
            <header className="store-editor-header">
              <div>
                <p className="eyebrow">
                  {editorMode === "create" ? "NEW STORE" : "STORE PROFILE"}
                </p>
                <h2 id="store-editor-title">
                  {editorMode === "create" ? "스토어 생성" : "스토어 상세 편집"}
                </h2>
                <p>
                  기본 운영 정보와 고객에게 안내할 영업 일정을 함께 관리합니다.
                </p>
              </div>
              <button
                className="modal-close"
                aria-label="닫기"
                onClick={() => setEditorMode(null)}
              >
                ×
              </button>
            </header>
            <div className="store-editor-workspace">
              <section
                className="store-profile-editor-panel"
                aria-labelledby="store-profile-editor-title"
              >
                <div className="store-editor-section-heading">
                  <div>
                    <p className="eyebrow">STORE INFORMATION</p>
                    <h3 id="store-profile-editor-title">기본 운영 정보</h3>
                  </div>
                  <p>사업장 정보, 운영 기간과 주문 방식을 설정합니다.</p>
                </div>
                <div className="store-editor-grid">
              <label>
                유형
                <select
                  value={editor.storeType}
                  onChange={(event) =>
                    setEditor({
                      ...editor,
                      storeType: event.target.value as StoreType,
                    })
                  }
                >
                  <option value="LOCAL_STORE">상설 매장</option>
                  <option value="EVENT_COMMERCE">이벤트 커머스</option>
                </select>
              </label>
              <label>
                사업장명 *
                <input
                  maxLength={150}
                  value={editor.name}
                  onChange={(event) =>
                    setEditor({ ...editor, name: event.target.value })
                  }
                />
              </label>
              <label className="wide">
                소개
                <textarea
                  maxLength={1000}
                  value={editor.description}
                  onChange={(event) =>
                    setEditor({ ...editor, description: event.target.value })
                  }
                />
              </label>
              <label>
                주소 *
                <input
                  maxLength={255}
                  value={editor.address}
                  onChange={(event) =>
                    setEditor({ ...editor, address: event.target.value })
                  }
                />
              </label>
              <label>
                상세 주소 *
                <input
                  maxLength={255}
                  value={editor.detailAddress}
                  onChange={(event) =>
                    setEditor({ ...editor, detailAddress: event.target.value })
                  }
                />
              </label>
              <label>
                대표 카테고리 *
                <select
                  value={editor.representativeCategory}
                  onChange={(event) =>
                    setEditor({
                      ...editor,
                      representativeCategory: event.target.value,
                    })
                  }
                >
                  <option value="">선택</option>
                  {STORE_CATEGORIES.map((category) => (
                    <option key={category} value={category}>
                      {category}
                    </option>
                  ))}
                </select>
              </label>
              <label>
                연락처 *
                <input
                  maxLength={30}
                  value={editor.phone}
                  onChange={(event) =>
                    setEditor({ ...editor, phone: event.target.value })
                  }
                />
              </label>
              <label>
                운영 시작일
                <input
                  type="date"
                  value={editor.operationStartDate}
                  onChange={(event) =>
                    setEditor({
                      ...editor,
                      operationStartDate: event.target.value,
                    })
                  }
                />
              </label>
              <label>
                운영 종료일
                <input
                  type="date"
                  min={editor.operationStartDate || undefined}
                  value={editor.operationEndDate}
                  onChange={(event) =>
                    setEditor({
                      ...editor,
                      operationEndDate: event.target.value,
                    })
                  }
                />
              </label>
              <label>
                위도
                <input
                  type="number"
                  step="any"
                  value={editor.latitude}
                  onChange={(event) =>
                    setEditor({ ...editor, latitude: event.target.value })
                  }
                />
              </label>
              <label>
                경도
                <input
                  type="number"
                  step="any"
                  value={editor.longitude}
                  onChange={(event) =>
                    setEditor({ ...editor, longitude: event.target.value })
                  }
                />
              </label>
              <label className="wide">
                이미지 URL
                <input
                  value={editor.imageUrl}
                  onChange={(event) =>
                    setEditor({ ...editor, imageUrl: event.target.value })
                  }
                />
              </label>
              <label className="wide">
                태그 (쉼표로 구분)
                <input
                  value={editor.tags}
                  onChange={(event) =>
                    setEditor({ ...editor, tags: event.target.value })
                  }
                />
              </label>
                </div>
                <fieldset className="choice-fieldset store-order-settings">
              <legend>주문 설정</legend>
              <label>
                <input
                  type="checkbox"
                  checked={editor.dineInAvailable}
                  onChange={(event) =>
                    setEditor({
                      ...editor,
                      dineInAvailable: event.target.checked,
                    })
                  }
                />
                매장 식사
              </label>
              <label>
                <input
                  type="checkbox"
                  checked={editor.takeoutAvailable}
                  onChange={(event) =>
                    setEditor({
                      ...editor,
                      takeoutAvailable: event.target.checked,
                    })
                  }
                />
                포장
              </label>
              <label>
                <input
                  type="checkbox"
                  checked={editor.orderAcceptingEnabled}
                  onChange={(event) =>
                    setEditor({
                      ...editor,
                      orderAcceptingEnabled: event.target.checked,
                    })
                  }
                />
                주문 접수
              </label>
                </fieldset>
              </section>
              <BusinessScheduleEditor
                value={editor.schedule}
                disabled={processing}
                onChange={(schedule) => setEditor({ ...editor, schedule })}
              />
            </div>
            <footer className="store-editor-footer">
              <p>변경한 기본 정보와 영업 일정은 한 번에 저장됩니다.</p>
              <div>
                <button
                  className="secondary-action"
                  disabled={processing}
                  onClick={() => setEditorMode(null)}
                >
                  취소
                </button>
                <button
                  className="primary-action"
                  disabled={processing}
                  onClick={() => void saveStore()}
                >
                  {processing ? "저장 중…" : "변경사항 저장"}
                </button>
              </div>
            </footer>
          </section>
        </div>
      )}

      {showTableForm && (
        <div className="modal-backdrop" role="presentation">
          <section
            className="connection-modal"
            role="dialog"
            aria-modal="true"
            aria-labelledby="table-title"
          >
            <button
              className="modal-close"
              aria-label="닫기"
              onClick={() => setShowTableForm(false)}
            >
              ×
            </button>
            <p className="eyebrow">NEW TABLE</p>
            <h2 id="table-title">테이블 추가</h2>
            <label>
              테이블 코드
              <input
                placeholder="WINDOW-08"
                value={tableCode}
                onChange={(event) => setTableCode(event.target.value)}
              />
            </label>
            <label>
              표시 이름
              <input
                placeholder="Window 08"
                value={tableName}
                onChange={(event) => setTableName(event.target.value)}
              />
            </label>
            <button
              className="primary-action"
              disabled={processing}
              onClick={() => void addTable()}
            >
              {processing ? "추가 중…" : "테이블 추가하기"}
            </button>
          </section>
        </div>
      )}

      {confirmAction && (
        <div className="modal-backdrop" role="presentation">
          <section
            className="connection-modal"
            role="dialog"
            aria-modal="true"
            aria-labelledby="store-confirm-title"
          >
            <button
              className="modal-close"
              aria-label="닫기"
              onClick={() => setConfirmAction(null)}
            >
              ×
            </button>
            <p className="eyebrow">STORE ACTION</p>
            <h2 id="store-confirm-title">
              {confirmAction === "delete" ? "사업장 폐업" : "사업장 휴업"}
            </h2>
            <p>
              {confirmAction === "delete"
                ? `'${store.name}' 사업장을 폐업할까요? 기존 주문과 결제 기록은 보존되며 직접 재개할 수 없습니다.`
                : `'${store.name}' 사업장을 휴업할까요? 고객 노출과 신규 주문 접수가 중지됩니다.`}
            </p>
            <button
              className="secondary-action"
              disabled={processing}
              onClick={() => setConfirmAction(null)}
            >
              취소
            </button>
            <button
              className={confirmAction === "delete" ? "reject-action" : "primary-action"}
              style={{ width: "100%", marginTop: 8 }}
              disabled={processing}
              onClick={() => {
                const action = confirmAction;
                setConfirmAction(null);
                if (action === "delete") void removeStore();
                else void suspendStore();
              }}
            >
              {confirmAction === "delete" ? "폐업하기" : "휴업하기"}
            </button>
          </section>
        </div>
      )}

      {showInactiveStores && (
        <div className="modal-backdrop" role="presentation">
          <section
            className="connection-modal store-editor-modal"
            role="dialog"
            aria-modal="true"
            aria-labelledby="inactive-store-title"
          >
            <button
              className="modal-close"
              aria-label="닫기"
              onClick={() => setShowInactiveStores(false)}
            >
              ×
            </button>
            <p className="eyebrow">INACTIVE STORES</p>
            <h2 id="inactive-store-title">휴업·폐업 사업장</h2>
            {inactiveLoading ? (
              <p>사업장을 불러오는 중입니다.</p>
            ) : (
              <div className="account-store-list">
                {inactiveStores.map((item) => (
                  <article key={item.storeId} className="announcement-card">
                    <div>
                      <strong>{item.name}</strong>
                      <small>
                        {item.status === "SUSPENDED" ? "휴업" : "폐업"}
                      </small>
                    </div>
                    {item.status === "SUSPENDED" && item.myRole === "OWNER" && (
                      <button
                        className="primary-action"
                        disabled={processing}
                        onClick={() => void reopenStore(item)}
                      >
                        사업장 재개
                      </button>
                    )}
                  </article>
                ))}
                {inactiveStores.length === 0 && (
                  <p>휴업·폐업 사업장이 없습니다.</p>
                )}
              </div>
            )}
          </section>
        </div>
      )}
    </main>
  );
}

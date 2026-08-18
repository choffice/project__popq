/* eslint-disable react-refresh/only-export-components -- 일정 정규화 유틸은 편집기와 동일 계약을 공유한다. */
import { useState } from "react";
import type {
  StoreBusinessHour,
  StoreClosedDay,
  StoreClosureRule,
  StoreSchedule,
  StoreScheduleException,
  StoreSchedulePayload,
  StoreSummary,
} from "../../types";

export const WEEKDAYS: StoreClosedDay[] = [
  "MONDAY",
  "TUESDAY",
  "WEDNESDAY",
  "THURSDAY",
  "FRIDAY",
  "SATURDAY",
  "SUNDAY",
];

export const DAY_LABELS: Record<StoreClosedDay, string> = {
  MONDAY: "월",
  TUESDAY: "화",
  WEDNESDAY: "수",
  THURSDAY: "목",
  FRIDAY: "금",
  SATURDAY: "토",
  SUNDAY: "일",
};

type ScheduleMode = "allDays" | "weekdayWeekend" | "daily";

type Props = {
  value: StoreSchedule;
  onChange: (value: StoreSchedule) => void;
  disabled?: boolean;
};

function timeValue(value: string | null | undefined, fallback: string) {
  return value?.slice(0, 5) || fallback;
}

function signature(value: StoreBusinessHour) {
  if (value.closed) return "closed";
  if (value.open24Hours) return "24hours";
  return `${timeValue(value.openTime, "")}-${timeValue(value.closeTime, "")}`;
}

function sameDays(left: StoreClosedDay[], right: StoreClosedDay[]) {
  return left.length === right.length && right.every((day) => left.includes(day));
}

function detectedMode(schedule: StoreSchedule): ScheduleMode {
  const signatures = schedule.businessHours.map(signature);
  if (new Set(signatures).size === 1) return "allDays";
  if (
    new Set(signatures.slice(0, 5)).size === 1 &&
    new Set(signatures.slice(5)).size === 1
  ) {
    return "weekdayWeekend";
  }
  return "daily";
}

export function createDefaultSchedule(
  openTime = "09:00",
  closeTime = "21:00",
  closedDays: StoreClosedDay[] = [],
): StoreSchedule {
  return {
    businessHours: WEEKDAYS.map((dayOfWeek) => ({
      dayOfWeek,
      closed: closedDays.includes(dayOfWeek),
      open24Hours: false,
      openTime,
      closeTime,
    })),
    closureRules: [],
    scheduleExceptions: [],
    publicHolidayAutoCalculationAvailable: false,
  };
}

export function scheduleFromStore(store: StoreSummary): StoreSchedule {
  const byDay = new Map(
    store.schedule?.businessHours.map((hour) => [hour.dayOfWeek, hour]),
  );
  if (byDay.size === 7 && WEEKDAYS.every((day) => byDay.has(day))) {
    return {
      businessHours: WEEKDAYS.map((day) => ({ ...byDay.get(day)! })),
      closureRules: (store.schedule?.closureRules ?? []).map((rule) => ({
        ...rule,
      })),
      scheduleExceptions: (store.schedule?.scheduleExceptions ?? []).map(
        (exception) => ({ ...exception }),
      ),
      publicHolidayAutoCalculationAvailable:
        store.schedule?.publicHolidayAutoCalculationAvailable ?? false,
    };
  }
  return createDefaultSchedule(
    timeValue(store.openTime, "09:00"),
    timeValue(store.closeTime, "21:00"),
    store.closedDays,
  );
}

export function scheduleValidationMessage(schedule: StoreSchedule) {
  if (
    schedule.businessHours.length !== 7 ||
    new Set(schedule.businessHours.map((hour) => hour.dayOfWeek)).size !== 7
  ) {
    return "월요일부터 일요일까지 영업시간을 모두 설정해 주세요.";
  }
  for (const hour of schedule.businessHours) {
    if (hour.closed || hour.open24Hours) continue;
    if (!hour.openTime || !hour.closeTime) {
      return `${DAY_LABELS[hour.dayOfWeek]}요일의 시작·종료 시간을 입력해 주세요.`;
    }
    if (timeValue(hour.openTime, "") === timeValue(hour.closeTime, "")) {
      return `${DAY_LABELS[hour.dayOfWeek]}요일의 시작·종료 시간이 같습니다. 24시간 영업을 선택해 주세요.`;
    }
  }
  for (const exception of schedule.scheduleExceptions) {
    if (!exception.startDate || !exception.endDate) {
      return "임시휴무의 시작일과 종료일을 모두 입력해 주세요.";
    }
    if (exception.endDate < exception.startDate) {
      return "임시휴무 종료일은 시작일보다 빠를 수 없습니다.";
    }
  }
  return null;
}

export function scheduleForApi(schedule: StoreSchedule): StoreSchedulePayload {
  return {
    businessHours: schedule.businessHours.map((hour) => ({
      ...hour,
      openTime:
        hour.closed || hour.open24Hours ? null : timeValue(hour.openTime, ""),
      closeTime:
        hour.closed || hour.open24Hours ? null : timeValue(hour.closeTime, ""),
    })),
    closureRules: schedule.closureRules.map((rule) => ({ ...rule })),
    scheduleExceptions: schedule.scheduleExceptions.map((exception) => ({
      ...exception,
      memo: exception.memo?.trim() || null,
    })),
  };
}

export function legacyFieldsFromSchedule(schedule: StoreSchedule) {
  const representative =
    schedule.businessHours.find((hour) => !hour.closed && !hour.open24Hours) ??
    schedule.businessHours.find((hour) => hour.open24Hours) ??
    schedule.businessHours[0];
  return {
    openTime: representative?.open24Hours
      ? "00:00"
      : timeValue(representative?.openTime, "09:00"),
    closeTime: representative?.open24Hours
      ? "00:00"
      : timeValue(representative?.closeTime, "21:00"),
    closedDays: schedule.businessHours
      .filter((hour) => hour.closed)
      .map((hour) => hour.dayOfWeek),
  };
}

function ruleLabel(rule: StoreClosureRule) {
  return rule.ruleType === "PUBLIC_HOLIDAY"
    ? "공휴일 휴무"
    : `매월 ${rule.weekOfMonth}번째 ${DAY_LABELS[rule.dayOfWeek!]}요일`;
}

function exceptionLabel(exception: StoreScheduleException) {
  return exception.startDate === exception.endDate
    ? exception.startDate
    : `${exception.startDate} ~ ${exception.endDate}`;
}

export function scheduleSummary(schedule: StoreSchedule) {
  const groups = new Map<string, StoreBusinessHour[]>();
  schedule.businessHours.forEach((hour) => {
    const key = signature(hour);
    groups.set(key, [...(groups.get(key) ?? []), hour]);
  });
  const lines = [...groups.values()].map((hours) => {
    const days = hours.map((hour) => hour.dayOfWeek);
    const label =
      days.length === 7
        ? "매일"
        : sameDays(days, WEEKDAYS.slice(0, 5))
          ? "평일"
          : sameDays(days, WEEKDAYS.slice(5))
            ? "주말"
            : days.map((day) => DAY_LABELS[day]).join("·");
    const hour = hours[0];
    if (hour.closed) return `${label} 휴무`;
    if (hour.open24Hours) return `${label} 24시간 영업`;
    const nextDay =
      timeValue(hour.closeTime, "") < timeValue(hour.openTime, "")
        ? "익일 "
        : "";
    return `${label} ${timeValue(hour.openTime, "-")} ~ ${nextDay}${timeValue(hour.closeTime, "-")}`;
  });
  schedule.closureRules.forEach((rule) => lines.push(ruleLabel(rule)));
  schedule.scheduleExceptions.forEach((exception) =>
    lines.push(
      `임시휴무 ${exceptionLabel(exception)}${exception.memo?.trim() ? ` · ${exception.memo.trim()}` : ""}`,
    ),
  );
  return lines;
}

export function BusinessScheduleEditor({ value, onChange, disabled }: Props) {
  const [mode, setMode] = useState<ScheduleMode>(() => detectedMode(value));
  const [ruleWeek, setRuleWeek] = useState(2);
  const [ruleDay, setRuleDay] = useState<StoreClosedDay>("WEDNESDAY");
  const [exceptionDraft, setExceptionDraft] = useState({
    startDate: "",
    endDate: "",
    memo: "",
  });

  const byDay = new Map(value.businessHours.map((hour) => [hour.dayOfWeek, hour]));
  const groups: { label: string; days: StoreClosedDay[] }[] =
    mode === "allDays"
      ? [{ label: "매일", days: WEEKDAYS }]
      : mode === "weekdayWeekend"
        ? [
            { label: "평일", days: WEEKDAYS.slice(0, 5) },
            { label: "주말", days: WEEKDAYS.slice(5) },
          ]
        : WEEKDAYS.map((day) => ({
            label: `${DAY_LABELS[day]}요일`,
            days: [day],
          }));

  function applyHour(days: StoreClosedDay[], changes: Partial<StoreBusinessHour>) {
    onChange({
      ...value,
      businessHours: value.businessHours.map((hour) =>
        days.includes(hour.dayOfWeek) ? { ...hour, ...changes } : hour,
      ),
    });
  }

  function changeMode(nextMode: ScheduleMode) {
    let businessHours = value.businessHours;
    if (nextMode === "allDays") {
      const template = byDay.get("MONDAY")!;
      businessHours = value.businessHours.map((hour) => ({
        ...template,
        dayOfWeek: hour.dayOfWeek,
      }));
    } else if (nextMode === "weekdayWeekend") {
      const weekday = byDay.get("MONDAY")!;
      const weekend = byDay.get("SATURDAY")!;
      businessHours = value.businessHours.map((hour, index) => ({
        ...(index < 5 ? weekday : weekend),
        dayOfWeek: hour.dayOfWeek,
      }));
    }
    setMode(nextMode);
    onChange({ ...value, businessHours });
  }

  function togglePublicHoliday(checked: boolean) {
    const closureRules = value.closureRules.filter(
      (rule) => rule.ruleType !== "PUBLIC_HOLIDAY",
    );
    if (checked) {
      closureRules.push({
        ruleType: "PUBLIC_HOLIDAY",
        weekOfMonth: null,
        dayOfWeek: null,
      });
    }
    onChange({ ...value, closureRules });
  }

  function addRule() {
    const duplicate = value.closureRules.some(
      (rule) =>
        rule.ruleType === "NTH_WEEKDAY" &&
        rule.weekOfMonth === ruleWeek &&
        rule.dayOfWeek === ruleDay,
    );
    if (duplicate || value.closureRules.length >= 20) return;
    onChange({
      ...value,
      closureRules: [
        ...value.closureRules,
        {
          ruleType: "NTH_WEEKDAY",
          weekOfMonth: ruleWeek,
          dayOfWeek: ruleDay,
        },
      ],
    });
  }

  function addException() {
    if (
      !exceptionDraft.startDate ||
      !exceptionDraft.endDate ||
      exceptionDraft.endDate < exceptionDraft.startDate ||
      value.scheduleExceptions.length >= 50
    ) {
      return;
    }
    onChange({
      ...value,
      scheduleExceptions: [
        ...value.scheduleExceptions,
        {
          startDate: exceptionDraft.startDate,
          endDate: exceptionDraft.endDate,
          exceptionType: "CLOSED",
          memo: exceptionDraft.memo.trim() || null,
        },
      ],
    });
    setExceptionDraft({ startDate: "", endDate: "", memo: "" });
  }

  return (
    <section className="schedule-editor" aria-labelledby="schedule-editor-title">
      <div className="schedule-editor-heading">
        <div>
          <p className="eyebrow">BUSINESS SCHEDULE</p>
          <h3 id="schedule-editor-title">영업 일정</h3>
        </div>
        <p>요일별 운영과 반복·임시휴무를 한 곳에서 관리합니다.</p>
      </div>

      <div className="schedule-mode" role="radiogroup" aria-label="영업시간 입력 방식">
        {(
          [
            ["allDays", "모든 요일"],
            ["weekdayWeekend", "평일/주말"],
            ["daily", "요일별"],
          ] as const
        ).map(([modeValue, label]) => (
          <button
            type="button"
            key={modeValue}
            role="radio"
            aria-checked={mode === modeValue}
            className={mode === modeValue ? "active" : ""}
            disabled={disabled}
            onClick={() => changeMode(modeValue)}
          >
            {label}
          </button>
        ))}
      </div>

      <div className="schedule-hours-list">
        {groups.map((group) => {
          const hour = byDay.get(group.days[0])!;
          return (
            <article className="schedule-hour-row" key={group.label}>
              <strong>{group.label}</strong>
              <label className="schedule-check">
                <input
                  type="checkbox"
                  checked={hour.closed}
                  disabled={disabled}
                  onChange={(event) =>
                    applyHour(group.days, {
                      closed: event.target.checked,
                      open24Hours: event.target.checked
                        ? false
                        : hour.open24Hours,
                      openTime:
                        !event.target.checked && !hour.openTime
                          ? "10:00"
                          : hour.openTime,
                      closeTime:
                        !event.target.checked && !hour.closeTime
                          ? "22:00"
                          : hour.closeTime,
                    })
                  }
                />
                휴무
              </label>
              {!hour.closed && (
                <label className="schedule-check">
                  <input
                    type="checkbox"
                    checked={hour.open24Hours}
                    disabled={disabled}
                    onChange={(event) =>
                      applyHour(group.days, {
                        open24Hours: event.target.checked,
                        openTime:
                          !event.target.checked && !hour.openTime
                            ? "10:00"
                            : hour.openTime,
                        closeTime:
                          !event.target.checked && !hour.closeTime
                            ? "22:00"
                            : hour.closeTime,
                      })
                    }
                  />
                  24시간
                </label>
              )}
              {!hour.closed && !hour.open24Hours && (
                <div className="schedule-time-range">
                  <label>
                    <span>시작</span>
                    <input
                      type="time"
                      aria-label={`${group.label} 시작 시간`}
                      value={timeValue(hour.openTime, "09:00")}
                      disabled={disabled}
                      onChange={(event) =>
                        applyHour(group.days, { openTime: event.target.value })
                      }
                    />
                  </label>
                  <span>~</span>
                  <label>
                    <span>종료</span>
                    <input
                      type="time"
                      aria-label={`${group.label} 종료 시간`}
                      value={timeValue(hour.closeTime, "21:00")}
                      disabled={disabled}
                      onChange={(event) =>
                        applyHour(group.days, { closeTime: event.target.value })
                      }
                    />
                  </label>
                </div>
              )}
            </article>
          );
        })}
      </div>

      <section className="closure-section" aria-labelledby="recurring-closure-title">
        <div className="closure-heading">
          <div>
            <h4 id="recurring-closure-title">정기휴무</h4>
            <p>매월 반복되는 휴무 규칙을 설정합니다.</p>
          </div>
          <label className="public-holiday-toggle">
            <input
              type="checkbox"
              checked={value.closureRules.some(
                (rule) => rule.ruleType === "PUBLIC_HOLIDAY",
              )}
              disabled={disabled}
              onChange={(event) => togglePublicHoliday(event.target.checked)}
            />
            공휴일 휴무
          </label>
        </div>
        {!value.publicHolidayAutoCalculationAvailable &&
          value.closureRules.some(
            (rule) => rule.ruleType === "PUBLIC_HOLIDAY",
          ) && (
            <p className="schedule-policy-note">
              공휴일 휴무 정책은 저장되지만 현재 자동 공휴일 판정 데이터는 제공되지 않습니다.
            </p>
          )}
        <div className="closure-rule-form">
          <label>
            <span>주차</span>
            <select
              aria-label="정기휴무 주차"
              value={ruleWeek}
              disabled={disabled}
              onChange={(event) => setRuleWeek(Number(event.target.value))}
            >
              {[1, 2, 3, 4, 5].map((week) => (
                <option key={week} value={week}>
                  {week}번째
                </option>
              ))}
            </select>
          </label>
          <label>
            <span>요일</span>
            <select
              aria-label="정기휴무 요일"
              value={ruleDay}
              disabled={disabled}
              onChange={(event) =>
                setRuleDay(event.target.value as StoreClosedDay)
              }
            >
              {WEEKDAYS.map((day) => (
                <option key={day} value={day}>
                  {DAY_LABELS[day]}요일
                </option>
              ))}
            </select>
          </label>
          <button type="button" disabled={disabled} onClick={addRule}>
            + 정기휴무 추가
          </button>
        </div>
        <div className="schedule-chip-list" aria-label="등록된 정기휴무">
          {value.closureRules
            .filter((rule) => rule.ruleType === "NTH_WEEKDAY")
            .map((rule, index) => (
              <span key={`${rule.weekOfMonth}-${rule.dayOfWeek}-${index}`}>
                {ruleLabel(rule)}
                <button
                  type="button"
                  aria-label={`${ruleLabel(rule)} 삭제`}
                  disabled={disabled}
                  onClick={() =>
                    onChange({
                      ...value,
                      closureRules: value.closureRules.filter(
                        (candidate) => candidate !== rule,
                      ),
                    })
                  }
                >
                  ×
                </button>
              </span>
            ))}
          {!value.closureRules.some(
            (rule) => rule.ruleType === "NTH_WEEKDAY",
          ) && <small>등록된 월간 정기휴무가 없습니다.</small>}
        </div>
      </section>

      <section className="closure-section" aria-labelledby="temporary-closure-title">
        <div className="closure-heading">
          <div>
            <h4 id="temporary-closure-title">임시휴무</h4>
            <p>휴가나 시설 점검처럼 특정 기간만 쉬는 일정을 등록합니다.</p>
          </div>
        </div>
        <div className="exception-form">
          <label>
            <span>시작일</span>
            <input
              type="date"
              value={exceptionDraft.startDate}
              disabled={disabled}
              onChange={(event) =>
                setExceptionDraft({
                  ...exceptionDraft,
                  startDate: event.target.value,
                  endDate:
                    exceptionDraft.endDate &&
                    exceptionDraft.endDate < event.target.value
                      ? event.target.value
                      : exceptionDraft.endDate,
                })
              }
            />
          </label>
          <label>
            <span>종료일</span>
            <input
              type="date"
              min={exceptionDraft.startDate || undefined}
              value={exceptionDraft.endDate}
              disabled={disabled}
              onChange={(event) =>
                setExceptionDraft({
                  ...exceptionDraft,
                  endDate: event.target.value,
                })
              }
            />
          </label>
          <label className="exception-memo">
            <span>메모</span>
            <input
              maxLength={255}
              placeholder="예: 여름휴가, 시설 점검"
              value={exceptionDraft.memo}
              disabled={disabled}
              onChange={(event) =>
                setExceptionDraft({
                  ...exceptionDraft,
                  memo: event.target.value,
                })
              }
            />
          </label>
          <button
            type="button"
            disabled={
              disabled ||
              !exceptionDraft.startDate ||
              !exceptionDraft.endDate ||
              exceptionDraft.endDate < exceptionDraft.startDate
            }
            onClick={addException}
          >
            + 임시휴무 추가
          </button>
        </div>
        <div className="exception-list">
          {value.scheduleExceptions.map((exception, index) => (
            <article key={`${exception.startDate}-${exception.endDate}-${index}`}>
              <div>
                <strong>{exceptionLabel(exception)}</strong>
                {exception.memo && <p>{exception.memo}</p>}
              </div>
              <button
                type="button"
                aria-label={`${exceptionLabel(exception)} 임시휴무 삭제`}
                disabled={disabled}
                onClick={() =>
                  onChange({
                    ...value,
                    scheduleExceptions: value.scheduleExceptions.filter(
                      (candidate) => candidate !== exception,
                    ),
                  })
                }
              >
                삭제
              </button>
            </article>
          ))}
          {value.scheduleExceptions.length === 0 && (
            <small>등록된 임시휴무가 없습니다.</small>
          )}
        </div>
      </section>
    </section>
  );
}

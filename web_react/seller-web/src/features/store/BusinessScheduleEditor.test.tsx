import { useState } from "react";
import { cleanup, render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it } from "vitest";
import type { StoreSchedule } from "../../types";
import {
  BusinessScheduleEditor,
  createDefaultSchedule,
  legacyFieldsFromSchedule,
  scheduleForApi,
  scheduleFromStore,
  scheduleSummary,
  scheduleValidationMessage,
} from "./BusinessScheduleEditor";

function ScheduleHarness() {
  const [schedule, setSchedule] = useState<StoreSchedule>(() =>
    createDefaultSchedule("10:00", "22:00"),
  );
  return (
    <>
      <BusinessScheduleEditor value={schedule} onChange={setSchedule} />
      <output data-testid="schedule-value">{JSON.stringify(schedule)}</output>
    </>
  );
}

describe("스토어 영업 일정", () => {
  afterEach(cleanup);

  it("레거시 영업시간과 휴무일을 7일 일정으로 변환한다", () => {
    const schedule = scheduleFromStore({
      storeId: 1,
      storeType: "LOCAL_STORE",
      name: "테스트 스토어",
      description: null,
      address: null,
      detailAddress: null,
      representativeCategory: null,
      imageUrl: null,
      phone: null,
      latitude: null,
      longitude: null,
      openTime: "09:30:00",
      closeTime: "21:30:00",
      closedDays: ["MONDAY"],
      takeoutAvailable: true,
      dineInAvailable: true,
      orderAcceptingEnabled: true,
      status: "ACTIVE",
      businessStatus: "OPEN",
      myRole: "OWNER",
    });

    expect(schedule.businessHours).toHaveLength(7);
    expect(schedule.businessHours[0]).toMatchObject({
      dayOfWeek: "MONDAY",
      closed: true,
      openTime: "09:30",
      closeTime: "21:30",
    });
    expect(legacyFieldsFromSchedule(schedule)).toEqual({
      openTime: "09:30",
      closeTime: "21:30",
      closedDays: ["MONDAY"],
    });
  });

  it("24시간 영업과 익일 마감, 휴무 규칙을 API 형식으로 정규화한다", () => {
    const schedule = createDefaultSchedule("18:00", "02:00");
    schedule.businessHours[0] = {
      ...schedule.businessHours[0],
      open24Hours: true,
    };
    schedule.closureRules = [
      {
        ruleType: "NTH_WEEKDAY",
        weekOfMonth: 2,
        dayOfWeek: "WEDNESDAY",
      },
    ];
    schedule.scheduleExceptions = [
      {
        startDate: "2026-08-20",
        endDate: "2026-08-22",
        exceptionType: "CLOSED",
        memo: " 여름휴가 ",
      },
    ];

    expect(scheduleValidationMessage(schedule)).toBeNull();
    expect(scheduleForApi(schedule).businessHours[0]).toMatchObject({
      open24Hours: true,
      openTime: null,
      closeTime: null,
    });
    expect(scheduleForApi(schedule).scheduleExceptions[0].memo).toBe(
      "여름휴가",
    );
    expect(scheduleSummary(schedule)).toEqual(
      expect.arrayContaining([
        "월 24시간 영업",
        "화·수·목·금·토·일 18:00 ~ 익일 02:00",
        "매월 2번째 수요일",
        "임시휴무 2026-08-20 ~ 2026-08-22 · 여름휴가",
      ]),
    );
  });

  it("요일별 시간과 정기·임시휴무를 편집한다", async () => {
    const user = userEvent.setup();
    render(<ScheduleHarness />);

    await user.click(screen.getByRole("radio", { name: "요일별" }));
    await user.click(screen.getAllByLabelText("휴무")[1]);
    await user.click(screen.getByLabelText("공휴일 휴무"));
    await user.click(screen.getByRole("button", { name: "+ 정기휴무 추가" }));

    await user.type(screen.getByLabelText("시작일"), "2026-08-25");
    await user.type(screen.getByLabelText("종료일"), "2026-08-26");
    await user.type(screen.getByLabelText("메모"), "시설 점검");
    await user.click(screen.getByRole("button", { name: "+ 임시휴무 추가" }));

    const value = JSON.parse(
      screen.getByTestId("schedule-value").textContent ?? "{}",
    ) as StoreSchedule;
    expect(value.businessHours[1].closed).toBe(true);
    expect(value.closureRules).toEqual(
      expect.arrayContaining([
        {
          ruleType: "PUBLIC_HOLIDAY",
          weekOfMonth: null,
          dayOfWeek: null,
        },
        {
          ruleType: "NTH_WEEKDAY",
          weekOfMonth: 2,
          dayOfWeek: "WEDNESDAY",
        },
      ]),
    );
    expect(value.scheduleExceptions[0]).toEqual({
      startDate: "2026-08-25",
      endDate: "2026-08-26",
      exceptionType: "CLOSED",
      memo: "시설 점검",
    });
  });
});

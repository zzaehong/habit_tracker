import { it, expect } from "vitest";
import {
  defaultPlan,
  mealEntry,
  nutritionSummary,
  duePlans,
} from "../shared/meals";
import { newActivity } from "../shared/model";
it("고정 식단 수정이 기존 기록을 바꾸지 않음", () => {
  const p = defaultPlan("아침");
  p.kcal = 400;
  const e = mealEntry(newActivity("meal"), p, "2026-10-14", "planned");
  p.kcal = 800;
  expect(e.data.kcal).toBe(400);
});
it("외식 미상과 거름을 구분", () => {
  const p = defaultPlan("아침");
  const a = newActivity("meal");
  const e = mealEntry(a, p, "2026-10-14", "outside");
  const skipped = mealEntry(a, p, "2026-10-14", "skipped");
  expect(e.data.kcal).toBeUndefined();
  expect(skipped.done).toBe(false);
  expect(nutritionSummary([e, skipped]).unknown).toBe(1);
});
it("끼니 요일과 활성 여부 적용", () => {
  const p = defaultPlan("아침");
  p.weekdays = [1];
  expect(duePlans([p], "2026-10-14")).toHaveLength(0);
  p.enabled = false;
  expect(duePlans([p], "2026-10-12")).toHaveLength(0);
});

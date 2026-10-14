import { it, expect } from "vitest";
import { prompt, validateAI } from "../shared/ai";
import { newActivity } from "../shared/model";
const a = newActivity("running");
it("어제는 입력일 기준으로 해석하도록 지시", () => {
  expect(prompt({ text: "어제 러닝", date: "2026-01-01" }, [a], [])).toContain(
    "어제=2025-12-31",
  );
});
it("없는 활동과 잘못된 강도 거부", () => {
  expect(() =>
    validateAI(
      { records: [{ activityId: "missing", date: "2026-10-14", data: {} }] },
      [a],
    ),
  ).toThrow();
  expect(() =>
    validateAI(
      {
        records: [
          { activityId: a.id, date: "2026-10-14", data: { intensity: 20 } },
        ],
      },
      [a],
    ),
  ).toThrow();
});
it("모르는 심박수를 생성하지 않는 출력 보존", () => {
  const r = validateAI(
    {
      records: [
        {
          activityId: a.id,
          date: "2026-10-14",
          data: { distance: 5, seconds: 1800 },
        },
      ],
    },
    [a],
  );
  expect(r.records[0].data.heartRate).toBeUndefined();
});

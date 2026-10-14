import { it, expect } from "vitest";
import { zipSync, unzipSync, strToU8, strFromU8 } from "fflate";
import { makeBackup, backupSchema, csv } from "../shared/backup";
import { newActivity } from "../shared/model";
import { mean, sum, achievement } from "../shared/stats";
it("JSON과 이미지 포함 ZIP 왕복", () => {
  const backup = makeBackup([newActivity("running")]);
  const image = new Uint8Array([1, 2, 3]);
  const zipped = zipSync({
    "records.json": strToU8(JSON.stringify(backup)),
    "attachments/example": image,
  });
  const files = unzipSync(zipped);
  expect(
    backupSchema.parse(JSON.parse(strFromU8(files["records.json"]))),
  ).toEqual(backup);
  expect(files["attachments/example"]).toEqual(image);
});
it("CSV 수식 주입 및 쉼표 처리", () => {
  expect(csv([["=cmd", "a,b", 'a"b', undefined]])).toContain(
    '"\'=cmd","a,b","a""b",""',
  );
});
it("누락값은 0 평균을 만들지 않음", () => {
  expect(mean([])).toBeUndefined();
  expect(sum([])).toBeUndefined();
});

import { selectBackup } from "../shared/backup";
import { now, type Draft, type Attachment } from "../shared/model";
it("미확정 캡처 초안의 이미지도 전체 백업에 포함", () => {
  const image: Attachment = {
    id: "image",
    type: "attachment",
    hash: "a".repeat(64),
    name: "nrc.png",
    mime: "image/png",
    size: 10,
    updatedAt: now(),
    version: 0,
  };
  const draft: Draft = {
    id: "draft",
    type: "draft",
    text: "캡처",
    date: "2026-10-15",
    createdAt: now(),
    updatedAt: now(),
    version: 0,
    status: "waiting",
    mode: "capture",
    attachments: ["image"],
  };
  expect(selectBackup([image, draft]).map((e) => e.id)).toEqual([
    "image",
    "draft",
  ]);
});
import { trendValue } from "../shared/stats";
import type { Entry } from "../shared/model";
it("기간 평균 페이스는 총시간/총거리", () => {
  const a = newActivity("running");
  const entries = [
    { definition: a, data: { distance: 5, seconds: 1800 } },
    { definition: a, data: { distance: 1, seconds: 600 } },
  ] as Entry[];
  expect(trendValue(entries, "pace")).toBe(400);
  expect(trendValue([], "heartRate")).toBeUndefined();
});

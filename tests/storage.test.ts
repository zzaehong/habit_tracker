import "fake-indexeddb/auto";
import { it, expect, vi } from "vitest";
import { db, save } from "../src/db";
import { newActivity } from "../shared/model";
it("기록과 전송 작업을 함께 보존", async () => {
  vi.stubGlobal("window", { dispatchEvent: () => {} });
  const a = newActivity("study");
  await save(a);
  expect((await db.entities.get(a.id))?.id).toBe(a.id);
  expect((await db.outbox.toArray()).some((o) => o.entity.id === a.id)).toBe(
    true,
  );
  await db.close();
  await db.open();
  expect(await db.entities.get(a.id)).toBeDefined();
});

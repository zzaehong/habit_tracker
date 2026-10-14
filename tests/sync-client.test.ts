import "fake-indexeddb/auto";
import { it, expect, vi } from "vitest";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { db, save, setMeta } from "../src/db";
import { sync, resolveConflict } from "../src/sync";
import { createApp, pairingCode } from "../server/app";
import { newActivity } from "../shared/model";
it("연속 수정 전송 순서, 응답 유실 재시도, 동시 수정 내용 보존", async () => {
  vi.stubGlobal("window", { dispatchEvent: () => {} });
  const dir = mkdtempSync(tmpdir() + "/chagok-sync-");
  const { app, repo } = await createApp(dir);
  try {
    const pair = await app.inject({
      method: "POST",
      url: "/api/pair",
      payload: { code: pairingCode(repo), name: "test" },
    });
    await setMeta("token", pair.json().token);
    let loseResponse = true;
    vi.stubGlobal("fetch", async (url: string, options: any) => {
      const r = await app.inject({
        method: options.method || "GET",
        url,
        headers: options.headers,
        payload: options.body,
      });
      if (loseResponse && url === "/api/sync") {
        loseResponse = false;
        throw Error("응답 유실");
      }
      return new Response(r.body, {
        status: r.statusCode,
        headers: { "Content-Type": "application/json" },
      });
    });
    const a = newActivity("study");
    await save(a);
    await save({ ...a, name: "두 번째" });
    await save({ ...a, name: "최종 수정" });
    const queue = await db.outbox.orderBy("sequence").toArray();
    expect(queue.map((o) => (o.entity as any).name)).toEqual([
      "공부",
      "두 번째",
      "최종 수정",
    ]);
    await sync();
    expect(await db.outbox.count()).toBe(3);
    await sync();
    expect(repo.get(a.id)?.version).toBe(3);
    expect((repo.get(a.id) as any).name).toBe("최종 수정");
    expect(await db.outbox.count()).toBe(0);
    const stale = await db.entities.get(a.id);
    repo.apply({
      id: "remote-edit",
      baseVersion: 3,
      entity: { ...repo.get(a.id)!, name: "다른 기기" } as any,
    });
    await save({ ...stale!, name: "내 기기" } as any);
    await sync();
    const conflict = await db.conflicts.get(a.id);
    expect((conflict?.local as any).name).toBe("내 기기");
    expect((conflict?.remote as any).name).toBe("다른 기기");
    await resolveConflict(a.id, "local");
    expect((repo.get(a.id) as any).name).toBe("내 기기");
    expect(await db.conflicts.count()).toBe(0);
  } finally {
    vi.unstubAllGlobals();
    await app.close();
    await db.delete();
    rmSync(dir, { recursive: true, force: true });
  }
});
it('복원 충돌에서 현재 기록 유지 선택은 전송 대기열을 보존',async()=>{vi.stubGlobal('window',{dispatchEvent:()=>{}});try{await db.open();const a=newActivity('study');await save(a);await db.conflicts.put({id:a.id,local:{...a,name:'백업 내용'},remote:a,source:'restore'});const pending=await db.outbox.count();await resolveConflict(a.id,'remote');expect(await db.outbox.count()).toBe(pending);expect((await db.entities.get(a.id) as any).name).toBe('공부')}finally{await db.delete();vi.unstubAllGlobals()}});

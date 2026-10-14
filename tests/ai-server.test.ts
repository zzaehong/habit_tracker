import { it, expect, vi } from "vitest";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { createApp, pairingCode } from "../server/app";
import { installAI } from "../server/ai";
import { newActivity, now, type Draft } from "../shared/model";
it("AI 작업 결과 보존 및 중복 요청 방지", async () => {
  const dir = mkdtempSync(tmpdir() + "/chagok-ai-");
  const { app, repo } = await createApp(dir);
  const a = newActivity("study");
  repo.apply({ id: "seed", baseVersion: 0, entity: a });
  const fetchMock = vi.fn().mockResolvedValue({
    ok: true,
    json: async () => ({
      message: {
        content: JSON.stringify({
          records: [
            {
              activityId: a.id,
              date: "2026-10-14",
              data: { seconds: 1800, subject: "회계" },
              questions: [],
            },
          ],
        }),
      },
    }),
  });
  vi.stubGlobal("fetch", fetchMock);
  const worker = installAI(app, repo);
  try {
    const pair = await app.inject({
      method: "POST",
      url: "/api/pair",
      payload: { code: pairingCode(repo), name: "test" },
    });
    const headers = { authorization: "Bearer " + pair.json().token };
    const draft: Draft = {
      id: "draft",
      type: "draft",
      version: 0,
      updatedAt: now(),
      createdAt: now(),
      date: "2026-10-14",
      text: "회계 30분",
      status: "waiting",
      mode: "text",
      attachments: [],
    };
    await app.inject({
      method: "POST",
      url: "/api/ai/jobs",
      headers,
      payload: { draft },
    });
    await vi.waitFor(async () => {
      const r = await app.inject({
        method: "GET",
        url: "/api/ai/jobs/draft",
        headers,
      });
      expect(r.json().status).toBe("review");
    });
    await app.inject({
      method: "POST",
      url: "/api/ai/jobs",
      headers,
      payload: { draft },
    });
    await worker.work();
    expect(fetchMock).toHaveBeenCalledTimes(1);
  } finally {
    vi.unstubAllGlobals();
    await app.close();
    rmSync(dir, { recursive: true, force: true });
  }
});

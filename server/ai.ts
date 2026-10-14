import type { FastifyInstance } from "fastify";
import { z } from "zod";
import { Repository } from "./store";
import { draftSchema, type Activity, type Draft } from "../shared/model";
import { outputSchema, prompt, validateAI } from "../shared/ai";
export type Job = {
  id: string;
  draft: Draft;
  status: "waiting" | "processing" | "review" | "error";
  result?: Draft["result"];
  error?: string;
  ocr?: string;
};
export type CaptureProcessor = (
  draft: Draft,
) => Promise<{ records: NonNullable<Draft["result"]>; ocr: string }>;
export function installAI(
  app: FastifyInstance,
  repo: Repository,
  capture?: CaptureProcessor,
) {
  let running = false,
    closed = false;
  const get = (id: string) => {
    const r = repo.db.prepare("SELECT json FROM jobs WHERE id=?").get(id) as
      { json: string } | undefined;
    return r ? (JSON.parse(r.json) as Job) : undefined;
  };
  const put = (job: Job) =>
    repo.db
      .prepare("INSERT OR REPLACE INTO jobs VALUES(?,?)")
      .run(job.id, JSON.stringify(job));
  for (const row of repo.db.prepare("SELECT json FROM jobs").all() as {
    json: string;
  }[]) {
    const j = JSON.parse(row.json) as Job;
    if (j.status === "processing") put({ ...j, status: "waiting" });
  }
  async function work() {
    if (running || closed) return;
    running = true;
    try {
      while (!closed) {
        const job = (
          repo.db.prepare("SELECT json FROM jobs").all() as { json: string }[]
        )
          .map((r) => JSON.parse(r.json) as Job)
          .find((j) => j.status === "waiting");
        if (!job) break;
        put({ ...job, status: "processing" });
        try {
          if (job.draft.mode === "capture") {
            if (!capture) throw Error("OCR 기능이 준비되지 않았습니다.");
            const result = await capture(job.draft);
            if (!closed)
              put({
                ...job,
                status: "review",
                result: result.records,
                ocr: result.ocr,
              });
            continue;
          }
          const activities = repo
            .all()
            .filter((e): e is Activity => e.type === "activity" && !e.deleted);
          const recent = repo
            .all()
            .filter((e) => e.type === "entry" && !e.deleted)
            .sort((a, b) => b.updatedAt.localeCompare(a.updatedAt))
            .slice(0, 8);
          const modelRow = repo.db
            .prepare("SELECT json FROM settings WHERE key='model'")
            .get() as { json: string } | undefined;
          const model = modelRow ? JSON.parse(modelRow.json) : "qwen3:4b";
          const response = await fetch("http://127.0.0.1:11434/api/chat", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
              model,
              stream: false,
              think: false,
              format: outputSchema,
              options: { temperature: 0, num_ctx: 8192 },
              messages: [
                {
                  role: "user",
                  content: prompt(job.draft, activities, recent),
                },
              ],
            }),
            signal: AbortSignal.timeout(120000),
          });
          if (!response.ok) throw Error("Ollama 모델을 확인하세요.");
          const body = (await response.json()) as {
            message: { content: string };
          };
          const parsed = validateAI(
            JSON.parse(body.message.content),
            activities,
          );
          if (!closed)
            put({ ...job, status: "review", result: parsed.records });
        } catch (e) {
          if (!closed) put({ ...job, status: "error", error: String(e) });
        }
      }
    } finally {
      running = false;
    }
  }
  app.post("/api/ai/jobs", async (req) => {
    const { draft, retry } = z
      .object({ draft: draftSchema, retry: z.boolean().optional() })
      .parse(req.body);
    const existing = get(draft.id);
    if (!existing || (retry && existing.status === "error"))
      put({ id: draft.id, draft, status: "waiting" });
    void work();
    return { id: draft.id };
  });
  app.get<{ Params: { id: string } }>(
    "/api/ai/jobs/:id",
    async (req, reply) => {
      const job = get(req.params.id);
      if (!job) return reply.code(404).send({ error: "작업 없음" });
      return job;
    },
  );
  app.get("/api/ai/settings", async () => {
    const row = repo.db
      .prepare("SELECT json FROM settings WHERE key='model'")
      .get() as { json: string } | undefined;
    let available = false;
    try {
      available = (
        await fetch("http://127.0.0.1:11434/api/tags", {
          signal: AbortSignal.timeout(1500),
        })
      ).ok;
    } catch {}
    return { model: row ? JSON.parse(row.json) : "qwen3:4b", available };
  });
  app.put("/api/ai/settings", async (req) => {
    const { model } = z
      .object({
        model: z
          .string()
          .min(1)
          .max(100)
          .regex(/^[\w./:-]+$/),
      })
      .parse(req.body);
    repo.db
      .prepare("INSERT OR REPLACE INTO settings VALUES('model',?)")
      .run(JSON.stringify(model));
    return { ok: true };
  });
  const timer = setInterval(() => void work(), 5000);
  timer.unref();
  app.addHook("onClose", async () => {
    closed = true;
    clearInterval(timer);
  });
  return { work };
}

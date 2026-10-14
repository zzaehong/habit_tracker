import Fastify from "fastify";
import staticPlugin from "@fastify/static";
import { createHash, randomBytes, randomInt } from "node:crypto";
import { mkdirSync, existsSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { z } from "zod";
import { Repository } from "./store";
import { opSchema } from "../shared/model";
export const hash = (s: string | Buffer) =>
  createHash("sha256").update(s).digest("hex");
export function pairingCode(repo: Repository) {
  const code = String(randomInt(10000000, 99999999));
  repo.db
    .prepare("INSERT INTO codes VALUES(?,?)")
    .run(hash(code), Date.now() + 10 * 60 * 1000);
  return code;
}
export async function createApp(directory: string, serveStatic = false) {
  mkdirSync(directory, { recursive: true, mode: 0o700 });
  const repo = new Repository(path.join(directory, "chagok.sqlite"));
  const app = Fastify({ logger: false, bodyLimit: 15 * 1024 * 1024 });
  const files = path.join(directory, "attachments");
  mkdirSync(files, { recursive: true, mode: 0o700 });
  app.setErrorHandler((err, _req, reply) => {
    const e = err as Error & { statusCode?: number };
    reply.code(e instanceof z.ZodError ? 400 : e.statusCode || 500).send({
      error:
        e instanceof z.ZodError
          ? "입력 형식이 올바르지 않습니다."
          : e.statusCode
            ? e.message
            : "요청 처리에 실패했습니다.",
    });
  });
  const attempts = new Map<string, { count: number; time: number }>();
  app.addHook("onRequest", async (req, reply) => {
    if (!req.url.startsWith("/api/")) return;
    const origin = req.headers.origin;
    if (origin && new URL(origin).host !== req.headers.host)
      return reply.code(403).send({ error: "허용되지 않은 출처" });
    if (req.url === "/api/pair") return;
    const token = req.headers.authorization?.replace(/^Bearer /, "");
    if (
      !token ||
      !repo.db.prepare("SELECT id FROM devices WHERE token=?").get(hash(token))
    )
      return reply.code(401).send({ error: "기기 연결이 필요합니다." });
  });
  app.post("/api/pair", async (req, reply) => {
    const ip = req.ip;
    const prior = attempts.get(ip);
    const state =
      prior && Date.now() - prior.time < 60000
        ? prior
        : { count: 0, time: Date.now() };
    state.count++;
    attempts.set(ip, state);
    if (state.count > 10)
      return reply.code(429).send({ error: "잠시 후 다시 시도하세요." });
    const { code, name } = z
      .object({ code: z.string(), name: z.string().min(1).max(100) })
      .parse(req.body);
    const valid = repo.db
      .prepare("SELECT hash FROM codes WHERE hash=? AND expires>?")
      .get(hash(code), Date.now());
    if (!valid)
      return reply
        .code(403)
        .send({ error: "코드가 잘못되었거나 만료되었습니다." });
    const token = randomBytes(32).toString("hex"),
      id = crypto.randomUUID();
    repo.db.exec("BEGIN IMMEDIATE");
    try {
      repo.db.prepare("DELETE FROM codes WHERE hash=?").run(hash(code));
      repo.db
        .prepare("INSERT INTO devices VALUES(?,?,?,?)")
        .run(id, name, hash(token), new Date().toISOString());
      repo.db.exec("COMMIT");
    } catch (e) {
      repo.db.exec("ROLLBACK");
      throw e;
    }
    return { token, id };
  });
  app.get("/api/devices", async () =>
    repo.db.prepare("SELECT id,name,created FROM devices").all(),
  );
  app.delete<{ Params: { id: string } }>("/api/devices/:id", async (req) => {
    repo.db.prepare("DELETE FROM devices WHERE id=?").run(req.params.id);
    return { ok: true };
  });
  app.post("/api/sync", async (req) => {
    const { operations, cursor } = z
      .object({
        operations: z.array(opSchema).max(100),
        cursor: z.number().int().nonnegative(),
      })
      .parse(req.body);
    const results = operations.map((op) => ({ id: op.id, ...repo.apply(op) }));
    return { ...repo.changes(cursor), results };
  });
  app.put<{ Params: { id: string } }>(
    "/api/attachments/:id",
    async (req, reply) => {
      const { data, mime } = z
        .object({
          data: z.string().max(14 * 1024 * 1024),
          mime: z.enum(["image/png", "image/jpeg"]),
        })
        .parse(req.body);
      if (!/^[a-f0-9]{64}$/.test(req.params.id))
        return reply.code(400).send({ error: "잘못된 이미지 해시" });
      const bytes = Buffer.from(data, "base64");
      const png = bytes
        .subarray(0, 8)
        .equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]));
      const jpg = bytes[0] === 255 && bytes[1] === 216 && bytes[2] === 255;
      if (
        bytes.length > 10 * 1024 * 1024 ||
        hash(bytes) !== req.params.id ||
        !(mime === "image/png" ? png : jpg)
      )
        return reply.code(400).send({ error: "이미지 형식 또는 해시 오류" });
      writeFileSync(path.join(files, req.params.id), bytes, { mode: 0o600 });
      return { ok: true };
    },
  );
  app.get<{ Params: { id: string } }>(
    "/api/attachments/:id",
    async (req, reply) => {
      const metadata = repo
        .all()
        .find(
          (e) =>
            e.type === "attachment" && !e.deleted && e.hash === req.params.id,
        );
      if (
        !metadata ||
        metadata.type !== "attachment" ||
        !/^[a-f0-9]{64}$/.test(req.params.id) ||
        !existsSync(path.join(files, req.params.id))
      )
        return reply.code(404).send({ error: "이미지 없음" });
      return reply
        .header("Cache-Control", "no-store")
        .type(metadata.mime)
        .send(readFileSync(path.join(files, req.params.id)));
    },
  );
  app.delete<{ Params: { id: string } }>(
    "/api/attachments/:id",
    async (req, reply) => {
      const entity = repo.get(req.params.id);
      if (!entity || entity.type !== "attachment")
        return reply.code(404).send();
      return repo.apply({
        id: crypto.randomUUID(),
        baseVersion: entity.version,
        entity: { ...entity, deleted: true },
      });
    },
  );
  app.get("/api/health", async () => ({
    ok: true,
    db: true,
    ocr: existsSync(path.join(directory, "ocr")),
    pendingJobs: (
      repo.db
        .prepare(
          'SELECT COUNT(*) AS count FROM jobs WHERE json LIKE \'%"status":"waiting"%\'',
        )
        .get() as { count: number }
    ).count,
  }));
  if (serveStatic) {
    await app.register(staticPlugin, {
      root: path.resolve("dist"),
      wildcard: true,
    });
    app.setNotFoundHandler((req, reply) =>
      req.url.startsWith("/api/")
        ? reply.code(404).send({ error: "없음" })
        : reply.sendFile("index.html"),
    );
  }
  app.addHook("onClose", async () => repo.close());
  return { app, repo, files };
}

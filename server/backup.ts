import { backup, DatabaseSync } from "node:sqlite";
import {
  mkdirSync,
  existsSync,
  copyFileSync,
  readFileSync,
  writeFileSync,
  readdirSync,
  statSync,
  renameSync,
  rmSync,
} from "node:fs";
import path from "node:path";
import type { FastifyInstance } from "fastify";
import type { Attachment } from "../shared/model";
import { Repository } from "./store";
import { hash } from "./app";
export type Snapshot = {
  id: string;
  createdAt: string;
  database: string;
  attachments: string[];
};
export async function createSnapshot(repo: Repository, dir: string) {
  const root = path.resolve(dir, "backups");
  mkdirSync(path.join(root, "blobs"), { recursive: true, mode: 0o700 });
  const id =
    new Date().toISOString().replace(/[:.]/g, "-") +
    "-" +
    crypto.randomUUID().slice(0, 8);
  const database = id + ".sqlite";
  const destination = path.join(root, database);
  await backup(repo.db, destination);
  const snapshotDB = new DatabaseSync(destination, { readOnly: true });
  let attachments: Attachment[];
  try {
    attachments = (
      snapshotDB.prepare("SELECT json FROM entities").all() as {
        json: string;
      }[]
    )
      .map((r) => JSON.parse(r.json))
      .filter((e): e is Attachment => e.type === "attachment" && !e.deleted);
  } finally {
    snapshotDB.close();
  }
  const hashes = [...new Set(attachments.map((a) => a.hash))];
  for (const digest of hashes) {
    const source = path.resolve(dir, "attachments", digest);
    if (!existsSync(source) || hash(readFileSync(source)) !== digest)
      throw Error("백업에 필요한 이미지가 없거나 손상되었습니다.");
    const dest = path.join(root, "blobs", digest);
    if (!existsSync(dest)) copyFileSync(source, dest);
  }
  const result: Snapshot = {
    id,
    createdAt: new Date().toISOString(),
    database,
    attachments: hashes,
  };
  writeFileSync(path.join(root, id + ".json.tmp"), JSON.stringify(result), {
    mode: 0o600,
  });
  renameSync(path.join(root, id + ".json.tmp"), path.join(root, id + ".json"));
  const snapshots = listSnapshots(dir);
  for (const old of snapshots.slice(30)) {
    rmSync(path.join(root, old.database), { force: true });
    rmSync(path.join(root, old.id + ".json"), { force: true });
  }
  const retained = new Set(listSnapshots(dir).flatMap((s) => s.attachments));
  for (const file of readdirSync(path.join(root, "blobs")))
    if (!retained.has(file)) rmSync(path.join(root, "blobs", file));
  repo.db
    .prepare("INSERT OR REPLACE INTO settings VALUES('lastBackup',?)")
    .run(JSON.stringify(result.createdAt));
  repo.db.prepare("DELETE FROM settings WHERE key='backupError'").run();
  return result;
}
export function listSnapshots(dir: string): Snapshot[] {
  const root = path.resolve(dir, "backups");
  if (!existsSync(root)) return [];
  return readdirSync(root)
    .filter((f) => f.endsWith(".json"))
    .map(
      (f) => JSON.parse(readFileSync(path.join(root, f), "utf8")) as Snapshot,
    )
    .sort((a, b) => b.createdAt.localeCompare(a.createdAt));
}
export function installBackups(
  app: FastifyInstance,
  repo: Repository,
  dir: string,
) {
  let active: Promise<Snapshot> | undefined;
  let stopped = false;
  const setting = (key: string) => {
    const r = repo.db
      .prepare("SELECT json FROM settings WHERE key=?")
      .get(key) as { json: string } | undefined;
    return r ? JSON.parse(r.json) : undefined;
  };
  const run = () => {
    if (!active) {
      active = createSnapshot(repo, dir)
        .catch((e) => {
          repo.db
            .prepare("INSERT OR REPLACE INTO settings VALUES('backupError',?)")
            .run(JSON.stringify(String(e)));
          throw e;
        })
        .finally(() => {
          active = undefined;
        });
    }
    return active;
  };
  app.get("/api/operations", async () => ({
    lastBackup: setting("lastBackup"),
    backupError: setting("backupError"),
    snapshots: listSnapshots(dir).length,
    attachmentBytes: existsSync(path.join(dir, "attachments"))
      ? readdirSync(path.join(dir, "attachments")).reduce(
          (n, f) => n + statSync(path.join(dir, "attachments", f)).size,
          0,
        )
      : 0,
  }));
  app.post("/api/backups", async () => run());
  const check = () => {
    if (stopped) return;
    const last = setting("lastBackup");
    if (!last || Date.now() - Date.parse(last) > 86400000)
      void run().catch(() => {});
  };
  const timer = setInterval(check, 60000);
  timer.unref();
  app.addHook("onReady", async () => {
    check();
  });
  app.addHook("preClose", async () => {
    stopped = true;
    clearInterval(timer);
    if (active) await active.catch(() => {});
  });
  return { run };
}

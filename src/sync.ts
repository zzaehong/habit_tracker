import { db, getMeta, setMeta, enqueue } from "./db";
import type { Entity, Operation } from "../shared/model";
export async function api(url: string, options: RequestInit = {}) {
  const token = await getMeta("token");
  const res = await fetch(url, {
    ...options,
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...options.headers,
    },
    signal: options.signal || AbortSignal.timeout(20000),
  });
  if (!res.ok)
    throw Error(
      (await res.json().catch(() => ({}))).error || `서버 오류 ${res.status}`,
    );
  return res;
}
let running = false;
export async function sync() {
  if (running || !(await getMeta("token"))) return;
  running = true;
  try {
    const attachments = await db.entities
      .where("type")
      .equals("attachment")
      .toArray();
    for (const a of attachments) {
      if (
        a.type !== "attachment" ||
        a.deleted ||
        (await getMeta("uploaded:" + a.hash))
      )
        continue;
      const file = await db.blobs.get(a.id);
      if (!file) continue;
      const data = await new Promise<string>((resolve, reject) => {
        const r = new FileReader();
        r.onload = () => resolve(String(r.result).split(",")[1]);
        r.onerror = reject;
        r.readAsDataURL(file.blob);
      });
      await api("/api/attachments/" + a.hash, {
        method: "PUT",
        body: JSON.stringify({ data, mime: a.mime }),
      });
      await setMeta("uploaded:" + a.hash, true);
    }
    let more = true;
    let passes = 0;
    while (more && passes++ < 500) {
      const conflicts = await db.conflicts.toArray();
      const operations = (await db.outbox.orderBy("sequence").toArray())
        .filter((o) => !conflicts.some((c) => c.id === o.entity.id))
        .slice(0, 1);
      const result = (await (
        await api("/api/sync", {
          method: "POST",
          body: JSON.stringify({
            operations,
            cursor: (await getMeta("cursor")) || 0,
          }),
        })
      ).json()) as {
        results: { id: string; entity?: Entity; conflict?: Entity }[];
        changes: Entity[];
        cursor: number;
        more: boolean;
      };
      await db.transaction(
        "rw",
        db.outbox,
        db.entities,
        db.meta,
        db.conflicts,
        async () => {
          for (const r of result.results) {
            const op = await db.outbox.get(r.id);
            if (!op) continue;
            if (r.conflict) {
              const local = (await db.entities.get(op.entity.id)) || op.entity;
              await db.conflicts.put({
                id: op.entity.id,
                local,
                remote: r.conflict,
              });
              continue;
            }
            await db.outbox.delete(r.id);
            if (r.entity) {
              const remaining = (await db.outbox.toArray()).filter(
                (o) => o.entity.id === r.entity!.id,
              );
              for (const p of remaining)
                await db.outbox.put({
                  ...p,
                  baseVersion: r.entity.version,
                  entity: { ...p.entity, version: r.entity.version },
                });
              if (!remaining.length) await db.entities.put(r.entity);
              else {
                const current = await db.entities.get(r.entity.id);
                if (current)
                  await db.entities.put({
                    ...current,
                    version: r.entity.version,
                  });
              }
            }
          }
          for (const entity of result.changes) {
            const dirty = (await db.outbox.toArray()).some(
              (o) => o.entity.id === entity.id,
            );
            if (!dirty && !(await db.conflicts.get(entity.id)))
              await db.entities.put(entity);
          }
          await db.meta.put({ key: "cursor", value: result.cursor });
        },
      );
      more =
        result.more ||
        (await db.outbox.toArray()).some(
          (o) =>
            !conflicts.some((c) => c.id === o.entity.id) &&
            !result.results.some((r) => r.conflict?.id === o.entity.id),
        );
    }
    for (const a of await db.entities
      .where("type")
      .equals("attachment")
      .toArray()) {
      if (
        a.type === "attachment" &&
        !a.deleted &&
        !(await db.blobs.get(a.id))
      ) {
        const res = await api("/api/attachments/" + a.hash);
        await db.blobs.put({ id: a.id, blob: await res.blob() });
        await setMeta("uploaded:" + a.hash, true);
      }
    }
    await setMeta("lastSync", new Date().toISOString());
    await setMeta("syncError", "");
    window.dispatchEvent(new Event("sync-complete"));
  } catch (e) {
    await setMeta("syncError", String(e));
  } finally {
    running = false;
  }
}
export async function resolveConflict(
  id: string,
  choice: "local" | "remote" | "both",
) {
  const conflict = await db.conflicts.get(id);
  if (!conflict) return;
  await db.transaction(
    "rw",
    db.entities,
    db.outbox,
    db.conflicts,
    db.meta,
    async () => {
      if (conflict.source === "restore" && choice === "remote") {
        await db.conflicts.delete(id);
        return;
      }
      const keepPending = conflict.source === "restore" && choice === "both";
      if (!keepPending)
        for (const op of await db.outbox.toArray())
          if (op.entity.id === id) await db.outbox.delete(op.id);
      await db.entities.put(conflict.remote);
      if (choice === "local") {
        const entity = { ...conflict.local, version: conflict.remote.version };
        await db.entities.put(entity);
        await enqueue(entity, entity.version);
      }
      if (choice === "both") {
        const entity = {
          ...conflict.local,
          id: crypto.randomUUID(),
          version: 0,
        };
        await db.entities.put(entity);
        await enqueue(entity, 0);
      }
      await db.conflicts.delete(id);
    },
  );
  await sync();
}
export function startSync() {
  const trigger = () => {
    if (document.visibilityState !== "hidden") void sync();
  };
  window.addEventListener("online", trigger);
  window.addEventListener("local-change", trigger);
  document.addEventListener("visibilitychange", trigger);
  const timer = setInterval(trigger, 30000);
  trigger();
  return () => {
    clearInterval(timer);
    window.removeEventListener("online", trigger);
    window.removeEventListener("local-change", trigger);
    document.removeEventListener("visibilitychange", trigger);
  };
}

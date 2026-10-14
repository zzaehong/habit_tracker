import Dexie, { type Table } from "dexie";
import {
  type Entity,
  type Operation,
  type Conflict,
  type Activity,
  entitySchema,
  newActivity,
  now,
} from "../shared/model";
class Store extends Dexie {
  entities!: Table<Entity, string>;
  outbox!: Table<Operation, string>;
  conflicts!: Table<Conflict, string>;
  meta!: Table<{ key: string; value: any }, string>;
  blobs!: Table<{ id: string; blob: Blob }, string>;
  constructor() {
    super("chagok");
    this.version(1).stores({
      entities: "id,type",
      outbox: "id",
      conflicts: "id",
      meta: "key",
      blobs: "id",
    });
    this.version(2)
      .stores({ outbox: "id,sequence" })
      .upgrade(async (tx) => {
        const rows = await tx.table("outbox").toArray();
        rows.sort((a, b) =>
          a.entity.updatedAt.localeCompare(b.entity.updatedAt),
        );
        let sequence = 0;
        for (const op of rows)
          await tx.table("outbox").put({ ...op, sequence: ++sequence });
        await tx.table("meta").put({ key: "nextOperation", value: sequence });
      });
  }
}
export const db = new Store();
export async function save(entity: Entity) {
  const valid = entitySchema.parse({ ...entity, updatedAt: now() });
  await db.transaction("rw", db.entities, db.outbox, db.meta, async () => {
    await db.entities.put(valid);
    await enqueue(valid, entity.version);
  });
  window.dispatchEvent(new Event("local-change"));
  return valid;
}
export async function remove(e: Entity) {
  await save({ ...e, deleted: true });
}
export async function initialize() {
  await db.transaction("rw", db.entities, db.outbox, db.meta, async () => {
    if (await db.meta.get("initialized")) return;
    for (const k of [
      "reading",
      "running",
      "weights",
      "meal",
      "tutoring",
      "study",
    ] as const) {
      const a = newActivity(k);
      a.id = "default-" + k;
      await db.entities.put(a);
      await enqueue(a, 0, true);
    }
    await db.meta.put({ key: "initialized", value: true });
  });
  navigator.storage?.persist?.().catch(() => {});
}
export async function getMeta(key: string) {
  return (await db.meta.get(key))?.value;
}
export async function setMeta(key: string, value: any) {
  await db.meta.put({ key, value });
}
export async function saveDefinition(a: Activity) {
  await save(a);
}

// Must be called inside a transaction containing meta and outbox.
export async function enqueue(
  entity: Entity,
  baseVersion: number,
  bootstrap = false,
) {
  const sequence = ((await db.meta.get("nextOperation"))?.value || 0) + 1;
  await db.meta.put({ key: "nextOperation", value: sequence });
  await db.outbox.add({
    id: crypto.randomUUID(),
    baseVersion,
    entity,
    sequence,
    bootstrap,
  });
}

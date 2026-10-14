import { z } from "zod";
import { entitySchema, type Entity } from "./model";
export const backupSchema = z
  .object({
    format: z.literal("chagok"),
    version: z.literal(1),
    exportedAt: z.string(),
    entities: z.array(entitySchema),
  })
  .superRefine((v, ctx) => {
    if (new Set(v.entities.map((e) => e.id)).size !== v.entities.length)
      ctx.addIssue({ code: "custom", message: "중복 ID가 있습니다." });
  });
export function makeBackup(entities: Entity[]) {
  return {
    format: "chagok" as const,
    version: 1 as const,
    exportedAt: new Date().toISOString(),
    entities,
  };
}
export function csv(rows: unknown[][]) {
  return (
    "\ufeff" +
    rows
      .map((row) =>
        row
          .map((v) => {
            let s = v === undefined || v === null ? "" : String(v);
            if (/^[=+@\-]/.test(s)) s = "'" + s;
            return '"' + s.replaceAll('"', '""') + '"';
          })
          .join(","),
      )
      .join("\r\n")
  );
}
export function comparable(e: Entity) {
  const { version, updatedAt, ...rest } = e;
  return JSON.stringify(rest);
}

export function selectBackup(
  entities: Entity[],
  from = "",
  to = "",
  activityId = "",
): Entity[] {
  const inRange = (date: string) =>
    (!from || date >= from) && (!to || date <= to);
  const records = entities.filter(
    (e) =>
      e.type === "entry" &&
      inRange(e.date) &&
      (!activityId || e.activityId === activityId),
  );
  const draftIds = new Set(
    records.flatMap((e) =>
      e.type === "entry" && e.draftId ? [e.draftId] : [],
    ),
  );
  const drafts = entities.filter(
    (e) =>
      e.type === "draft" &&
      (draftIds.has(e.id) ||
        (inRange(e.date) && (!activityId || e.activityId === activityId))),
  );
  const included = new Set([...records, ...drafts].map((e) => e.id));
  const images = new Set(
    [...records, ...drafts].flatMap((e) =>
      e.type === "entry" || e.type === "draft" ? e.attachments : [],
    ),
  );
  return entities.filter(
    (e) =>
      included.has(e.id) ||
      (e.type === "activity" && (!activityId || e.id === activityId)) ||
      e.type === "mealPlan" ||
      (e.type === "attachment" &&
        (images.has(e.id) || (!from && !to && !activityId))),
  );
}

import { z } from "zod";
export const kinds = [
  "reading",
  "running",
  "weights",
  "meal",
  "tutoring",
  "study",
  "check",
] as const;
export type Kind = (typeof kinds)[number];
export const labels: Record<Kind, string> = {
  reading: "독서",
  running: "러닝",
  weights: "웨이트",
  meal: "Meal Prep",
  tutoring: "과외",
  study: "공부",
  check: "일반 활동",
};
export const dateSchema=z.string().regex(/^\d{4}-\d{2}-\d{2}$/).refine(value=>Number.isFinite(Date.parse(value+"T00:00:00Z"))&&new Date(value+"T00:00:00Z").toISOString().slice(0,10)===value,"올바른 날짜를 입력하세요.");
export const scheduleSchema = z.object({
  type: z.enum(["daily", "weekdays", "weekly", "interval", "once"]),
  start: dateSchema,
  weekdays: z.array(z.number().int().min(0).max(6)).default([]),
  count: z.number().int().min(1).max(7).default(3),
  interval: z.number().int().min(1).default(2),
});
export type Schedule = z.infer<typeof scheduleSchema>;
export const fieldSchema = z.object({
  id: z.string(),
  name: z.string().min(1),
  type: z.enum(["number", "text", "select"]),
  unit: z.string().default(""),
  options: z.array(z.string()).default([]),
  aggregate: z.enum(["sum", "mean"]).default("sum"),
  hidden: z.boolean().default(false),
});
export type Field = z.infer<typeof fieldSchema>;
const base = {
  id: z.string().min(1),
  version: z.number().int().nonnegative(),
  updatedAt: z.string(),
  deleted: z.boolean().optional(),
};
export const activitySchema = z.object({
  ...base,
  type: z.literal("activity"),
  name: z.string().min(1),
  kind: z.enum(kinds),
  fields: z.array(fieldSchema),
  schedule: z.array(
    z.object({
      effective: dateSchema,
      value: scheduleSchema,
      enabled: z.boolean().optional(),
    }),
  ),
  enabled: z.boolean().default(true),
});
export type Activity = z.infer<typeof activitySchema>;
export const setSchema = z.object({
  exercise: z.string().min(1),
  kg: z.number().nonnegative(),
  reps: z.number().int().nonnegative(),
  done: z.boolean(),
});
export const dataSchema = z.object({
  book: z.string().optional(),
  startPage: z.number().int().nonnegative().optional(),
  lastPage: z.number().int().nonnegative().optional(),
  seconds: z.number().nonnegative().optional(),
  note: z.string().optional(),
  distance: z.number().nonnegative().optional(),
  intensity: z.number().min(1).max(10).optional(),
  heartRate: z.number().positive().optional(),
  cadence: z.number().positive().optional(),
  reportedPace: z.number().positive().optional(),
  subject: z.string().optional(),
  alias: z.string().optional(),
  plannedSeconds: z.number().nonnegative().optional(),
  sets: z.array(setSchema).optional(),
  slot: z.string().optional(),
  mealStatus: z.enum(["planned", "outside", "skipped"]).optional(),
  mealTime: z.string().optional(),
  menu: z.string().optional(),
  kcal: z.number().nonnegative().optional(),
  carbs: z.number().nonnegative().optional(),
  protein: z.number().nonnegative().optional(),
  fat: z.number().nonnegative().optional(),
  custom: z.record(z.union([z.string(), z.number()])).default({}),
});
export type RecordData = z.infer<typeof dataSchema>;
export const entrySchema = z.object({
  ...base,
  type: z.literal("entry"),
  activityId: z.string(),
  date: dateSchema,
  timezone: z.string(),
  done: z.boolean(),
  data: dataSchema,
  definition: activitySchema,
  source: z.enum(["manual", "reuse", "ai", "capture"]),
  draftId: z.string().optional(),
  attachments: z.array(z.string()).default([]),
});
export type Entry = z.infer<typeof entrySchema>;
export const mealPlanSchema = z.object({
  ...base,
  type: z.literal("mealPlan"),
  slot: z.string(),
  menu: z.string(),
  kcal: z.number().nonnegative(),
  carbs: z.number().nonnegative(),
  protein: z.number().nonnegative(),
  fat: z.number().nonnegative(),
  enabled: z.boolean(),
  weekdays: z.array(z.number().int().min(0).max(6)),
});
export type MealPlan = z.infer<typeof mealPlanSchema>;
export const draftSchema = z.object({
  ...base,
  type: z.literal("draft"),
  text: z.string(),
  createdAt: z.string(),
  date: z.string(),
  status: z.enum(["waiting", "processing", "review", "saved", "error"]),
  mode: z.enum(["text", "capture"]),
  activityId: z.string().optional(),
  attachments: z.array(z.string()),
  result: z
    .array(
      z.object({
        activityId: z.string(),
        date: z.string(),
        data: dataSchema,
        questions: z.array(z.string()).default([]),
      }),
    )
    .optional(),
  error: z.string().optional(),
  ocr: z.string().optional(),
});
export type Draft = z.infer<typeof draftSchema>;
export const attachmentSchema = z.object({
  ...base,
  type: z.literal("attachment"),
  hash: z.string().regex(/^[a-f0-9]{64}$/),
  name: z.string(),
  mime: z.enum(["image/png", "image/jpeg"]),
  size: z
    .number()
    .max(10 * 1024 * 1024)
    .nonnegative(),
});
export type Attachment = z.infer<typeof attachmentSchema>;
export const entitySchema = z.discriminatedUnion("type", [
  activitySchema,
  entrySchema,
  mealPlanSchema,
  draftSchema,
  attachmentSchema,
]);
export type Entity = z.infer<typeof entitySchema>;
export const opSchema = z.object({
  id: z.string(),
  baseVersion: z.number().int().nonnegative(),
  sequence: z.number().int().nonnegative().optional(),
  bootstrap: z.boolean().optional(),
  entity: entitySchema,
});
export type Operation = z.infer<typeof opSchema>;
export type Conflict = {
  id: string;
  local: Entity;
  remote: Entity;
  source?: "sync" | "restore";
};
export function now() {
  return new Date().toISOString();
}
export function today() {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Seoul",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date());
}
export function addDays(date: string, n: number) {
  return new Date(Date.parse(date + "T00:00:00Z") + n * 86400000)
    .toISOString()
    .slice(0, 10);
}
export function weekday(date: string) {
  return new Date(date + "T00:00:00Z").getUTCDay();
}
export function weekStart(date: string) {
  return addDays(date, -((weekday(date) + 6) % 7));
}
export function scheduleAt(a: Activity, date: string) {
  return [...a.schedule]
    .sort((x, y) => x.effective.localeCompare(y.effective))
    .filter((s) => s.effective <= date)
    .at(-1)?.value;
}
export function enabledAt(a: Activity, date: string) {
  return (
    [...a.schedule]
      .sort((x, y) => x.effective.localeCompare(y.effective))
      .filter((s) => s.effective <= date)
      .at(-1)?.enabled ?? true
  );
}
export function isDue(a: Activity, date: string, entries: Entry[] = []) {
  const s = scheduleAt(a, date);
  if (!enabledAt(a, date) || !s || date < s.start) return false;
  switch (s.type) {
    case "daily":
      return true;
    case "weekdays":
      return s.weekdays.includes(weekday(date));
    case "weekly":
      return true;
    case "interval":
      return (
        Math.round((Date.parse(date) - Date.parse(s.start)) / 86400000) %
          s.interval ===
        0
      );
    case "once":
      return !entries.some(
        (e) =>
          !e.deleted &&
          e.activityId === a.id &&
          e.done &&
          e.date >= s.start &&
          e.date < date,
      );
  }
}
export function weeklyCount(a: Activity, date: string, entries: Entry[]) {
  return new Set(
    entries
      .filter(
        (e) =>
          !e.deleted &&
          e.done &&
          e.activityId === a.id &&
          e.date >= weekStart(date) &&
          e.date <= addDays(weekStart(date), 6),
      )
      .map((e) => e.date),
  ).size;
}
export function pace(data: RecordData) {
  return data.distance && data.seconds !== undefined
    ? data.seconds / data.distance
    : undefined;
}
export function duration(seconds?: number) {
  if (seconds === undefined) return "—";
  const rounded = Math.round(seconds);
  return `${Math.floor(rounded / 60)}:${String(rounded % 60).padStart(2, "0")}`;
}
export function newActivity(kind: Kind, name = labels[kind]): Activity {
  return {
    id: crypto.randomUUID(),
    type: "activity",
    version: 0,
    updatedAt: now(),
    name,
    kind,
    fields: [],
    enabled: true,
    schedule: [
      {
        effective: today(),
        enabled: true,
        value: {
          type: "daily",
          start: today(),
          weekdays: [1, 2, 3, 4, 5],
          count: 3,
          interval: 2,
        },
      },
    ],
  };
}
export function summarize(e: Entry) {
  const d = e.data;
  switch (e.definition.kind) {
    case "reading":
      return [
        d.book,
        d.lastPage !== undefined ? `${d.lastPage}쪽` : null,
        d.seconds !== undefined ? duration(d.seconds) : null,
      ]
        .filter(Boolean)
        .join(" · ");
    case "running":
      return [
        d.distance !== undefined ? `${d.distance} km` : null,
        d.seconds !== undefined ? duration(d.seconds) : null,
        pace(d) !== undefined ? `${duration(pace(d))}/km` : null,
      ]
        .filter(Boolean)
        .join(" · ");
    case "weights":
      return `${d.sets?.filter((s) => s.done).length || 0}세트 완료`;
    case "meal":
      return `${d.slot || ""} · ${{ planned: "식단대로 먹음", outside: "외식/대체식", skipped: "거름" }[d.mealStatus || "planned"]} · ${d.menu || ""}`;
    default:
      return [
        d.subject,
        d.alias,
        d.seconds !== undefined ? duration(d.seconds) : null,
        d.note,
      ]
        .filter(Boolean)
        .join(" · ");
  }
}

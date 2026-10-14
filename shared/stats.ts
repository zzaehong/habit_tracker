import {
  type Entry,
  type Activity,
  addDays,
  isDue,
  weekStart,
  scheduleAt,
  weeklyCount,
  enabledAt,
} from "./model";
export function values(entries: Entry[], key: string) {
  return entries
    .map((e) => (e.data as any)[key])
    .filter((v): v is number => typeof v === "number" && Number.isFinite(v));
}
export function sum(v: number[]) {
  return v.length ? v.reduce((a, b) => a + b, 0) : undefined;
}
export function mean(v: number[]) {
  return v.length ? v.reduce((a, b) => a + b, 0) / v.length : undefined;
}
export function days(from: string, to: string) {
  const out: string[] = [];
  if(!/^\d{4}-\d{2}-\d{2}$/.test(from)||!/^\d{4}-\d{2}-\d{2}$/.test(to)||!Number.isFinite(Date.parse(from))||!Number.isFinite(Date.parse(to)))return out;
  for (let d = from; d <= to && out.length < 3660; d = addDays(d, 1))
    out.push(d);
  return out;
}
export function achievement(
  a: Activity,
  entries: Entry[],
  from: string,
  to: string,
) {
  let expected = 0,
    done = 0;
  const weeks = new Set<string>();
  for (const date of days(from, to)) {
    const s = scheduleAt(a, date);
    if (!s || !enabledAt(a, date) || date < s.start) continue;
    if (s.type === "weekly") {
      const w = weekStart(date);
      if (weeks.has(w)) continue;
      weeks.add(w);
      expected += s.count;
      done += Math.min(s.count, weeklyCount(a, date, entries));
      continue;
    }
    if (s.type === "once" && date !== s.start) continue;
    if (isDue(a, date, [])) {
      expected++;
      if (
        entries.some(
          (e) =>
            !e.deleted &&
            e.done &&
            e.activityId === a.id &&
            (s.type === "once"
              ? e.date >= date && e.date <= to
              : e.date === date),
        )
      )
        done++;
    }
  }
  return { done, expected };
}

export type TrendMetric =
  | "count"
  | "distance"
  | "pace"
  | "heartRate"
  | "cadence"
  | "reading"
  | "study"
  | "volume"
  | "kcal";
export const trendLabels: Record<TrendMetric, string> = {
  count: "완료 횟수",
  distance: "러닝 거리 (km)",
  pace: "러닝 페이스 (초/km)",
  heartRate: "평균 심박수 (bpm)",
  cadence: "평균 케이던스 (steps/min)",
  reading: "독서 분량 (쪽)",
  study: "공부 시간 (분)",
  volume: "웨이트 볼륨 (kg)",
  kcal: "알려진 열량 (kcal)",
};
export function trendValue(entries: Entry[], metric: TrendMetric) {
  if (metric === "count") return entries.filter((e) => e.done).length;
  if (metric === "distance")
    return sum(
      values(
        entries.filter((e) => e.definition.kind === "running"),
        "distance",
      ),
    );
  if (metric === "heartRate" || metric === "cadence")
    return mean(
      values(
        entries.filter((e) => e.definition.kind === "running"),
        metric,
      ),
    );
  if (metric === "pace") {
    const valid = entries.filter(
      (e) =>
        e.definition.kind === "running" &&
        e.data.distance &&
        e.data.seconds !== undefined,
    );
    return valid.length
      ? valid.reduce((n, e) => n + e.data.seconds!, 0) /
          valid.reduce((n, e) => n + e.data.distance!, 0)
      : undefined;
  }
  if (metric === "reading")
    return sum(
      entries
        .filter(
          (e) =>
            e.definition.kind === "reading" &&
            e.data.startPage !== undefined &&
            e.data.lastPage !== undefined,
        )
        .map((e) => Math.max(0, e.data.lastPage! - e.data.startPage!)),
    );
  if (metric === "study") {
    const seconds = sum(
      values(
        entries.filter((e) => e.definition.kind === "study"),
        "seconds",
      ),
    );
    return seconds === undefined ? undefined : seconds / 60;
  }
  if (metric === "kcal")
    return sum(
      values(
        entries.filter(
          (e) =>
            e.definition.kind === "meal" && e.data.mealStatus !== "skipped",
        ),
        "kcal",
      ),
    );
  return sum(
    entries
      .filter((e) => e.definition.kind === "weights")
      .flatMap((e) =>
        (e.data.sets || []).filter((s) => s.done).map((s) => s.kg * s.reps),
      ),
  );
}

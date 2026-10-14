import { useState } from "react";
import {
  type Entry,
  type Activity,
  weekStart,
  today,
  addDays,
  pace,
  duration,
} from "../shared/model";
import {
  sum,
  mean,
  values,
  days,
  achievement,
  trendValue,
  trendLabels,
  type TrendMetric,
} from "../shared/stats";
import { nutritionSummary } from "../shared/meals";
export function Insights({
  entries,
  activities,
}: {
  entries: Entry[];
  activities: Activity[];
}) {
  const [from, setFrom] = useState(weekStart(today())),
    [to, setTo] = useState(today()),
    [activity, setActivity] = useState("");
  const [trend, setTrend] = useState<TrendMetric>("count");
  const rows = entries.filter(
    (e) =>
      e.date >= from &&
      e.date <= to &&
      (!activity || e.activityId === activity),
  );
  const running = rows.filter((e) => e.definition.kind === "running");
  const reading = rows.filter((e) => e.definition.kind === "reading");
  const study = rows.filter((e) => e.definition.kind === "study");
  const tutoring = rows.filter((e) => e.definition.kind === "tutoring");
  const weights = rows.filter((e) => e.definition.kind === "weights");
  const nutrition = nutritionSummary(rows);
  const display = (v: number | undefined, unit = "") =>
    v === undefined ? "—" : `${Number(v.toFixed(1))} ${unit}`;
  const ds = days(from, to);
  const counts = ds.map((d) =>
    trendValue(
      rows.filter((e) => e.date === d),
      trend,
    ),
  );
  const max = Math.max(
    1,
    ...counts.filter((v): v is number => v !== undefined),
  );
  const metric = (label: string, value: string) => (
    <div className="card" key={label}>
      <small>{label}</small>
      <h2>{value}</h2>
    </div>
  );
  return (
    <>
      <section className="heading">
        <div>
          <p className="eyebrow">쌓여가는 변화</p>
          <h1>나의 흐름</h1>
        </div>
        <div className="row">
          <button
            onClick={() => {
              setFrom(weekStart(today()));
              setTo(today());
            }}
          >
            이번 주
          </button>
          <button
            onClick={() => {
              setFrom(today().slice(0, 7) + "-01");
              setTo(today());
            }}
          >
            이번 달
          </button>
        </div>
      </section>
      <div className="row wrap">
        <label>
          시작일
          <input
            type="date"
            value={from}
            onChange={(e) => setFrom(e.target.value)}
          />
        </label>
        <label>
          종료일
          <input
            type="date"
            value={to}
            min={from}
            onChange={(e) => setTo(e.target.value)}
          />
        </label>
        <label>
          활동
          <select
            value={activity}
            onChange={(e) => setActivity(e.target.value)}
          >
            <option value="">모든 활동</option>
            {activities.map((a) => (
              <option key={a.id} value={a.id}>
                {a.name}
              </option>
            ))}
          </select>
        </label>
      </div>
      <section className="panel">
        <h2>날짜별 변화</h2>
        <label>
          차트 지표
          <select
            value={trend}
            onChange={(e) => setTrend(e.target.value as TrendMetric)}
          >
            {Object.entries(trendLabels).map(([key, label]) => (
              <option key={key} value={key}>
                {label}
              </option>
            ))}
          </select>
        </label>
        <div className="barchart" role="img" aria-label={trendLabels[trend]}>
          {ds.map((d, i) => (
            <div
              className="barcol"
              key={d}
              title={`${d}: ${display(counts[i])}`}
            >
              <span>{display(counts[i])}</span>
              <div style={{ height: `${((counts[i] || 0) / max) * 100}px` }} />
              <small>{d.slice(5)}</small>
            </div>
          ))}
        </div>
        <p className="muted">
          누락값은 0으로 간주하지 않습니다. 아래 합계는 입력된 데이터만
          포함합니다.
        </p>
      </section>
      <div className="cards">
        {metric(
          "독서량",
          display(
            sum(
              reading
                .map((e) =>
                  e.data.lastPage !== undefined &&
                  e.data.startPage !== undefined
                    ? Math.max(0, e.data.lastPage - e.data.startPage)
                    : undefined,
                )
                .filter((v): v is number => v !== undefined),
            ),
            "쪽",
          ),
        )}
        {metric(
          "독서 시간",
          display(
            sum(values(reading, "seconds")) === undefined
              ? undefined
              : sum(values(reading, "seconds"))! / 60,
            "분",
          ),
        )}
        {metric("러닝 거리", display(sum(values(running, "distance")), "km"))}
        {metric(
          "러닝 시간",
          display(
            sum(values(running, "seconds")) === undefined
              ? undefined
              : sum(values(running, "seconds"))! / 60,
            "분",
          ),
        )}
        {metric(
          "평균 러닝 페이스",
          duration(trendValue(running, "pace")) + " /km",
        )}
        {metric(
          "평균 심박수",
          display(mean(values(running, "heartRate")), "bpm"),
        )}
        {metric(
          "평균 케이던스",
          display(mean(values(running, "cadence")), "steps/min"),
        )}
        {metric(
          "공부 시간",
          display(
            sum(values(study, "seconds")) === undefined
              ? undefined
              : sum(values(study, "seconds"))! / 60,
            "분",
          ),
        )}
        {metric(
          "과외 예정 / 실제",
          `${display(sum(values(tutoring, "plannedSeconds")) === undefined ? undefined : sum(values(tutoring, "plannedSeconds"))! / 60)} / ${display(sum(values(tutoring, "seconds")) === undefined ? undefined : sum(values(tutoring, "seconds"))! / 60, "분")}`,
        )}
      </div>
      <section className="panel space">
        <h2>활동 달성</h2>
        {activities
          .filter((a) => a.kind !== "meal" && (!activity || a.id === activity))
          .map((a) => {
            const rate = achievement(a, entries, from, to);
            return (
              <div className="settingsrow" key={a.id}>
                <span>{a.name}</span>
                <span>
                  {rate.done} / {rate.expected}{" "}
                  {rate.expected
                    ? `(${Math.round((rate.done / rate.expected) * 100)}%)`
                    : ""}
                </span>
              </div>
            );
          })}
        <small>주 N회 목표는 해당 주 전체의 수행일 수를 사용합니다.</small>
      </section>
      <section className="panel">
        <h2>웨이트 · 운동별</h2>
        {[
          ...new Set(
            weights.flatMap((e) => e.data.sets?.map((s) => s.exercise) || []),
          ),
        ].map((name) => {
          const sets = weights
            .flatMap((e) => e.data.sets || [])
            .filter((s) => s.exercise === name && s.done);
          return (
            <div className="settingsrow" key={name}>
              <span>{name}</span>
              <span>
                최대 {sets.length ? Math.max(...sets.map((s) => s.kg)) : "—"} kg
                · 볼륨 {sets.reduce((n, s) => n + s.kg * s.reps, 0)} kg
              </span>
            </div>
          );
        })}
      </section>
      <section className="panel">
        <h2>식사와 영양소</h2>
        <p>
          알려진 영양소 합계: {display(nutrition.totals.kcal, "kcal")} · 탄{" "}
          {display(nutrition.totals.carbs, "g")} / 단{" "}
          {display(nutrition.totals.protein, "g")} / 지{" "}
          {display(nutrition.totals.fat, "g")}
        </p>
        <p>영양소 누락 {nutrition.unknown}끼니</p>
        {["러닝 전 에피타이저", "아침", "점심", "저녁", "추가 식사"].map(
          (slot) => {
            const r = rows.filter((e) => e.data.slot === slot);
            return (
              <div className="settingsrow" key={slot}>
                <span>{slot}</span>
                <small>
                  식단 {r.filter((e) => e.data.mealStatus === "planned").length}{" "}
                  · 외식{" "}
                  {r.filter((e) => e.data.mealStatus === "outside").length} ·
                  거름 {r.filter((e) => e.data.mealStatus === "skipped").length}
                </small>
              </div>
            );
          },
        )}
      </section>
      <section className="panel">
        <h2>추가 항목 통계</h2>
        {activities.flatMap((a) =>
          a.fields
            .filter((f) => f.type === "number")
            .map((f) => {
              const vals = rows
                .filter((e) => e.activityId === a.id)
                .map((e) => e.data.custom[f.id])
                .filter((v): v is number => typeof v === "number");
              return (
                <div className="settingsrow" key={f.id}>
                  <span>
                    {a.name} · {f.name} (
                    {f.aggregate === "sum" ? "합계" : "평균"})
                  </span>
                  <span>
                    {display(
                      f.aggregate === "sum" ? sum(vals) : mean(vals),
                      f.unit,
                    )}
                  </span>
                </div>
              );
            }),
        )}
      </section>
    </>
  );
}

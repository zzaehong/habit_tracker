import {mealEntry,defaultPlan} from "../shared/meals";
import { Operations } from "./Operations";
import { Assistant, AISettings } from "./Assistant";
import { Insights } from "./Insights";
import { Backup } from "./Backup";
import { Connection } from "./Connection";
import { startSync } from "./sync";
import { useEffect, useState } from "react";
import { useLiveQuery } from "dexie-react-hooks";
import { db, initialize, save, remove } from "./db";
import {
  type Activity,
  type Entry,
  type Kind,
  labels,
  today,
  now,
  newActivity,
  isDue,
  weeklyCount,
  scheduleAt,
  summarize,
} from "../shared/model";
import { MealToday, MealSettings, MealEditor } from "./Meals";
import { type MealPlan } from "../shared/model";
import { RecordEditor, ActivityEditor } from "./Editor";
export function App() {
  const [mealEdit, setMealEdit] = useState<Entry>();
  const [tab, setTab] = useState("오늘");
  const [date, setDate] = useState(today());
  const [error, setError] = useState("");
  const [editing, setEditing] = useState<{
    activity: Activity;
    entry?: Entry;
  }>();
  const [config, setConfig] = useState<Activity>();
  const [filter, setFilter] = useState("");
  const [from, setFrom] = useState(""),
    [to, setTo] = useState(today());
  const entities = useLiveQuery(() => db.entities.toArray(), []) || [];
  const pending = useLiveQuery(() => db.outbox.count(), []) || 0;
  const conflictsCount = useLiveQuery(() => db.conflicts.count(), []) || 0;
  const lastSync = useLiveQuery(() => db.meta.get("lastSync"), []);
  const activities = entities.filter(
    (e): e is Activity => e.type === "activity" && !e.deleted,
  );
  const entries = entities
    .filter((e): e is Entry => e.type === "entry" && !e.deleted)
    .sort(
      (a, b) =>
        b.date.localeCompare(a.date) || b.updatedAt.localeCompare(a.updatedAt),
    );
  useEffect(() => {
    initialize().catch((e) => setError(String(e)));
    return startSync();
  }, []);
  async function quick(a: Activity) {
    try {
      await save({
        id: crypto.randomUUID(),
        type: "entry",
        version: 0,
        updatedAt: now(),
        activityId: a.id,
        date,
        timezone: "Asia/Seoul",
        done: true,
        data: { custom: {} },
        definition: a,
        source: "manual",
        attachments: [],
      });
    } catch (e) {
      setError("저장 실패: " + String(e));
    }
  }
  const plans = entities.filter(
    (e): e is MealPlan => e.type === "mealPlan" && !e.deleted,
  );
  const mealActivity = activities.find((a) => a.kind === "meal");
  const due = activities.filter(
    (a) => a.kind !== "meal" && isDue(a, date, entries),
  );
  const completed = due.filter((a) =>
    entries.some((e) => e.date === date && e.activityId === a.id && e.done),
  ).length;
  return (
    <>
      <aside className="sidebar">
        <a className="brand" href="/">
          ▤ 차곡<span>작은 기록, 쌓이는 변화</span>
        </a>
        <nav>
          {["오늘", "기록", "통계", "설정"].map((t, i) => (
            <button
              key={t}
              className={tab === t ? "active" : ""}
              onClick={() => setTab(t)}
            >
              <span aria-hidden="true">{["◉", "▤", "▥", "⚙"][i]}</span>
              {t}
            </button>
          ))}
        </nav>
        <div className="sidebarfoot">
          <span className="dot" /> 나만의 기록 공간
          <br />
          <small>LOCAL FIRST · PRIVATE</small>
        </div>
      </aside>
      <main>
        <header className="topbar">
          <span>MY DAILY JOURNAL</span>
          <span className="badge">
            {conflictsCount
              ? `확인 필요 ${conflictsCount}`
              : pending
                ? `동기화 대기 ${pending}`
                : lastSync
                  ? "동기화 완료"
                  : "기기에 저장됨"}
          </span>
        </header>
        {error && (
          <div className="error" role="alert">
            {error}
            <button onClick={() => setError("")}>닫기</button>
          </div>
        )}
        <Assistant activities={activities} />
        {tab === "오늘" && (
          <>
            <section className="heading">
              <div>
                <p className="eyebrow">하루를 나답게</p>
                <h1>오늘도, 차곡차곡.</h1>
                <p className="muted">
                  작은 실천을 남기고 나의 흐름을 발견해 보세요.
                </p>
              </div>
              <input
                aria-label="선택 날짜"
                type="date"
                value={date}
                onChange={(e) => setDate(e.target.value)}
              />
            </section>
            <div className="hero">
              <div>
                <small>오늘의 발자국</small>
                <h2>
                  {completed}
                  <span> / {due.length} 활동</span>
                </h2>
                <p>완벽한 하루보다 꾸준한 기록.</p>
              </div>
              <div
                className="progressring"
                style={{
                  background: `conic-gradient(#d6edb6 ${due.length ? (completed / due.length) * 100 : 0}%,#456854 0)`,
                }}
              >
                <span>
                  {due.length ? Math.round((completed / due.length) * 100) : 0}%
                </span>
              </div>
            </div>
            <section className="sectionhead">
              <h2>
                오늘의 활동 <span>{due.length}</span>
              </h2>
              <button onClick={() => setTab("설정")}>활동 관리 ↗</button>
            </section>
            <div className="cards">
              {due.map((a) => {
                const record = entries.find(
                  (e) => e.date === date && e.activityId === a.id,
                );
                const s = scheduleAt(a, date);
                return (
                  <article className="card" key={a.id}>
                    <div className="row between">
                      <span className={"activity-icon " + a.kind}>
                        {
                          {
                            reading: "▤",
                            running: "↗",
                            weights: "↔",
                            meal: "◒",
                            tutoring: "◇",
                            study: "✎",
                            check: "✓",
                          }[a.kind]
                        }
                      </span>
                      <span className={"pill " + (record?.done ? "done" : "")}>
                        {record?.done
                          ? "기록 완료"
                          : s?.type === "weekly"
                            ? `주 ${weeklyCount(a, date, entries)} / ${s.count}회`
                            : "오늘 예정"}
                      </span>
                    </div>
                    <h3>{a.name}</h3>
                    <p className="card-detail">
                      {record
                        ? summarize(record) || "오늘의 실천을 남겼어요."
                        : `${labels[a.kind]} · 나를 위한 작은 시간`}
                    </p>
                    <div className="row">
                      <button
                        className={record ? "" : "primary"}
                        onClick={() =>
                          record
                            ? setEditing({ activity: a, entry: record })
                            : quick(a)
                        }
                      >
                        {record ? "기록 수정" : "✓ 완료"}
                      </button>
                      <button onClick={() => setEditing({ activity: a })}>
                        ＋ 상세 기록
                      </button>
                    </div>
                  </article>
                );
              })}
            </div>
            {mealActivity && (
              <MealToday
                activity={mealActivity}
                plans={plans}
                entries={entries}
                date={date}
                onEdit={setMealEdit}
              />
            )}{" "}
            {!due.length && (
              <div className="empty">
                오늘 예정된 활동이 없습니다. 설정에서 활동을 추가하세요.
              </div>
            )}
          </>
        )}
        {tab === "기록" && (
          <>
            <section className="heading">
              <div>
                <p className="eyebrow">나의 발자취</p>
                <h1>기록 모아보기</h1>
              </div>
              <select
                aria-label="활동 필터"
                value={filter}
                onChange={(e) => setFilter(e.target.value)}
              >
                <option value="">모든 활동</option>
                {activities.map((a) => (
                  <option key={a.id} value={a.id}>
                    {a.name}
                  </option>
                ))}
              </select>
            </section>
            <div className="row">
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
                  onChange={(e) => setTo(e.target.value)}
                />
              </label>
            </div>
            <label>예정에 없는 활동 기록<select value="" onChange={e=>{const a=activities.find(a=>a.id===e.target.value);if(!a)return;if(a.kind==="meal")setMealEdit(mealEntry(a,{...defaultPlan("추가 식사"),slot:"추가 식사"},today(),"outside"));else setEditing({activity:a})}}><option value="">활동 선택</option>{activities.map(a=><option key={a.id} value={a.id}>{a.name}</option>)}</select></label>
          <div className="recordlist">
              {entries
                .filter(
                  (e) =>
                    (!filter || e.activityId === filter) &&
                    (!from || e.date >= from) &&
                    e.date <= to,
                )
                .map((e) => (
                  <article key={e.id} className="recordrow">
                    <div>
                      <small>
                        {e.date} · {e.definition.name}
                      </small>
                      <h3>{summarize(e) || "완료 기록"}</h3>
                      {e.data.note && <p>{e.data.note}</p>}
                    </div>
                    <div className="row">
                      <button
                        onClick={() =>
                          e.definition.kind === "meal"
                            ? setMealEdit(e)
                            : setEditing({ activity: e.definition, entry: e })
                        }
                      >
                        수정
                      </button>
                      <button
                        onClick={() => {
                          if (confirm("이 기록을 삭제할까요?"))
                            remove(e).catch((x) => setError(String(x)));
                        }}
                      >
                        삭제
                      </button>
                    </div>
                  </article>
                ))}
              {!entries.length && (
                <div className="empty">첫 기록을 남겨보세요.</div>
              )}
            </div>
          </>
        )}
        {tab === "통계" && (
          <Insights entries={entries} activities={activities} />
        )}
        {tab === "설정" && (
          <>
            <section className="heading">
              <div>
                <p className="eyebrow">나에게 맞추기</p>
                <h1>설정</h1>
              </div>
            </section>
            <section className="panel">
              <h2>활동 관리</h2>
              {activities.map((a) => (
                <div className="settingsrow" key={a.id}>
                  <span>
                    {a.name} <small>{a.enabled ? "사용 중" : "중지됨"}</small>
                  </span>
                  <button onClick={() => setConfig(a)}>설정</button>
                </div>
              ))}
              <label>
                새 활동 추가
                <select
                  defaultValue=""
                  onChange={(e) => {
                    if (e.target.value)
                      setConfig(newActivity(e.target.value as Kind));
                    e.target.value = "";
                  }}
                >
                  <option value="">템플릿 선택</option>
                  {Object.entries(labels).map(([k, v]) => (
                    <option key={k} value={k}>
                      {v}
                    </option>
                  ))}
                </select>
              </label>
            </section>
            <MealSettings plans={plans} />
            <Connection />
            <AISettings />
            <Operations />
            <Backup entities={entities} />
            <section className="panel">
              <h2>로컬 저장</h2>
              <p>
                이 기기에 먼저 저장됩니다. 브라우저 데이터를 지우면 미동기화
                기록이 사라질 수 있습니다.
              </p>
              <p>기본 시간대: Asia/Seoul · 한 주의 시작: 월요일</p>
            </section>
          </>
        )}
        <footer>
          하루의 작은 조각들이 나를 만듭니다. <span>차곡</span>
        </footer>
      </main>
      {editing && (
        <RecordEditor
          activity={editing.activity}
          entry={editing.entry}
          initialDate={date}
          previous={entries.find(
            (e) =>
              e.activityId === editing.activity.id &&
              e.id !== editing.entry?.id,
          )}
          onClose={() => setEditing(undefined)}
        />
      )}{" "}
      {mealEdit && (
        <MealEditor entry={mealEdit} onClose={() => setMealEdit(undefined)} />
      )}{" "}
      {config && (
        <ActivityEditor
          activity={config}
          onClose={() => setConfig(undefined)}
        />
      )}
    </>
  );
}

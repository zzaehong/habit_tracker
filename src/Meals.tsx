import { useState } from "react";
import {
  type MealPlan,
  type Activity,
  type Entry,
  today,
} from "../shared/model";
import {
  slots,
  nutrients,
  nutrientLabels,
  defaultPlan,
  mealEntry,
  nutritionSummary,
  duePlans,
  planNutrition,
} from "../shared/meals";
import { save, db } from "./db";
export function MealSettings({ plans }: { plans: MealPlan[] }) {
  const [editing, setEditing] = useState<MealPlan>();
  const [error, setError] = useState("");
  return (
    <section className="panel">
      <h2>나의 고정 식단</h2>
      <p className="muted">
        끼니별 영양소 총량을 한 번 등록하세요. 수정해도 과거 기록은 바뀌지
        않습니다.
      </p>
      {slots.map((slot) => {
        const p = plans.find((p) => p.slot === slot);
        return (
          <div key={slot} className="settingsrow">
            <div>
              {slot}
              <br />
              <small>
                {p
                  ? `${p.menu || "메뉴 미입력"} · ${p.kcal} kcal`
                  : "아직 등록하지 않았어요"}
              </small>
            </div>
            <button onClick={() => setEditing(p || defaultPlan(slot))}>
              식단 설정
            </button>
          </div>
        );
      })}
      {editing && (
        <div className="overlay">
          <section className="dialog" role="dialog" aria-label="식단 설정">
            <h2>{editing.slot}</h2>
            <label>
              메뉴
              <input
                value={editing.menu}
                onChange={(e) =>
                  setEditing({ ...editing, menu: e.target.value })
                }
              />
            </label>
            <div className="formgrid">
              {nutrients.map((k) => (
                <label key={k}>
                  {nutrientLabels[k]}
                  <input
                    type="number"
                    min="0"
                    step="any"
                    value={editing[k]}
                    onChange={(e) =>
                      setEditing({ ...editing, [k]: Number(e.target.value) })
                    }
                  />
                </label>
              ))}
            </div>
            <label className="row">
              <input
                type="checkbox"
                checked={editing.enabled}
                onChange={(e) =>
                  setEditing({ ...editing, enabled: e.target.checked })
                }
              />
              이 끼니 사용
            </label>
            <div className="row wrap">
              {["일", "월", "화", "수", "목", "금", "토"].map((d, i) => (
                <label className="row" key={d}>
                  <input
                    type="checkbox"
                    checked={editing.weekdays.includes(i)}
                    onChange={(e) =>
                      setEditing({
                        ...editing,
                        weekdays: e.target.checked
                          ? [...editing.weekdays, i]
                          : editing.weekdays.filter((x) => x !== i),
                      })
                    }
                  />
                  {d}
                </label>
              ))}
            </div>
            {error && <p role="alert">{error}</p>}
            <div className="row">
              <button onClick={() => setEditing(undefined)}>취소</button>
              <button
                className="primary"
                onClick={async () => {
                  try {
                    if (!editing.menu.trim()) throw Error("메뉴를 입력하세요.");
                    await save(editing);
                    setEditing(undefined);
                  } catch (e) {
                    setError(String(e));
                  }
                }}
              >
                식단 저장
              </button>
            </div>
          </section>
        </div>
      )}
    </section>
  );
}
export function MealEditor({
  entry,
  onClose,
  onSaved,
}: {
  entry: Entry;
  onClose: () => void;
  onSaved?: (e: Entry) => Promise<void>;
}) {
  const [e, setE] = useState(entry);
  const [error, setError] = useState("");
  async function changeMeal(
    slot: string,
    status: "planned" | "outside" | "skipped",
  ) {
    try {
      const plans = await db.entities
        .where("type")
        .equals("mealPlan")
        .toArray();
      const plan = plans.find(
        (p): p is MealPlan =>
          p.type === "mealPlan" && !p.deleted && p.slot === slot,
      );
      setE((previous) => ({
        ...previous,
        done: status !== "skipped",
        data: {
          ...previous.data,
          slot,
          mealStatus: status,
          ...planNutrition(status === "planned" ? plan : undefined),
        },
      }));
    } catch (error) {
      setError(String(error));
    }
  }
  const patch = (key: string, value: unknown) =>
    setE({ ...e, data: { ...e.data, [key]: value } });
  return (
    <div className="overlay">
      <section className="dialog" role="dialog" aria-label="식사 기록">
        <div className="row between">
          <h2>{e.data.slot || "추가 식사"}</h2>
          <button onClick={onClose}>닫기</button>
        </div>
        <div className="formgrid">
          <label>
            날짜
            <input
              type="date"
              value={e.date}
              onChange={(x) => setE({ ...e, date: x.target.value })}
            />
          </label>
          <label>
            식사 시간
            <input
              type="time"
              value={e.data.mealTime || ""}
              onChange={(x) => patch("mealTime", x.target.value)}
            />
          </label>
        </div>
        <label>
          끼니
          <select
            value={e.data.slot || ""}
            onChange={(x) =>
              changeMeal(x.target.value, e.data.mealStatus || "outside")
            }
          >
            <option value="">선택하세요</option>
            {[...slots, "추가 식사"].map((slot) => (
              <option key={slot}>{slot}</option>
            ))}
          </select>
        </label>
        <label>
          식사 상태
          <select
            value={e.data.mealStatus || ""}
            onChange={(x) =>
              changeMeal(
                e.data.slot || "",
                x.target.value as "planned" | "outside" | "skipped",
              )
            }
          >
            <option value="" disabled>
              선택하세요
            </option>
            <option value="planned">식단대로 먹음</option>
            <option value="outside">외식/대체식</option>
            <option value="skipped">거름</option>
          </select>
        </label>
        <label>
          메뉴
          <input
            value={e.data.menu || ""}
            onChange={(x) => patch("menu", x.target.value)}
          />
        </label>
        <p className="muted">
          모르는 영양소는 비워 두세요. 0과 구분하여 보관합니다.
        </p>
        <div className="formgrid">
          {nutrients.map((k) => (
            <label key={k}>
              {nutrientLabels[k]}
              <input
                type="number"
                min="0"
                step="any"
                value={e.data[k] ?? ""}
                onChange={(x) =>
                  patch(
                    k,
                    x.target.value === "" ? undefined : Number(x.target.value),
                  )
                }
              />
            </label>
          ))}
        </div>
        <label>
          메모
          <textarea
            value={e.data.note || ""}
            onChange={(x) => patch("note", x.target.value)}
          />
        </label>
        {error && (
          <p className="error" role="alert">
            {error}
          </p>
        )}
        <button
          className="primary wide"
          onClick={async () => {
            try {
              if (!e.data.slot || !e.data.mealStatus)
                throw Error("끼니와 식사 상태를 선택하세요.");
              await save({ ...e, done: e.data.mealStatus !== "skipped" });
              if (onSaved) await onSaved(e);
              onClose();
            } catch (x) {
              setError(String(x));
            }
          }}
        >
          식사 저장
        </button>
      </section>
    </div>
  );
}
export function MealToday({
  activity,
  plans,
  entries,
  date,
  onEdit,
}: {
  activity: Activity;
  plans: MealPlan[];
  entries: Entry[];
  date: string;
  onEdit: (e: Entry) => void;
}) {
  const [error, setError] = useState("");
  const [saving, setSaving] = useState("");
  async function quick(plan: MealPlan, status: "planned" | "skipped") {
    setSaving(plan.id);
    try {
      const entry = mealEntry(activity, plan, date, status);
      const previous = await db.entities.get(entry.id);
      await save({ ...entry, version: previous?.version || 0 });
    } catch (e) {
      setError(String(e));
    } finally {
      setSaving("");
    }
  }
  const summary = nutritionSummary(entries.filter((e) => e.date === date));
  return (
    <section>
      <div className="sectionhead">
        <h2>오늘의 식사</h2>
        <button
          onClick={() =>
            onEdit(
              mealEntry(
                activity,
                { ...defaultPlan("추가 식사"), slot: "추가 식사" },
                date,
                "outside",
              ),
            )
          }
        >
          ＋ 추가 음식
        </button>
      </div>
      <div className="cards">
        {duePlans(plans, date).map((p) => {
          const existing = entries.find(
            (e) =>
              e.date === date &&
              e.data.slot === p.slot &&
              e.activityId === activity.id,
          );
          return (
            <article className="card" key={p.id}>
              <small>{p.slot}</small>
              <h3>{p.menu}</h3>
              <p className="muted">
                {existing
                  ? `${existing.data.mealTime || ""} · ${{ planned: "식단대로 먹음", outside: "외식/대체식", skipped: "거름" }[existing.data.mealStatus || "planned"]}`
                  : `${p.kcal} kcal · 미기록`}
              </p>
              {existing ? (
                <button onClick={() => onEdit(existing)}>식사 수정</button>
              ) : (
                <div className="row wrap">
                  <button
                    className="primary"
                    disabled={saving === p.id}
                    onClick={() => quick(p, "planned")}
                  >
                    식단대로
                  </button>
                  <button
                    onClick={() =>
                      onEdit(mealEntry(activity, p, date, "outside"))
                    }
                  >
                    외식
                  </button>
                  <button
                    disabled={saving === p.id}
                    onClick={() => quick(p, "skipped")}
                  >
                    거름
                  </button>
                </div>
              )}
            </article>
          );
        })}
      </div>
      {error && (
        <p role="alert" className="error">
          {error}
        </p>
      )}
      {!plans.length && (
        <p className="muted">
          설정에서 네 끼니의 고정 메뉴와 영양소를 등록하세요.
        </p>
      )}
      <p className="muted">
        알려진 영양소 합계 {summary.totals.kcal} kcal · 탄{" "}
        {summary.totals.carbs}g / 단 {summary.totals.protein}g / 지{" "}
        {summary.totals.fat}g · 영양소 누락 {summary.unknown}끼니
      </p>
    </section>
  );
}

import { useState } from "react";
import { useLiveQuery } from "dexie-react-hooks";
import { db, setMeta } from "./db";
import { api, sync, resolveConflict } from "./sync";
export function Connection() {
  const [code, setCode] = useState(""),
    [name, setName] = useState("나의 기기"),
    [message, setMessage] = useState("");
  const [devices, setDevices] = useState<{ id: string; name: string }[]>([]);
  const meta = useLiveQuery(() => db.meta.toArray(), []) || [];
  const conflicts = useLiveQuery(() => db.conflicts.toArray(), []) || [];
  const value = (key: string) => meta.find((m) => m.key === key)?.value;
  return (
    <section className="panel">
      <h2>기기 연결 및 동기화</h2>
      {value("token") ? (
        <>
          <p>
            마지막 동기화:{" "}
            {value("lastSync")
              ? new Date(value("lastSync")).toLocaleString("ko-KR")
              : "아직 없음"}
          </p>
          <div className="row wrap">
            <button onClick={() => sync()}>지금 동기화</button>
            <button
              onClick={async () => {
                try {
                  setDevices(await (await api("/api/devices")).json());
                } catch (e) {
                  setMessage(String(e));
                }
              }}
            >
              연결된 기기
            </button>
            <button
              onClick={async () => {
                await db.meta.delete("token");
                setMessage(
                  "이 기기의 연결을 해제했습니다. 로컬 기록은 유지합니다.",
                );
              }}
            >
              이 기기 연결 해제
            </button>
          </div>
          {devices.map((d) => (
            <div className="settingsrow" key={d.id}>
              <span>{d.name}</span>
              <button
                onClick={async () => {
                  try {
                    await api("/api/devices/" + d.id, { method: "DELETE" });
                    setDevices(devices.filter((x) => x.id !== d.id));
                  } catch (e) {
                    setMessage(String(e));
                  }
                }}
              >
                접근 취소
              </button>
            </div>
          ))}
        </>
      ) : (
        <>
          <p className="muted">
            맥미니에서 발급한 8자리 코드를 입력하세요. 연결 전에도 기록할 수
            있습니다.
          </p>
          <label>
            기기 이름
            <input value={name} onChange={(e) => setName(e.target.value)} />
          </label>
          <label>
            연결 코드
            <input
              inputMode="numeric"
              value={code}
              onChange={(e) => setCode(e.target.value)}
            />
          </label>
          <button
            onClick={async () => {
              try {
                const r = await (
                  await api("/api/pair", {
                    method: "POST",
                    body: JSON.stringify({ code, name }),
                  })
                ).json();
                await setMeta("token", r.token);
                await setMeta("cursor", 0);
                for (const m of await db.meta.toArray())
                  if (m.key.startsWith("uploaded:"))
                    await db.meta.delete(m.key);
                await setMeta("deviceId", r.id);
                await sync();
                setCode("");
                setMessage("연결되었습니다.");
              } catch (e) {
                setMessage(String(e));
              }
            }}
          >
            기기 연결
          </button>
        </>
      )}
      {value("syncError") && (
        <p className="muted">
          연결 대기: {value("syncError")} · 기록은 기기에 보관됩니다.
        </p>
      )}
      {message && <p role="status">{message}</p>}
      {conflicts.map((c) => (
        <div className="fieldbox" key={c.id}>
          <h3>동시 수정 확인 필요</h3>
          <div className="formgrid">
            <div>
              <small>{c.source === "restore" ? "백업 파일" : "이 기기"}</small>
              <pre>{JSON.stringify(c.local, null, 2)}</pre>
            </div>
            <div>
              <small>
                {c.source === "restore" ? "현재 기록" : "다른 기기"}
              </small>
              <pre>{JSON.stringify(c.remote, null, 2)}</pre>
            </div>
          </div>
          <div className="row wrap">
            <button onClick={() => resolveConflict(c.id, "local")}>
              {c.source === "restore" ? "백업 내용 사용" : "이 기기 내용 사용"}
            </button>
            <button onClick={() => resolveConflict(c.id, "remote")}>
              {c.source === "restore" ? "현재 기록 유지" : "서버 내용 사용"}
            </button>
            {c.local.type === "entry" && (
              <button onClick={() => resolveConflict(c.id, "both")}>
                둘 다 보관
              </button>
            )}
          </div>
        </div>
      ))}
    </section>
  );
}

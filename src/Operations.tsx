import { useState } from "react";
import { api } from "./sync";
export function Operations() {
  const [state, setState] = useState<any>(),
    [local, setLocal] = useState<StorageEstimate>(),
    [message, setMessage] = useState("");
  async function load() {
    try {
      setLocal(await navigator.storage?.estimate());
      setState(await (await api("/api/operations")).json());
      setMessage("");
    } catch (e) {
      setMessage(String(e));
    }
  }
  return (
    <section className="panel">
      <h2>저장 공간과 백업</h2>
      <p>
        이 기기 사용량:{" "}
        {local?.usage === undefined
          ? "—"
          : `${(local.usage / 1024 / 1024).toFixed(1)} MB`}
      </p>
      <p>
        서버 이미지:{" "}
        {state ? `${(state.attachmentBytes / 1024 / 1024).toFixed(1)} MB` : "—"}{" "}
        · 백업 {state?.snapshots ?? "—"}개
      </p>
      <p>
        마지막 백업:{" "}
        {state?.lastBackup
          ? new Date(state.lastBackup).toLocaleString("ko-KR")
          : "아직 확인하지 않음"}
      </p>
      {state?.backupError && <p className="error">{state.backupError}</p>}
      <div className="row">
        <button onClick={load}>상태 새로고침</button>
        <button
          onClick={async () => {
            try {
              await api("/api/backups", {
                method: "POST",
                body: "{}",
                signal: AbortSignal.timeout(120000),
              });
              await load();
              setMessage("서버 백업 완료");
            } catch (e) {
              setMessage(String(e));
            }
          }}
        >
          지금 백업
        </button>
      </div>
      <p role="status">{message}</p>
      <small>
        백업도 같은 SSD에 있습니다. 디스크 고장에 대비해 backups 폴더 전체를
        별도 디스크로 복사하세요.
      </small>
    </section>
  );
}

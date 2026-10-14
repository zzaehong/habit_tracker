import { useEffect, useState } from "react";
import { useLiveQuery } from "dexie-react-hooks";
import { db, save, remove } from "./db";
import { type Activity, type Attachment, now, today } from "../shared/model";
import { sync } from "./sync";
export function CaptureInput({
  activity,
  onCreated,
}: {
  activity: Activity;
  onCreated?: () => void;
}) {
  const [error, setError] = useState(""),
    [busy, setBusy] = useState(false);
  async function select(files: File[]) {
    setBusy(true);
    setError("");
    try {
      if (files.length > 5 || !files.length) throw Error("1–5장을 선택하세요.");
      const items: { entity: Attachment; blob: Blob }[] = [];
      for (const file of files) {
        if (
          !["image/png", "image/jpeg"].includes(file.type) ||
          file.size > 10 * 1024 * 1024
        )
          throw Error("PNG/JPEG, 장당 10MB 이하만 지원합니다.");
        const buffer = await file.arrayBuffer();
        const hash = Array.from(
          new Uint8Array(await crypto.subtle.digest("SHA-256", buffer)),
        )
          .map((x) => x.toString(16).padStart(2, "0"))
          .join("");
        const existing = (
          await db.entities.where("type").equals("attachment").toArray()
        ).find((a) => a.type === "attachment" && !a.deleted && a.hash === hash);
        if (
          (existing || items.some((i) => i.entity.hash === hash)) &&
          !confirm(
            "이미 등록된 캡처입니다. 같은 이미지로 새 기록을 분석할까요?",
          )
        )
          return;
        const entity: Attachment = (existing as Attachment) || {
          id: crypto.randomUUID(),
          type: "attachment",
          version: 0,
          updatedAt: now(),
          hash,
          name: file.name,
          mime: file.type as Attachment["mime"],
          size: file.size,
        };
        items.push({ entity, blob: file });
      }
      await db.transaction(
        "rw",
        db.entities,
        db.outbox,
        db.blobs,
        db.meta,
        async () => {
          for (const item of items) {
            await db.blobs.put({ id: item.entity.id, blob: item.blob });
            await save(item.entity);
          }
          await save({
            id: crypto.randomUUID(),
            type: "draft",
            version: 0,
            updatedAt: now(),
            createdAt: now(),
            date: today(),
            text: `NRC 캡처 · ${activity.name}`,
            activityId: activity.id,
            mode: "capture",
            status: "waiting",
            attachments: [...new Set(items.map((i) => i.entity.id))],
          });
        },
      );
      window.dispatchEvent(new Event("open-assistant"));
      onCreated?.();
      setError("캡처를 기기에 저장했습니다. 연결 후 분석 결과를 확인하세요.");
      void sync();
    } catch (e) {
      setError(String(e));
    } finally {
      setBusy(false);
    }
  }
  return (
    <section className="fieldbox">
      <h3>Nike Run Club 캡처</h3>
      <p className="muted">
        거리·시간·페이스와 표시된 심박수·케이던스를 추출합니다. 결과는 확인 후
        저장됩니다.
      </p>
      <input
        aria-label="NRC 캡처 업로드"
        disabled={busy}
        type="file"
        accept="image/png,image/jpeg"
        multiple
        onChange={(e) => {
          void select(Array.from(e.target.files || []));
          e.target.value = "";
        }}
      />
      {error && <p role="status">{error}</p>}
    </section>
  );
}
export function AttachmentGallery({
  ids,
  editable = false,
}: {
  ids: string[];
  editable?: boolean;
}) {
  const files =
    useLiveQuery(async () => {
      const out = [];
      for (const id of ids) {
        const a = await db.entities.get(id);
        const b = await db.blobs.get(id);
        if (a?.type === "attachment" && !a.deleted && b)
          out.push({ a, b: b.blob });
      }
      return out;
    }, [ids.join(",")]) || [];
  const [urls, setUrls] = useState<{ id: string; url: string; name: string }[]>(
    [],
  );
  useEffect(() => {
    const values = files.map((f) => ({
      id: f.a.id,
      url: URL.createObjectURL(f.b),
      name: f.a.name,
    }));
    setUrls(values);
    return () => values.forEach((v) => URL.revokeObjectURL(v.url));
  }, [files.map((f) => f.a.id + f.a.updatedAt).join(",")]);
  return (
    <div className="capture-gallery">
      {urls.map((f) => (
        <figure key={f.id}>
          <img src={f.url} alt="러닝 캡처 원본" />
          <figcaption>{f.name}</figcaption>
          {editable && (
            <button
              onClick={async () => {
                if (
                  !confirm(
                    "이 원본 이미지를 삭제할까요? 수치 기록은 유지됩니다.",
                  )
                )
                  return;
                const a = await db.entities.get(f.id);
                if (a) {
                  await remove(a);
                  await db.blobs.delete(f.id);
                }
              }}
            >
              원본 삭제
            </button>
          )}
        </figure>
      ))}
    </div>
  );
}

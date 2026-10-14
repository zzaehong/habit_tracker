import { existsSync, mkdirSync, readFileSync, copyFileSync } from "node:fs";
import path from "node:path";
import { createHash } from "node:crypto";
import { Repository } from "../server/store";
const [manifest, target] = process.argv.slice(2);
if (!manifest || !target)
  throw Error("사용법: npm run restore:server -- 백업.json 새데이터폴더");
if (existsSync(target))
  throw Error(
    "기존 데이터 보호를 위해 존재하지 않는 새 폴더만 복원 대상으로 사용할 수 있습니다.",
  );
const snapshot = JSON.parse(readFileSync(manifest, "utf8")) as {
  database: string;
  attachments: string[];
};
if (
  path.basename(snapshot.database) !== snapshot.database ||
  !snapshot.database.endsWith(".sqlite") ||
  !Array.isArray(snapshot.attachments) ||
  snapshot.attachments.some((h) => !/^([a-f0-9]{64})$/.test(h))
)
  throw Error("잘못된 백업 목록");
const root = path.dirname(path.resolve(manifest));
for (const h of snapshot.attachments) {
  const bytes = readFileSync(path.join(root, "blobs", h));
  if (createHash("sha256").update(bytes).digest("hex") !== h)
    throw Error("첨부 파일 손상");
}
mkdirSync(path.join(target, "attachments"), { recursive: true, mode: 0o700 });
copyFileSync(
  path.join(root, snapshot.database),
  path.join(target, "chagok.sqlite"),
);
for (const h of snapshot.attachments)
  copyFileSync(
    path.join(root, "blobs", h),
    path.join(target, "attachments", h),
  );
const repo = new Repository(path.join(target, "chagok.sqlite"));
repo.db.exec("DELETE FROM devices; DELETE FROM codes;");
repo.db
  .prepare("INSERT OR REPLACE INTO settings VALUES('serverId',?)")
  .run(JSON.stringify(crypto.randomUUID()));
repo.close();
console.log(
  "복원 완료. DATA_DIR을 새 경로로 지정해 서버를 시작하고 기기를 다시 연결하세요. 기존 데이터는 보존되었습니다.",
);

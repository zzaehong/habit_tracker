import { mkdirSync } from "node:fs";
import { Repository } from "../server/store";
import { pairingCode } from "../server/app";
const dir = process.env.DATA_DIR || "runtime";
mkdirSync(dir, { recursive: true, mode: 0o700 });
const repo = new Repository(dir + "/chagok.sqlite");
console.log("기기 연결 코드 (10분 유효):", pairingCode(repo));
repo.close();

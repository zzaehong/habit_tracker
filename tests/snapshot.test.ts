import { it, expect } from "vitest";
import {
  mkdtempSync,
  mkdirSync,
  rmSync,
  writeFileSync,
  readFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { DatabaseSync } from "node:sqlite";
import { Repository } from "../server/store";
import { createSnapshot, listSnapshots } from "../server/backup";
import { hash } from "../server/app";
import { newActivity, now } from "../shared/model";
it("SQLite 백업과 해시 첨부가 같은 시점의 데이터를 보존", async () => {
  const dir = mkdtempSync(tmpdir() + "/chagok-backup-");
  mkdirSync(dir + "/attachments");
  const repo = new Repository(dir + "/chagok.sqlite");
  try {
    const a = newActivity("running");
    repo.apply({ id: "a", baseVersion: 0, entity: a });
    const bytes = Buffer.from("fixture");
    const digest = hash(bytes);
    writeFileSync(dir + "/attachments/" + digest, bytes);
    repo.apply({
      id: "image",
      baseVersion: 0,
      entity: {
        id: "image",
        type: "attachment",
        version: 0,
        updatedAt: now(),
        hash: digest,
        name: "test.png",
        mime: "image/png",
        size: bytes.length,
      },
    });
    const s = await createSnapshot(repo, dir);
    const b = new DatabaseSync(dir + "/backups/" + s.database, {
      readOnly: true,
    });
    expect(b.prepare("SELECT count(*) AS n FROM entities").get()?.n).toBe(2);
    b.close();
    expect(readFileSync(dir + "/backups/blobs/" + digest)).toEqual(bytes);
    expect(listSnapshots(dir)).toHaveLength(1);
  } finally {
    repo.close();
    rmSync(dir, { recursive: true, force: true });
  }
});

import {execFileSync} from 'node:child_process';
it('서버 복원은 새 경로에만 쓰고 기기 인증을 초기화',async()=>{const dir=mkdtempSync(tmpdir()+'/chagok-restore-');mkdirSync(dir+'/attachments');const repo=new Repository(dir+'/chagok.sqlite');try{const a=newActivity('study');repo.apply({id:'a',baseVersion:0,entity:a});repo.db.prepare('INSERT INTO devices VALUES(?,?,?,?)').run('device','test','secret','now');const snap=await createSnapshot(repo,dir);const target=dir+'/restored';execFileSync(process.execPath,['--import','tsx','scripts/restore-server.ts',dir+'/backups/'+snap.id+'.json',target]);const restored=new Repository(target+'/chagok.sqlite');expect(restored.get(a.id)).toBeDefined();expect(restored.db.prepare('SELECT count(*) AS n FROM devices').get()?.n).toBe(0);restored.close();expect(repo.get(a.id)).toBeDefined();expect(()=>execFileSync(process.execPath,['--import','tsx','scripts/restore-server.ts',dir+'/backups/'+snap.id+'.json',target],{stdio:'pipe'})).toThrow()}finally{repo.close();rmSync(dir,{recursive:true,force:true})}});

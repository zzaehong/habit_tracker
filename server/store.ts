import { DatabaseSync } from "node:sqlite";
import { type Entity, type Operation } from "../shared/model";
export class Repository {
  db: DatabaseSync;
  constructor(path: string) {
    this.db = new DatabaseSync(path);
    this.db.exec(`PRAGMA journal_mode=WAL; PRAGMA foreign_keys=ON;
 CREATE TABLE IF NOT EXISTS entities(id TEXT PRIMARY KEY,json TEXT NOT NULL,version INTEGER NOT NULL);
 CREATE TABLE IF NOT EXISTS changes(seq INTEGER PRIMARY KEY AUTOINCREMENT,json TEXT NOT NULL);
 CREATE TABLE IF NOT EXISTS operations(id TEXT PRIMARY KEY,result TEXT NOT NULL);
 CREATE TABLE IF NOT EXISTS devices(id TEXT PRIMARY KEY,name TEXT,token TEXT UNIQUE,created TEXT);
 CREATE TABLE IF NOT EXISTS codes(hash TEXT PRIMARY KEY,expires INTEGER);
 CREATE TABLE IF NOT EXISTS jobs(id TEXT PRIMARY KEY,json TEXT NOT NULL);
 CREATE TABLE IF NOT EXISTS settings(key TEXT PRIMARY KEY,json TEXT NOT NULL);`);
  }
  get(id: string): Entity | undefined {
    const row = this.db
      .prepare("SELECT json FROM entities WHERE id=?")
      .get(id) as { json: string } | undefined;
    return row ? JSON.parse(row.json) : undefined;
  }
  all(): Entity[] {
    return (
      this.db.prepare("SELECT json FROM entities").all() as { json: string }[]
    ).map((r) => JSON.parse(r.json));
  }
  apply(op: Operation): { entity?: Entity; conflict?: Entity } {
    const previous = this.db
      .prepare("SELECT result FROM operations WHERE id=?")
      .get(op.id) as { result: string } | undefined;
    if (previous) return JSON.parse(previous.result);
    this.db.exec("BEGIN IMMEDIATE");
    try {
      const current = this.get(op.entity.id);
      let result: { entity?: Entity; conflict?: Entity };
      if (current && op.bootstrap) {
        result = { entity: current };
      } else if ((current?.version || 0) !== op.baseVersion) {
        result = { conflict: current! };
      } else {
        const entity = { ...op.entity, version: (current?.version || 0) + 1 };
        this.db
          .prepare("INSERT OR REPLACE INTO entities VALUES(?,?,?)")
          .run(entity.id, JSON.stringify(entity), entity.version);
        this.db
          .prepare("INSERT INTO changes(json) VALUES(?)")
          .run(JSON.stringify(entity));
        result = { entity };
      }
      this.db
        .prepare("INSERT INTO operations VALUES(?,?)")
        .run(op.id, JSON.stringify(result));
      this.db.exec("COMMIT");
      return result;
    } catch (e) {
      this.db.exec("ROLLBACK");
      throw e;
    }
  }
  changes(cursor: number) {
    const rows = this.db
      .prepare(
        "SELECT seq,json FROM changes WHERE seq>? ORDER BY seq LIMIT 500",
      )
      .all(cursor) as { seq: number; json: string }[];
    return {
      cursor: rows.at(-1)?.seq || cursor,
      changes: rows.map((r) => JSON.parse(r.json) as Entity),
      more: rows.length === 500,
    };
  }
  close() {
    this.db.close();
  }
}

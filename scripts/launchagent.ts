import { mkdirSync, writeFileSync } from "node:fs";
import path from "node:path";
const cwd = process.cwd();
const escape = (s: string) =>
  s
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
mkdirSync("runtime", { recursive: true, mode: 0o700 });
const args = [
  process.execPath,
  "--import",
  path.resolve("node_modules/tsx/dist/loader.mjs"),
  path.resolve("server/index.ts"),
];
const plist = `<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>Label</key><string>local.chagok.server</string><key>ProgramArguments</key><array>${args.map((a) => `<string>${escape(a)}</string>`).join("")}</array><key>WorkingDirectory</key><string>${escape(cwd)}</string><key>RunAtLoad</key><true/><key>KeepAlive</key><true/><key>ThrottleInterval</key><integer>10</integer><key>StandardOutPath</key><string>${escape(path.resolve("runtime/server.log"))}</string><key>StandardErrorPath</key><string>${escape(path.resolve("runtime/server-error.log"))}</string></dict></plist>`;
writeFileSync("runtime/local.chagok.server.plist", plist, { mode: 0o600 });
console.log(path.resolve("runtime/local.chagok.server.plist"));

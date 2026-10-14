import { defineConfig } from "@playwright/test";
const dataDir = process.env.CHAGOK_E2E_DIR || "runtime/e2e-" + Date.now();
process.env.CHAGOK_E2E_DIR = dataDir;
export default defineConfig({
  testDir: "./e2e",
  testMatch: "**/*.pw.ts",
  timeout: 45000,
  workers: 1,
  fullyParallel: false,
  use: {
    baseURL: "http://127.0.0.1:8798",
    viewport: { width: 1280, height: 900 },
    trace: "retain-on-failure",
  },
  webServer: {
    command: `PORT=8798 DATA_DIR=${dataDir} node --import tsx server/index.ts`,
    url: "http://127.0.0.1:8798",
    reuseExistingServer: false,
    timeout: 30000,
  },
  reporter: [["list"], ["html", { open: "never" }]],
});

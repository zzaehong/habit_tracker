import { installBackups } from "./backup";
import { captureProcessor } from "./capture";
import { installAI } from "./ai";
import { createApp } from "./app";
const { app, repo } = await createApp(process.env.DATA_DIR || "runtime", true);
installAI(app, repo, captureProcessor(repo, process.env.DATA_DIR || "runtime"));
installBackups(app, repo, process.env.DATA_DIR || "runtime");
await app.listen({ port: Number(process.env.PORT || 8787), host: "127.0.0.1" });
console.log("차곡 서버: http://127.0.0.1:" + String(process.env.PORT || 8787));
for (const signal of ["SIGINT", "SIGTERM"])
  process.on(signal, () => {
    app.close().then(() => process.exit(0));
  });

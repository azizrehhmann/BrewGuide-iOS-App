// Renders standalone SVG files to transparent PNGs with headless Chrome.
//   node --experimental-websocket render.mjs <scale> <in.svg> <out.png> [<in.svg> <out.png> ...]
import { spawn } from "node:child_process";
import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { pathToFileURL } from "node:url";
import { chromePort } from "./chrome-port.mjs";

const [scaleArg, ...pairs] = process.argv.slice(2);
const scale = Number(scaleArg);
if (!scale || pairs.length % 2) {
  console.error("usage: render.mjs <scale> <in.svg> <out.png> ...");
  process.exit(1);
}

const binary = [
  process.env.CHROME_PATH,
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
  "/Applications/Chromium.app/Contents/MacOS/Chromium",
].find((path) => path && existsSync(path));
if (!binary) {
  console.error("No Chrome found. Set CHROME_PATH.");
  process.exit(1);
}

const profile = mkdtempSync(join(tmpdir(), "kohi-render-"));
const chrome = spawn(binary, ["--headless=new", "--remote-debugging-port=0", `--user-data-dir=${profile}`, "--no-first-run", "--hide-scrollbars", "--allow-file-access-from-files", "about:blank"]);
const port = await chromePort(chrome, profile);
const target = await (await fetch(`http://127.0.0.1:${port}/json/new?about:blank`, { method: "PUT" })).json();
const socket = new WebSocket(target.webSocketDebuggerUrl);
await new Promise((done) => (socket.onopen = done));
let id = 0;
const pending = new Map();
let loaded = () => {};
socket.onmessage = (message) => {
  const data = JSON.parse(message.data);
  if (data.method === "Page.loadEventFired") loaded();
  if (data.id && pending.has(data.id)) {
    pending.get(data.id)(data);
    pending.delete(data.id);
  }
};
const send = (method, params = {}) =>
  new Promise((done) => {
    const n = ++id;
    pending.set(n, done);
    socket.send(JSON.stringify({ id: n, method, params }));
  });

await send("Page.enable");
await send("Emulation.setDefaultBackgroundColorOverride", { color: { r: 0, g: 0, b: 0, a: 0 } });
try {
  for (let i = 0; i < pairs.length; i += 2) {
    const svgPath = resolve(pairs[i]);
    const [, w, h] = readFileSync(svgPath, "utf8").match(/viewBox="0 0 ([\d.]+) ([\d.]+)"/) ?? [];
    const width = Math.ceil(Number(w));
    const height = Math.ceil(Number(h));
    await send("Emulation.setDeviceMetricsOverride", { width, height, deviceScaleFactor: scale, mobile: false });
    // A sibling HTML file: a data: page may not load file:// images
    const htmlPath = svgPath.replace(/\.svg$/, ".render.html");
    writeFileSync(htmlPath, `<!doctype html><html><body style="margin:0;background:transparent"><img src="${pathToFileURL(svgPath).href}" style="display:block;width:${width}px;height:${height}px"></body></html>`);
    const page = pathToFileURL(htmlPath).href;
    const ready = new Promise((done) => (loaded = done));
    await send("Page.navigate", { url: page });
    await ready;
    await new Promise((done) => setTimeout(done, 150));
    const shot = await send("Page.captureScreenshot", { format: "png", clip: { x: 0, y: 0, width, height, scale: 1 } });
    writeFileSync(resolve(pairs[i + 1]), Buffer.from(shot.result.data, "base64"));
    rmSync(htmlPath, { force: true });
    console.log("rendered", pairs[i + 1], `${width * scale}x${height * scale}`);
  }
} finally {
  socket.close();
  chrome.kill("SIGKILL");
  setTimeout(() => {
    try {
      rmSync(profile, { recursive: true, force: true });
    } catch {}
  }, 300);
}

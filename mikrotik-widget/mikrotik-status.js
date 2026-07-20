// Variables used by Scriptable.
// These must be at the very top of the file. Do not edit.
// icon-color: red; icon-glyph: network-wired;
//
// MikroTik Status Widget для iPhone (Scriptable)
//
// Показує навантаження роутера MikroTik: CPU, RAM, аптайм і трафік
// на WAN-інтерфейсі. Працює через REST API RouterOS (потрібен RouterOS 7.1+).
//
// Налаштування — відредагуйте блок CONFIG нижче.

// ============================== CONFIG ==============================

const CONFIG = {
  // IP-адреса або hostname роутера в локальній мережі
  host: "192.168.88.1",

  // true  -> https (сервіс www-ssl, потрібен валідний сертифікат)
  // false -> http  (сервіс www; вмикайте лише в локальній мережі)
  useHttps: false,

  // Користувач RouterOS (радимо окремого read-only користувача, див. README)
  user: "widget",
  password: "ЗМІНІТЬ_МЕНЕ",

  // Інтерфейс, трафік якого показувати (зазвичай WAN)
  wanInterface: "ether1",

  // Як часто iOS має оновлювати віджет (хвилини; iOS може оновлювати рідше)
  refreshMinutes: 5,
};

// ====================================================================

const COLORS = {
  bgTop: new Color("#1c1c2e"),
  bgBottom: new Color("#12121c"),
  text: Color.white(),
  dim: new Color("#9a9ab0"),
  barBg: new Color("#3a3a50"),
  good: new Color("#34c759"),
  warn: new Color("#ff9f0a"),
  bad: new Color("#ff453a"),
  accent: new Color("#64d2ff"),
};

function baseUrl() {
  return (CONFIG.useHttps ? "https" : "http") + "://" + CONFIG.host + "/rest";
}

function authHeader() {
  const data = Data.fromString(CONFIG.user + ":" + CONFIG.password);
  return "Basic " + data.toBase64String();
}

async function apiGet(path) {
  const req = new Request(baseUrl() + path);
  req.headers = { Authorization: authHeader() };
  req.timeoutInterval = 10;
  return await req.loadJSON();
}

async function apiPost(path, body) {
  const req = new Request(baseUrl() + path);
  req.method = "POST";
  req.headers = {
    Authorization: authHeader(),
    "Content-Type": "application/json",
  };
  req.body = JSON.stringify(body);
  req.timeoutInterval = 10;
  return await req.loadJSON();
}

// Збирає всі дані з роутера
async function fetchStatus() {
  const resource = await apiGet("/system/resource");

  let identity = null;
  try {
    identity = await apiGet("/system/identity");
  } catch (e) {}

  let traffic = null;
  try {
    const r = await apiPost("/interface/monitor-traffic", {
      interface: CONFIG.wanInterface,
      once: true,
    });
    traffic = Array.isArray(r) ? r[0] : r;
  } catch (e) {}

  const totalMem = parseInt(resource["total-memory"], 10);
  const freeMem = parseInt(resource["free-memory"], 10);

  return {
    name: identity ? identity.name : CONFIG.host,
    board: resource["board-name"] || "",
    version: resource["version"] || "",
    cpuLoad: parseInt(resource["cpu-load"], 10),
    memUsedPct: totalMem > 0 ? ((totalMem - freeMem) / totalMem) * 100 : 0,
    memUsed: totalMem - freeMem,
    memTotal: totalMem,
    uptime: resource["uptime"] || "",
    rxBps: traffic ? parseInt(traffic["rx-bits-per-second"], 10) : null,
    txBps: traffic ? parseInt(traffic["tx-bits-per-second"], 10) : null,
  };
}

// ---------- форматування ----------

function loadColor(pct) {
  if (pct < 50) return COLORS.good;
  if (pct < 80) return COLORS.warn;
  return COLORS.bad;
}

function fmtBytes(bytes) {
  if (bytes >= 1073741824) return (bytes / 1073741824).toFixed(1) + " ГБ";
  if (bytes >= 1048576) return (bytes / 1048576).toFixed(0) + " МБ";
  return (bytes / 1024).toFixed(0) + " КБ";
}

function fmtBps(bits) {
  if (bits == null || isNaN(bits)) return "—";
  if (bits >= 1e9) return (bits / 1e9).toFixed(2) + " Гбіт/с";
  if (bits >= 1e6) return (bits / 1e6).toFixed(1) + " Мбіт/с";
  if (bits >= 1e3) return (bits / 1e3).toFixed(0) + " кбіт/с";
  return bits + " біт/с";
}

// "1w2d3h4m5s" -> "1т 2д 3г" (двi найбільші одиниці)
function fmtUptime(uptime) {
  const m = uptime.match(/(?:(\d+)w)?(?:(\d+)d)?(?:(\d+)h)?(?:(\d+)m)?(?:(\d+)s)?/);
  if (!m) return uptime;
  const parts = [];
  if (m[1]) parts.push(m[1] + "т");
  if (m[2]) parts.push(m[2] + "д");
  if (m[3]) parts.push(m[3] + "г");
  if (m[4]) parts.push(m[4] + "хв");
  if (m[5] && parts.length === 0) parts.push(m[5] + "с");
  return parts.slice(0, 2).join(" ") || uptime;
}

// ---------- малювання ----------

function addBar(parent, pct, width, height) {
  const frac = Math.max(0, Math.min(1, pct / 100));
  const outer = parent.addStack();
  outer.size = new Size(width, height);
  outer.backgroundColor = COLORS.barBg;
  outer.cornerRadius = height / 2;
  outer.layoutHorizontally();

  const inner = outer.addStack();
  inner.size = new Size(Math.max(height, width * frac), height);
  inner.backgroundColor = loadColor(pct);
  inner.cornerRadius = height / 2;
  outer.addSpacer();
}

function addMetricRow(widget, label, valueText, pct, barWidth) {
  const row = widget.addStack();
  row.layoutHorizontally();
  row.centerAlignContent();

  const lbl = row.addText(label);
  lbl.font = Font.mediumSystemFont(11);
  lbl.textColor = COLORS.dim;
  lbl.lineLimit = 1;

  row.addSpacer();

  const val = row.addText(valueText);
  val.font = Font.boldSystemFont(11);
  val.textColor = loadColor(pct);

  widget.addSpacer(2);
  addBar(widget, pct, barWidth, 6);
}

function buildWidget(status, family) {
  const w = new ListWidget();
  const grad = new LinearGradient();
  grad.colors = [COLORS.bgTop, COLORS.bgBottom];
  grad.locations = [0, 1];
  w.backgroundGradient = grad;
  w.setPadding(12, 14, 12, 14);
  w.refreshAfterDate = new Date(Date.now() + CONFIG.refreshMinutes * 60 * 1000);

  const isSmall = family === "small";
  const barWidth = isSmall ? 120 : 145;

  // Заголовок
  const header = w.addStack();
  header.layoutHorizontally();
  header.centerAlignContent();
  const dot = header.addText("●");
  dot.font = Font.systemFont(9);
  dot.textColor = COLORS.good;
  header.addSpacer(5);
  const title = header.addText(status.name);
  title.font = Font.boldSystemFont(13);
  title.textColor = COLORS.text;
  title.lineLimit = 1;
  header.addSpacer();
  if (!isSmall && status.board) {
    const board = header.addText(status.board);
    board.font = Font.systemFont(10);
    board.textColor = COLORS.dim;
    board.lineLimit = 1;
  }

  w.addSpacer(8);

  if (isSmall) {
    addMetricRow(w, "CPU", status.cpuLoad + "%", status.cpuLoad, barWidth);
    w.addSpacer(7);
    addMetricRow(w, "RAM", Math.round(status.memUsedPct) + "%", status.memUsedPct, barWidth);
    w.addSpacer(8);
    const up = w.addText("⏱ " + fmtUptime(status.uptime));
    up.font = Font.systemFont(10);
    up.textColor = COLORS.dim;
  } else {
    // medium: зліва метрики, справа трафік і аптайм
    const cols = w.addStack();
    cols.layoutHorizontally();

    const left = cols.addStack();
    left.layoutVertically();
    addMetricRow(left, "CPU", status.cpuLoad + "%", status.cpuLoad, barWidth);
    left.addSpacer(8);
    addMetricRow(
      left,
      "RAM  " + fmtBytes(status.memUsed) + " / " + fmtBytes(status.memTotal),
      Math.round(status.memUsedPct) + "%",
      status.memUsedPct,
      barWidth
    );

    cols.addSpacer(18);

    const right = cols.addStack();
    right.layoutVertically();

    const dl = right.addText("↓ " + fmtBps(status.rxBps));
    dl.font = Font.mediumSystemFont(12);
    dl.textColor = COLORS.accent;
    right.addSpacer(4);
    const ul = right.addText("↑ " + fmtBps(status.txBps));
    ul.font = Font.mediumSystemFont(12);
    ul.textColor = COLORS.accent;
    right.addSpacer(8);
    const up = right.addText("⏱ " + fmtUptime(status.uptime));
    up.font = Font.systemFont(11);
    up.textColor = COLORS.dim;
  }

  w.addSpacer();

  // Час останнього оновлення
  const footer = w.addStack();
  footer.layoutHorizontally();
  footer.addSpacer();
  const df = new DateFormatter();
  df.useShortTimeStyle();
  const upd = footer.addText("оновлено " + df.string(new Date()));
  upd.font = Font.systemFont(8);
  upd.textColor = COLORS.dim;

  return w;
}

function buildErrorWidget(err) {
  const w = new ListWidget();
  const grad = new LinearGradient();
  grad.colors = [COLORS.bgTop, COLORS.bgBottom];
  grad.locations = [0, 1];
  w.backgroundGradient = grad;
  w.setPadding(12, 14, 12, 14);
  // при помилці пробуємо частіше
  w.refreshAfterDate = new Date(Date.now() + 2 * 60 * 1000);

  const header = w.addStack();
  header.layoutHorizontally();
  header.centerAlignContent();
  const dot = header.addText("●");
  dot.font = Font.systemFont(9);
  dot.textColor = COLORS.bad;
  header.addSpacer(5);
  const title = header.addText(CONFIG.host);
  title.font = Font.boldSystemFont(13);
  title.textColor = COLORS.text;

  w.addSpacer(8);
  const msg = w.addText("Роутер недоступний");
  msg.font = Font.mediumSystemFont(12);
  msg.textColor = COLORS.bad;
  w.addSpacer(4);
  const det = w.addText(String(err).slice(0, 120));
  det.font = Font.systemFont(9);
  det.textColor = COLORS.dim;
  det.lineLimit = 3;
  w.addSpacer();
  return w;
}

// ---------- запуск ----------

let widget;
try {
  const status = await fetchStatus();
  widget = buildWidget(status, config.widgetFamily || "medium");
} catch (err) {
  widget = buildErrorWidget(err);
}

if (config.runsInWidget) {
  Script.setWidget(widget);
} else {
  await widget.presentMedium();
}
Script.complete();

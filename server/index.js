// LumoraRPG online server: who is online, rooms with a short code, invites
// and a relay for live co-op. The game itself runs on the room's host (the
// player who opened the room); this server only passes messages along.
//
// Messages are JSON text. From a client:
//   {t:"hello", name}            sign in with the account name
//   {t:"who", names:[...]}       which of these accounts are online
//   {t:"create"}                 open a room (you become its host)
//   {t:"join", code}             join a room by its code
//   {t:"leave"}                  leave the room (a leaving host closes it)
//   {t:"invite", to}             invite an online account to your room
//   {t:"game", d, to?}           co-op data for the room (or one member)
//   {t:"ping"}
// To a client:
//   {t:"welcome", id}  {t:"who", online}  {t:"room", code, host, members, you}
//   {t:"room_closed", reason}  {t:"invited", from, code}  {t:"invite_sent", to}
//   {t:"game", from, d}  {t:"error", msg}  {t:"pong"}

const http = require("http");
const { WebSocketServer } = require("ws");

const PORT = Number(process.env.PORT) || 8080;
const MAX_MEMBERS = 4;
const CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const NAME_MAX = 16;

const clients = new Map(); // id -> client
const rooms = new Map(); // code -> room
let nextId = 1;

function send(c, msg) {
  if (c.ws.readyState === 1) c.ws.send(JSON.stringify(msg));
}

function online(name) {
  const key = String(name).toLowerCase();
  for (const c of clients.values()) if (c.name && c.name.toLowerCase() === key) return c;
  return null;
}

function newCode() {
  for (;;) {
    let code = "";
    for (let i = 0; i < 5; i++) code += CODE_CHARS[Math.floor(Math.random() * CODE_CHARS.length)];
    if (!rooms.has(code)) return code;
  }
}

function roomInfo(room, you) {
  return {
    t: "room",
    code: room.code,
    host: room.host,
    members: room.members.map((id) => ({ id, name: clients.get(id)?.name || "?" })),
    you,
  };
}

function broadcastRoom(room) {
  for (const id of room.members) {
    const c = clients.get(id);
    if (c) send(c, roomInfo(room, id));
  }
}

function leaveRoom(c, reason) {
  const room = c.room && rooms.get(c.room);
  c.room = null;
  if (!room) return;
  room.members = room.members.filter((id) => id !== c.id);
  if (room.host === c.id || room.members.length === 0) {
    rooms.delete(room.code);
    for (const id of room.members) {
      const m = clients.get(id);
      if (!m) continue;
      m.room = null;
      send(m, { t: "room_closed", reason: reason || "Ev sahibi odadan ayrıldı." });
    }
    return;
  }
  broadcastRoom(room);
}

function joinRoom(c, code) {
  const room = rooms.get(String(code || "").toUpperCase().trim());
  if (!room) return send(c, { t: "error", msg: "Bu kodla bir oda yok." });
  if (room.members.includes(c.id)) return send(c, roomInfo(room, c.id));
  if (room.members.length >= MAX_MEMBERS) return send(c, { t: "error", msg: "Oda dolu (en fazla " + MAX_MEMBERS + " kişi)." });
  if (c.room) leaveRoom(c);
  room.members.push(c.id);
  c.room = room.code;
  broadcastRoom(room);
}

function handle(c, msg) {
  if (!msg || typeof msg.t !== "string") return;
  if (msg.t === "ping") return send(c, { t: "pong" });
  if (msg.t === "hello") {
    c.name = String(msg.name || "").trim().slice(0, NAME_MAX);
    return send(c, { t: "welcome", id: c.id });
  }
  if (!c.name) return send(c, { t: "error", msg: "Önce giriş yap." });
  switch (msg.t) {
    case "who": {
      const names = Array.isArray(msg.names) ? msg.names.slice(0, 200) : [];
      return send(c, { t: "who", online: names.filter((n) => online(n)) });
    }
    case "create": {
      if (c.room) leaveRoom(c);
      const room = { code: newCode(), host: c.id, members: [c.id] };
      rooms.set(room.code, room);
      c.room = room.code;
      return broadcastRoom(room);
    }
    case "join":
      return joinRoom(c, msg.code);
    case "leave":
      return leaveRoom(c);
    case "invite": {
      if (!c.room) return send(c, { t: "error", msg: "Önce bir oda kur." });
      const to = online(msg.to);
      if (!to) return send(c, { t: "error", msg: String(msg.to) + " şu an çevrimiçi değil." });
      if (to === c) return send(c, { t: "error", msg: "Kendini davet edemezsin." });
      send(to, { t: "invited", from: c.name, code: c.room });
      return send(c, { t: "invite_sent", to: to.name });
    }
    case "game": {
      const room = c.room && rooms.get(c.room);
      if (!room) return;
      const out = JSON.stringify({ t: "game", from: c.id, d: msg.d });
      for (const id of room.members) {
        if (id === c.id || (msg.to !== undefined && msg.to !== id)) continue;
        const m = clients.get(id);
        if (m && m.ws.readyState === 1) m.ws.send(out);
      }
      return;
    }
  }
}

const server = http.createServer((req, res) => {
  res.writeHead(200, { "content-type": "text/plain; charset=utf-8" });
  res.end(`Lumora online sunucusu çalışıyor. Çevrimiçi: ${clients.size}, oda: ${rooms.size}\n`);
});

const wss = new WebSocketServer({ server, maxPayload: 256 * 1024 });

wss.on("connection", (ws) => {
  const c = { id: nextId++, ws, name: "", room: null, alive: true };
  clients.set(c.id, c);
  ws.on("pong", () => (c.alive = true));
  ws.on("message", (data, isBinary) => {
    if (isBinary) return;
    let msg;
    try {
      msg = JSON.parse(data.toString());
    } catch {
      return;
    }
    handle(c, msg);
  });
  ws.on("close", () => {
    leaveRoom(c);
    clients.delete(c.id);
  });
});

// Drop connections that stopped answering.
const heartbeat = setInterval(() => {
  for (const c of clients.values()) {
    if (!c.alive) {
      c.ws.terminate();
      continue;
    }
    c.alive = false;
    c.ws.ping();
  }
}, 20000);
wss.on("close", () => clearInterval(heartbeat));

server.listen(PORT, () => console.log(`Lumora online server on port ${PORT}`));

module.exports = { server, wss };

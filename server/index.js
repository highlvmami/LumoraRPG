// LumoraRPG online server: who is online, rooms with a short code, invites
// and a relay for live co-op. The game itself runs on the room's host (the
// player who opened the room); this server only passes messages along.
//
// Accounts live in Postgres (DATABASE_URL) with their saved game (profile),
// so the same account works on any computer; without a database (local
// tests) they are kept in memory.
//
// Messages are JSON text. From a client:
//   {t:"register", name, pw, profile?, at?}  open an account (signs in)
//   {t:"login", name, pw}        sign in; answer {t:"auth", ok, name, token, profile, savedAt}
//   {t:"resume", name, token}    sign in again with a remembered token
//   {t:"save", profile, at}      store the signed-in account's game
//   {t:"password", new}          change the password (other devices sign out)
//   {t:"online_list"}            up to 50 accounts online now
//   {t:"exists", name}           is there an account with this name
//   {t:"who", names:[...]}       which of these accounts are online (and their levels)
//   {t:"levels", names:[...]}    account levels of these accounts
//   {t:"leaderboard", cat}       the best 20 accounts of a category and your rank
//   {t:"create", look?}          open a room (you become its host)
//   {t:"join", code, look?}      join a room by its code
//   {t:"look", look}             how your character looks (shown in the room's tavern)
//   {t:"leave"}                  leave the room (a leaving host closes it)
//   {t:"invite", to}             invite an online account to your room
//   {t:"game", d, to?}           co-op data for the room (or one member)
//   {t:"hub_join", look?}        walk into the hub tavern (everyone online can come)
//   {t:"hub_leave"}              leave the hub tavern
//   {t:"hub_state", d}           where you are in the tavern: {p:[x,y,z], f, s, a, o}
//   {t:"chat", text}             say something in the hub tavern
//   {t:"guild"}                  your guild (or none)
//   {t:"guild_list"}             the biggest guilds
//   {t:"guild_create", name, tag} {t:"guild_join", name}  {t:"guild_leave"}  {t:"guild_kick", name}
//   {t:"guild_chat", text}       say something to your guild
//   {t:"guild_kills", n}         monsters defeated in a run (weekly guild goal)
//   {t:"duel_challenge", to, fighter}  {t:"duel_inbox"}  {t:"duel_answer", from, accept, fighter}
//   {t:"guild_claim"}            take the weekly reward once the goal is reached
//   {t:"trade_offer", to, item, price}  offer an item from your backpack for gold
//   {t:"trade_answer", id, accept}      accept or decline an offer made to you
//   {t:"trade_cancel", id}              take back your offer
//   {t:"trades"}                        your open offers
//   {t:"ping"}
// To a client:
//   {t:"welcome", id}  {t:"auth", ...}  {t:"saved", at}  {t:"who", online, levels}
//   {t:"levels", levels}  {t:"leaderboard", cat, rows:[{name, value, level}], me:{rank, value}|null}
//   {t:"online_list", names, levels}  {t:"exists", name, found}  {t:"password", ok, msg, token}  {t:"room", code, host, members, you}
//   {t:"room_closed", reason}  {t:"invited", from, code}  {t:"invite_sent", to}
//   {t:"game", from, d}  {t:"error", msg}  {t:"pong"}
//   {t:"hub", members:[{id, name, look, seat, level}], you, chat:[{name, text, at}]}  {t:"hub_chat", id, name, text, at}
//   {t:"hub_state", id, d}       another visitor of the hub tavern moved or sat down
//   {t:"guild", guild:{name, tag, leader, members:[{name, level, online}], chat, quest:{goal, progress, reward, claimed, top, endsIn}}|null}
//   {t:"guild_reward", gold}
//   {t:"duel_sent", to}  {t:"duel_inbox", invites:[{from, cls}]}  {t:"duel_declined", by}
//   {t:"duel_result", a, b, winner:0|1|-1, frames:[[seconds, hpA, hpB, hitA, hitB]]}
//   {t:"guild_list", guilds:[{name, tag, members, leader}]}  {t:"guild_chat", name, text, at}
//   {t:"trades", offers:[{id, from, to, item, price}]}  (sent whenever your offers change)
//   {t:"trade_done", id, from, to, item, price}  a trade went through: the seller gives the
//                                item and gets the gold, the buyer the other way round
//   {t:"trade_closed", id, reason}

const http = require("http");
const { WebSocketServer } = require("ws");
const { Accounts, key } = require("./accounts.js");
const { Guilds } = require("./guilds.js");
const { Duels } = require("./duels.js");
const { Trades } = require("./trades.js");

const PORT = Number(process.env.PORT) || 8080;
const MAX_MEMBERS = 4;
const CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const MAX_FAILS = 8;
const MAX_LOOK = 1500;
const BOARD_SIZE = 20;
const BOARD_CACHE_MS = 15000;
const HUB_MAX = 40; // visitors in the hub tavern (each gets a spot number to arrive at)
const HUB_ACTIONS = ["", "sit", "swing", "dance"];
const HUB_STATE_GAP_MS = 30;
const CHAT_KEEP = 40;
const CHAT_MAX = 200;
const CHAT_GAP_MS = 600;

// Leaderboard categories: where the number is in the saved game.
const BOARDS = {
  level: ["accountLevel"],
  kills: ["totalKills"],
  bosses: ["stats", "bossKills"],
  bestLevel: ["bestLevel"],
  bestTime: ["stats", "bestTime"],
  damage: ["stats", "damageDealt"],
  gold: ["stats", "goldEarned"],
};
const boardCache = new Map(); // cat -> {at, rows}

const accounts = new Accounts(process.env.DATABASE_URL);
const guilds = new Guilds(accounts.store.pool);
const duels = new Duels();
const trades = new Trades();

const clients = new Map(); // id -> client
const rooms = new Map(); // code -> room
// The hub tavern: one big room for everyone online to walk around and chat in.
const hub = { seats: new Map(), chat: [] }; // seats: client id -> arrival spot number
let nextId = 1;

function send(c, msg) {
  if (c.ws.readyState === 1) c.ws.send(JSON.stringify(msg));
}

function online(name) {
  const k = key(name);
  for (const c of clients.values()) if (c.name && key(c.name) === k) return c;
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
    members: room.members.map((id) => ({ id, name: clients.get(id)?.name || "?", look: clients.get(id)?.look || null })),
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

// A small look dictionary for the tavern (anything else is ignored).
function setLook(c, look) {
  if (!look || typeof look !== "object" || Array.isArray(look)) return false;
  if (JSON.stringify(look).length > MAX_LOOK) return false;
  c.look = look;
  return true;
}

async function hubInfo(you) {
  const ids = [...hub.seats.keys()];
  const names = ids.map((id) => clients.get(id)?.name || "?");
  const levels = await accounts.levels(names);
  return {
    t: "hub",
    you,
    members: ids.map((id, n) => {
      const c = clients.get(id);
      return { id, name: names[n], look: c?.look || null, seat: hub.seats.get(id), level: levels[names[n]] || 0, guild: guilds.of(names[n])?.tag || "" };
    }),
    chat: hub.chat,
  };
}

async function broadcastHub() {
  const info = await hubInfo(0);
  for (const id of hub.seats.keys()) {
    const c = clients.get(id);
    if (c) send(c, { ...info, you: id });
  }
}

function hubJoin(c) {
  if (hub.seats.has(c.id)) return broadcastHub();
  const taken = new Set(hub.seats.values());
  let seat = -1;
  for (let s = 0; s < HUB_MAX; s++) {
    if (!taken.has(s)) {
      seat = s;
      break;
    }
  }
  if (seat < 0) return send(c, { t: "error", msg: "Taverna dolu, biraz sonra tekrar dene." });
  hub.seats.set(c.id, seat);
  return broadcastHub();
}

function hubLeave(c) {
  if (!hub.seats.delete(c.id)) return;
  broadcastHub().catch((e) => console.error("hub update failed", e));
}

// Where a visitor is: numbers only, a known action, passed on to the others.
function hubState(c, d) {
  if (!hub.seats.has(c.id) || !d || typeof d !== "object") return;
  const now = Date.now();
  if (now - (c.lastState || 0) < HUB_STATE_GAP_MS) return;
  const num = (v) => (Number.isFinite(v) ? Math.round(v * 100) / 100 : 0);
  const p = Array.isArray(d.p) ? d.p.slice(0, 3).map((v) => num(Number(v))) : [0, 0, 0];
  while (p.length < 3) p.push(0);
  const clean = {
    p,
    f: num(Number(d.f)),
    s: num(Number(d.s)),
    a: HUB_ACTIONS.includes(d.a) ? d.a : "",
    o: Number.isInteger(d.o) && d.o >= 0 && d.o < 1000 ? d.o : -1,
  };
  c.lastState = now;
  const out = JSON.stringify({ t: "hub_state", id: c.id, d: clean });
  for (const id of hub.seats.keys()) {
    if (id === c.id) continue;
    const m = clients.get(id);
    if (m && m.ws.readyState === 1) m.ws.send(out);
  }
}

// A chat line: one line of plain text, not too long, not too often.
function hubChat(c, text) {
  if (!hub.seats.has(c.id)) return send(c, { t: "error", msg: "Sohbet için tavernada olmalısın." });
  const now = Date.now();
  if (now - (c.lastChat || 0) < CHAT_GAP_MS) return;
  const clean = String(text ?? "")
    .replace(/[\u0000-\u001f\u007f]/g, " ")
    .trim()
    .slice(0, CHAT_MAX);
  if (!clean) return;
  c.lastChat = now;
  const line = { name: c.name, text: clean, at: now };
  hub.chat.push(line);
  if (hub.chat.length > CHAT_KEEP) hub.chat.shift();
  const out = JSON.stringify({ t: "hub_chat", id: c.id, ...line });
  for (const id of hub.seats.keys()) {
    const m = clients.get(id);
    if (m && m.ws.readyState === 1) m.ws.send(out);
  }
}

// --- Guilds -------------------------------------------------------------------

async function guildInfo(g) {
  if (!g) return { t: "guild", guild: null };
  const levels = await accounts.levels(g.members);
  return {
    t: "guild",
    guild: {
      name: g.name,
      tag: g.tag,
      leader: g.leader,
      members: g.members.map((m) => ({ name: m, level: levels[m] || 1, online: Boolean(online(m)) })),
      chat: g.chat,
      quest: guilds.questView(g),
    },
  };
}

// Tells every online member (and anyone listed in `also`) how the guild looks now.
async function broadcastGuild(g, also = []) {
  const info = await guildInfo(g);
  for (const name of g ? g.members : []) {
    const m = online(name);
    if (m) send(m, info);
  }
  for (const name of also) {
    const m = online(name);
    if (m) send(m, { t: "guild", guild: null });
  }
  if (hub.seats.size) await broadcastHub();
}

async function guildMessage(c, msg) {
  switch (msg.t) {
    case "guild":
      return send(c, await guildInfo(guilds.of(c.name)));
    case "guild_list":
      return send(c, { t: "guild_list", guilds: guilds.list() });
    case "guild_create": {
      const res = await guilds.create(c.name, msg.name, msg.tag);
      if (!res.ok) return send(c, { t: "error", msg: res.msg });
      return broadcastGuild(res.guild);
    }
    case "guild_join": {
      const res = await guilds.join(c.name, msg.name);
      if (!res.ok) return send(c, { t: "error", msg: res.msg });
      return broadcastGuild(res.guild);
    }
    case "guild_leave": {
      const res = await guilds.leave(c.name);
      if (!res.ok) return send(c, { t: "error", msg: res.msg });
      return broadcastGuild(res.guild, [c.name]);
    }
    case "guild_kick": {
      const who = String(msg.name || "");
      const res = await guilds.kick(c.name, who);
      if (!res.ok) return send(c, { t: "error", msg: res.msg });
      const out = online(who);
      if (out) send(out, { t: "error", msg: "Loncadan çıkarıldın." });
      return broadcastGuild(res.guild, [who]);
    }
    case "guild_kills": {
      const res = await guilds.addKills(c.name, msg.n);
      if (!res.ok) return;
      return broadcastGuild(res.guild);
    }
    case "guild_claim": {
      const res = await guilds.claim(c.name);
      if (!res.ok) return send(c, { t: "error", msg: res.msg });
      send(c, { t: "guild_reward", gold: res.gold });
      return broadcastGuild(res.guild);
    }
    case "guild_chat": {
      const now = Date.now();
      if (now - (c.lastGuildChat || 0) < CHAT_GAP_MS) return;
      const clean = String(msg.text ?? "").replace(/[\u0000-\u001f\u007f]/g, " ").trim().slice(0, CHAT_MAX);
      if (!clean) return;
      c.lastGuildChat = now;
      const line = { name: c.name, text: clean, at: now };
      const g = await guilds.say(c.name, line);
      if (!g) return send(c, { t: "error", msg: "Bir loncada değilsin." });
      for (const name of g.members) {
        const m = online(name);
        if (m) send(m, { t: "guild_chat", ...line });
      }
      return;
    }
  }
}

// --- Duels ---

async function duelMessage(c, msg) {
  switch (msg.t) {
    case "duel_challenge": {
      const target = online(String(msg.to || ""));
      if (!target) return send(c, { t: "error", msg: "Bu oyuncu çevrimiçi değil." });
      const res = duels.challenge(c.name, target.name, msg.fighter);
      if (!res.ok) return send(c, { t: "error", msg: res.msg });
      send(target, { t: "duel_inbox", invites: duels.inbox(target.name) });
      return send(c, { t: "duel_sent", to: target.name });
    }
    case "duel_inbox":
      return send(c, { t: "duel_inbox", invites: duels.inbox(c.name) });
    case "duel_answer": {
      const res = duels.answer(c.name, String(msg.from || ""), Boolean(msg.accept), msg.fighter);
      if (!res.ok) return send(c, { t: "error", msg: res.msg });
      send(c, { t: "duel_inbox", invites: duels.inbox(c.name) });
      const challenger = online(String(msg.from || ""));
      if (res.declined) {
        if (challenger) send(challenger, { t: "duel_declined", by: c.name });
        return;
      }
      const result = { t: "duel_result", a: res.a, b: res.b, winner: res.winner, frames: res.frames };
      send(c, result);
      if (challenger) send(challenger, result);
      return;
    }
  }
}

// --- Trades ---

function sendTrades(name) {
  const c = name && online(name);
  if (c) send(c, { t: "trades", offers: trades.of(name, key).map(({ id, from, to, item, price }) => ({ id, from, to, item, price })) });
}

function closeTrade(id, reason) {
  const o = trades.close(id);
  if (!o) return;
  for (const n of [o.from, o.to]) {
    const m = online(n);
    if (m) send(m, { t: "trade_closed", id: o.id, reason });
    sendTrades(n);
  }
}

function tradeMessage(c, msg) {
  switch (msg.t) {
    case "trades":
      return sendTrades(c.name);
    case "trade_offer": {
      const to = online(msg.to);
      const res = trades.offer(c.name, to && to.name, msg.item, msg.price, key);
      if (res.msg) return send(c, { t: "error", msg: res.msg });
      sendTrades(c.name);
      return sendTrades(res.offer.to);
    }
    case "trade_cancel": {
      const o = trades.get(msg.id);
      if (!o || key(o.from) !== key(c.name)) return;
      return closeTrade(o.id, c.name + " teklifi geri aldı.");
    }
    case "trade_answer": {
      const o = trades.get(msg.id);
      if (!o || key(o.to) !== key(c.name)) return send(c, { t: "error", msg: "Bu teklif artık yok." });
      if (!msg.accept) return closeTrade(o.id, c.name + " teklifi reddetti.");
      const seller = online(o.from);
      if (!seller) return closeTrade(o.id, o.from + " çevrimiçi değil.");
      trades.close(o.id);
      const done = { t: "trade_done", id: o.id, from: o.from, to: o.to, item: o.item, price: o.price };
      send(seller, done);
      send(c, done);
      sendTrades(o.from);
      return sendTrades(o.to);
    }
  }
}

// Offers are dropped when either side goes offline.
function dropTrades(name) {
  if (!name || online(name)) return;
  for (const o of trades.of(name, key)) closeTrade(o.id, name + " çevrimdışı oldu.");
}

async function topRows(cat) {
  const hit = boardCache.get(cat);
  if (hit && Date.now() - hit.at < BOARD_CACHE_MS) return hit.rows;
  const rows = await accounts.top(BOARDS[cat], BOARD_SIZE);
  boardCache.set(cat, { at: Date.now(), rows });
  return rows;
}

async function authenticate(c, msg) {
  if (c.fails >= MAX_FAILS) return send(c, { t: "auth", ok: false, code: "too_many", msg: "Çok fazla deneme. Biraz sonra tekrar dene." });
  let res;
  if (msg.t === "register") res = await accounts.register(msg.name, msg.pw, msg.profile, msg.at);
  else if (msg.t === "login") res = await accounts.login(msg.name, msg.pw);
  else res = await accounts.resume(msg.name, msg.token);
  if (!res.ok) {
    c.fails++;
    return send(c, { t: "auth", ok: false, code: res.code, msg: res.msg });
  }
  c.name = res.name;
  send(c, { t: "auth", ok: true, name: res.name, token: res.token, profile: res.profile, savedAt: res.savedAt, id: c.id });
}

async function handle(c, msg) {
  if (!msg || typeof msg.t !== "string") return;
  if (msg.t === "ping") return send(c, { t: "pong" });
  if (msg.t === "hello") return send(c, { t: "error", msg: "Oyunun yeni sürümü var, sayfayı yenile." });
  if (msg.t === "register" || msg.t === "login" || msg.t === "resume") return authenticate(c, msg);
  if (msg.t === "exists") return send(c, { t: "exists", name: String(msg.name), found: await accounts.exists(msg.name) });
  if (!c.name) return send(c, { t: "error", msg: "Önce giriş yap." });
  switch (msg.t) {
    case "save":
      if (msg.profile && typeof msg.profile === "object" && (await accounts.save(c.name, msg.profile, msg.at))) send(c, { t: "saved", at: msg.at });
      return;
    case "password": {
      const res = await accounts.changePassword(c.name, msg.new);
      return send(c, { t: "password", ok: res.ok, msg: res.ok ? "Şifre değişti." : res.msg, token: res.token });
    }
    case "online_list": {
      const names = [...new Set([...clients.values()].filter((o) => o.name && o !== c).map((o) => o.name))].slice(0, 50);
      return send(c, { t: "online_list", names, levels: await accounts.levels(names) });
    }
    case "who": {
      const names = Array.isArray(msg.names) ? msg.names.slice(0, 200).map(String) : [];
      return send(c, { t: "who", online: names.filter((n) => online(n)), levels: await accounts.levels(names) });
    }
    case "levels": {
      const names = Array.isArray(msg.names) ? msg.names.slice(0, 200).map(String) : [];
      return send(c, { t: "levels", levels: await accounts.levels(names) });
    }
    case "leaderboard": {
      const cat = String(msg.cat);
      if (!Object.prototype.hasOwnProperty.call(BOARDS, cat)) return send(c, { t: "error", msg: "Böyle bir sıralama yok." });
      const rows = await topRows(cat);
      const me = await accounts.rank(BOARDS[cat], c.name);
      return send(c, { t: "leaderboard", cat, rows, me });
    }
    case "look": {
      if (!setLook(c, msg.look)) return;
      if (c.room && rooms.has(c.room)) broadcastRoom(rooms.get(c.room));
      if (hub.seats.has(c.id)) await broadcastHub();
      return;
    }
    case "guild":
    case "guild_list":
    case "guild_create":
    case "guild_join":
    case "guild_leave":
    case "guild_kick":
    case "guild_kills":
    case "guild_claim":
    case "guild_chat":
      return guildMessage(c, msg);
    case "duel_challenge":
    case "duel_inbox":
    case "duel_answer":
      return duelMessage(c, msg);
    case "trades":
    case "trade_offer":
    case "trade_cancel":
    case "trade_answer":
      return tradeMessage(c, msg);
    case "hub_join":
      setLook(c, msg.look);
      return hubJoin(c);
    case "hub_leave":
      return hubLeave(c);
    case "hub_state":
      return hubState(c, msg.d);
    case "chat":
      return hubChat(c, msg.text);
    case "create": {
      setLook(c, msg.look);
      if (c.room) leaveRoom(c);
      const room = { code: newCode(), host: c.id, members: [c.id] };
      rooms.set(room.code, room);
      c.room = room.code;
      return broadcastRoom(room);
    }
    case "join":
      setLook(c, msg.look);
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
  res.end(`Lumora online sunucusu çalışıyor. Çevrimiçi: ${clients.size}, oda: ${rooms.size}, tavernada: ${hub.seats.size}\n`);
});

const wss = new WebSocketServer({ server, maxPayload: 2 * 1024 * 1024 });

wss.on("connection", (ws) => {
  const c = { id: nextId++, ws, name: "", room: null, alive: true, fails: 0, look: null };
  clients.set(c.id, c);
  send(c, { t: "welcome", id: c.id });
  ws.on("pong", () => (c.alive = true));
  ws.on("message", (data, isBinary) => {
    if (isBinary) return;
    let msg;
    try {
      msg = JSON.parse(data.toString());
    } catch {
      return;
    }
    handle(c, msg).catch((e) => {
      console.error("message failed", e);
      send(c, { t: "error", msg: "Sunucu hatası, tekrar dene." });
    });
  });
  ws.on("close", () => {
    leaveRoom(c);
    hubLeave(c);
    clients.delete(c.id);
    dropTrades(c.name);
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

const ready = accounts
  .init()
  .then(() => guilds.init())
  .catch((e) => console.error("account database failed to start", e))
  .then(
    () =>
      new Promise((resolve) =>
        server.listen(PORT, () => {
          console.log(`Lumora online server on port ${PORT} (accounts: ${accounts.persistent ? "database" : "memory"})`);
          resolve();
        })
      )
  );

module.exports = { server, wss, ready, boardCache, hub, guilds };

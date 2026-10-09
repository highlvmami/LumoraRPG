// Guilds: a name, a short tag, a leader, up to MAX_GUILD members and the
// last guild chat lines. All guilds are kept in memory and written to
// Postgres (table guilds) when they change; without a database (local
// tests) they only live in memory.

const { key } = require("./accounts.js");

const MAX_GUILD = 20;
const GUILD_CHAT_KEEP = 40;
const GUILD_NAME_RE = /^[\p{L}\p{N} _]{3,20}$/u;
const TAG_RE = /^[\p{L}\p{N}]{2,4}$/u;

class Guilds {
  constructor(pool) {
    this.pool = pool || null; // a pg Pool, or null for memory only
    this.byKey = new Map(); // guild key -> {key, name, tag, leader, members:[name], chat:[{name,text,at}], createdAt}
  }
  async init() {
    if (!this.pool) return;
    await this.pool.query(`CREATE TABLE IF NOT EXISTS guilds (
      key TEXT PRIMARY KEY,
      data JSONB NOT NULL
    )`);
    const res = await this.pool.query("SELECT data FROM guilds");
    for (const r of res.rows) if (r.data && r.data.key) this.byKey.set(r.data.key, r.data);
  }
  async _save(g) {
    if (this.pool) await this.pool.query("INSERT INTO guilds (key, data) VALUES ($1, $2) ON CONFLICT (key) DO UPDATE SET data = $2", [g.key, JSON.stringify(g)]);
  }
  async _drop(g) {
    this.byKey.delete(g.key);
    if (this.pool) await this.pool.query("DELETE FROM guilds WHERE key = $1", [g.key]);
  }
  // The guild an account is in (or null).
  of(name) {
    const k = key(name);
    for (const g of this.byKey.values()) if (g.members.some((m) => key(m) === k)) return g;
    return null;
  }
  // The biggest guilds first: [{name, tag, members, leader}].
  list(limit = 30) {
    return [...this.byKey.values()]
      .sort((a, b) => b.members.length - a.members.length || a.name.localeCompare(b.name))
      .slice(0, limit)
      .map((g) => ({ name: g.name, tag: g.tag, members: g.members.length, leader: g.leader }));
  }
  // Each returns {ok, guild} or {ok:false, msg}.
  async create(owner, name, tag) {
    name = String(name || "").trim().replace(/\s+/g, " ");
    tag = String(tag || "").trim();
    if (!GUILD_NAME_RE.test(name)) return { ok: false, msg: "Lonca adı 3-20 harf, rakam ya da boşluk olmalı." };
    if (!TAG_RE.test(tag)) return { ok: false, msg: "Lonca etiketi 2-4 harf ya da rakam olmalı." };
    if (this.of(owner)) return { ok: false, msg: "Zaten bir loncadasın, önce ayrıl." };
    const k = key(name);
    if (this.byKey.has(k)) return { ok: false, msg: "Bu isimde bir lonca var." };
    if ([...this.byKey.values()].some((g) => key(g.tag) === key(tag))) return { ok: false, msg: "Bu etiket alınmış." };
    const g = { key: k, name, tag: tag.toLocaleUpperCase("tr"), leader: owner, members: [owner], chat: [], createdAt: Date.now() };
    this.byKey.set(k, g);
    await this._save(g);
    return { ok: true, guild: g };
  }
  async join(who, name) {
    const g = this.byKey.get(key(String(name || "")));
    if (!g) return { ok: false, msg: "Böyle bir lonca yok." };
    if (this.of(who)) return { ok: false, msg: "Zaten bir loncadasın, önce ayrıl." };
    if (g.members.length >= MAX_GUILD) return { ok: false, msg: `Lonca dolu (en fazla ${MAX_GUILD} kişi).` };
    g.members.push(who);
    await this._save(g);
    return { ok: true, guild: g };
  }
  // Leaving: the leader's place goes to the next member; the last one closes it.
  async leave(who) {
    const g = this.of(who);
    if (!g) return { ok: false, msg: "Bir loncada değilsin." };
    g.members = g.members.filter((m) => key(m) !== key(who));
    if (g.members.length === 0) {
      await this._drop(g);
      return { ok: true, guild: null, closed: g };
    }
    if (key(g.leader) === key(who)) g.leader = g.members[0];
    await this._save(g);
    return { ok: true, guild: g };
  }
  async kick(leader, who) {
    const g = this.of(leader);
    if (!g || key(g.leader) !== key(leader)) return { ok: false, msg: "Sadece lonca lideri çıkarabilir." };
    if (key(who) === key(leader)) return { ok: false, msg: "Kendini çıkaramazsın." };
    const before = g.members.length;
    g.members = g.members.filter((m) => key(m) !== key(who));
    if (g.members.length === before) return { ok: false, msg: "Bu oyuncu loncada değil." };
    await this._save(g);
    return { ok: true, guild: g };
  }
  async say(who, line) {
    const g = this.of(who);
    if (!g) return null;
    g.chat.push(line);
    if (g.chat.length > GUILD_CHAT_KEEP) g.chat.shift();
    await this._save(g);
    return g;
  }
}

module.exports = { Guilds, MAX_GUILD };

// Guilds: a name, a short tag, a leader, up to MAX_GUILD members and the
// last guild chat lines. All guilds are kept in memory and written to
// Postgres (table guilds) when they change; without a database (local
// tests) they only live in memory.

const { key } = require("./accounts.js");

const MAX_GUILD = 20;
// Guild upgrades are bought by the leader with the treasury (gold the
// members donate). Each level adds `per` to a stat of every member.
const UPGRADES = {
  gold: { name: "Altın Bereketi", stat: "goldGain", per: 0.02, max: 5, base: 600 },
  exp: { name: "Bilgelik", stat: "expGain", per: 0.03, max: 5, base: 600 },
  damage: { name: "Savaş Çığlığı", stat: "damage", per: 0.02, max: 5, base: 900 },
  health: { name: "Sağlam Kale", stat: "maxHp", per: 8, max: 5, base: 900 },
  size: { name: "Geniş Salon", stat: null, per: 4, max: 5, base: 1200 },
};
const MAX_DONATION = 100000;
const GUILD_CHAT_KEEP = 40;
const GUILD_NAME_RE = /^[\p{L}\p{N} _]{3,20}$/u;
const TAG_RE = /^[\p{L}\p{N}]{2,4}$/u;

// The weekly guild goal: the members together defeat enough monsters; then
// everyone who helped can take the reward once.
const GOAL_BASE = 1000;
const GOAL_PER_MEMBER = 400;
const REWARD_GOLD = 400;
const MAX_KILLS_PER_REPORT = 2500;
const WEEK_MS = 7 * 24 * 3600 * 1000;

// "2026-W41": the week a moment falls in (weeks start on Monday, UTC).
function weekKey(now = Date.now()) {
  const d = new Date(now);
  d.setUTCHours(0, 0, 0, 0);
  d.setUTCDate(d.getUTCDate() + 3 - ((d.getUTCDay() + 6) % 7));
  const week1 = new Date(Date.UTC(d.getUTCFullYear(), 0, 4));
  const n = 1 + Math.round(((d - week1) / 86400000 - 3 + ((week1.getUTCDay() + 6) % 7)) / 7);
  return `${d.getUTCFullYear()}-W${n}`;
}

// Start of the next week (Monday 00:00 UTC) after `now`.
function weekEnd(now = Date.now()) {
  const d = new Date(now);
  d.setUTCHours(0, 0, 0, 0);
  return d.getTime() + (7 - ((d.getUTCDay() + 6) % 7)) * 86400000;
}

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
    const cap = this.maxMembers(g);
    if (g.members.length >= cap) return { ok: false, msg: `Lonca dolu (en fazla ${cap} kişi).` };
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
  // Upgrade levels, treasury and what each upgrade costs next.
  upgradeLevel(g, id) {
    return Math.min(UPGRADES[id].max, Math.max(0, Math.floor((g.upgrades && g.upgrades[id]) || 0)));
  }
  maxMembers(g) {
    return MAX_GUILD + UPGRADES.size.per * this.upgradeLevel(g, "size");
  }
  upgradeCost(g, id) {
    const lv = this.upgradeLevel(g, id);
    return lv >= UPGRADES[id].max ? 0 : UPGRADES[id].base * (lv + 1);
  }
  // Stat bonuses every member gets: {goldGain: 0.04, ...}.
  bonuses(g) {
    const out = {};
    for (const [id, u] of Object.entries(UPGRADES)) {
      if (u.stat) out[u.stat] = (out[u.stat] || 0) + u.per * this.upgradeLevel(g, id);
    }
    return out;
  }
  upgradeView(g) {
    const levels = {};
    const costs = {};
    for (const id of Object.keys(UPGRADES)) {
      levels[id] = this.upgradeLevel(g, id);
      costs[id] = this.upgradeCost(g, id);
    }
    const donors = Object.entries(g.donors || {}).sort((a, b) => b[1] - a[1]).slice(0, 5).map(([name, gold]) => ({ name, gold }));
    return { treasury: g.treasury || 0, levels, costs, bonuses: this.bonuses(g), maxMembers: this.maxMembers(g), donors };
  }
  async donate(who, gold) {
    const g = this.of(who);
    if (!g) return { ok: false, msg: "Bir loncada değilsin." };
    const n = Math.floor(Number(gold) || 0);
    if (n < 1 || n > MAX_DONATION) return { ok: false, msg: `Bağış 1 ile ${MAX_DONATION} altın arasında olmalı.` };
    g.treasury = (g.treasury || 0) + n;
    g.donors = g.donors || {};
    g.donors[who] = (g.donors[who] || 0) + n;
    await this._save(g);
    return { ok: true, guild: g, gold: n };
  }
  async buy(who, id) {
    const g = this.of(who);
    if (!g || key(g.leader) !== key(who)) return { ok: false, msg: "Sadece lonca lideri yükseltme alabilir." };
    if (!Object.prototype.hasOwnProperty.call(UPGRADES, id)) return { ok: false, msg: "Böyle bir yükseltme yok." };
    const cost = this.upgradeCost(g, id);
    if (cost === 0) return { ok: false, msg: "Bu yükseltme en üst seviyede." };
    if ((g.treasury || 0) < cost) return { ok: false, msg: "Lonca kasasında yeterli altın yok." };
    g.treasury -= cost;
    g.upgrades = g.upgrades || {};
    g.upgrades[id] = this.upgradeLevel(g, id) + 1;
    await this._save(g);
    return { ok: true, guild: g };
  }
  // This week's goal of a guild; a new week starts a new one.
  quest(g, now = Date.now()) {
    const week = weekKey(now);
    if (!g.quest || g.quest.week !== week) g.quest = { week, progress: 0, contrib: {}, claimed: [] };
    return g.quest;
  }
  goal(g) {
    return GOAL_BASE + GOAL_PER_MEMBER * g.members.length;
  }
  questView(g, now = Date.now()) {
    const q = this.quest(g, now);
    const top = Object.entries(q.contrib).sort((a, b) => b[1] - a[1]).slice(0, 5).map(([name, kills]) => ({ name, kills }));
    return { goal: this.goal(g), progress: q.progress, reward: REWARD_GOLD, claimed: q.claimed, top, endsIn: weekEnd(now) - now };
  }
  // A member's defeated monsters count toward the goal.
  async addKills(who, kills, now = Date.now()) {
    const g = this.of(who);
    if (!g) return { ok: false, msg: "Bir loncada değilsin." };
    const n = Math.max(0, Math.min(MAX_KILLS_PER_REPORT, Math.floor(Number(kills) || 0)));
    if (n === 0) return { ok: true, guild: g };
    const q = this.quest(g, now);
    q.progress += n;
    q.contrib[who] = (q.contrib[who] || 0) + n;
    await this._save(g);
    return { ok: true, guild: g };
  }
  // Takes the weekly reward once, when the goal is reached and the member helped.
  async claim(who, now = Date.now()) {
    const g = this.of(who);
    if (!g) return { ok: false, msg: "Bir loncada değilsin." };
    const q = this.quest(g, now);
    const k = key(who);
    if (q.progress < this.goal(g)) return { ok: false, msg: "Haftalık hedef henüz tamamlanmadı." };
    if (!q.contrib[who]) return { ok: false, msg: "Ödül için hedefe en az bir canavarla katkı yapmalısın." };
    if (q.claimed.includes(k)) return { ok: false, msg: "Bu haftanın ödülünü zaten aldın." };
    q.claimed.push(k);
    await this._save(g);
    return { ok: true, guild: g, gold: REWARD_GOLD };
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

module.exports = { Guilds, MAX_GUILD, UPGRADES, weekKey, GOAL_BASE, GOAL_PER_MEMBER, REWARD_GOLD };

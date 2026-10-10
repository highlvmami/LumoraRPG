// The weekly world boss: one boss for the whole server. Every fight adds the
// damage a player did; when the shared health is gone the boss is down and
// everyone who hit it claims gold by their share. A new boss every week.
const { weekKey, weekEnd } = require("./guilds.js");

const BOSSES = ["boss", "spider_boss", "yeti_boss", "pharaoh_boss"];
const NAMES = { boss: "Orman Devi", spider_boss: "Örümcek Kraliçe", yeti_boss: "Buzul Yeti", pharaoh_boss: "Kum Firavunu" };
const MAX_HP = 400000;
const MAX_PER_FIGHT = 40000;
const MIN_GAP_MS = 45000;
const BASE_GOLD = 300;
const SHARE_GOLD = 4000;

class WorldBoss {
  constructor(pool) {
    this.pool = pool || null;
    this.doc = null; // {week, hp, dmg:{name:n}, claimed:{name:true}}
    this.last = new Map(); // name -> last fight time
  }
  async init() {
    if (!this.pool) return;
    await this.pool.query("CREATE TABLE IF NOT EXISTS worldboss (key TEXT PRIMARY KEY, data JSONB NOT NULL)");
    const res = await this.pool.query("SELECT data FROM worldboss WHERE key = 'current'");
    if (res.rows[0]) this.doc = res.rows[0].data;
  }
  async _save() {
    if (this.pool) await this.pool.query("INSERT INTO worldboss (key, data) VALUES ('current', $1) ON CONFLICT (key) DO UPDATE SET data = $1", [JSON.stringify(this.doc)]);
  }
  _current(now = Date.now()) {
    const week = weekKey(now);
    if (!this.doc || this.doc.week !== week) this.doc = { week, hp: MAX_HP, dmg: {}, claimed: {} };
    return this.doc;
  }
  kind(now = Date.now()) {
    const n = parseInt(weekKey(now).split("-W")[1], 10) || 0;
    return BOSSES[n % BOSSES.length];
  }
  view(name, now = Date.now()) {
    const d = this._current(now);
    const ranked = Object.entries(d.dmg).sort((a, b) => b[1] - a[1]);
    const mine = d.dmg[name] || 0;
    const dead = d.hp <= 0;
    const total = ranked.reduce((s, r) => s + r[1], 0);
    return {
      kind: this.kind(now), name: NAMES[this.kind(now)], hp: Math.max(0, d.hp), max: MAX_HP, endsIn: weekEnd(now) - now,
      mine, rank: mine ? ranked.findIndex((r) => r[0] === name) + 1 : 0, top: ranked.slice(0, 5).map((r) => ({ name: r[0], dmg: r[1] })),
      dead, claimed: !!d.claimed[name], reward: mine && dead ? this.rewardFor(mine, total) : 0,
    };
  }
  rewardFor(mine, total) {
    return BASE_GOLD + Math.round(SHARE_GOLD * (total ? mine / total : 0));
  }
  async hit(name, amount, now = Date.now()) {
    const d = this._current(now);
    if (d.hp <= 0) return { ok: false, msg: "Bu haftaki boss zaten yenildi." };
    const gap = now - (this.last.get(name) || 0);
    if (gap < MIN_GAP_MS) return { ok: false, msg: "Biraz dinlen, yeni savaş için bekle." };
    const dmg = Math.min(MAX_PER_FIGHT, Math.max(0, Math.floor(Number(amount) || 0)));
    if (dmg <= 0) return { ok: false, msg: "" };
    this.last.set(name, now);
    d.dmg[name] = (d.dmg[name] || 0) + dmg;
    d.hp -= dmg;
    await this._save();
    return { ok: true, dmg };
  }
  async claim(name, now = Date.now()) {
    const d = this._current(now);
    if (d.hp > 0) return { ok: false, msg: "Boss henüz yenilmedi." };
    const mine = d.dmg[name] || 0;
    if (!mine) return { ok: false, msg: "Bu bosa vurmadın." };
    if (d.claimed[name]) return { ok: false, msg: "Ödülü zaten aldın." };
    const total = Object.values(d.dmg).reduce((s, n) => s + n, 0);
    d.claimed[name] = true;
    await this._save();
    return { ok: true, gold: this.rewardFor(mine, total) };
  }
}

module.exports = { WorldBoss, MAX_HP, MAX_PER_FIGHT };

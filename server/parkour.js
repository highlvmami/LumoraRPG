// The tavern parkour course: every finished run is recorded per player (best
// time, runs, falls) and the board shows the fastest ten. Times are checked
// only for sanity: nobody finishes the course (on foot, about 100 m of jumps) faster than MIN_MS.
const MIN_MS = 12000;
const MAX_MS = 3600000;
const FIRST_GOLD = 300;
const RUN_GOLD = 40;
const RECORD_GOLD = 100;

class Parkour {
  constructor(pool) {
    this.pool = pool || null;
    this.rows = new Map(); // name -> {name, best, runs, falls, last}
    this.total = 0;
  }
  async init() {
    if (!this.pool) return;
    await this.pool.query("CREATE TABLE IF NOT EXISTS parkour (name TEXT PRIMARY KEY, data JSONB NOT NULL)");
    const res = await this.pool.query("SELECT name, data FROM parkour");
    for (const r of res.rows) this.rows.set(r.name, { name: r.name, ...r.data });
    this.total = [...this.rows.values()].reduce((s, r) => s + r.runs, 0);
  }
  async _save(row) {
    if (!this.pool) return;
    const { name, ...data } = row;
    await this.pool.query("INSERT INTO parkour (name, data) VALUES ($1, $2) ON CONFLICT (name) DO UPDATE SET data = $2", [name, JSON.stringify(data)]);
  }
  _ranked() {
    return [...this.rows.values()].filter((r) => r.best > 0).sort((a, b) => a.best - b.best || a.name.localeCompare(b.name));
  }
  board(name) {
    const ranked = this._ranked();
    const mine = this.rows.get(name);
    return {
      top: ranked.slice(0, 10).map((r) => ({ name: r.name, best: r.best, runs: r.runs })),
      mine: mine ? { best: mine.best, runs: mine.runs, falls: mine.falls, last: mine.last, rank: mine.best > 0 ? ranked.findIndex((r) => r.name === name) + 1 : 0 } : null,
      total: this.total,
      players: ranked.length,
    };
  }
  async finish(name, ms, falls) {
    const time = Math.floor(Number(ms) || 0);
    if (time < MIN_MS || time > MAX_MS) return { ok: false, msg: "Bu süre geçerli değil." };
    const row = this.rows.get(name) || { name, best: 0, runs: 0, falls: 0, last: 0 };
    const first = row.runs === 0;
    const record = row.best === 0 || time < row.best;
    row.runs += 1;
    row.falls += Math.max(0, Math.min(999, Math.floor(Number(falls) || 0)));
    row.last = time;
    if (record) row.best = time;
    this.rows.set(name, row);
    this.total += 1;
    await this._save(row);
    return { ok: true, ms: time, first, record, gold: RUN_GOLD + (first ? FIRST_GOLD : 0) + (record && !first ? RECORD_GOLD : 0) };
  }
}

module.exports = { Parkour, MIN_MS };

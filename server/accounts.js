// Account storage: Postgres when DATABASE_URL is set (Render), otherwise
// memory (local tests). Passwords are kept only as scrypt hashes; sign-in
// tokens only as sha256 hashes.

const crypto = require("crypto");

const MAX_TOKENS = 8;

function hashPassword(password, salt) {
  return crypto.scryptSync(String(password), salt, 32).toString("hex");
}

function sha(text) {
  return crypto.createHash("sha256").update(String(text)).digest("hex");
}

function key(name) {
  // Case-insensitive, and I / ı / İ / i count as the same letter.
  return String(name).trim().toLocaleLowerCase("tr").replace(/ı/g, "i");
}

// A number at `path` (["stats", "bossKills"]) in a saved game, 0 if missing.
function numberAt(profile, path) {
  let v = profile;
  for (const k of path) v = v && typeof v === "object" ? v[k] : undefined;
  const n = Number(v);
  return Number.isFinite(n) ? n : 0;
}

class MemoryStore {
  constructor() {
    this.rows = new Map();
  }
  async init() {}
  async top(path, limit) {
    return [...this.rows.values()]
      .filter((r) => r.profile)
      .map((r) => ({ name: r.name, value: numberAt(r.profile, path), level: numberAt(r.profile, ["accountLevel"]) }))
      .sort((a, b) => b.value - a.value || b.level - a.level || a.name.localeCompare(b.name))
      .slice(0, limit);
  }
  async rank(path, name) {
    const me = this.rows.get(key(name));
    if (!me || !me.profile) return null;
    const value = numberAt(me.profile, path);
    let above = 0;
    for (const r of this.rows.values()) if (r.profile && numberAt(r.profile, path) > value) above++;
    return { rank: above + 1, value };
  }
  async levels(names) {
    const out = {};
    for (const n of names) {
      const r = this.rows.get(key(n));
      if (r && r.profile) out[r.name] = numberAt(r.profile, ["accountLevel"]) || 1;
    }
    return out;
  }
  async get(name) {
    return this.rows.get(key(name)) || null;
  }
  async create(row) {
    if (this.rows.has(row.key)) return false;
    this.rows.set(row.key, row);
    return true;
  }
  async update(row) {
    this.rows.set(row.key, row);
  }
}

class PgStore {
  constructor(url) {
    const { Pool } = require("pg");
    this.pool = new Pool({ connectionString: url, ssl: url.includes("localhost") ? false : { rejectUnauthorized: false }, max: 4 });
  }
  async init() {
    await this.pool.query(`CREATE TABLE IF NOT EXISTS accounts (
      key TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      salt TEXT NOT NULL,
      hash TEXT NOT NULL,
      tokens JSONB NOT NULL DEFAULT '[]',
      profile JSONB,
      saved_at DOUBLE PRECISION NOT NULL DEFAULT 0,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )`);
  }
  _row(r) {
    return r && { key: r.key, name: r.name, salt: r.salt, hash: r.hash, tokens: r.tokens || [], profile: r.profile, savedAt: Number(r.saved_at) };
  }
  async get(name) {
    const res = await this.pool.query("SELECT * FROM accounts WHERE key = $1", [key(name)]);
    return this._row(res.rows[0]);
  }
  async create(row) {
    const res = await this.pool.query(
      "INSERT INTO accounts (key, name, salt, hash, tokens, profile, saved_at) VALUES ($1,$2,$3,$4,$5,$6,$7) ON CONFLICT (key) DO NOTHING",
      [row.key, row.name, row.salt, row.hash, JSON.stringify(row.tokens), row.profile ? JSON.stringify(row.profile) : null, row.savedAt]
    );
    return res.rowCount === 1;
  }
  // A number at a JSON path of the saved game; anything that isn't a number counts as 0.
  static _num(param) {
    return `(CASE WHEN (profile #>> ${param}::text[]) ~ '^-?[0-9]+(\\.[0-9]+)?([eE][-+]?[0-9]+)?$' THEN (profile #>> ${param}::text[])::float8 ELSE 0 END)`;
  }
  async top(path, limit) {
    const v = PgStore._num("$1");
    const lv = PgStore._num("'{accountLevel}'");
    const res = await this.pool.query(
      `SELECT name, ${v} AS value, ${lv} AS level FROM accounts WHERE profile IS NOT NULL ORDER BY value DESC, level DESC, name ASC LIMIT $2`,
      [path, limit]
    );
    return res.rows.map((r) => ({ name: r.name, value: Number(r.value), level: Number(r.level) }));
  }
  async rank(path, name) {
    const v = PgStore._num("$1");
    const res = await this.pool.query(
      `SELECT ${v} AS value, (SELECT count(*) FROM accounts o WHERE o.profile IS NOT NULL AND ${v.replace(/profile/g, "o.profile")} > ${v.replace(/profile/g, "a.profile")}) AS above
       FROM accounts a WHERE a.key = $2 AND a.profile IS NOT NULL`,
      [path, key(name)]
    );
    const r = res.rows[0];
    return r ? { rank: Number(r.above) + 1, value: Number(r.value) } : null;
  }
  async levels(names) {
    const lv = PgStore._num("'{accountLevel}'");
    const res = await this.pool.query(`SELECT name, ${lv} AS level FROM accounts WHERE key = ANY($1) AND profile IS NOT NULL`, [names.map(key)]);
    const out = {};
    for (const r of res.rows) out[r.name] = Number(r.level) || 1;
    return out;
  }
  async update(row) {
    await this.pool.query("UPDATE accounts SET salt=$2, hash=$3, tokens=$4, profile=$5, saved_at=$6 WHERE key=$1", [
      row.key, row.salt, row.hash, JSON.stringify(row.tokens), row.profile ? JSON.stringify(row.profile) : null, row.savedAt,
    ]);
  }
}

const NAME_RE = /^[\p{L}\p{N}_]{3,16}$/u;

class Accounts {
  constructor(url) {
    this.store = url ? new PgStore(url) : new MemoryStore();
    this.persistent = Boolean(url);
  }
  init() {
    return this.store.init();
  }
  _token(row) {
    const token = crypto.randomBytes(24).toString("hex");
    row.tokens = [sha(token), ...row.tokens].slice(0, MAX_TOKENS);
    return token;
  }
  // Each returns {ok, name, token, profile, savedAt} or {ok:false, code, msg}.
  async register(name, password, profile, savedAt) {
    name = String(name || "").trim();
    if (!NAME_RE.test(name)) return { ok: false, code: "bad_name", msg: "Kullanıcı adı 3-16 harf, rakam ya da _ olmalı." };
    if (String(password || "").length < 4) return { ok: false, code: "bad_password", msg: "Şifre en az 4 karakter olmalı." };
    const salt = crypto.randomBytes(16).toString("hex");
    const row = { key: key(name), name, salt, hash: hashPassword(password, salt), tokens: [], profile: profile || null, savedAt: Number(savedAt) || 0 };
    const token = this._token(row);
    if (!(await this.store.create(row))) return { ok: false, code: "taken", msg: "Bu kullanıcı adı alınmış." };
    return { ok: true, name: row.name, token, profile: row.profile, savedAt: row.savedAt };
  }
  async login(name, password) {
    const row = await this.store.get(name);
    if (!row) return { ok: false, code: "no_account", msg: "Böyle bir hesap yok. Kayıt Ol sekmesinden açabilirsin." };
    const given = Buffer.from(hashPassword(password, row.salt), "hex");
    if (!crypto.timingSafeEqual(given, Buffer.from(row.hash, "hex"))) return { ok: false, code: "wrong_password", msg: "Şifre yanlış." };
    const token = this._token(row);
    await this.store.update(row);
    return { ok: true, name: row.name, token, profile: row.profile, savedAt: row.savedAt };
  }
  async resume(name, token) {
    const row = await this.store.get(name);
    if (!row || !row.tokens.includes(sha(token))) return { ok: false, code: "token", msg: "Oturumun sona erdi, tekrar giriş yap." };
    return { ok: true, name: row.name, token, profile: row.profile, savedAt: row.savedAt };
  }
  async save(name, profile, savedAt) {
    const row = await this.store.get(name);
    if (!row || Number(savedAt) < row.savedAt) return false;
    row.profile = profile;
    row.savedAt = Number(savedAt) || 0;
    await this.store.update(row);
    return true;
  }
  // The signed-in player sets a new password; other devices are signed out.
  async changePassword(name, newPassword) {
    if (String(newPassword || "").length < 4) return { ok: false, code: "bad_password", msg: "Şifre en az 4 karakter olmalı." };
    const row = await this.store.get(name);
    row.salt = crypto.randomBytes(16).toString("hex");
    row.hash = hashPassword(newPassword, row.salt);
    row.tokens = [];
    const token = this._token(row);
    await this.store.update(row);
    return { ok: true, name: row.name, token };
  }
  async exists(name) {
    return Boolean(await this.store.get(name));
  }
  // The best accounts for a number in their saved game: [{name, value, level}].
  top(path, limit = 20) {
    return this.store.top(path, limit);
  }
  // {rank, value} of one account for that number (null without a saved game).
  rank(path, name) {
    return this.store.rank(path, name);
  }
  // Account levels by name for the accounts that exist: {Name: level}.
  levels(names) {
    return names.length ? this.store.levels(names) : Promise.resolve({});
  }
}

module.exports = { Accounts, key, numberAt };

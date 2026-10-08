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

class MemoryStore {
  constructor() {
    this.rows = new Map();
  }
  async init() {}
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
}

module.exports = { Accounts, key };

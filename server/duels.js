// Duels: two online players fight in the arena. The server plays the whole
// fight with the fighters' stats and sends both sides the same replay
// (hit points over time), so nobody can bend the result afterwards.

const { key } = require("./accounts.js");

const INVITE_MS = 60 * 1000;
const MAX_SECONDS = 90;
const STEP = 0.1;
const FRAME_EVERY = 5; // steps between replay frames

const CLASSES = new Set(["warrior", "archer", "mage", "rogue"]);
const clamp = (v, lo, hi, d) => {
  v = Number(v);
  return Number.isFinite(v) ? Math.min(hi, Math.max(lo, v)) : d;
};

// Stats from a client, kept inside sane limits.
function fighter(name, f) {
  f = f && typeof f === "object" ? f : {};
  return {
    name,
    cls: CLASSES.has(f.cls) ? f.cls : "archer",
    hp: clamp(f.hp, 40, 4000, 100),
    dmg: clamp(f.dmg, 1, 600, 8),
    aps: clamp(f.aps, 0.3, 6, 1),
    crit: clamp(f.crit, 0, 1, 0.05),
    critDmg: clamp(f.critDmg, 1, 6, 1.5),
    defense: clamp(f.defense, 0, 0.6, 0),
  };
}

// A small deterministic random generator (so a replay can be checked).
function rng(seed) {
  let s = seed >>> 0 || 1;
  return () => {
    s = (s * 1664525 + 1013904223) >>> 0;
    return s / 4294967296;
  };
}

// Plays the fight: both swing as often as their speed allows.
// Returns {winner: 0 | 1 | -1, frames: [[seconds, hp0, hp1, hit0, hit1], ...]}.
function simulate(a, b, seed = Date.now()) {
  const rand = rng(seed);
  const fs = [a, b];
  const hp = [a.hp, b.hp];
  const next = [0.3 + rand() * 0.2, 0.3 + rand() * 0.2];
  const frames = [[0, hp[0], hp[1], 0, 0]];
  let hits = [0, 0];
  for (let step = 1; step <= MAX_SECONDS / STEP && hp[0] > 0 && hp[1] > 0; step++) {
    const t = step * STEP;
    for (let i = 0; i < 2; i++) {
      if (t < next[i] || hp[0] <= 0 || hp[1] <= 0) continue;
      next[i] += 1 / fs[i].aps;
      const j = 1 - i;
      const crit = rand() < fs[i].crit;
      const dmg = fs[i].dmg * (crit ? fs[i].critDmg : 1) * (0.9 + rand() * 0.2) * (1 - fs[j].defense);
      hp[j] = Math.max(0, hp[j] - dmg);
      hits[i] = crit ? 2 : 1;
    }
    if (step % FRAME_EVERY === 0 || hp[0] <= 0 || hp[1] <= 0) {
      frames.push([Math.round(t * 10) / 10, Math.round(hp[0]), Math.round(hp[1]), hits[0], hits[1]]);
      hits = [0, 0];
    }
  }
  const winner = hp[0] > 0 && hp[1] <= 0 ? 0 : hp[1] > 0 && hp[0] <= 0 ? 1 : hp[0] === hp[1] ? -1 : hp[0] > hp[1] ? 0 : 1;
  return { winner, frames };
}

class Duels {
  constructor() {
    this.pending = new Map(); // challenged name key -> [{from, fighter, at}]
  }
  _live(k, now) {
    const list = (this.pending.get(k) || []).filter((p) => now - p.at < INVITE_MS);
    if (list.length) this.pending.set(k, list);
    else this.pending.delete(k);
    return list;
  }
  // `from` challenges `to`; the newest challenge of one player replaces the old one.
  challenge(from, to, f, now = Date.now()) {
    if (key(from) === key(to)) return { ok: false, msg: "Kendinle düello yapamazsın." };
    for (const k of [...this.pending.keys()]) {
      const rest = this._live(k, now).filter((p) => key(p.from) !== key(from));
      if (rest.length) this.pending.set(k, rest);
      else this.pending.delete(k);
    }
    const k = key(to);
    const list = this._live(k, now);
    list.push({ from, fighter: fighter(from, f), at: now });
    this.pending.set(k, list);
    return { ok: true };
  }
  // `who` answers the challenge of `from`; accepting plays the fight.
  answer(who, from, accept, f, now = Date.now(), seed = now) {
    const k = key(who);
    const list = this._live(k, now);
    const p = list.find((x) => key(x.from) === key(from));
    if (!p) return { ok: false, msg: "Bu düello daveti artık geçerli değil." };
    this.pending.set(k, list.filter((x) => x !== p));
    if (!accept) return { ok: true, declined: true, from: p.from };
    const mine = fighter(who, f);
    const res = simulate(p.fighter, mine, seed);
    return { ok: true, declined: false, a: p.fighter, b: mine, ...res };
  }
  // Challenges waiting for `who`.
  inbox(who, now = Date.now()) {
    return this._live(key(who), now).map((p) => ({ from: p.from, cls: p.fighter.cls }));
  }
}

module.exports = { Duels, simulate, fighter };

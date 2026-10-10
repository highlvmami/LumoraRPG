// Tavern games with gold bets: dice (two dice, the higher total wins) and
// cards (the higher card wins). One player invites another with a bet; if the
// other accepts the server rolls for both. Ties are re-rolled. The players'
// games move the gold (the loser pays the bet to the winner).
const crypto = require("crypto");
const { key } = require("./accounts.js");

const INVITE_MS = 60000;
const MIN_BET = 10;
const MAX_BET = 5000;
const KINDS = new Set(["dice", "cards"]);
const SUITS = ["♠", "♥", "♦", "♣"];

function roll(kind) {
  if (kind === "dice") {
    const d = [crypto.randomInt(1, 7), crypto.randomInt(1, 7)];
    return { v: d, total: d[0] + d[1] };
  }
  const rank = crypto.randomInt(2, 15); // 11 J, 12 Q, 13 K, 14 A
  return { v: [rank, crypto.randomInt(0, 4)], total: rank };
}

// Plays one game: [{name, v, total}, {name, v, total}] and the winner index.
function play(kind, a, b) {
  for (let i = 0; i < 6; i++) {
    const ra = roll(kind);
    const rb = roll(kind);
    if (ra.total !== rb.total) return { a: { name: a, ...ra }, b: { name: b, ...rb }, winner: ra.total > rb.total ? 0 : 1 };
    if (i === 5) return { a: { name: a, ...ra }, b: { name: b, ...rb }, winner: crypto.randomInt(0, 2) };
  }
}

class Games {
  constructor() {
    this.pending = new Map(); // challenged key -> [{from, kind, bet, at}]
  }
  _live(k, now) {
    const list = (this.pending.get(k) || []).filter((p) => now - p.at < INVITE_MS);
    if (list.length) this.pending.set(k, list);
    else this.pending.delete(k);
    return list;
  }
  challenge(from, to, kind, bet, now = Date.now()) {
    if (key(from) === key(to)) return { ok: false, msg: "Kendinle oynayamazsın." };
    if (!KINDS.has(kind)) return { ok: false, msg: "Bilinmeyen oyun." };
    const amount = Math.floor(Number(bet) || 0);
    if (amount < MIN_BET || amount > MAX_BET) return { ok: false, msg: `Bahis ${MIN_BET} ile ${MAX_BET} altın arasında olmalı.` };
    for (const k of [...this.pending.keys()]) {
      const rest = this._live(k, now).filter((p) => key(p.from) !== key(from));
      if (rest.length) this.pending.set(k, rest);
      else this.pending.delete(k);
    }
    const k = key(to);
    const list = this._live(k, now);
    list.push({ from, kind, bet: amount, at: now });
    this.pending.set(k, list);
    return { ok: true, bet: amount };
  }
  answer(who, from, accept, now = Date.now()) {
    const k = key(who);
    const list = this._live(k, now);
    const p = list.find((x) => key(x.from) === key(from));
    if (!p) return { ok: false, msg: "Bu davet artık geçerli değil." };
    this.pending.set(k, list.filter((x) => x !== p));
    if (!accept) return { ok: true, declined: true };
    return { ok: true, declined: false, kind: p.kind, bet: p.bet, ...play(p.kind, p.from, who) };
  }
  inbox(who, now = Date.now()) {
    return this._live(key(who), now).map((p) => ({ from: p.from, kind: p.kind, bet: p.bet }));
  }
}

module.exports = { Games, play, MAX_BET, MIN_BET };

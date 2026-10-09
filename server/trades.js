// Trades between two online players: one offers an item from the backpack
// for a price in gold, the other accepts or declines. The server only
// keeps the open offers (in memory) and tells both sides when a trade is
// done; the games move the item and the gold in their own saves.
// An offer is dropped when either side goes offline.

const MAX_ITEM = 4000; // bytes of JSON
const MAX_PRICE = 1000000;
const MAX_OPEN = 5; // offers one player can have open

class Trades {
  constructor() {
    this.offers = new Map(); // id -> {id, from, to, item, price, at}
    this.nextId = 1;
  }

  // Checks an offer. Returns {offer} or {msg}.
  offer(from, to, item, price, key) {
    if (!to) return { msg: "Bu oyuncu şu an çevrimiçi değil." };
    if (key(from) === key(to)) return { msg: "Kendine teklif yapamazsın." };
    if (!item || typeof item !== "object" || Array.isArray(item)) return { msg: "Eşya bozuk." };
    const size = JSON.stringify(item).length;
    if (size > MAX_ITEM || item.uid === undefined) return { msg: "Eşya bozuk." };
    const gold = Math.floor(Number(price));
    if (!Number.isFinite(gold) || gold < 0 || gold > MAX_PRICE) return { msg: "Fiyat 0 ile " + MAX_PRICE + " arasında olmalı." };
    const mine = [...this.offers.values()].filter((o) => key(o.from) === key(from));
    if (mine.length >= MAX_OPEN) return { msg: "En fazla " + MAX_OPEN + " açık teklifin olabilir." };
    if (mine.some((o) => String(o.item.uid) === String(item.uid))) return { msg: "Bu eşya zaten teklifte." };
    const offer = { id: this.nextId++, from, to, item, price: gold, at: Date.now() };
    this.offers.set(offer.id, offer);
    return { offer };
  }

  get(id) {
    return this.offers.get(Number(id));
  }

  close(id) {
    const o = this.get(id);
    if (o) this.offers.delete(o.id);
    return o;
  }

  // Offers made by or to this player.
  of(name, key) {
    const k = key(name);
    return [...this.offers.values()].filter((o) => key(o.from) === k || key(o.to) === k);
  }
}

module.exports = { Trades };

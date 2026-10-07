// Lumora RPG - ortak yardımcılar ve olay sistemi.
// Tüm modüller tek bir global isim alanını (window.Lumora) paylaşır;
// böylece oyun index.html'e çift tıklayarak (sunucusuz) açılabilir.
window.Lumora = window.Lumora || {};

(function (L) {
  L.utils = {
    clamp: (v, a, b) => Math.max(a, Math.min(b, v)),
    rand: (a, b) => a + Math.random() * (b - a),
    pick: (arr) => arr[Math.floor(Math.random() * arr.length)],

    // 1234 -> "1.23K"
    fmt(n) {
      n = Math.floor(n);
      if (n < 1000) return String(n);
      const units = ['K', 'M', 'B', 'T', 'Qa', 'Qi'];
      let i = -1;
      while (n >= 1000 && i < units.length - 1) { n /= 1000; i++; }
      return n.toFixed(n < 10 ? 2 : n < 100 ? 1 : 0) + units[i];
    },

    // Tekrarlanabilir rastgele sayı üreteci (arka planlar için)
    seeded(seed) {
      return function () {
        seed |= 0; seed = (seed + 0x6d2b79f5) | 0;
        let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
        t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
        return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
      };
    },

    weightedPick(items) {
      const total = items.reduce((s, it) => s + it.weight, 0);
      let r = Math.random() * total;
      for (const it of items) { r -= it.weight; if (r <= 0) return it; }
      return items[items.length - 1];
    },
  };

  // Basit olay yayıncısı: sistemler birbirini doğrudan çağırmak yerine olay yayar.
  const listeners = {};
  L.events = {
    on(name, fn) { (listeners[name] = listeners[name] || []).push(fn); },
    emit(name, data) { (listeners[name] || []).forEach((fn) => fn(data)); },
  };
})(window.Lumora);

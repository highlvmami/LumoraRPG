// Detaylı oyuncu karakteri (32x48 piksel). Her parça (vücut, saç, üst, alt, ayakkabı, şapka, silah)
// küçük bir çizim fonksiyonudur; kıyafet eklemek için ilgili tabloya yeni bir fonksiyon ekle
// ve js/data/appearance.js'teki listeye id + isim yaz.
(function (L) {
  const W = 32, H = 48;

  // ---------- renk yardımcıları ----------
  function rgb(hex) {
    let h = hex.replace('#', '');
    if (h.length === 3) h = h.split('').map((c) => c + c).join('');
    const n = parseInt(h, 16);
    return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
  }
  function hex([r, g, b]) {
    return '#' + [r, g, b].map((v) => Math.max(0, Math.min(255, Math.round(v))).toString(16).padStart(2, '0')).join('');
  }
  function mix(a, b, t) {
    const x = rgb(a), y = rgb(b);
    return hex(x.map((v, i) => v + (y[i] - v) * t));
  }
  // Işık/gölge tonları: hi (parlak), b (ana), sh (gölge), dk (koyu)
  function ramp(base) {
    return { hi: mix(base, '#fff6e0', 0.28), b: base, sh: mix(base, '#1a1030', 0.28), dk: mix(base, '#120a20', 0.5) };
  }

  // ---------- ızgara ----------
  function grid() {
    const c = new Array(W * H).fill(null);
    const g = {
      set(x, y, col) { if (x >= 0 && y >= 0 && x < W && y < H && col) c[y * W + x] = col; },
      get(x, y) { return x >= 0 && y >= 0 && x < W && y < H ? c[y * W + x] : null; },
      rect(x, y, w, h, col) { for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) g.set(x + i, y + j, col); },
      row(y, x0, x1, col) { for (let x = x0; x <= x1; x++) g.set(x, y, col); },
      col(x, y0, y1, col) { for (let y = y0; y <= y1; y++) g.set(x, y, col); },
      // sadece dolu piksellerin üstüne boya (gölgelendirme için)
      paintIf(x, y, col) { if (g.get(x, y)) g.set(x, y, col); },
      clear(x, y) { if (x >= 0 && y >= 0 && x < W && y < H) c[y * W + x] = null; },
      cells: c,
    };
    return g;
  }

  // ---------- vücut ----------
  const HEAD_ROWS = { 8: [11, 20], 9: [10, 21], 21: [10, 21], 22: [11, 20] };
  function headRange(y) { return HEAD_ROWS[y] || (y >= 10 && y <= 20 ? [9, 22] : null); }

  function body(g, s) {
    // bacaklar ve ayaklar (kıyafetin altında kalır)
    g.rect(11, 36, 5, 8, s.b); g.rect(16, 36, 5, 8, s.b);
    g.col(15, 38, 43, s.sh); g.col(20, 37, 43, s.sh);
    g.rect(11, 44, 5, 3, s.b); g.rect(16, 44, 5, 3, s.b);
    // gövde
    g.rect(10, 24, 12, 12, s.b);
    g.col(21, 25, 35, s.sh);
    // kollar + eller
    g.rect(7, 25, 3, 9, s.b); g.rect(22, 25, 3, 9, s.b);
    g.col(9, 26, 33, s.sh); g.col(24, 26, 33, s.sh);
    g.rect(7, 34, 3, 2, s.b); g.rect(22, 34, 3, 2, s.b);
    g.set(9, 35, s.sh); g.set(24, 35, s.sh);
    // boyun
    g.rect(14, 22, 4, 3, s.sh);
  }

  function head(g, s, eye, hair) {
    for (let y = 8; y <= 22; y++) {
      const r = headRange(y);
      for (let x = r[0]; x <= r[1]; x++) g.set(x, y, s.b);
    }
    // gölge: sağ yan + çene
    for (let y = 10; y <= 20; y++) { g.set(22, y, s.sh); g.set(21, y, s.sh); }
    g.row(21, 12, 21, s.sh); g.row(22, 11, 20, s.sh);
    g.col(10, 10, 13, s.hi);
    // kulaklar
    g.rect(8, 14, 1, 4, s.b); g.set(8, 15, s.sh); g.set(8, 16, s.sh);
    g.rect(23, 14, 1, 4, s.sh); g.set(23, 15, s.dk);
    // kaşlar
    g.row(12, 12, 13, hair.dk); g.row(12, 18, 19, hair.dk);
    // gözler (kirpik + iris + parlama)
    const e = ramp(eye);
    for (const ex of [12, 18]) {
      g.row(14, ex, ex + 1, '#1b1424');
      g.rect(ex, 15, 2, 3, e.b);
      g.row(17, ex, ex + 1, e.dk);
      g.set(ex, 15, '#ffffff');
    }
    // allık, burun, ağız
    g.set(11, 18, mix(s.b, '#ff6b81', 0.35)); g.set(20, 18, mix(s.sh, '#ff6b81', 0.35));
    g.set(16, 18, s.sh);
    g.row(20, 15, 16, mix(s.dk, '#8b1e3f', 0.4));
  }

  // ---------- saç ----------
  function hairCap(g, h) {
    g.row(6, 11, 20, h.b); g.row(7, 10, 21, h.b);
    g.rect(9, 8, 14, 3, h.b);
    g.row(7, 11, 14, h.hi); g.row(8, 10, 12, h.hi);
    g.col(22, 8, 10, h.sh); g.set(21, 7, h.sh);
    // perçem (dişli)
    for (const x of [9, 10, 11, 13, 14, 16, 17, 19, 21, 22]) g.set(x, 11, h.b);
    for (const x of [9, 10, 14, 17, 22]) g.set(x, 12, h.sh);
    // favoriler
    g.col(9, 11, 15, h.b); g.col(22, 11, 15, h.sh);
  }

  const HAIR = {
    bald: { front(g, h, s) { g.row(9, 12, 14, mix(s.b, '#ffffff', 0.3)); } },
    short: { front: hairCap },
    long: {
      back(g, h) { g.rect(7, 10, 18, 20, h.sh); g.row(30, 8, 23, h.dk); },
      front(g, h) {
        hairCap(g, h);
        g.rect(8, 11, 2, 15, h.b); g.rect(22, 11, 2, 15, h.sh);
        g.set(8, 26, h.sh); g.set(23, 26, h.dk);
      },
    },
    spiky: {
      front(g, h) {
        hairCap(g, h);
        const spikes = [[10, 4], [13, 2], [16, 1], [19, 2], [22, 4]];
        for (const [x, top] of spikes) {
          for (let y = top; y <= 6; y++) {
            const w = Math.floor((y - top) / 2);
            g.row(y, x - w, x + w, y === top ? h.hi : h.b);
          }
        }
        g.set(8, 9, h.b); g.set(23, 9, h.sh); g.set(7, 8, h.b); g.set(24, 8, h.sh);
      },
    },
    ponytail: {
      back(g, h) {
        g.rect(4, 12, 4, 14, h.b); g.rect(3, 15, 2, 9, h.sh);
        g.row(26, 4, 6, h.sh); g.set(5, 27, h.dk);
        g.rect(6, 11, 3, 3, '#e64980'); // toka
      },
      front: hairCap,
    },
    bob: {
      front(g, h) {
        hairCap(g, h);
        g.rect(8, 11, 2, 10, h.b); g.rect(22, 11, 2, 10, h.sh);
        g.row(21, 8, 10, h.sh); g.row(21, 21, 23, h.dk);
      },
    },
    mohawk: {
      front(g, h, s) {
        g.row(9, 10, 21, mix(s.b, h.b, 0.35));
        for (let y = 1; y <= 10; y++) g.row(y, 14, 17, y < 3 ? h.hi : h.b);
        g.col(17, 2, 10, h.sh);
      },
    },
  };

  // ---------- üst kıyafetler ----------
  function torso(g, c) {
    g.rect(10, 24, 12, 12, c.b);
    g.col(20, 25, 35, c.sh); g.col(21, 24, 35, c.sh);
    g.row(35, 10, 21, c.sh);
    g.col(10, 25, 30, c.hi);
  }
  function sleeves(g, c, long) {
    const end = long ? 33 : 28;
    g.rect(7, 25, 3, end - 24, c.b); g.rect(22, 25, 3, end - 24, c.b);
    g.col(9, 26, end, c.sh); g.col(24, 26, end, c.sh);
    g.col(7, 25, end, c.hi);
    g.row(end, 7, 9, c.sh); g.row(end, 22, 24, c.dk);
  }
  function belt(g, y, col, buckle) {
    g.row(y, 10, 21, col.b); g.row(y + 1, 10, 21, col.sh);
    if (buckle) { g.rect(15, y, 2, 2, buckle); }
  }

  const TOPS = {
    peasant(g) { // Köylü Tişörtü
      const c = ramp('#c9a87c');
      torso(g, c); sleeves(g, c, false);
      g.row(24, 13, 18, c.dk); g.row(24, 14, 17, L.character._skin); g.row(25, 15, 16, L.character._skin);
      g.col(15, 26, 29, c.sh);
      belt(g, 33, ramp('#6b4226'));
    },
    vest(g) { // Deri Yelek
      const w = ramp('#e9ecef'), v = ramp('#8b5a2b');
      torso(g, w); sleeves(g, w, true);
      g.rect(10, 24, 4, 12, v.b); g.rect(18, 24, 4, 12, v.b);
      g.col(13, 24, 35, v.sh); g.col(21, 24, 35, v.dk); g.col(10, 25, 32, v.hi);
      g.row(35, 10, 13, v.dk); g.row(35, 18, 21, v.dk);
      g.set(12, 28, '#fab005'); g.set(12, 31, '#fab005');
      belt(g, 33, ramp('#4a2d16'), '#fab005');
    },
    knight(g) { // Şövalye Zırhı
      const m = ramp('#adb5bd'), ch = ramp('#6c757d');
      torso(g, m); sleeves(g, ch, true);
      for (let y = 26; y <= 33; y += 2) for (let x = 7; x <= 24; x++) if ((x + y) % 2 === 0) g.paintIf(x, y, ch.sh);
      g.rect(10, 24, 12, 12, m.b);
      g.rect(12, 25, 8, 6, m.hi); g.col(15, 25, 31, m.b); g.col(16, 25, 31, m.sh);
      g.row(31, 10, 21, m.sh); g.row(33, 10, 21, m.dk);
      g.col(21, 24, 35, m.sh);
      // omuzluklar
      for (const [x0, flip] of [[6, false], [21, true]]) {
        g.rect(x0, 24, 5, 3, m.b); g.row(24, x0, x0 + 4, m.hi); g.row(26, x0, x0 + 4, m.sh);
        g.set(flip ? x0 + 4 : x0, 27, m.sh);
      }
      g.rect(15, 27, 2, 2, '#e03131');
      belt(g, 34, ramp('#6b4226'), '#fab005');
    },
    wizard(g) { // Büyücü Cübbesi
      const r = ramp('#5f3dc4'), gold = '#fab005';
      torso(g, r);
      g.rect(10, 36, 12, 7, r.b); g.rect(9, 40, 14, 3, r.b);
      g.col(21, 36, 42, r.sh); g.col(22, 40, 42, r.sh); g.row(42, 9, 22, r.dk);
      // geniş kollar
      g.rect(6, 25, 4, 10, r.b); g.rect(22, 25, 4, 10, r.b);
      g.col(6, 25, 34, r.hi); g.col(9, 26, 34, r.sh); g.col(25, 25, 34, r.sh);
      g.row(34, 6, 9, gold); g.row(34, 22, 25, gold);
      // altın şerit
      g.col(15, 24, 42, gold); g.col(16, 24, 42, mix(gold, '#8f5b00', 0.4));
      g.row(42, 9, 22, gold);
      g.set(13, 28, '#ffe066'); g.set(18, 30, '#ffe066');
    },
    pirate(g) { // Korsan Gömleği
      const w = ramp('#f1f3f5'), red = ramp('#c92a2a');
      torso(g, w); sleeves(g, w, true);
      g.row(29, 7, 9, w.sh); g.row(29, 22, 24, w.sh);
      // V yaka
      const s = L.character._skin;
      for (let y = 24; y <= 27; y++) g.row(y, 14 + (y - 24) / 2 | 0, 17 - ((y - 24) / 2 | 0), s);
      // kuşak
      g.rect(10, 32, 12, 3, red.b); g.row(32, 10, 21, red.hi); g.row(34, 10, 21, red.sh);
      g.rect(19, 35, 2, 3, red.b); g.set(20, 37, red.sh);
    },
    ninja(g) { // Ninja Kıyafeti
      const k = ramp('#343a40'), red = ramp('#e03131');
      torso(g, k); sleeves(g, k, true);
      for (let i = 0; i < 7; i++) { g.set(11 + i, 24 + i, k.hi); g.set(20 - i, 24 + i, k.sh); }
      belt(g, 32, red); g.rect(11, 34, 2, 3, red.b); g.set(11, 36, red.sh);
      g.row(33, 7, 9, k.dk); g.row(33, 22, 24, k.dk);
    },
    hunter(g) { // Avcı Tuniği
      const gr = ramp('#2f9e44'), br = ramp('#7c4a2a');
      torso(g, gr); sleeves(g, gr, true);
      g.rect(10, 36, 12, 3, gr.b); g.row(38, 10, 21, gr.sh);
      for (const x of [11, 14, 17, 20]) g.set(x, 38, gr.dk);
      g.rect(7, 30, 3, 4, br.b); g.rect(22, 30, 3, 4, br.sh); // bileklik
      g.row(24, 12, 19, gr.dk);
      belt(g, 33, br, '#ced4da');
      g.rect(18, 34, 3, 3, br.b); g.set(20, 36, br.dk); // kese
      // çapraz kayış
      for (let i = 0; i < 9; i++) g.set(11 + i, 24 + i, br.sh);
    },
  };

  // ---------- alt kıyafetler ----------
  function legs(g, c, from = 36, to = 43) {
    g.rect(10, from, 12, 1, c.b);
    g.rect(11, from, 5, to - from + 1, c.b); g.rect(16, from, 5, to - from + 1, c.b);
    g.col(11, from, to, c.hi); g.col(15, from + 2, to, c.sh); g.col(16, from + 2, to, c.b);
    g.col(20, from, to, c.sh); g.col(21, from, from, c.sh);
  }

  const BOTTOMS = {
    jeans(g) { const c = ramp('#3b5bdb'); legs(g, c); g.row(43, 11, 15, c.dk); g.row(43, 16, 20, c.dk); g.set(13, 38, c.hi); g.set(18, 38, c.hi); },
    leather(g) { const c = ramp('#7c4a2a'); legs(g, c); g.set(13, 40, c.sh); g.set(18, 40, c.sh); },
    greaves(g) {
      const c = ramp('#868e96'), m = ramp('#ced4da');
      legs(g, c);
      for (const x0 of [11, 16]) { g.rect(x0, 39, 5, 2, m.b); g.row(39, x0, x0 + 4, m.hi); g.rect(x0, 42, 5, 2, m.sh); }
    },
    shorts(g) { const c = ramp('#d9b38c'); legs(g, c, 36, 39); g.row(39, 11, 15, c.dk); g.row(39, 16, 20, c.dk); },
    cloth(g) { const c = ramp('#495057'); legs(g, c); g.col(13, 37, 43, c.sh); g.col(18, 37, 43, c.sh); },
    hunterPants(g) {
      const c = ramp('#2b5d34'), w = ramp('#c9a87c');
      legs(g, c);
      for (const y of [40, 42]) { g.row(y, 11, 15, w.sh); g.row(y, 16, 20, w.sh); }
    },
  };

  // ---------- ayakkabılar ----------
  function feet(g, c, top = 44) {
    for (const [x0, x1] of [[10, 15], [16, 21]]) {
      for (let y = top; y <= 47; y++) g.row(y, y === top ? x0 + 1 : x0, x1, c.b);
      g.row(47, x0, x1, c.dk); g.set(x0 + 1, top, c.hi);
      g.col(x1, top, 46, c.sh);
    }
  }
  const SHOES = {
    boots(g) { const c = ramp('#6b4226'); feet(g, c, 41); g.row(41, 11, 15, c.hi); g.row(41, 16, 21, c.hi); },
    ironBoots(g) { const c = ramp('#adb5bd'); feet(g, c, 42); g.row(44, 10, 15, c.sh); g.row(44, 16, 21, c.sh); },
    sandals(g) {
      const s = L.character._skinRamp, b = ramp('#8b5a2b');
      feet(g, s, 44); g.row(45, 10, 15, b.b); g.row(45, 16, 21, b.b);
      g.row(47, 10, 15, b.dk); g.row(47, 16, 21, b.dk);
    },
    sneakers(g) {
      const c = ramp('#e03131');
      feet(g, c, 44); g.row(47, 10, 15, '#f8f9fa'); g.row(47, 16, 21, '#f8f9fa');
      g.set(12, 45, '#ffffff'); g.set(18, 45, '#ffffff');
    },
    tabi(g) { const c = ramp('#212529'); feet(g, c, 43); g.col(13, 45, 47, c.hi); g.col(19, 45, 47, c.hi); },
  };

  // ---------- şapkalar ----------
  const HATS = {
    none: null,
    cap(g) {
      const c = ramp('#1c7ed6');
      g.row(5, 11, 20, c.b); g.row(6, 10, 21, c.b); g.rect(9, 7, 14, 3, c.b);
      g.row(5, 11, 14, c.hi); g.col(22, 7, 9, c.sh);
      g.rect(8, 10, 16, 2, c.sh); g.row(11, 8, 23, c.dk);
      g.rect(15, 6, 2, 2, '#f8f9fa');
    },
    wizard(g) {
      const c = ramp('#5f3dc4');
      for (let y = 0; y <= 8; y++) {
        const half = 1 + Math.floor(y * 0.75);
        const cx = 17 - Math.floor((8 - y) / 3);
        g.row(y, cx - half, cx + half, c.b);
        g.set(cx + half, y, c.sh); g.set(cx - half, y, c.hi);
      }
      g.rect(5, 9, 22, 2, c.b); g.row(9, 5, 26, c.hi); g.row(10, 5, 26, c.sh);
      g.row(8, 11, 22, '#fab005');
      g.set(16, 4, '#ffe066'); g.set(15, 5, '#ffe066'); g.set(17, 5, '#ffe066'); g.set(16, 6, '#ffe066'); g.set(16, 5, '#fff3bf');
    },
    helmet(g) {
      const m = ramp('#adb5bd'), red = ramp('#e03131');
      for (let y = 1; y <= 6; y++) g.row(y, 14, 17, y < 3 ? red.hi : red.b);
      g.row(5, 11, 20, m.b); g.row(6, 10, 21, m.b); g.rect(8, 7, 16, 5, m.b);
      g.row(6, 11, 14, m.hi); g.row(7, 9, 12, m.hi);
      g.col(23, 7, 11, m.sh); g.row(11, 8, 23, m.sh);
      g.rect(8, 12, 3, 8, m.b); g.rect(21, 12, 3, 8, m.sh); g.col(8, 12, 19, m.hi);
      g.rect(15, 12, 2, 6, m.b); g.set(16, 17, m.sh);
    },
    crown(g) {
      const c = ramp('#fab005');
      for (const x of [10, 13, 16, 19, 21]) g.set(x, 3, c.hi);
      for (const x of [10, 11, 12, 13, 15, 16, 17, 19, 20, 21]) g.set(x, 4, c.b);
      g.rect(10, 5, 12, 4, c.b); g.row(8, 10, 21, c.sh); g.col(21, 4, 8, c.sh);
      g.rect(12, 6, 2, 2, '#e03131'); g.rect(15, 6, 2, 2, '#1c7ed6'); g.rect(18, 6, 2, 2, '#2f9e44');
      g.set(12, 6, '#ffa8a8'); g.set(15, 6, '#a5d8ff'); g.set(18, 6, '#b2f2bb');
    },
    bandana(g) {
      const c = ramp('#e03131');
      g.row(8, 10, 21, c.b); g.rect(8, 9, 16, 3, c.b); g.row(11, 8, 23, c.sh); g.row(8, 10, 14, c.hi);
      for (const x of [10, 14, 18, 22]) g.set(x, 10, '#fff5f5');
      g.rect(5, 10, 3, 2, c.b); g.rect(4, 12, 3, 4, c.sh); g.set(4, 16, c.dk);
    },
    hood(g) {
      const c = ramp('#2b8a3e');
      g.row(4, 12, 19, c.b); g.row(5, 10, 21, c.b); g.row(6, 9, 22, c.b);
      g.rect(7, 7, 18, 4, c.b);
      g.rect(7, 11, 3, 14, c.b); g.rect(22, 11, 3, 14, c.sh);
      g.rect(6, 22, 20, 4, c.b); g.row(25, 6, 25, c.sh); g.col(25, 22, 25, c.dk);
      g.row(4, 12, 15, c.hi); g.col(7, 8, 24, c.hi);
      g.row(10, 10, 21, c.dk); g.col(10, 11, 21, c.dk); g.col(21, 11, 21, c.dk);
    },
    pirateHat(g) {
      const c = ramp('#212529');
      g.rect(10, 3, 12, 5, c.b); g.row(3, 11, 20, c.hi);
      g.rect(4, 8, 24, 3, c.b); g.row(8, 4, 27, '#fab005'); g.row(10, 5, 26, c.dk);
      g.set(3, 7, c.b); g.set(28, 7, c.b);
      g.rect(15, 4, 2, 2, '#f8f9fa'); g.row(6, 14, 17, '#f8f9fa');
    },
  };

  // ---------- silah ----------
  function sword(g) {
    const blade = ramp('#ced4da');
    g.set(26, 12, blade.hi);
    g.col(25, 13, 31, blade.hi); g.col(26, 13, 31, blade.sh); g.col(27, 14, 30, blade.dk);
    g.row(32, 23, 29, '#c9a227'); g.set(23, 32, '#8f6b10'); g.set(29, 32, '#8f6b10');
    g.col(25, 33, 35, '#6b4226'); g.col(26, 33, 35, '#4a2d16');
    g.rect(25, 36, 2, 1, '#c9a227');
  }

  // Seçmeli kontur: boş piksel, komşusunun koyu tonuyla boyanır
  function outline(g) {
    const add = [];
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
      if (g.get(x, y)) continue;
      const n = g.get(x, y + 1) || g.get(x, y - 1) || g.get(x + 1, y) || g.get(x - 1, y);
      if (n) add.push([x, y, mix(n, '#0d0816', 0.72)]);
    }
    for (const [x, y, c] of add) g.set(x, y, c);
  }

  L.character = {
    W, H,
    HAIR, TOPS, BOTTOMS, SHOES, HATS,
    _skin: null, _skinRamp: null,

    // görünüm -> 32x48 renk ızgarası
    compose(app) {
      const g = grid();
      const s = ramp(app.skin), h = ramp(app.hairColor);
      this._skin = s.b; this._skinRamp = s;
      const hair = HAIR[app.hairStyle] || HAIR.short;
      const hood = app.hat === 'hood';
      if (hair.back && !hood) hair.back(g, h, s);
      body(g, s);
      (BOTTOMS[app.bottom] || BOTTOMS.jeans)(g);
      (SHOES[app.shoes] || SHOES.boots)(g);
      (TOPS[app.top] || TOPS.peasant)(g);
      head(g, s, app.eye, h);
      if (!hood) hair.front(g, h, s);
      const hat = HATS[app.hat];
      if (hat) hat(g);
      sword(g);
      outline(g);
      return g;
    },

    toCanvas(app, scale, flash) {
      const g = this.compose(app);
      const c = document.createElement('canvas');
      c.width = W * scale; c.height = H * scale;
      const ctx = c.getContext('2d');
      for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
        const col = g.get(x, y);
        if (!col) continue;
        ctx.fillStyle = flash || col;
        ctx.fillRect(x * scale, y * scale, scale, scale);
      }
      return c;
    },
  };
})(window.Lumora);

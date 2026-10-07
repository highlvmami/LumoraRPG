// Dünya arka planları: 160x90'lık piksel ızgarada çizilir, sonra 4 kat büyütülür.
// Yeni dünya için buraya bir çizim fonksiyonu ekle ve worlds.js'te bg adını ver.
(function (L) {
  const W = 160, H = 90, GROUND = 67;
  const cache = {};

  function px(ctx, x, y, c, w = 1, h = 1) { ctx.fillStyle = c; ctx.fillRect(x, y, w, h); }

  function sky(ctx, colors) {
    const band = Math.ceil(GROUND / colors.length);
    for (let y = 0; y < GROUND; y++) {
      const b = Math.min(colors.length - 1, Math.floor(y / band));
      for (let x = 0; x < W; x++) {
        // bant geçişlerinde dama tahtası dithering
        const dither = b > 0 && y % band < 2 && (x + y) % 2 === 0;
        px(ctx, x, y, colors[dither ? b - 1 : b]);
      }
    }
  }

  function disc(ctx, cx, cy, r, c) {
    for (let y = -r; y <= r; y++)
      for (let x = -r; x <= r; x++)
        if (x * x + y * y <= r * r) px(ctx, cx + x, cy + y, c);
  }

  function hills(ctx, base, amp, freq, phase, color) {
    for (let x = 0; x < W; x++) {
      const h = Math.round(base + Math.sin(x * freq + phase) * amp + Math.sin(x * freq * 2.7) * amp * 0.4);
      px(ctx, x, h, color, 1, GROUND - h);
    }
  }

  function pine(ctx, x, base, h, dark, light) {
    px(ctx, x - 1, base - 3, '#5c3a1e', 2, 3);
    for (let r = 0; r < h; r++) {
      const half = Math.floor((r % 5) * 0.7 + r * 0.35) + 1;
      const y = base - 3 - h + r;
      px(ctx, x - half, y, light, half, 1);
      px(ctx, x, y, dark, half, 1);
    }
  }

  function deadTree(ctx, x, base, h, rnd) {
    const c = '#4a3b2f';
    px(ctx, x, base - h, c, 2, h);
    for (let i = 0; i < 3; i++) {
      const by = base - h + 2 + Math.floor(rnd() * (h - 6));
      const dir = rnd() < 0.5 ? -1 : 1;
      const len = 2 + Math.floor(rnd() * 4);
      for (let j = 1; j <= len; j++) px(ctx, x + (dir > 0 ? 1 + j : -j), by - Math.floor(j / 2), c);
    }
  }

  function ground(ctx, rnd, top, grass, dirt, speck) {
    px(ctx, 0, GROUND, grass, W, 4);
    px(ctx, 0, GROUND, top, W, 1);
    for (let x = 0; x < W; x += 1) if (rnd() < 0.25) px(ctx, x, GROUND - 1, top);
    px(ctx, 0, GROUND + 4, dirt, W, H - GROUND - 4);
    for (let x = 0; x < W; x++) if (rnd() < 0.5) px(ctx, x, GROUND + 4, grass);
    for (let i = 0; i < 140; i++) px(ctx, Math.floor(rnd() * W), GROUND + 5 + Math.floor(rnd() * (H - GROUND - 5)), speck);
  }

  const painters = {
    forest(ctx) {
      const rnd = L.utils.seeded(7);
      sky(ctx, ['#4fb4e0', '#63c3e8', '#7dd0ee', '#9adcf2']);
      disc(ctx, 130, 14, 8, '#fff3bf');
      disc(ctx, 130, 14, 6, '#ffe066');
      hills(ctx, 47, 4, 0.05, 0, '#8cc56b');
      hills(ctx, 56, 3, 0.08, 1.3, '#5e9e48');
      for (let i = 0; i < 12; i++) {
        const x = 4 + Math.floor(rnd() * 152);
        pine(ctx, x, GROUND, 12 + Math.floor(rnd() * 10), '#24612d', '#2f7a3a');
      }
      ground(ctx, rnd, '#99e550', '#6abe30', '#8f563b', '#74432d');
      for (let i = 0; i < 10; i++) { // çiçekler
        const x = Math.floor(rnd() * W);
        px(ctx, x, GROUND - 1, rnd() < 0.5 ? '#ff8787' : '#fff');
      }
    },

    swamp(ctx) {
      const rnd = L.utils.seeded(21);
      sky(ctx, ['#2f3e4f', '#3b4d61', '#4d6377', '#62788a']);
      disc(ctx, 28, 14, 6, '#e9ecef');
      disc(ctx, 30, 13, 5, '#4d6377');
      hills(ctx, 50, 3, 0.06, 2, '#3f5245');
      hills(ctx, 58, 2, 0.1, 0.5, '#33463a');
      for (let i = 0; i < 7; i++) deadTree(ctx, 6 + Math.floor(rnd() * 148), GROUND, 10 + Math.floor(rnd() * 10), rnd);
      ground(ctx, rnd, '#7a9a55', '#4b5d3a', '#3e3a2a', '#2e2b1f');
      for (let i = 0; i < 5; i++) { // su birikintileri
        const x = Math.floor(rnd() * 140), w = 8 + Math.floor(rnd() * 14), y = GROUND + 8 + Math.floor(rnd() * 12);
        px(ctx, x, y, '#2f5d62', w, 2);
        px(ctx, x + 2, y, '#4f8a8b', 3, 1);
      }
      for (let i = 0; i < 18; i++) { // sazlar
        const x = Math.floor(rnd() * W), h = 2 + Math.floor(rnd() * 4);
        px(ctx, x, GROUND - h, '#5c7a3a', 1, h);
      }
    },
  };

  L.backgrounds = {
    GROUND_Y: GROUND * 4,

    get(name) {
      if (!cache[name]) {
        const c = document.createElement('canvas');
        c.width = W; c.height = H;
        (painters[name] || painters.forest)(c.getContext('2d'));
        cache[name] = c;
      }
      return cache[name];
    },

    cloudColor(name) { return name === 'swamp' ? 'rgba(160,175,185,0.55)' : 'rgba(255,255,255,0.9)'; },
  };
})(window.Lumora);

// Ana menü ve karakter ekranının arkasındaki 2.5D pixel orman.
// Katmanlar farklı hızlarda kayar (parallax), zemin satır satır kaydırılarak derinlik hissi verilir.
// İçinde kamp ateşleri, çadır, dolaşan moblar, ateş böcekleri ve yıldızlar var.
(function (L) {
  let canvas, ctx, low, lctx, W = 320, H = 200, K = 3;
  let layers = {}, tufts = [], stars = [], flies = [], sparks = [], entities = [];
  let running = false, raf = 0, last = 0, mouseX = 0, camSmooth = 0;
  const HORIZON = () => Math.round(H * 0.6);

  function rnd(seed) { return L.utils.seeded(seed); }
  function px(c, x, y, col, w = 1, h = 1) { c.fillStyle = col; c.fillRect(Math.round(x), Math.round(y), w, h); }

  // Uzaktaki çam ağacı silueti
  function pine(c, x, base, h, dark, light) {
    px(c, x - 1, base - 3, '#1a1420', 2, 3);
    for (let r = 0; r < h; r++) {
      const half = Math.floor((r % 6) * 0.6 + r * 0.32) + 1;
      const y = base - 3 - h + r;
      px(c, x - half, y, light, half, 1);
      px(c, x, y, dark, half + 1, 1);
    }
  }

  function makeLayer(width, draw) {
    const c = document.createElement('canvas');
    c.width = width; c.height = H;
    draw(c.getContext('2d'), width);
    return c;
  }

  function build() {
    const hz = HORIZON();
    const margin = 80;
    const r = rnd(42);

    // gökyüzü
    layers.sky = makeLayer(W, (c) => {
      const bands = ['#0d0e26', '#141537', '#1d1b48', '#2a2257', '#3d2a63', '#5a3368', '#7a3f66'];
      const bh = Math.ceil(hz / bands.length);
      for (let y = 0; y < hz + 10; y++) {
        const b = Math.min(bands.length - 1, Math.floor(y / bh));
        for (let x = 0; x < W; x++) {
          const d = b > 0 && y % bh < 2 && (x + y) % 2 === 0;
          px(c, x, y, bands[d ? b - 1 : b]);
        }
      }
    });
    stars = Array.from({ length: Math.floor(W / 5) }, () => ({ x: r() * W, y: r() * hz * 0.7, p: r() * 6, b: r() < 0.2 }));

    // uzak dağlar
    layers.mountains = makeLayer(W + margin * 2, (c, w) => {
      for (let x = 0; x < w; x++) {
        const h = Math.round(hz - 18 - Math.abs(Math.sin(x * 0.021)) * 26 - Math.sin(x * 0.07) * 6);
        px(c, x, h, '#2b2554', 1, hz - h + 20);
        if (Math.sin(x * 0.021) > 0.93) px(c, x, h, '#4a4380', 1, 2);
      }
    });

    // uzak orman
    layers.far = makeLayer(W + margin * 2, (c, w) => {
      const rr = rnd(7);
      for (let x = -5; x < w + 5; x += 3 + Math.floor(rr() * 4)) pine(c, x, hz + 4, 18 + Math.floor(rr() * 20), '#1a2444', '#222e52');
      px(c, 0, hz + 2, '#1a2444', w, 30);
    });

    // orta orman
    layers.mid = makeLayer(W + margin * 2, (c, w) => {
      const rr = rnd(99);
      for (let x = -10; x < w + 10; x += 9 + Math.floor(rr() * 12)) pine(c, x, hz + 12, 34 + Math.floor(rr() * 30), '#17332f', '#24493d');
      px(c, 0, hz + 10, '#17332f', w, 30);
    });

    // zemindeki ot öbekleri
    const rt = rnd(5);
    tufts = Array.from({ length: Math.floor(W * 0.9) }, () => ({ x: rt() * (W + 200) - 100, y: hz + 6 + Math.floor(rt() ** 0.8 * (H - hz - 6)), c: rt() < 0.5 ? '#3f7d45' : '#2f6338', f: rt() < 0.06 }));

    // ateş böcekleri
    flies = Array.from({ length: 28 }, () => ({ x: r() * W, y: hz - 20 + r() * (H - hz + 10), p: r() * 10, s: 0.3 + r() * 0.6 }));

    // varlıklar: kamp ateşleri, çadır, moblar
    const cx = W / 2;
    entities = [
      { type: 'fire', x: cx - W * 0.28, y: hz + 30 },
      { type: 'tent', x: cx - W * 0.36, y: hz + 22 },
      { type: 'fire', x: cx + W * 0.3, y: hz + 58 },
      { type: 'fire', x: cx + W * 0.05, y: hz + 14 },
      { type: 'mob', id: 'goblin', x: cx - W * 0.22, y: hz + 31, mode: 'sit' },
      { type: 'mob', id: 'goblin_shaman', x: cx - W * 0.33, y: hz + 33, mode: 'sit', face: 1 },
      { type: 'mob', id: 'goblin_warrior', x: cx + W * 0.1, y: hz + 15, mode: 'sit', face: -1 },
      { type: 'mob', id: 'goblin', x: cx, y: hz + 44, mode: 'walk', v: 6, min: cx - W * 0.45, max: cx + W * 0.2 },
      { type: 'mob', id: 'slime_blue', x: cx + W * 0.2, y: hz + 66, mode: 'hop', v: -5, min: cx - W * 0.1, max: cx + W * 0.45 },
      { type: 'mob', id: 'slime_poison', x: cx - W * 0.1, y: hz + 24, mode: 'hop', v: 4, min: cx - W * 0.2, max: cx + W * 0.25 },
      { type: 'mob', id: 'goblin_warrior', x: cx + W * 0.38, y: hz + 38, mode: 'walk', v: -4, min: cx + W * 0.15, max: cx + W * 0.5 },
    ];
    sparks = [];
  }

  // derinliğe göre parallax ve piksel ölçeği
  function rowParallax(y) { const hz = HORIZON(); return 0.4 + Math.max(0, (y - hz) / (H - hz)) * 0.8; }
  function depthScale(y) { const hz = HORIZON(); const t = (y - hz) / (H - hz); return t < 0.3 ? 1 : t < 0.65 ? 2 : 3; }

  function drawGround(c, cam) {
    const hz = HORIZON();
    const cols = ['#1b3326', '#20402c', '#264c32', '#2c5838', '#32633d'];
    for (let y = hz; y < H; y++) {
      const t = (y - hz) / (H - hz);
      const col = cols[Math.min(cols.length - 1, Math.floor(t * cols.length))];
      px(c, 0, y, col, W, 1);
      // toprak patika
      const off = -cam * rowParallax(y);
      const center = W / 2 + Math.sin((y - hz) / 22) * 22 + off;
      const half = 4 + t * t * 70;
      px(c, center - half - 1, y, '#3d3226', 1, 1);
      px(c, center - half, y, t > 0.5 ? '#6b5440' : '#5a4636', half * 2, 1);
      px(c, center + half, y, '#3d3226', 1, 1);
    }
    for (const tf of tufts) {
      const x = tf.x - cam * rowParallax(tf.y);
      if (x < -2 || x > W + 2) continue;
      const s = depthScale(tf.y);
      px(c, x, tf.y - s, tf.c, 1, s); px(c, x + 1, tf.y - s * 2, tf.c, 1, s * 2); px(c, x + 2, tf.y - s, tf.c, 1, s);
      if (tf.f) px(c, x + 1, tf.y - s * 2 - 1, '#ffd8a8');
    }
  }

  function drawFire(c, x, y, s, t) {
    // ışık
    c.save();
    c.globalCompositeOperation = 'lighter';
    const rad = 26 * s + Math.sin(t * 9 + x) * 2 * s;
    const g = c.createRadialGradient(x, y - 3 * s, 1, x, y - 3 * s, rad);
    g.addColorStop(0, 'rgba(255,160,70,0.42)');
    g.addColorStop(1, 'rgba(255,90,30,0)');
    c.fillStyle = g;
    c.fillRect(x - rad, y - 3 * s - rad, rad * 2, rad * 2);
    c.restore();
    // taşlar ve odunlar
    for (let i = -3; i <= 3; i++) px(c, x + i * 2 * s - s, y - s, i % 2 ? '#6c6f7a' : '#8a8d99', s * 2, s);
    px(c, x - 5 * s, y - 2 * s, '#5c3a1e', 10 * s, s); px(c, x - 4 * s, y - 3 * s, '#7a4a26', 8 * s, s);
    // alevler
    const cols = ['#e8590c', '#ff922b', '#ffd43b', '#fff3bf'];
    for (let i = -2; i <= 2; i++) {
      const h = (5 - Math.abs(i) * 1.5 + Math.sin(t * 14 + i * 2.1 + x) * 1.5) | 0;
      for (let j = 0; j < h; j++) {
        const ci = Math.min(cols.length - 1, Math.floor((1 - j / h) * 2 + (Math.abs(i) < 1 ? 1.5 : 0)));
        px(c, x + i * s - s / 2, y - 3 * s - j * s, cols[Math.max(0, 3 - ci)], s, s);
      }
    }
    if (Math.random() < 0.25) sparks.push({ x: x + (Math.random() - 0.5) * 4 * s, y: y - 6 * s, vy: -10 - Math.random() * 15, vx: (Math.random() - 0.5) * 6, life: 1 + Math.random() });
  }

  function drawTent(c, x, y, s) {
    const h = 14 * s;
    for (let j = 0; j < h; j++) {
      const half = Math.round(j * 0.9) + 1;
      px(c, x - half, y - h + j, j % 4 === 0 ? '#9c5f34' : '#b8733f', half, 1);
      px(c, x, y - h + j, '#8a5129', half, 1);
      if (j > h * 0.45) px(c, x - Math.round((j - h * 0.45) * 0.35), y - h + j, '#2b1a12', Math.round((j - h * 0.45) * 0.7) + 1, 1);
    }
    px(c, x, y - h - 3 * s, '#5c3a1e', s, 3 * s);
    px(c, x + s, y - h - 3 * s, '#e03131', 3 * s, 2 * s);
  }

  function drawMob(c, e, t, cam) {
    const s = depthScale(e.y);
    const spr = L.pixel.monster(e.id, s);
    let bob = 0;
    if (e.mode === 'hop') bob = -Math.abs(Math.sin(t * 4 + e.x)) * 5 * s;
    else if (e.mode === 'walk') bob = (Math.sin(t * 8) > 0 ? 0 : -s);
    else bob = Math.sin(t * 2 + e.x) > 0.6 ? -s : 0;
    const x = e.x - cam * rowParallax(e.y);
    const dir = e.mode === 'sit' ? (e.face || -1) : Math.sign(e.v);
    // gölge
    c.fillStyle = 'rgba(0,0,0,0.3)';
    c.fillRect(Math.round(x - spr.width * 0.3), Math.round(e.y - s), Math.round(spr.width * 0.6), s * 2);
    c.save();
    c.translate(Math.round(x), Math.round(e.y + bob));
    if (dir > 0) c.scale(-1, 1);
    c.drawImage(spr, -spr.width / 2, -spr.height);
    c.restore();
  }

  function frame(now) {
    if (!running) return;
    const t = now / 1000;
    const dt = Math.min(0.05, (now - last) / 1000 || 0);
    last = now;
    const hz = HORIZON();
    camSmooth += ((Math.sin(t * 0.12) * 14 + mouseX * 24) - camSmooth) * Math.min(1, dt * 3);
    const cam = camSmooth;
    const c = lctx;

    c.drawImage(layers.sky, 0, 0);
    for (const st of stars) {
      const a = Math.sin(t * 2 + st.p);
      if (a > -0.3) px(c, st.x - cam * 0.02, st.y, a > 0.7 || st.b ? '#ffffff' : '#a5a8d6');
    }
    // ay
    const mx = W * 0.78 - cam * 0.03, my = H * 0.15;
    c.save(); c.globalCompositeOperation = 'lighter';
    const mg = c.createRadialGradient(mx, my, 2, mx, my, 40);
    mg.addColorStop(0, 'rgba(255,240,210,0.25)'); mg.addColorStop(1, 'rgba(255,240,210,0)');
    c.fillStyle = mg; c.fillRect(mx - 40, my - 40, 80, 80); c.restore();
    for (let y = -9; y <= 9; y++) for (let x = -9; x <= 9; x++) if (x * x + y * y <= 81) px(c, mx + x, my + y, x + y > 6 ? '#e6d9b8' : '#fff3d6');
    px(c, mx - 3, my - 2, '#e6d9b8', 3, 2); px(c, mx + 2, my + 3, '#e6d9b8', 2, 2);

    c.drawImage(layers.mountains, Math.round(-80 - cam * 0.08), 0);
    c.drawImage(layers.far, Math.round(-80 - cam * 0.2), 0);
    // sis
    c.fillStyle = 'rgba(150,140,220,0.10)';
    for (let i = 0; i < 3; i++) c.fillRect(0, hz - 12 + i * 5 + Math.sin(t * 0.5 + i) * 2, W, 4);
    c.drawImage(layers.mid, Math.round(-80 - cam * 0.35), 0);

    drawGround(c, cam);

    // varlıklar derinliğe göre sıralı
    for (const e of entities) {
      if (e.type === 'mob' && e.mode !== 'sit') {
        e.x += e.v * dt;
        if (e.x < e.min || e.x > e.max) e.v = -e.v;
      }
    }
    const sorted = entities.slice().sort((a, b) => a.y - b.y);
    for (const e of sorted) {
      const s = depthScale(e.y);
      const x = e.x - cam * rowParallax(e.y);
      if (e.type === 'fire') drawFire(c, Math.round(x), Math.round(e.y), s, t);
      else if (e.type === 'tent') drawTent(c, Math.round(x), Math.round(e.y), s);
      else drawMob(c, e, t, cam);
    }

    // kıvılcımlar
    for (const sp of sparks) { sp.life -= dt; sp.y += sp.vy * dt; sp.x += sp.vx * dt + Math.sin(t * 6 + sp.y) * 0.2; }
    sparks = sparks.filter((sp) => sp.life > 0);
    for (const sp of sparks) px(c, sp.x, sp.y, sp.life > 0.6 ? '#ffd43b' : '#ff922b');

    // ateş böcekleri
    c.save(); c.globalCompositeOperation = 'lighter';
    for (const f of flies) {
      const fx = (f.x + Math.sin(t * f.s + f.p) * 12 - cam * 0.7 + W) % W;
      const fy = f.y + Math.cos(t * f.s * 1.3 + f.p) * 6;
      const a = (Math.sin(t * 3 + f.p) + 1) / 2;
      c.fillStyle = `rgba(216,245,162,${0.15 * a})`; c.fillRect(Math.round(fx) - 1, Math.round(fy) - 1, 3, 3);
      c.fillStyle = `rgba(240,255,200,${0.4 + 0.6 * a})`; c.fillRect(Math.round(fx), Math.round(fy), 1, 1);
    }
    c.restore();

    // ön plan: kenarlarda koyu ağaçlar
    const fg = '#0a1512';
    const lx = Math.round(-cam * 1.3);
    px(c, lx - 6, 0, fg, 16, H); px(c, lx + 10, 0, '#0f1f1a', 3, H);
    for (let i = 0; i < 6; i++) px(c, lx - 10 + i * 4, i * 9, fg, 26 - i * 3, 6);
    px(c, W + lx - 12, 0, fg, 16, H); px(c, W + lx - 15, 0, '#0f1f1a', 3, H);
    for (let i = 0; i < 6; i++) px(c, W + lx - 18 + i * 2, 10 + i * 8, fg, 22, 6);
    for (let x = -10; x < W + 10; x += 3) {
      const h = 6 + Math.round(Math.sin(x * 1.7) * 3 + 3);
      const sw = Math.round(Math.sin(t * 1.5 + x * 0.3));
      px(c, x - cam * 1.4 + sw, H - h, fg, 2, h);
    }

    // kenar karartma
    const vg = c.createRadialGradient(W / 2, H * 0.55, H * 0.35, W / 2, H * 0.55, W * 0.75);
    vg.addColorStop(0, 'rgba(0,0,0,0)'); vg.addColorStop(1, 'rgba(5,3,15,0.55)');
    c.fillStyle = vg; c.fillRect(0, 0, W, H);

    ctx.imageSmoothingEnabled = false;
    ctx.drawImage(low, 0, 0, W * K, H * K);
    raf = requestAnimationFrame(frame);
  }

  function resize() {
    const vw = window.innerWidth, vh = window.innerHeight;
    K = Math.max(2, Math.round(vh / 210));
    H = Math.ceil(vh / K); W = Math.ceil(vw / K);
    canvas.width = W * K; canvas.height = H * K;
    low.width = W; low.height = H;
    build();
  }

  L.forest = {
    init(el) {
      canvas = el; ctx = canvas.getContext('2d');
      low = document.createElement('canvas'); lctx = low.getContext('2d');
      resize();
      window.addEventListener('resize', () => { if (running) resize(); });
      window.addEventListener('mousemove', (e) => { mouseX = (e.clientX / window.innerWidth) * 2 - 1; });
    },
    start() {
      if (running) return;
      running = true;
      canvas.classList.remove('hidden');
      resize();
      last = performance.now();
      raf = requestAnimationFrame(frame);
    },
    stop() {
      running = false;
      cancelAnimationFrame(raf);
      canvas.classList.add('hidden');
    },
  };
})(window.Lumora);

// Piksel haritalarını tuvale (canvas) çeviren ve sonuçları önbellekleyen çizim çekirdeği.
(function (L) {
  const OUTLINE = '#1b1b24';
  const cache = new Map();

  function hexToRgb(hex) {
    let h = hex.replace('#', '');
    if (h.length === 3) h = h.split('').map((c) => c + c).join('');
    const n = parseInt(h, 16);
    return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
  }

  // amt < 0 koyulaştırır, amt > 0 açar
  function shade(hex, amt) {
    const [r, g, b] = hexToRgb(hex);
    const f = (c) => Math.round(amt < 0 ? c * (1 + amt) : c + (255 - c) * amt);
    return `rgb(${f(r)},${f(g)},${f(b)})`;
  }

  function resolve(pal, ch) {
    if (pal[ch]) return pal[ch];
    const up = ch.toUpperCase();
    if (ch !== up && pal[up]) return shade(pal[up], -0.3);
    return null;
  }

  // layers: [{ rows, pal, y0?, x0?, outline? }] -> renk ızgarası
  function compose(layers, w, h) {
    const grid = Array.from({ length: h }, () => Array(w).fill(null));
    const outlined = [];
    for (const layer of layers) {
      const x0 = layer.x0 || 0, y0 = layer.y0 || 0;
      layer.rows.forEach((row, ry) => {
        for (let rx = 0; rx < row.length; rx++) {
          const ch = row[rx];
          if (ch === '.') continue;
          const c = resolve(layer.pal, ch);
          const x = rx + x0, y = ry + y0;
          if (!c || x < 0 || y < 0 || x >= w || y >= h) continue;
          grid[y][x] = c;
          if (layer.outline) outlined.push([x, y]);
        }
      });
    }
    // Saç/şapka gibi konturu olmayan katmanlara otomatik kontur
    for (const [x, y] of outlined) {
      for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
        const nx = x + dx, ny = y + dy;
        if (nx >= 0 && ny >= 0 && nx < w && ny < h && !grid[ny][nx]) grid[ny][nx] = OUTLINE;
      }
    }
    return grid;
  }

  function gridToCanvas(grid, scale, override) {
    const h = grid.length, w = grid[0].length;
    const c = document.createElement('canvas');
    c.width = w * scale; c.height = h * scale;
    const ctx = c.getContext('2d');
    for (let y = 0; y < h; y++) {
      for (let x = 0; x < w; x++) {
        if (!grid[y][x]) continue;
        ctx.fillStyle = override || grid[y][x];
        ctx.fillRect(x * scale, y * scale, scale, scale);
      }
    }
    return c;
  }

  function cached(key, build) {
    if (!cache.has(key)) cache.set(key, build());
    return cache.get(key);
  }

  L.pixel = {
    shade,

    characterLayers(app) {
      const S = L.sprites.player;
      const pal = {
        O: OUTLINE, S: app.skin, E: app.eye, T: app.shirt, P: app.pants, B: app.shoes,
        H: app.hairColor, W: '#dee2e6', G: '#c9a227', R: '#6b4226',
      };
      const layers = [{ rows: S.base, pal }];
      const hair = S.hair[app.hairStyle];
      if (hair) layers.push({ rows: hair.rows, y0: hair.y0, pal, outline: true });
      const hat = S.hats[app.hat];
      if (hat) {
        layers.push({ rows: hat.rows, y0: hat.y0, outline: true,
          pal: { C: app.hatColor, D: L.appearance.hatAccent[app.hat] || '#fff' } });
      }
      layers.push({ rows: S.weapon.rows, y0: S.weapon.y0, pal, outline: true });
      return layers;
    },

    // Karakter sprite'ı (önbellekli). flash: beyaz/kırmızı parlama rengi
    character(app, scale, flash) {
      const S = L.sprites.player;
      const key = 'char|' + JSON.stringify(app) + '|' + scale + '|' + (flash || '');
      return cached(key, () => gridToCanvas(compose(this.characterLayers(app), S.width, S.height), scale, flash));
    },

    monster(id, scale, flash) {
      const def = L.monsters[id];
      const key = 'mon|' + id + '|' + scale + '|' + (flash || '');
      return cached(key, () => {
        const rows = L.sprites[def.sprite];
        const layers = [{ rows, pal: def.pal }];
        if (def.crownY !== undefined) layers.push({ rows: L.sprites.bossCrown, y0: def.crownY, pal: def.pal });
        return gridToCanvas(compose(layers, rows[0].length, rows.length), scale, flash);
      });
    },
  };
})(window.Lumora);

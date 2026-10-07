// Savaş sahnesini çizer: arka plan, bulutlar, oyuncu, canavar, can barları ve efektler.
(function (L) {
  const FONT = '"Press Start 2P", monospace';
  const CLOUDS = [
    ['..XXXX....', '.XXXXXXX..', 'XXXXXXXXXX'],
    ['...XXX.......', '.XXXXXXX.XX..', 'XXXXXXXXXXXXX'],
  ];

  function text(ctx, str, x, y, color, size, align = 'center') {
    ctx.font = `${size}px ${FONT}`;
    ctx.textAlign = align;
    ctx.textBaseline = 'middle';
    ctx.lineWidth = Math.max(3, size / 4);
    ctx.strokeStyle = '#111';
    ctx.lineJoin = 'round';
    ctx.strokeText(str, x, y);
    ctx.fillStyle = color;
    ctx.fillText(str, x, y);
  }

  function bar(ctx, x, y, w, h, ratio, fill, back = '#3b0d0d') {
    ctx.fillStyle = '#111';
    ctx.fillRect(x - 4, y - 4, w + 8, h + 8);
    ctx.fillStyle = back;
    ctx.fillRect(x, y, w, h);
    ctx.fillStyle = fill;
    ctx.fillRect(x, y, Math.round(w * L.utils.clamp(ratio, 0, 1) / 4) * 4, h);
    ctx.fillStyle = 'rgba(255,255,255,0.25)';
    ctx.fillRect(x, y, Math.round(w * L.utils.clamp(ratio, 0, 1) / 4) * 4, 4);
  }

  function shadow(ctx, cx, w) {
    ctx.fillStyle = 'rgba(0,0,0,0.25)';
    ctx.fillRect(cx - w / 2, L.backgrounds.GROUND_Y - 4, w, 8);
    ctx.fillRect(cx - w / 2 + 8, L.backgrounds.GROUND_Y - 8, w - 16, 16);
  }

  L.scene = {
    draw(ctx, t) {
      const B = L.battle, P = B.player, M = B.monster;
      const world = L.worlds.forStage(L.save.data.progress.stage);
      const groundY = L.backgrounds.GROUND_Y;
      ctx.imageSmoothingEnabled = false;
      ctx.drawImage(L.backgrounds.get(world.bg), 0, 0, 640, 360);

      // bulutlar
      ctx.fillStyle = L.backgrounds.cloudColor(world.bg);
      CLOUDS.forEach((shape, i) => {
        const span = 640 + 80;
        const cx = ((t * (8 + i * 5) + i * 330) % span) - 60;
        const cy = 30 + i * 36;
        shape.forEach((row, ry) => {
          for (let rx = 0; rx < row.length; rx++) if (row[rx] === 'X') ctx.fillRect(Math.round(cx / 4) * 4 + rx * 8, cy + ry * 8, 8, 8);
        });
      });

      // --- oyuncu ---
      const app = L.save.data.character;
      const lunge = Math.sin(P.lunge * Math.PI) * 28;
      const bob = Math.sin(t * 4) > 0 ? 0 : 4;
      const px = B.PLAYER_X + Math.round(lunge / 4) * 4;
      const py = groundY - 112 + (P.dead ? 0 : bob);
      shadow(ctx, px + 32, 56);
      const pSprite = L.pixel.character(app, 4, P.hurt > 0 ? '#ffffff' : null);
      ctx.save();
      if (P.dead) ctx.globalAlpha = 0.35;
      ctx.drawImage(pSprite, px, py);
      ctx.restore();

      // --- canavar ---
      let mScale = 0, mW = 0;
      if (M) {
        mScale = M.isBoss ? 7 : 5;
        mW = 16 * mScale;
        const rows = L.sprites[M.def.sprite].length;
        const mh = rows * mScale;
        const mLunge = Math.sin(M.lunge * Math.PI) * 24;
        const mbob = Math.sin(t * 5 + 1) > 0 ? 0 : 4;
        const mx = Math.round((M.x - mLunge) / 4) * 4;
        let my = groundY - mh + mbob;
        shadow(ctx, mx + mW / 2, mW * 0.7);
        ctx.save();
        if (M.dying > 0) { ctx.globalAlpha = Math.max(0, M.dying / 0.45); my -= (0.45 - M.dying) * 60; }
        ctx.drawImage(L.pixel.monster(M.id, mScale, M.flash > 0 ? '#ffffff' : null), mx, my);
        ctx.restore();

        if (M.dying <= 0) {
          const bw = M.isBoss ? 160 : 100;
          const bx = Math.round(M.x + mW / 2 - bw / 2);
          const by = groundY - mh - 20;
          bar(ctx, bx, by, bw, 8, M.hp / M.maxHp, M.isBoss ? '#e03131' : '#fa5252');
          text(ctx, M.name, M.x + mW / 2, by - 18, M.isBoss ? '#ff8787' : '#ffffff', M.isBoss ? 12 : 10);
        }
      }

      // oyuncu can barı
      const d = L.player.derived();
      bar(ctx, B.PLAYER_X - 2, groundY - 140, 68, 8, P.hp / d.maxHp, '#51cf66', '#0b3d1a');
      text(ctx, app.name || 'Kahraman', B.PLAYER_X + 32, groundY - 158, '#ffffff', 10);

      // kılıç izi
      for (const s of B.slashes) {
        const k = 1 - s.life / s.max;
        ctx.fillStyle = `rgba(255,255,255,${s.life / s.max})`;
        for (let a = -1.1; a <= 1.1; a += 0.18) {
          const ang = a + k * 0.6;
          const r = 46;
          ctx.fillRect(Math.round((s.x - 30 + Math.cos(ang) * r) / 4) * 4, Math.round((s.y + Math.sin(ang) * r) / 4) * 4, 8, 8);
        }
      }

      for (const p of B.particles) {
        ctx.fillStyle = p.color;
        ctx.fillRect(Math.round(p.x / 4) * 4, Math.round(p.y / 4) * 4, p.s, p.s);
      }

      for (const tx of B.texts) {
        ctx.save();
        ctx.globalAlpha = Math.min(1, tx.life * 2);
        text(ctx, tx.text, tx.x, tx.y, tx.color, tx.size);
        ctx.restore();
      }

      // boss sayacı
      if (B.boss.active) {
        const ratio = B.boss.time / L.balance.bossTime;
        bar(ctx, 170, 20, 300, 14, ratio, ratio > 0.3 ? '#fab005' : '#fa5252', '#2b2b2b');
        text(ctx, `BOSS  ${B.boss.time.toFixed(1)}s`, 320, 52, '#ffffff', 12);
      }

      if (P.dead) {
        ctx.fillStyle = 'rgba(0,0,0,0.35)';
        ctx.fillRect(0, 0, 640, 360);
        text(ctx, 'YENİLDİN', 320, 150, '#ff6b6b', 24);
        text(ctx, `Yeniden doğuluyor... ${Math.max(0, P.respawn).toFixed(1)}`, 320, 190, '#ffffff', 10);
      }
    },
  };
})(window.Lumora);

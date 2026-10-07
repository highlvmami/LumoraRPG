// Giriş noktası: kaydı yükler, karakter ekranını veya oyunu başlatır, ana döngüyü çalıştırır.
(function (L) {
  const $ = (id) => document.getElementById(id);
  const SAVE_EVERY = 5; // sn

  let running = false;
  let last = 0;
  let saveTimer = 0;
  let hudTimer = 0;

  function startGame() {
    $('creator').classList.add('hidden');
    $('game').classList.remove('hidden');
    L.battle.init();
    L.hud.enter();
    if (!running) {
      running = true;
      last = performance.now();
      requestAnimationFrame(frame);
    }
  }

  function frame(now) {
    if (!running) return;
    const dt = Math.min(0.1, (now - last) / 1000);
    last = now;
    if (!$('game').classList.contains('hidden')) {
      const steps = (L.dev && L.dev.speed) || 1; // geliştirici menüsündeki oyun hızı
      for (let i = 0; i < steps; i++) L.battle.update(dt);
      L.scene.draw($('battle').getContext('2d'), now / 1000);
      hudTimer += dt;
      if (hudTimer > 0.1) { hudTimer = 0; L.hud.update(); }
    }
    saveTimer += dt;
    if (saveTimer > SAVE_EVERY) { saveTimer = 0; L.save.write(); }
    requestAnimationFrame(frame);
  }

  function boot() {
    L.creator.bind();
    L.hud.bind();
    L.devmenu.init();

    L.events.on('levelup', ({ level }) => {
      const B = L.battle;
      B.player.hp = L.player.derived().maxHp;
      B.addText('LEVEL UP!', B.PLAYER_X + 32, 90, '#ffd43b', 16);
      B.burst(B.PLAYER_X + 32, 200, '#ffd43b', 18);
      B.log(`⭐ Level ${level} oldun! +${L.balance.pointsPerLevel} yetenek puanı.`, 'good');
      L.save.write();
    });
    L.events.on('statchange', () => L.save.write());

    $('editCharBtn').onclick = () => {
      L.creator.open(L.save.data.character, (app) => {
        L.save.data.character = app;
        L.save.write();
        $('game').classList.remove('hidden');
        L.hud.drawPortrait();
      }, { editing: true });
    };

    $('resetBtn').onclick = () => {
      if (!confirm('Tüm ilerleme silinecek. Emin misin?')) return;
      L.save.reset();
      location.reload();
    };

    window.addEventListener('beforeunload', () => L.save.write());
    document.addEventListener('visibilitychange', () => { if (document.hidden) L.save.write(); });

    if (L.save.load()) {
      startGame();
      L.hud.log(`Tekrar hoş geldin, ${L.save.data.character.name}!`, 'good');
    } else {
      L.creator.open(L.appearance.defaults(), (app) => {
        L.save.newGame(app);
        startGame();
        L.hud.log(`Macera başlıyor! ${L.worlds.label(0)} · ${L.worlds.list[0].name}`, 'good');
        L.hud.log(`${L.balance.killsForBoss} goblin kes, sonra boss'u çağır.`, '');
      });
    }
  }

  document.addEventListener('DOMContentLoaded', boot);
})(window.Lumora);

// Giriş noktası: ana menü -> (karakter ekranı) -> oyun akışı ve ana döngü.
(function (L) {
  const $ = (id) => document.getElementById(id);
  const SAVE_EVERY = 5; // sn

  let running = false;
  let last = 0;
  let saveTimer = 0;
  let hudTimer = 0;

  function showOnly(id) {
    document.querySelectorAll('.screen').forEach((s) => s.classList.toggle('hidden', s.id !== id));
  }

  function showTitle() {
    L.creator.close();
    showOnly('title');
    L.forest.start();
    const has = L.save.hasSave() && L.save.load();
    $('continueBtn').classList.toggle('hidden', !has);
    if (has) {
      const d = L.save.data;
      $('continueInfo').textContent = `${d.character.name} · Lv ${d.player.level} · ${L.worlds.label(d.progress.stage)}`;
    } else {
      $('continueInfo').textContent = '';
    }
  }

  function startGame() {
    L.forest.stop();
    showOnly('game');
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
    const inGame = !$('game').classList.contains('hidden');
    if (inGame && $('menuModal').classList.contains('hidden')) {
      const steps = (L.dev && L.dev.speed) || 1; // geliştirici menüsündeki oyun hızı
      for (let i = 0; i < steps; i++) L.battle.update(dt);
    }
    if (inGame) {
      L.scene.draw($('battle').getContext('2d'), now / 1000);
      hudTimer += dt;
      if (hudTimer > 0.1) { hudTimer = 0; L.hud.update(); }
      saveTimer += dt;
      if (saveTimer > SAVE_EVERY) { saveTimer = 0; L.save.write(); }
    }
    requestAnimationFrame(frame);
  }

  function newGame() {
    if (L.save.hasSave() && !confirm('Mevcut kaydın silinecek. Yeni oyuna başlansın mı?')) return;
    L.save.reset();
    L.creator.open(L.appearance.defaults(), (app) => {
      L.save.newGame(app);
      startGame();
      L.hud.log(`Macera başlıyor! ${L.worlds.label(0)} · ${L.worlds.list[0].name}`, 'good');
      L.hud.log(`${L.balance.killsForBoss} goblin kes, sonra boss'u çağır.`, '');
    }, { onBack: showTitle });
  }

  function boot() {
    L.forest.init($('forestBg'));
    L.creator.bind();
    L.hud.bind();
    L.devmenu.init();

    L.events.on('levelup', ({ level, levels }) => {
      const B = L.battle;
      B.player.hp = L.player.derived().maxHp;
      B.addText('LEVEL UP!', B.PLAYER_X + 48, 70, '#ffd43b', 16);
      B.burst(B.PLAYER_X + 48, 200, '#ffd43b', 18);
      B.log(`⭐ Level ${level} oldun! +${L.balance.pointsPerLevel * levels} stat, +${L.balance.skillPointsPerLevel * levels} yetenek puanı.`, 'good');
      L.save.write();
    });
    L.events.on('statchange', () => L.save.write());

    $('continueBtn').onclick = () => {
      if (!L.save.load()) return showTitle();
      startGame();
      L.hud.log(`Tekrar hoş geldin, ${L.save.data.character.name}!`, 'good');
    };
    $('newGameBtn').onclick = newGame;

    const backToGame = () => { startGame(); };
    $('editCharBtn').onclick = () => {
      L.hud.closeMenu();
      L.save.write();
      L.creator.open(L.save.data.character, (app) => {
        L.save.data.character = app;
        L.save.write();
        backToGame();
      }, { editing: true, onBack: backToGame });
    };
    $('toTitleBtn').onclick = () => { L.save.write(); L.hud.closeMenu(); showTitle(); };
    $('resetBtn').onclick = () => {
      if (!confirm('Tüm ilerleme silinecek. Emin misin?')) return;
      L.save.reset();
      L.hud.closeMenu();
      showTitle();
    };

    window.addEventListener('beforeunload', () => L.save.write());
    document.addEventListener('visibilitychange', () => { if (document.hidden) L.save.write(); });

    showTitle();
  }

  document.addEventListener('DOMContentLoaded', boot);
})(window.Lumora);

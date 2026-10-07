// Oyun içi arayüz: üst bar, bölüm gezinme, boss butonu, yetenek puanları, günlük.
(function (L) {
  const $ = (id) => document.getElementById(id);
  const U = L.utils;
  const MAX_LOG = 40;

  L.hud = {
    bind() {
      $('prevStage').onclick = () => L.battle.goToStage(L.save.data.progress.stage - 1);
      $('nextStage').onclick = () => L.battle.goToStage(L.save.data.progress.stage + 1);
      $('bossBtn').onclick = () => L.battle.summonBoss();
      $('autoBoss').onchange = (e) => { L.save.data.progress.autoBoss = e.target.checked; L.save.write(); };

      L.events.on('log', ({ msg, kind }) => this.log(msg, kind));
      L.events.on('levelup', () => this.buildStats());
      L.events.on('statchange', () => this.buildStats());
      L.events.on('stagechange', () => this.update());
    },

    enter() {
      $('autoBoss').checked = !!L.save.data.progress.autoBoss;
      this.drawPortrait();
      this.buildStats();
      this.update();
    },

    drawPortrait() {
      const c = $('portrait'), ctx = c.getContext('2d');
      ctx.imageSmoothingEnabled = false;
      ctx.clearRect(0, 0, c.width, c.height);
      // sadece kafa kısmı (sprite'ın 2-17. satırları)
      const spr = L.pixel.character(L.save.data.character, 3);
      ctx.drawImage(spr, 0, 3 * 2, 48, 48, 0, 0, 48, 48);
      $('hudName').textContent = L.save.data.character.name;
    },

    buildStats() {
      const p = L.save.data.player;
      $('pointsBadge').textContent = p.points;
      $('pointsBadge').classList.toggle('glow', p.points > 0);
      const list = $('statList');
      list.innerHTML = '';
      for (const s of L.player.statDefs) {
        const row = document.createElement('div');
        row.className = 'stat-row';
        row.innerHTML = `<span class="stat-icon">${s.icon}</span>
          <div class="stat-info"><div>${s.name} <b>${p.stats[s.id]}</b></div><div class="small">${s.desc}</div></div>`;
        const add = document.createElement('button');
        add.className = 'btn btn-sq btn-plus';
        add.textContent = '+';
        add.disabled = p.points <= 0;
        add.title = 'Shift ile tıkla: +10';
        add.onclick = (e) => L.player.spendPoint(s.id, e.shiftKey ? 10 : 1);
        row.appendChild(add);
        list.appendChild(row);
      }
      this.updateDerived();
    },

    updateDerived() {
      const d = L.player.derived();
      $('derived').innerHTML = `
        <div>Hasar <b>${U.fmt(d.damage)}</b></div>
        <div>Can <b>${U.fmt(d.maxHp)}</b></div>
        <div>Saldırı/sn <b>${(1 / d.interval).toFixed(2)}</b></div>
        <div>Kritik <b>%${Math.round(d.crit * 100)}</b></div>
        <div>Altın bonusu <b>%${Math.round((d.goldMult - 1) * 100)}</b></div>`;
    },

    // Her karede çağrılır ama DOM'a sadece değişince dokunur
    update() {
      const s = L.save.data, p = s.player, pr = s.progress, B = L.balance;
      const need = L.player.expNeeded();
      this.set('hudLevel', p.level);
      this.set('hudGold', U.fmt(p.gold));
      this.set('expText', `${U.fmt(p.exp)} / ${U.fmt(need)} EXP`);
      $('expFill').style.width = `${(p.exp / need) * 100}%`;

      const world = L.worlds.forStage(pr.stage);
      this.set('stageName', L.worlds.label(pr.stage));
      this.set('worldName', world.name);
      $('prevStage').disabled = pr.stage <= 0;
      $('nextStage').disabled = pr.stage >= pr.maxStage;

      const atFront = pr.stage === pr.maxStage;
      const kills = atFront ? pr.kills : B.killsForBoss;
      this.set('killText', atFront
        ? `Boss için mob: ${kills}/${B.killsForBoss}`
        : 'Bu bölüm tamamlandı · farm yapabilirsin');
      $('killFill').style.width = `${(kills / B.killsForBoss) * 100}%`;
      const bossBtn = $('bossBtn');
      bossBtn.disabled = !L.battle.canSummonBoss();
      bossBtn.classList.toggle('ready', L.battle.canSummonBoss());
      bossBtn.style.visibility = atFront ? 'visible' : 'hidden';
    },

    set(id, val) {
      const el = $(id);
      const v = String(val);
      if (el.textContent !== v) el.textContent = v;
    },

    log(msg, kind = '') {
      const ul = $('log');
      const li = document.createElement('li');
      li.className = kind;
      li.textContent = msg;
      ul.prepend(li);
      while (ul.children.length > MAX_LOG) ul.lastChild.remove();
    },
  };
})(window.Lumora);

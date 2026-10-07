// Oyun içi arayüz: kahraman kartı (portre, can, EXP), altın, bölüm şeridi, boss satırı,
// yan paneldeki sekmeler (Stat / Yetenek / Günlük) ve menü penceresi.
(function (L) {
  const $ = (id) => document.getElementById(id);
  const U = L.utils;
  const MAX_LOG = 40;

  L.hud = {
    tab: 'stats',

    bind() {
      $('prevStage').onclick = () => L.battle.goToStage(L.save.data.progress.stage - 1);
      $('nextStage').onclick = () => L.battle.goToStage(L.save.data.progress.stage + 1);
      $('bossBtn').onclick = () => L.battle.summonBoss();
      $('autoBoss').onchange = (e) => { L.save.data.progress.autoBoss = e.target.checked; L.save.write(); };

      document.querySelectorAll('.side-tab').forEach((b) => {
        b.onclick = () => this.showTab(b.dataset.tab);
      });

      $('menuBtn').onclick = () => this.openMenu();
      $('resumeBtn').onclick = () => this.closeMenu();
      $('menuModal').onclick = (e) => { if (e.target.id === 'menuModal') this.closeMenu(); };
      document.addEventListener('keydown', (e) => {
        if (e.key !== 'Escape' || $('game').classList.contains('hidden')) return;
        $('menuModal').classList.contains('hidden') ? this.openMenu() : this.closeMenu();
      });

      L.skilltree.bind();
      L.events.on('log', ({ msg, kind }) => this.log(msg, kind));
      L.events.on('levelup', () => this.buildStats());
      L.events.on('statchange', () => this.buildStats());
      L.events.on('skillchange', () => this.buildStats());
      L.events.on('stagechange', () => this.update());
    },

    enter() {
      $('autoBoss').checked = !!L.save.data.progress.autoBoss;
      $('log').innerHTML = '';
      this.closeMenu();
      this.drawPortrait();
      this.buildStats();
      this.showTab(this.tab);
      this.update();
    },

    showTab(id) {
      this.tab = id;
      document.querySelectorAll('.side-tab').forEach((b) => b.classList.toggle('active', b.dataset.tab === id));
      document.querySelectorAll('.tab-body').forEach((t) => t.classList.toggle('hidden', t.id !== 'tab-' + id));
      if (id === 'skills') L.skilltree.render();
    },

    openMenu() { $('menuModal').classList.remove('hidden'); },
    closeMenu() { $('menuModal').classList.add('hidden'); },

    drawPortrait() {
      const c = $('portrait'), ctx = c.getContext('2d');
      ctx.imageSmoothingEnabled = false;
      ctx.clearRect(0, 0, c.width, c.height);
      // karakterin kafa bölgesi (32x48 ızgarada x 4-28, y 1-25), 3 katı büyütülmüş
      const spr = L.pixel.character(L.save.data.character, 3);
      ctx.drawImage(spr, 4 * 3, 1 * 3, 24 * 3, 24 * 3, 0, 0, 72, 72);
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
        add.className = 'gbtn gbtn-sm gbtn-plus';
        add.textContent = '+';
        add.disabled = p.points <= 0;
        add.title = 'Shift ile tıkla: +10';
        add.onclick = (e) => L.player.spendPoint(s.id, e.shiftKey ? 10 : 1);
        row.appendChild(add);
        list.appendChild(row);
      }
      this.updateDerived();
      this.updateBadges();
      if (this.tab === 'skills') L.skilltree.render();
    },

    updateBadges() {
      const p = L.save.data.player;
      $('statBadge').classList.toggle('hidden', p.points <= 0);
      $('skillBadge').classList.toggle('hidden', p.skillPoints <= 0);
    },

    updateDerived() {
      const d = L.player.derived();
      const pct = (v) => `%${Math.round(v * 100)}`;
      const rows = [
        ['Hasar', U.fmt(d.damage)],
        ['Can', U.fmt(d.maxHp)],
        ['Saldırı/sn', (1 / d.interval).toFixed(2)],
        ['Kritik', pct(d.crit)],
        ['Kritik hasar', `x${d.critMult.toFixed(2)}`],
        ['Altın bonusu', pct(d.goldMult - 1)],
      ];
      if (d.expMult > 1) rows.push(['EXP bonusu', pct(d.expMult - 1)]);
      if (d.damageTaken < 1) rows.push(['Hasar azaltma', pct(1 - d.damageTaken)]);
      $('derived').innerHTML = rows.map(([k, v]) => `<div>${k} <b>${v}</b></div>`).join('');
    },

    // Her ~0.1 sn çağrılır ama DOM'a sadece değişince dokunur
    update() {
      const s = L.save.data, p = s.player, pr = s.progress, B = L.balance;
      const need = L.player.expNeeded();
      const maxHp = L.player.derived().maxHp;
      const hp = Math.max(0, Math.ceil(L.battle.player.hp));
      this.set('hudLevel', p.level);
      this.set('hudGold', U.fmt(p.gold));
      this.set('expText', `${U.fmt(p.exp)} / ${U.fmt(need)}`);
      this.set('hpText', `${U.fmt(hp)} / ${U.fmt(maxHp)}`);
      $('expFill').style.width = `${Math.min(100, (p.exp / need) * 100)}%`;
      $('hpFill').style.width = `${Math.min(100, (hp / maxHp) * 100)}%`;

      const world = L.worlds.forStage(pr.stage);
      this.set('stageName', L.worlds.label(pr.stage));
      this.set('worldName', world.name);
      $('prevStage').disabled = pr.stage <= 0;
      $('nextStage').disabled = pr.stage >= pr.maxStage;

      const atFront = pr.stage === pr.maxStage;
      const kills = atFront ? pr.kills : B.killsForBoss;
      this.set('killText', atFront
        ? `Boss için mob: ${kills}/${B.killsForBoss}`
        : 'Bölüm tamamlandı · farm yapabilirsin');
      $('killFill').style.width = `${Math.min(100, (kills / B.killsForBoss) * 100)}%`;
      const bossBtn = $('bossBtn');
      const ready = L.battle.canSummonBoss();
      bossBtn.disabled = !ready;
      bossBtn.classList.toggle('ready', ready);
      bossBtn.style.visibility = atFront ? 'visible' : 'hidden';
      this.updateBadges();
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

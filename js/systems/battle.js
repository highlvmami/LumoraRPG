// Savaş döngüsü: otomatik saldırı, canavar doğurma, ödüller, boss ve bölüm ilerlemesi.
// Çizimle ilgilenmez; sahne (js/render/scene.js) buradaki durumu okuyup çizer.
(function (L) {
  const U = L.utils;

  const PLAYER_X = 110;
  const MONSTER_X = 450;
  const BOSS_X = 420;

  L.battle = {
    player: { hp: 1, atkT: 0, lunge: 0, hurt: 0, dead: false, respawn: 0 },
    monster: null,
    boss: { active: false, time: 0 },
    texts: [],      // uçan yazılar (hasar, +exp, +altın)
    particles: [],
    slashes: [],
    pendingAdvance: false,
    PLAYER_X,

    get prog() { return L.save.data.progress; },

    init() {
      this.player.hp = L.player.derived().maxHp;
      this.player.dead = false;
      this.boss.active = false;
      this.spawn(false);
    },

    canSummonBoss() {
      const p = this.prog;
      return p.stage === p.maxStage && p.kills >= L.balance.killsForBoss && !this.boss.active;
    },

    spawn(isBoss) {
      const B = L.balance, i = this.prog.stage;
      const world = L.worlds.forStage(i);
      const id = isBoss ? world.boss : U.weightedPick(world.monsters).id;
      const def = L.monsters[id];
      const mult = isBoss ? B.boss : { hp: 1, dmg: 1, exp: 1, gold: 1 };
      const val = (k) => B.monsterBase[k] * Math.pow(B.monsterScale[k], i) * def[k] * mult[k];
      const hp = Math.ceil(val('hp'));
      this.monster = {
        id, def, name: def.name, isBoss,
        hp, maxHp: hp,
        dmg: Math.max(1, Math.round(val('dmg'))),
        exp: Math.max(1, Math.round(val('exp'))),
        gold: Math.max(1, Math.round(val('gold'))),
        atkT: 0, x: 700, targetX: isBoss ? BOSS_X : MONSTER_X,
        entered: false, flash: 0, lunge: 0, dying: 0,
      };
    },

    summonBoss() {
      if (!this.canSummonBoss()) return false;
      this.boss.active = true;
      this.boss.time = L.balance.bossTime;
      this.spawn(true);
      this.log(`👹 ${this.monster.name} ortaya çıktı! ${L.balance.bossTime} saniyen var.`, 'boss');
      return true;
    },

    goToStage(i) {
      const p = this.prog;
      i = U.clamp(i, 0, p.maxStage);
      if (i === p.stage) return;
      p.stage = i;
      this.boss.active = false;
      this.pendingAdvance = false;
      this.spawn(false);
      L.events.emit('stagechange');
    },

    update(dt) {
      const P = this.player, d = L.player.derived();
      this.updateEffects(dt);
      P.lunge = Math.max(0, P.lunge - dt * 5);
      P.hurt = Math.max(0, P.hurt - dt);

      if (P.dead) {
        P.respawn -= dt;
        if (P.respawn <= 0) {
          P.dead = false;
          P.hp = d.maxHp;
          this.spawn(false);
        }
        return;
      }

      P.hp = Math.min(d.maxHp, P.hp + d.maxHp * L.balance.player.regenPct * dt);

      const M = this.monster;
      M.flash = Math.max(0, M.flash - dt);
      M.lunge = Math.max(0, M.lunge - dt * 5);

      if (M.dying > 0) {
        M.dying -= dt;
        if (M.dying <= 0) this.afterKill();
        return;
      }

      if (this.boss.active) {
        this.boss.time -= dt;
        if (this.boss.time <= 0) {
          this.boss.active = false;
          this.log('⌛ Süre doldu, boss kaçtı! Tekrar dene.', 'bad');
          this.spawn(false);
          return;
        }
      }

      if (!M.entered) {
        M.x -= dt * 700;
        if (M.x <= M.targetX) { M.x = M.targetX; M.entered = true; }
        return;
      }

      P.atkT += dt;
      if (P.atkT >= d.interval) { P.atkT = 0; this.playerAttack(d); }

      if (M.hp > 0 && M.dying <= 0) {
        M.atkT += dt;
        if (M.atkT >= L.balance.monsterBase.atkInterval) { M.atkT = 0; this.monsterAttack(d); }
      }
    },

    playerAttack(d) {
      const M = this.monster, P = this.player;
      const crit = Math.random() < d.crit;
      let dmg = Math.max(1, Math.round(d.damage * U.rand(0.9, 1.1) * (crit ? d.critMult : 1)));
      if (L.dev && L.dev.oneShot) dmg = Math.max(dmg, M.hp);
      M.hp -= dmg;
      M.flash = 0.1;
      P.lunge = 1;
      const cx = M.x + (M.isBoss ? 56 : 40);
      this.slashes.push({ x: cx, y: 200, life: 0.18, max: 0.18 });
      this.addText(crit ? `${U.fmt(dmg)}!` : U.fmt(dmg), cx + U.rand(-20, 20), 150,
        crit ? '#ffd43b' : '#ffffff', crit ? 20 : 16);
      if (M.hp <= 0) { M.hp = 0; this.kill(d); }
    },

    monsterAttack(d) {
      const M = this.monster, P = this.player;
      const dmg = L.dev && L.dev.god ? 0 : Math.max(1, Math.round(M.dmg * U.rand(0.9, 1.1)));
      P.hp -= dmg;
      P.hurt = 0.15;
      M.lunge = 1;
      this.addText(`-${U.fmt(dmg)}`, PLAYER_X + 32 + U.rand(-10, 10), 140, '#ff6b6b', 14);
      if (P.hp <= 0) {
        P.hp = 0;
        P.dead = true;
        P.respawn = L.balance.respawnTime;
        if (this.boss.active) {
          this.boss.active = false;
          this.log('💀 Boss seni yendi! Biraz daha güçlen ve tekrar dene.', 'bad');
        } else {
          this.log('💀 Yenildin! Yeniden doğuyorsun...', 'bad');
        }
      }
    },

    kill(d) {
      const M = this.monster, s = L.save.data, p = this.prog;
      M.dying = 0.45;
      const gold = Math.max(1, Math.round(M.gold * d.goldMult));
      L.player.addGold(gold);
      L.player.addExp(M.exp);
      s.records.totalKills++;

      const cx = M.x + (M.isBoss ? 56 : 40);
      this.addText(`+${U.fmt(M.exp)} EXP`, cx, 110, '#74c0fc', 12);
      this.addText(`+${U.fmt(gold)} 🪙`, cx, 130, '#ffd43b', 12);
      this.burst(cx, 220, M.def.pal.G || M.def.pal.S, M.isBoss ? 30 : 14);

      if (M.isBoss) {
        this.boss.active = false;
        s.records.bossKills++;
        this.pendingAdvance = true;
        this.log(`🏆 ${M.name} yenildi! ${L.worlds.label(p.stage)} tamamlandı.`, 'good');
      } else if (p.stage === p.maxStage && p.kills < L.balance.killsForBoss) {
        p.kills++;
        if (p.kills === L.balance.killsForBoss) this.log('👹 Boss çağırmaya hazırsın!', 'boss');
      }
    },

    afterKill() {
      const p = this.prog;
      if (this.pendingAdvance) {
        this.pendingAdvance = false;
        if (p.stage === p.maxStage) { p.maxStage++; p.kills = 0; }
        p.stage++;
        this.player.hp = L.player.derived().maxHp;
        const w = L.worlds.forStage(p.stage);
        this.log(`➡️ ${L.worlds.label(p.stage)} · ${w.name} bölümüne geçtin.`, 'good');
        L.events.emit('stagechange');
        L.save.write();
      }
      if (p.autoBoss && this.canSummonBoss()) this.summonBoss();
      else this.spawn(false);
    },

    // --- efektler ---
    addText(text, x, y, color, size) {
      this.texts.push({ text, x, y, color, size, life: 1, vy: -40 });
    },

    burst(x, y, color, n) {
      for (let i = 0; i < n; i++) {
        this.particles.push({
          x, y, vx: U.rand(-160, 160), vy: U.rand(-260, -60),
          life: U.rand(0.4, 0.8), color: Math.random() < 0.3 ? '#ffd43b' : color, s: 4 + 4 * Math.floor(Math.random() * 2),
        });
      }
    },

    updateEffects(dt) {
      for (const t of this.texts) { t.life -= dt; t.y += t.vy * dt; }
      this.texts = this.texts.filter((t) => t.life > 0);
      for (const p of this.particles) { p.life -= dt; p.vy += 600 * dt; p.x += p.vx * dt; p.y += p.vy * dt; }
      this.particles = this.particles.filter((p) => p.life > 0 && p.y < 280);
      for (const s of this.slashes) s.life -= dt;
      this.slashes = this.slashes.filter((s) => s.life > 0);
    },

    log(msg, kind) { L.events.emit('log', { msg, kind }); },
  };
})(window.Lumora);

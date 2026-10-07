// Oyuncu: level, EXP, stat puanları, yetenek ağacı ve bunlardan türeyen savaş değerleri.
(function (L) {
  L.player = {
    statDefs: [
      { id: 'str', name: 'Güç', icon: '⚔️', desc: 'Hasar +3' },
      { id: 'vit', name: 'Dayanıklılık', icon: '❤️', desc: 'Can +15' },
      { id: 'agi', name: 'Çeviklik', icon: '💨', desc: 'Saldırı hızı +%5' },
      { id: 'luck', name: 'Şans', icon: '🍀', desc: 'Kritik +%1, Altın +%2' },
    ],

    get p() { return L.save.data.player; },

    skill(id) { return (this.p.skills && this.p.skills[id]) || 0; },

    derived() {
      const B = L.balance.player, p = this.p, s = p.stats, k = (id) => this.skill(id);
      const baseDmg = B.baseDmg + s.str * B.dmgPerStr + p.level * B.dmgPerLevel;
      const baseHp = B.baseHp + s.vit * B.hpPerVit + p.level * B.hpPerLevel;
      return {
        damage: Math.round(baseDmg * (1 + 0.1 * k('sharp'))),
        maxHp: Math.round(baseHp * (1 + 0.1 * k('thickSkin'))),
        interval: Math.max(B.minInterval, B.baseInterval / (1 + s.agi * B.agiSpeed)),
        crit: Math.min(B.maxCrit, B.baseCrit + s.luck * B.critPerLuck),
        critMult: B.critMult + 0.25 * k('critMaster'),
        heavyStrike: k('heavy') > 0,
        regenPct: B.regenPct + 0.005 * k('regen'),
        damageTaken: 1 - 0.08 * k('ironWill'),
        goldMult: 1 + s.luck * B.goldPerLuck + 0.1 * k('greed'),
        expMult: 1 + 0.1 * k('wisdom'),
        bossTime: L.balance.bossTime + 5 * k('bossHunter'),
      };
    },

    expNeeded() { return L.balance.expToNext(this.p.level); },

    addExp(amount) {
      const p = this.p;
      p.exp += amount;
      let gained = 0;
      while (p.exp >= this.expNeeded()) {
        p.exp -= this.expNeeded();
        p.level++;
        p.points += L.balance.pointsPerLevel;
        p.skillPoints += L.balance.skillPointsPerLevel;
        gained++;
      }
      if (gained) L.events.emit('levelup', { level: p.level, levels: gained });
    },

    addGold(amount) { this.p.gold += amount; },

    spendPoint(statId, count = 1) {
      const p = this.p;
      const n = Math.min(count, p.points);
      if (n <= 0 || !(statId in p.stats)) return false;
      p.stats[statId] += n;
      p.points -= n;
      L.events.emit('statchange', { statId });
      return true;
    },

    // Yetenek ağacı
    canLearn(id) {
      const sk = L.skills.get(id);
      if (!sk || this.p.skillPoints <= 0 || this.skill(id) >= sk.max) return false;
      return !sk.requires || this.skill(sk.requires) > 0;
    },

    learn(id) {
      if (!this.canLearn(id)) return false;
      this.p.skills[id] = this.skill(id) + 1;
      this.p.skillPoints--;
      L.events.emit('skillchange', { id });
      return true;
    },

    resetSkills() {
      const p = this.p;
      for (const id in p.skills) p.skillPoints += p.skills[id];
      p.skills = {};
      L.events.emit('skillchange', {});
    },
  };
})(window.Lumora);

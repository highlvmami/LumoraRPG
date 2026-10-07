// Oyuncu: level, EXP, yetenek puanları ve bunlardan türeyen savaş değerleri.
(function (L) {
  L.player = {
    statDefs: [
      { id: 'str', name: 'Güç', icon: '⚔️', desc: 'Hasar +3' },
      { id: 'vit', name: 'Dayanıklılık', icon: '❤️', desc: 'Can +15' },
      { id: 'agi', name: 'Çeviklik', icon: '💨', desc: 'Saldırı hızı +%5' },
      { id: 'luck', name: 'Şans', icon: '🍀', desc: 'Kritik +%1, Altın +%2' },
    ],

    get p() { return L.save.data.player; },

    derived() {
      const B = L.balance.player, p = this.p, s = p.stats;
      return {
        damage: B.baseDmg + s.str * B.dmgPerStr + p.level * B.dmgPerLevel,
        maxHp: B.baseHp + s.vit * B.hpPerVit + p.level * B.hpPerLevel,
        interval: Math.max(B.minInterval, B.baseInterval / (1 + s.agi * B.agiSpeed)),
        crit: Math.min(B.maxCrit, B.baseCrit + s.luck * B.critPerLuck),
        critMult: B.critMult,
        goldMult: 1 + s.luck * B.goldPerLuck,
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
  };
})(window.Lumora);

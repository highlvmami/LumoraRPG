// Oyun dengesi: tüm sayılar burada. Oyunu ayarlamak için çoğu zaman sadece bu dosyayı değiştirmek yeter.
(function (L) {
  L.balance = {
    stagesPerWorld: 10,     // her dünyada kaç bölüm var (1-1 ... 1-10)
    killsForBoss: 10,       // boss çağırmak için gereken mob sayısı
    bossTime: 30,           // boss'u kesmek için saniye
    respawnTime: 2,         // ölünce yeniden doğma süresi (sn)
    pointsPerLevel: 3,      // level başına stat puanı
    skillPointsPerLevel: 1, // level başına yetenek ağacı puanı

    expToNext: (level) => Math.floor(12 * Math.pow(level, 1.7)),

    // Bölüm indeksi i (0 = 1-1) için canavar değerleri: base * scale^i
    monsterBase: { hp: 18, dmg: 4, exp: 6, gold: 4, atkInterval: 1.6 },
    monsterScale: { hp: 1.2, dmg: 1.17, exp: 1.16, gold: 1.16 },
    boss: { hp: 10, dmg: 1.6, exp: 6, gold: 8 }, // normal canavara göre çarpanlar

    player: {
      baseDmg: 4, dmgPerStr: 3, dmgPerLevel: 1,
      baseHp: 40, hpPerVit: 15, hpPerLevel: 5,
      baseInterval: 1.0, agiSpeed: 0.05, minInterval: 0.25,
      baseCrit: 0.05, critPerLuck: 0.01, maxCrit: 0.5, critMult: 2,
      goldPerLuck: 0.02,
      regenPct: 0.01,       // saniyede max canın %1'i yenilenir
    },
  };
})(window.Lumora);

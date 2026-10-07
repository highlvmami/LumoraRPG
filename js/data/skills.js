// Yetenek ağacı. Her level 1 yetenek puanı verir (balance.skillPointsPerLevel).
// Bir yeteneği açmak için `requires` içindeki yeteneğin en az 1 seviyesi olmalı.
// Etkiler js/systems/player.js'teki derived() içinde uygulanır.
(function (L) {
  L.skills = {
    branches: [
      { id: 'war', name: 'Savaş', color: '#fa5252' },
      { id: 'guard', name: 'Savunma', color: '#4dabf7' },
      { id: 'fortune', name: 'Servet', color: '#fab005' },
    ],
    list: [
      // Savaş
      { id: 'sharp', branch: 'war', tier: 1, icon: '🗡️', name: 'Keskin Kılıç', max: 5,
        desc: (r) => `Hasar +%${r * 10}`, next: '+%10 hasar' },
      { id: 'critMaster', branch: 'war', tier: 2, icon: '💥', name: 'Kritik Ustalığı', max: 3, requires: 'sharp',
        desc: (r) => `Kritik hasarı +%${r * 25}`, next: '+%25 kritik hasarı' },
      { id: 'heavy', branch: 'war', tier: 3, icon: '🔨', name: 'Ağır Darbe', max: 1, requires: 'critMaster',
        desc: () => 'Her 5. vuruş 3 kat hasar', next: 'Her 5. vuruş 3 kat hasar verir' },
      // Savunma
      { id: 'thickSkin', branch: 'guard', tier: 1, icon: '🛡️', name: 'Kalın Deri', max: 5,
        desc: (r) => `Can +%${r * 10}`, next: '+%10 maksimum can' },
      { id: 'regen', branch: 'guard', tier: 2, icon: '💚', name: 'Yenilenme', max: 3, requires: 'thickSkin',
        desc: (r) => `Saniyede +%${(r * 0.5).toFixed(1)} can`, next: 'Saniyede +%0.5 can yenilenmesi' },
      { id: 'ironWill', branch: 'guard', tier: 3, icon: '🪨', name: 'Demir İrade', max: 3, requires: 'regen',
        desc: (r) => `Alınan hasar -%${r * 8}`, next: 'Alınan hasar -%8' },
      // Servet
      { id: 'greed', branch: 'fortune', tier: 1, icon: '🪙', name: 'Altın Avcısı', max: 5,
        desc: (r) => `Altın +%${r * 10}`, next: '+%10 altın' },
      { id: 'wisdom', branch: 'fortune', tier: 2, icon: '📖', name: 'Bilgelik', max: 5, requires: 'greed',
        desc: (r) => `EXP +%${r * 10}`, next: '+%10 EXP' },
      { id: 'bossHunter', branch: 'fortune', tier: 3, icon: '⏳', name: 'Boss Avcısı', max: 2, requires: 'wisdom',
        desc: (r) => `Boss süresi +${r * 5} sn`, next: 'Boss süresi +5 saniye' },
    ],
    get(id) { return this.list.find((s) => s.id === id); },
  };
})(window.Lumora);

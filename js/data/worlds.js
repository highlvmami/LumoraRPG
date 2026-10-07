// Dünyalar. Her dünya balance.stagesPerWorld bölümden oluşur.
// Tanımlı son dünyadan sonra gelen bölümler son dünyayı (daha güçlü canavarlarla) kullanır.
(function (L) {
  L.worlds = {
    list: [
      {
        name: 'Goblin Ormanı',
        monsters: [
          { id: 'goblin', weight: 6 },
          { id: 'goblin_warrior', weight: 2 },
          { id: 'goblin_shaman', weight: 2 },
        ],
        boss: 'goblin_chief',
        bg: 'forest',
      },
      {
        name: 'Balçık Bataklığı',
        monsters: [
          { id: 'slime_blue', weight: 6 },
          { id: 'slime_poison', weight: 2 },
          { id: 'slime_fire', weight: 2 },
        ],
        boss: 'slime_king',
        bg: 'swamp',
      },
    ],

    // Bölüm indeksi (0 tabanlı) -> dünya
    forStage(i) {
      const idx = Math.floor(i / L.balance.stagesPerWorld);
      return this.list[Math.min(idx, this.list.length - 1)];
    },

    // 0 -> "1-1", 10 -> "2-1"
    label(i) {
      const n = L.balance.stagesPerWorld;
      return `${Math.floor(i / n) + 1}-${(i % n) + 1}`;
    },
  };
})(window.Lumora);

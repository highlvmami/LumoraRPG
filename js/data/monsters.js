// Canavar tanımları. hp/dmg/exp/gold, bölüm değerine uygulanan çarpanlardır.
// Yeni canavar: sprite seç (js/data/sprites.js), renk paletini ver, bir dünyanın listesine ekle.
(function (L) {
  const OUT = '#141018';

  L.monsters = {
    // --- Dünya 1: Goblin Ormanı ---
    goblin: {
      name: 'Goblin', sprite: 'goblin',
      pal: { O: OUT, G: '#6abe30', R: '#ff3b3b', W: '#ffffff', L: '#8f563b' },
      hp: 1, dmg: 1, exp: 1, gold: 1,
    },
    goblin_warrior: {
      name: 'Goblin Savaşçı', sprite: 'goblin',
      pal: { O: OUT, G: '#4b8b1f', R: '#ffd43b', W: '#ffffff', L: '#868e96' },
      hp: 1.4, dmg: 1.2, exp: 1.3, gold: 1.3,
    },
    goblin_shaman: {
      name: 'Goblin Şaman', sprite: 'goblin',
      pal: { O: OUT, G: '#8fce9a', R: '#da77f2', W: '#ffffff', L: '#76428a' },
      hp: 0.9, dmg: 1.5, exp: 1.3, gold: 1.4,
    },
    goblin_chief: {
      name: 'Goblin Şefi', sprite: 'goblin', crownY: 1,
      pal: { O: OUT, G: '#3f7a1a', R: '#ff3b3b', W: '#ffffff', L: '#ac3232', Y: '#ffd43b' },
      hp: 1, dmg: 1, exp: 1, gold: 1,
    },

    // --- Dünya 2: Balçık Bataklığı ---
    slime_blue: {
      name: 'Mavi Balçık', sprite: 'slime',
      pal: { O: OUT, S: '#4dabf7', W: '#e7f5ff' },
      hp: 1, dmg: 1, exp: 1, gold: 1,
    },
    slime_poison: {
      name: 'Zehirli Balçık', sprite: 'slime',
      pal: { O: OUT, S: '#94d82d', W: '#f4fce3' },
      hp: 1.1, dmg: 1.4, exp: 1.3, gold: 1.2,
    },
    slime_fire: {
      name: 'Ateş Balçığı', sprite: 'slime',
      pal: { O: OUT, S: '#ff6b6b', W: '#fff5f5' },
      hp: 1.5, dmg: 1.2, exp: 1.4, gold: 1.4,
    },
    slime_king: {
      name: 'Balçık Kralı', sprite: 'slime', crownY: 6,
      pal: { O: OUT, S: '#9775fa', W: '#f3f0ff', Y: '#ffd43b', R: '#e03131' },
      hp: 1, dmg: 1, exp: 1, gold: 1,
    },
  };
})(window.Lumora);

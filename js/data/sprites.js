// Piksel sanat haritaları. Her karakter bir renk anahtarıdır, '.' saydamdır.
// Küçük harf, aynı büyük harfin otomatik koyu (gölge) tonudur: 't' = koyu tişört rengi.
//
// Oyuncu (16x28): O kontur, S ten, E göz, T tişört, P pantolon, B ayakkabı,
//                 H saç, C şapka, D şapka süsü, W kılıç, G kabza, R sap
(function (L) {
  const S = {};

  S.player = {
    width: 16,
    height: 28,
    base: [
      '................',
      '................',
      '................',
      '................',
      '................',
      '................',
      '................',
      '................',
      '.....OOOOOO.....',
      '....OSSSSSSO....',
      '....OSSSSSSO....',
      '....OSSSSESO....',
      '....OSSSSESO....',
      '....OsSSSSSO....',
      '.....OsSSSO.....',
      '......OssO......',
      '....OOTTTTOO....',
      '...OTTTTTTTtO...',
      '...OTTTTTTTtO...',
      '...OtOTTTtOtO...',
      '...OSOTTTtOSO...',
      '...OOOPPPpOOO...',
      '.....OPPPpO.....',
      '.....OPPPpO.....',
      '.....OPOOpO.....',
      '.....OPOOpO.....',
      '....OBBOObBO....',
      '....OOOOOOOO....',
    ],

    hair: {
      bald: null,
      short: { y0: 7, rows: [
        '.....HHHHHH.....',
        '....HHHHHHHH....',
        '....HHHHHHh.....',
        '....HH..........',
        '....H...........',
      ] },
      long: { y0: 7, rows: [
        '.....HHHHHH.....',
        '....HHHHHHHH....',
        '...HHHHHHHHh....',
        '...HHh..........',
        '...HHh..........',
        '...HHh..........',
        '...HHh..........',
        '...HHh..........',
        '...Hh...........',
        '...Hh...........',
      ] },
      spiky: { y0: 5, rows: [
        '.....H..H.......',
        '....HH.HH.H.....',
        '....HHHHHHHH....',
        '...HHHHHHHHHH...',
        '....HHHHHHh.....',
        '....HH..........',
      ] },
      ponytail: { y0: 7, rows: [
        '.....HHHHHH.....',
        '....HHHHHHHH....',
        '...HHHHHHHh.....',
        '..HHh...........',
        '.HHh............',
        '.Hh.............',
        '.h..............',
      ] },
    },

    hats: {
      none: null,
      cap: { y0: 6, rows: [
        '.....CCCCC......',
        '....CCCCCDC.....',
        '....cCCCCCCCCC..',
      ] },
      wizard: { y0: 0, rows: [
        '..........C.....',
        '.........CC.....',
        '........CCC.....',
        '.......CCDC.....',
        '......CCCCCC....',
        '.....CCDDCCC....',
        '.....cCCCCCC....',
        '...cCCCCCCCCCC..',
      ] },
      helmet: { y0: 4, rows: [
        '.......DD.......',
        '......CCCC......',
        '.....CCCCCC.....',
        '....CCCCCCCC....',
        '....CCCCCCCC....',
        '....Cc.....C....',
        '....Cc..........',
      ] },
      crown: { y0: 4, rows: [
        '....C..C..C.....',
        '....CCCCCCC.....',
        '....CDCCCDC.....',
        '....cCCCCCc.....',
      ] },
      bandana: { y0: 8, rows: [
        '....CCCCCCCC....',
        '...CCDCCDCCc....',
        '..CC............',
        '.Cc.............',
      ] },
    },

    weapon: { y0: 12, rows: [
      '............W...',
      '............W...',
      '............W...',
      '............W...',
      '............w...',
      '...........GGG..',
      '............R...',
      '............R...',
    ] },
  };

  // Canavarlar (16 genişlik). O kontur, G deri, R göz, W diş, L giysi/zırh
  S.goblin = [
    '................',
    '................',
    '................',
    '..OO........OO..',
    '..OGO.OOOO.OGO..',
    '...OGOGGGGOGO...',
    '....OGGGGGGO....',
    '....OGRGGRgO....',
    '....OGGGGGgO....',
    '....OGOWWOgO....',
    '.....OGGGgO.....',
    '....OLLLLLlO....',
    '...OGOLLLlOGO...',
    '...OGOLLLlOgO...',
    '...OOOLLLlOOO...',
    '.....OGgOGgO....',
    '.....OGO.OgO....',
    '....OOGO.OgOO...',
    '....OOOO.OOOO...',
  ];

  // Balçık (16x19). S gövde, W parlama, O kontur/göz
  S.slime = [
    '................',
    '................',
    '................',
    '................',
    '................',
    '................',
    '................',
    '................',
    '................',
    '......OOOO......',
    '....OOSSSSOO....',
    '...OSSSSSSSsO...',
    '..OSSWSSSSSSsO..',
    '..OSWSSSSSSSsO..',
    '.OSSSOSSSSOSSsO.',
    '.OSSSSSSSSSSSsO.',
    '.OSSSSSSSSSSssO.',
    '..OsssssssssssO.',
    '...OOOOOOOOOOO..',
  ];

  // Boss tacı (canavarın üstüne bindirilir). Y altın, R mücevher
  S.bossCrown = [
    '.....Y.YY.Y.....',
    '.....YYYYYY.....',
    '.....YRYYRy.....',
  ];

  L.sprites = S;
})(window.Lumora);

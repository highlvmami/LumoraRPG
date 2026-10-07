// Piksel sanat haritaları. Her karakter bir renk anahtarıdır, '.' saydamdır.
// Küçük harf, aynı büyük harfin otomatik koyu (gölge) tonudur: 't' = koyu tişört rengi.
//
// (Oyuncu karakteri artık js/render/character.js'te çiziliyor.)
(function (L) {
  const S = {};

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
